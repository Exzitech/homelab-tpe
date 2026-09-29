#!/bin/sh
# VM : export complet de Paperless (originaux, versions OCR, base en JSON) dans
# $DONNEES/backups/paperless, reimportable par document_importer, meme dans une version plus
# recente de Paperless. Miroir incremental : seuls les fichiers changes sont reecrits, les
# documents supprimes en sortent.
set -eu
. /etc/homelab.conf
docker exec paperless document_exporter ../export --delete --no-thumbnail --no-progress-bar
echo "OK $(date +%F\ %T) : $(du -sh "$DONNEES/backups/paperless" | cut -f1)"
