#!/bin/sh
# Hote Proxmox : crochet du job de sauvegarde vzdump (option "script" du job, dans
# /etc/pve/jobs.cfg). Envoie a healthchecks.io (check "vzdump") le debut du job puis sa fin,
# en echec si une seule machine a echoue, avec la liste des machines en cause.
# Doit TOUJOURS sortir en 0 : un code non nul ferait echouer la sauvegarde elle-meme.
[ -r /etc/homelab.conf ] && . /etc/homelab.conf
phase=$1
cle=$(cat "${HC_CLE_FICHIER:-/etc/healthchecks-ping-key}" 2>/dev/null) || exit 0
url="${HC_URL:-https://hc-ping.com}/$cle/vzdump"
echecs=/run/vzdump-signal.echecs
ping() { curl -fsS -m 10 --retry 3 -o /dev/null "$@" || echo "vzdump-signal: signal non envoye" >&2; }
case $phase in
  job-start)    : > "$echecs"; ping "$url/start" ;;
  backup-abort) echo "echec de la sauvegarde de $3" >> "$echecs" ;;   # arguments : phase mode vmid
  job-end)      if [ -s "$echecs" ]; then ping --data-binary @"$echecs" "$url/fail"; else ping "$url"; fi ;;
  job-abort)    ping --data-raw "job vzdump interrompu" "$url/fail" ;;
esac
exit 0
