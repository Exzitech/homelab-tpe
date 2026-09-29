#!/bin/sh
# VM : sauvegarde quotidienne du coffre Vaultwarden (14 copies) dans $DONNEES/backups/vaultwarden.
# Le coffre est chiffre cote client : sans les mots de passe maitres, l'archive est illisible ;
# rsa_key.pem sert seulement a garder les sessions valides apres une restauration.
# dernier.tar.gz = copie de la plus recente, a chemin fixe, pour l'envoi hors site nocturne
# (restic regroupe les instantanes par chemin : un nom horodate creerait un groupe par jour).
set -eu
. /etc/homelab.conf
umask 077
SRC="$DONNEES/vaultwarden"
DEST="$DONNEES/backups/vaultwarden"
mkdir -p "$DEST"
# copie coherente de la base SQLite par Vaultwarden lui-meme (data/db_AAAAMMJJ_HHMMSS.sqlite3)
docker exec vaultwarden /vaultwarden backup 2>/dev/null | grep -q "was successful" \
  || { echo "ECHEC: copie de la base" >&2; exit 1; }
DB=$(ls -1t "$SRC"/db_*.sqlite3 | head -1)
F="$DEST/vaultwarden-$(date +%Y%m%d-%H%M).tar.gz"
cd "$SRC"
tar -czf "$F.tmp" "$(basename "$DB")" rsa_key.pem $(ls -d config.json attachments sends 2>/dev/null || true)
mv "$F.tmp" "$F"
cp "$F" "$DEST/dernier.tar.gz"
rm -f "$SRC"/db_*.sqlite3
ls -1t "$DEST"/vaultwarden-*.tar.gz | tail -n +15 | xargs -r rm -f
echo "OK $(date +%F\ %T)"
