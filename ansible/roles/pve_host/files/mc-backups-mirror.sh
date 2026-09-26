#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HC=$(awk '$1=="mc-backups-mirror"{print $2}' /root/scripts/hc-urls.txt)
curl -fsS -m10 -o /dev/null "$HC/start" 2>/dev/null
if rsync -a --delete /mnt/nfs-share/minecraft-backups/ /mnt/pve/backup-storage/minecraft-world/; then
  curl -fsS -m10 --retry 3 -o /dev/null "$HC" 2>/dev/null
else
  curl -fsS -m10 --retry 3 -o /dev/null "$HC/fail" 2>/dev/null
  exit 1
fi
