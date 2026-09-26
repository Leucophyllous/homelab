#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
set -o pipefail
set -a; . /root/scripts/.env; set +a
export RESTIC_CACHE_DIR=/var/cache/restic RESTIC_REPOSITORY="s3:${OCI_S3_ENDPOINT}/homelab-offsite"
restic(){ command restic -o s3.region=ap-tokyo-1 -o s3.bucket-lookup=path "$@"; }
HC=$(awk '$1=="offsite-backup"{print $2}' /root/scripts/hc-urls.txt)
S=/var/tmp/offsite-stage; O="-o BatchMode=yes -o ConnectTimeout=15"
LOG=/var/log/offsite-backup.log
fail(){ echo "FAIL: $1" >> $LOG; curl -fsS -m10 -o /dev/null --data-raw "$1" "$HC/fail"; exit 1; }
curl -fsS -m10 -o /dev/null "$HC/start" || true
mountpoint -q /mnt/pve/backup-storage || fail "backup-storage not mounted"
rm -rf $S; mkdir -p $S/docker-vm $S/minecraft; chmod 700 $S
ssh $O leila@192.168.0.113 'sudo tar czf - -C /opt --exclude=stacks/ilust/data --exclude=stacks/monitoring/prometheus --exclude=stacks/monitoring/grafana --warning=no-file-changed stacks; r=$?; [ $r -le 1 ]' > $S/docker-vm/stacks.tar.gz || fail "docker-vm stacks"
ssh $O leila@192.168.0.113 'sudo cat /opt/stacks/monitoring/grafana/data/grafana.db' > $S/docker-vm/grafana.db || fail "grafana.db"
w=$(ls -t /mnt/nfs-share/minecraft-backups/world-*.tar.gz 2>/dev/null | head -1); [ -n "$w" ] && ln -f "$w" $S/minecraft/latest-world.tar.gz 2>/dev/null || cp "$w" $S/minecraft/latest-world.tar.gz
restic backup --no-scan -q --tag daily $S /mnt/pve/backup-storage/host-config /mnt/pve/backup-storage/vm-data /etc /root/scripts /root/ansible >> $LOG 2>&1 || fail "restic backup rc=$?"
restic forget -q --keep-daily 7 --keep-weekly 4 --keep-monthly 6 >> $LOG 2>&1 || fail "restic forget"
[ "$(date +%u)" = 7 ] && { restic prune -q >> $LOG 2>&1 || fail "restic prune"; }
[ "$(date +%d)" = 01 ] && { restic check -q >> $LOG 2>&1 || fail "restic check"; }
rm -rf $S
echo "OK $(date)" >> $LOG
curl -fsS -m10 --retry 3 -o /dev/null "$HC"
