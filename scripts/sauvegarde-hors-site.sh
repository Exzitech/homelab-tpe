#!/bin/sh
# VM : copie hors site chiffree avec restic (cloud via rclone, ou machine distante en sftp).
# Usage : sauvegarde-hors-site.sh <etiquette> <chemin>...
#   hebdomadaire : sauvegarde-hors-site.sh complet /srv/data/backups /srv/data/nextcloud/html/data
#   nocturne     : sauvegarde-hors-site.sh coffre /srv/data/backups/vaultwarden/dernier.tar.gz
# Chaque etiquette a sa propre retention (7 jours, 4 semaines, 6 mois) : le menage d'une
# etiquette ne touche jamais aux instantanes d'une autre.
# Garde-fou : refuse d'envoyer plus de HORS_SITE_MAX_GO (quota du stockage, duree d'envoi).
set -eu
. /etc/homelab.conf
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE
umask 077
tag=$1; shift
[ $# -gt 0 ] || { echo "usage: $0 <etiquette> <chemin>..." >&2; exit 2; }

# miniatures Nextcloud et journaux : regenerables ou sans valeur, exclus de l'envoi et du calcul
ko=$(du -sck --exclude 'preview' --exclude '*.log' "$@" | tail -1 | cut -f1)
[ "$ko" -le $((HORS_SITE_MAX_GO * 1024 * 1024)) ] \
  || { echo "ECHEC: $((ko / 1024 / 1024)) Go a envoyer, limite $HORS_SITE_MAX_GO Go" >&2; exit 1; }

restic backup "$@" --tag "$tag" --exclude 'appdata_*/preview' --exclude '*.log' --quiet
restic forget --tag "$tag" --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune --quiet
echo "OK $(date +%F\ %T) : $tag, $((ko / 1024)) Mo"
