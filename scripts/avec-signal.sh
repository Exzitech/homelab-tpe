#!/bin/sh
# Enrobe une tache planifiee et envoie son resultat a healthchecks.io (check <nom>) : debut, puis
# code de sortie et fin du journal. Un echec, ou un signal qui n'arrive pas (tache bloquee, machine
# eteinte, plus d'internet), declenche la notification (e-mail, ntfy...).
# Usage (cron) : avec-signal.sh <nom> <commande> [args...]  -> meme sortie et meme code que <commande>.
# Sans cle ou sans internet, la tache s'execute quand meme : seul le signal manque, et c'est
# justement ce qui alerte.
set -u
[ -r /etc/homelab.conf ] && . /etc/homelab.conf
nom=$1; shift
cle=$(cat "${HC_CLE_FICHIER:-/etc/healthchecks-ping-key}" 2>/dev/null) || exec "$@"
url="${HC_URL:-https://hc-ping.com}/$cle/$nom"
curl -fsS -m 10 --retry 3 -o /dev/null "$url/start" || echo "avec-signal: signal de debut non envoye" >&2
sortie=$(mktemp)
"$@" > "$sortie" 2>&1
rc=$?
cat "$sortie"
# healthchecks accepte le code de sortie comme URL (0 = succes, autre = echec)
tail -c 10000 "$sortie" | curl -fsS -m 10 --retry 3 -o /dev/null --data-binary @- "$url/$rc" \
  || echo "avec-signal: signal de fin non envoye" >&2
rm -f "$sortie"
exit $rc
