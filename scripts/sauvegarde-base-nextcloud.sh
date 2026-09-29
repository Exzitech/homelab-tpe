#!/bin/sh
# VM : export quotidien de la base Nextcloud (7 copies) dans $DONNEES/backups/db, que l'hote
# recopie ensuite sur son disque de sauvegarde (sauvegarde-vm-fichiers.sh).
# --single-transaction : copie coherente sans arreter Nextcloud (tables InnoDB).
set -eu
. /etc/homelab.conf
umask 077
DEST="$DONNEES/backups/db"
mkdir -p "$DEST"
F="$DEST/nextcloud-$(date +%Y%m%d-%H%M).sql.gz"
docker exec nextcloud-db sh -c 'exec mariadb-dump --single-transaction -uroot -p"$MYSQL_ROOT_PASSWORD" nextcloud' \
  | gzip > "$F.tmp"
# un export sans la ligne finale "Dump completed" est tronque : on le rejette plutot que de
# remplacer une bonne copie par une mauvaise
if zcat "$F.tmp" | tail -1 | grep -q "Dump completed"; then mv "$F.tmp" "$F"
else rm -f "$F.tmp"; echo "ECHEC: export tronque" >&2; exit 1; fi
ls -1t "$DEST"/nextcloud-*.sql.gz | tail -n +8 | xargs -r rm -f
echo "OK $(date +%F\ %T) : $(du -h "$F" | cut -f1)"
