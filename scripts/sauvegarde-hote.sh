#!/bin/sh
# Hote Proxmox : archive quotidienne de la configuration de l'hote (7 copies) sur le disque de
# sauvegarde. /etc contient /etc/pve (configs des VM et LXC, jobs), le reseau et les taches cron ;
# /usr/local/bin contient ces scripts. De quoi reconstruire l'hote apres une reinstallation.
set -eu
. /etc/homelab.conf
umask 077
mountpoint -q "$SAUVEGARDES" || { echo "ECHEC: disque de sauvegarde non monte" >&2; exit 1; }
D="$SAUVEGARDES/hote"
mkdir -p "$D"
F="$D/hote-$(date +%Y%m%d-%H%M).tar.gz"
tar -czf "$F.tmp" -C / etc usr/local/bin
mv "$F.tmp" "$F"
ls -1t "$D"/hote-*.tar.gz | tail -n +8 | xargs -r rm -f
echo "OK $(date +%F\ %T) : $(du -h "$F" | cut -f1)"
