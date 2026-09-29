#!/bin/sh
# VM, toutes les 5 min : Paperless supprime les fichiers qu'il avale dans les dossiers d'entree
# de Nextcloud sans passer par Nextcloud. Ce rescan cible les retire de son index (sinon ils
# restent affiches, et les clients de synchronisation tentent de les telecharger).
# Usage : nextcloud-rescan.sh "/alice/files/A classer" [...]   (chemins vus par Nextcloud, ~1 s)
set -eu
for p in "$@"; do
  docker exec -u www-data nextcloud php occ files:scan --path="$p" -q
done
