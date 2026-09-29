#!/bin/sh
# Hote Proxmox : copie les fichiers utiles de la VM sur le disque de sauvegarde (miroir rsync).
# Remplace la sauvegarde du disque de donnees dans le vzdump (disque en backup=0) : le vzdump ne
# garde que le systeme de la VM, et on choisit ici ce qui merite d'etre copie.
# Sens unique : l'hote tire depuis la VM, la VM n'a AUCUN acces a l'hote ni aux sauvegardes.
# Une VM compromise ne peut donc ni lire ni effacer ses propres sauvegardes.
# Cote VM : cle $VM_CLE dans authorized_keys avec from="<ip de l'hote>", et une regle sudoers
# limitee a rsync pour ce compte.
set -eu
. /etc/homelab.conf
mountpoint -q "$SAUVEGARDES" || { echo "ECHEC: disque de sauvegarde non monte" >&2; exit 1; }
D="$SAUVEGARDES/vm-fichiers"
mkdir -p "$D"; chmod 700 "$D"
umask 077
SSH="ssh -i $VM_CLE -o BatchMode=yes"

# Exports des bases et des coffres, piles compose (avec leurs .env), Nextcloud (config et
# fichiers, sans les miniatures regenerables), reverse proxy (hotes et certificats), taches cron.
for s in "$DONNEES/backups" "$DONNEES/stack" "$DONNEES/nextcloud/html/config" "$DONNEES/nextcloud/html/data" \
         "$DONNEES/npm" /etc/cron.d /usr/local/bin; do
  rsync -a --delete --relative --rsh="$SSH" --rsync-path="sudo rsync" \
    --exclude "$DONNEES/nextcloud/html/data/appdata_*/preview" \
    --exclude "$DONNEES/nextcloud/html/data/*.log" \
    "$VM_SSH:$s" "$D/"
done
echo "OK $(date +%F\ %T) : $(du -sh "$D" | cut -f1)"
