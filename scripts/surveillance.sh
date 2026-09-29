#!/bin/sh
# Hote Proxmox, toutes les 5 min : controle l'etat du serveur et envoie le resultat a
# healthchecks.io (check "serveur"). Rien a signaler -> signal OK ; sinon signal d'echec avec la
# liste des problemes. Si le signal n'arrive plus (hote eteint, carte reseau bloquee, plus
# d'internet), healthchecks alerte aussi : c'est la seule alerte qui ne depend pas du serveur.
set -u
. /etc/homelab.conf
# cron ne fournit pas /usr/sbin (qm, pct, lvs) : sans cette ligne, tout parait arrete
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
P=$(mktemp); trap 'rm -f "$P"' EXIT
pb() { echo "$*" >> "$P"; }

# Machines
[ "$(qm status "$VM_ID" | cut -d' ' -f2)" = running ] || pb "VM $VM_ID arretee"
for id in $LXC_IDS; do [ "$(pct status "$id" | cut -d' ' -f2)" = running ] || pb "LXC $id arrete"; done

# Services publics, par le nom de domaine (comme depuis l'exterieur) : reponse HTTP < 400 attendue
for u in $URLS; do
  c=$(curl -sS -o /dev/null -m 15 -w '%{http_code}' "$u" 2>/dev/null)
  [ "${c:-000}" -ge 200 ] && [ "$c" -lt 400 ] || pb "$u -> HTTP ${c:-000}"
done

# DNS local
[ -z "$DNS_LOCAL" ] || dig +short +time=3 +tries=2 @"$DNS_LOCAL" "$DNS_NOM" | grep -q . \
  || pb "DNS local ($DNS_LOCAL) ne repond pas"

# Certificats : le proxy les renouvelle seul ; il en reste moins de CERT_JOURS = renouvellement rate.
# On verifie le certificat SERVI, pas celui sur le disque.
for d in $CERTIFICATS; do
  echo | openssl s_client -connect "$PROXY_IP:443" -servername "$d" 2>/dev/null \
    | openssl x509 -noout -checkend $((CERT_JOURS * 86400)) >/dev/null 2>&1 \
    || pb "certificat $d : expire dans moins de $CERT_JOURS jours"
done

# Disques. Une mesure vide (commande en echec) est un probleme, pas un disque vide.
plein() { case ${2:-} in ""|*[!0-9]*) pb "$1 : mesure impossible" ;; *) [ "$2" -lt "$DISQUE_MAX" ] || pb "$1 plein a $2 %" ;; esac; }
pourcent() { awk 'NR==2 {sub("%","",$5); print $5}'; }   # lit la sortie de "df -P"
mountpoint -q "$SAUVEGARDES" || pb "disque de sauvegarde non monte"
plein "hote /" "$(df -P / 2>/dev/null | pourcent)"
plein "disque de sauvegarde" "$(df -P "$SAUVEGARDES" 2>/dev/null | pourcent)"
plein "thin pool" "$(lvs --noheadings -o data_percent pve/data 2>/dev/null | awk '{printf "%d", $1}')"
plein "VM $DONNEES" "$(ssh -i "$VM_CLE" -o BatchMode=yes -o ConnectTimeout=10 "$VM_SSH" df -P "$DONNEES" 2>/dev/null | pourcent)"
for id in $LXC_IDS; do plein "LXC $id /" "$(pct exec "$id" -- df -P / 2>/dev/null | pourcent)"; done

# Carte reseau Intel e1000e (voir docs/incident-carte-reseau.md) : le message suffit, meme si le
# lien est revenu entre-temps
journalctl -k --since "-6min" -q 2>/dev/null | grep -q "Hardware Unit Hang" && pb "carte reseau $NIC : Hardware Unit Hang"

cle=$(cat "$HC_CLE_FICHIER") || exit 1
url="$HC_URL/$cle/serveur"
if [ -s "$P" ]; then cat "$P"; curl -fsS -m 10 --retry 3 -o /dev/null --data-binary @"$P" "$url/fail"
else curl -fsS -m 10 --retry 3 -o /dev/null "$url"; fi
