#!/bin/bash
set -o pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. /root/scripts/.env
LOG=/var/log/gd-archive.log
B=/mnt/pve/backup-storage
CR=gdcrypt:
DUMP_KEEP_DAYS=90
MC_KEEP_DAYS=180
say(){ echo "$(date '+%F %T') $*" >> $LOG; }
tg(){ curl -s -m15 -o /dev/null --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$1" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"; }
exec 9>/var/lock/gd-archive.lock
flock -n 9 || exit 0
pgrep -f /root/gd-evac.sh >/dev/null && { say "SKIP evac running"; exit 0; }
mountpoint -q $B || { tg "⚠️ Drive退避を実行できない(backup-storageが未マウント)"; exit 1; }
rclone listremotes | grep -q '^gdcrypt:' || { tg "⚠️ Drive退避を実行できない(gdcrypt の設定が無い)"; exit 1; }

fails=0; moved=0
copy_files(){
  rclone copy "$1" "${CR}$2" --files-from "$3" --transfers 4 --drive-chunk-size 64M --drive-stop-on-upload-limit --low-level-retries 20 --retries 3 >> $LOG 2>&1
}
xfer(){
  local name="$1" base="$2" list="$3"
  [ -s "$list" ] || { say "SKIP $name (nothing)"; return 0; }
  local n; n=$(wc -l < "$list")
  say "START $name files=$n"
  if copy_files "$base" "$name" "$list" && rclone cryptcheck "$base" "${CR}$name" --files-from "$list" >> $LOG 2>&1; then
    (cd "$base" && tr '\n' '\0' < "$list" | xargs -0 rm -f --) && { say "DONE $name (verified, local removed)"; moved=$((moved+n)); }
  else
    say "FAIL $name (local kept)"; fails=$((fails+1))
  fi
}

l=$(mktemp)
(cd $B/dump && ls -1 vzdump-* 2>/dev/null | awk '{s=$0; sub(/\.(log|notes|tar\.zst|vma\.zst|tar\.gz|tar\.lzo|vma)$/,"",s); sub(/\.tar$/,"",s); t=s; sub(/^vzdump-/,"",t); split(t,a,"-"); k=a[1]"-"a[2]; if(!(k in m)||s>m[k])m[k]=s; f[NR]=$0; st[NR]=s; kk[NR]=k} END{for(i=1;i<=NR;i++) if(st[i]!=m[kk[i]]) print f[i]}') > $l
xfer nas-dump $B/dump $l

(cd $B/minecraft-world && ls -1t world-* 2>/dev/null | tail -n +3) > $l
xfer nas-minecraft-world $B/minecraft-world $l
rm -f $l

rclone delete "${CR}nas-dump" --min-age ${DUMP_KEEP_DAYS}d >> $LOG 2>&1 || fails=$((fails+1))
rclone delete "${CR}nas-minecraft-world" --min-age ${MC_KEEP_DAYS}d >> $LOG 2>&1 || fails=$((fails+1))

if [ $fails -eq 0 ]; then
  touch /var/lib/gd-archive.last
  say "=== ok moved=$moved ==="
  [ $moved -gt 0 ] && tg "☁️ Drive退避が完了(旧世代 ${moved} ファイルを暗号化して転送・検証・元を削除。Driveの保持: vzdump ${DUMP_KEEP_DAYS}日 / Minecraft ${MC_KEEP_DAYS}日)"
  exit 0
fi
tg "⚠️ Drive退避で ${fails} 件の失敗(元データは残してある)。pveの $LOG を確認"
exit 1
