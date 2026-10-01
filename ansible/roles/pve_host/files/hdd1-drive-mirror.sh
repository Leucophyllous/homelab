#!/bin/bash
set -o pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. /root/scripts/.env
LOG=/var/log/hdd1-drive-mirror.log
SRC=/mnt/hdd1/
DST=gdcrypt:nas-hdd1-backup
TRASH=gdcrypt:nas-hdd1-deleted
KEEP_DAYS=14
MAXDUR=${MAXDUR:-2h30m}
RETIRE=${RETIRE:-1}
B=/mnt/pve/backup-storage
OLD=$B/hdd1-backup
OLDTRASH=$B/hdd1-backup-deleted
STATE=/var/lib/hdd1-drive-mirror
HC=$(awk '$1=="hdd1-mirror"{print $2}' /root/scripts/hc-urls.txt)
F=(--no-unicode-normalization --fast-list --skip-links --exclude '$RECYCLE.BIN/**' --exclude 'System Volume Information/**')
say(){ echo "$(date '+%F %T') $*" >> $LOG; }
tg(){ curl -s -m15 -o /dev/null --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$1" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"; }
hc(){ [ -n "$HC" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC$1"; }
bump(){ local n; n=$(( $(cat "$STATE/$1" 2>/dev/null || echo 0) + 1 )); echo $n > "$STATE/$1"; echo $n; }
evac_oldtrash(){
  [ -d "$OLDTRASH" ] && mountpoint -q $B || return 0
  if rclone copy "$OLDTRASH" "$TRASH" "${F[@]}" --transfers 4 --tpslimit 5 --drive-chunk-size 64M --log-file $LOG --log-level NOTICE && rclone cryptcheck "$OLDTRASH" "$TRASH" "${F[@]}" --one-way --tpslimit 10 --log-file $LOG --log-level NOTICE; then
    rm -rf --one-file-system "$OLDTRASH" && say "UPLOADED+REMOVED $OLDTRASH"
  else
    say "FAIL upload $OLDTRASH (kept, retry next run)"
  fi
}

mkdir -p $STATE; touch $LOG
exec 9>/var/lock/hdd1-drive-mirror.lock
flock -n 9 || { say "SKIP already running"; exit 0; }
if ! mountpoint -q /mnt/hdd1 || [ -z "$(ls -A /mnt/hdd1 2>/dev/null)" ]; then
  say "FAIL /mnt/hdd1 not mounted or empty"; tg "⚠️ hdd1のDriveミラーを中止した(/mnt/hdd1が未マウントか空。Drive側は触っていない)"; hc /fail; exit 1
fi
rclone listremotes | grep -q '^gdcrypt:' || { say "FAIL gdcrypt missing"; tg "⚠️ hdd1のDriveミラーを実行できない(gdcryptの設定が無い)"; hc /fail; exit 1; }

say "START sync maxdur=$MAXDUR"
pos=$(stat -c %s $LOG)
rclone sync "$SRC" "$DST" "${F[@]}" --backup-dir "$TRASH/$(date +%F)" --transfers 4 --checkers 8 --tpslimit 5 --drive-chunk-size 64M --drive-stop-on-upload-limit --max-duration "$MAXDUR" --cutoff-mode soft --low-level-retries 20 --retries 3 --stats 30m --stats-one-line --stats-log-level NOTICE --log-file $LOG --log-level NOTICE
rc=$?
ret=0
if [ $rc -eq 0 ]; then
  say "OK sync complete"; echo 0 > $STATE/partial; hc ""
elif { [ $rc -eq 7 ] || [ $rc -eq 10 ]; } && tail -c +$((pos+1)) $LOG | grep -qE 'max transfer duration reached|upload limit|User rate limit exceeded'; then
  n=$(bump partial); say "PARTIAL rc=$rc run=$n (continues next run)"
  if [ $n -ge 7 ]; then tg "⚠️ hdd1のDriveミラーが${n}回続けて途中終了(Driveの上限か時間切れ)。pveの $LOG を確認"; hc /fail; ret=1; else hc ""; fi
else
  say "FAIL sync rc=$rc"; tg "⚠️ hdd1のDriveミラーが失敗した(exit $rc)。pveの $LOG を確認"; hc /fail; ret=$rc
fi

cut=$(date -d "-$KEEP_DAYS days" +%F)
for d in $(rclone lsf "$TRASH" --dirs-only 2>/dev/null | tr -d /); do
  if [[ $d =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ $d < $cut ]]; then
    rclone purge "$TRASH/$d" --log-file $LOG --log-level NOTICE && say "PURGED $TRASH/$d"
  fi
done

if [ -f $STATE/retired ]; then
  evac_oldtrash
elif [ $rc -eq 0 ] && [ "$RETIRE" = 1 ]; then
  say "VERIFY start"
  verify_full(){
    rm -f $STATE/differ $STATE/missing
    rclone cryptcheck "$SRC" "$DST" "${F[@]}" --one-way --checkers 8 --tpslimit 10 --differ $STATE/differ --missing-on-dst $STATE/missing --log-file $LOG --log-level NOTICE && return 0
    cat $STATE/differ $STATE/missing 2>/dev/null | sort -u > $STATE/fix
    [ -s $STATE/fix ] || return 1
    say "REUPLOAD $(wc -l < $STATE/fix) files that differ or are missing"
    rclone copy "$SRC" "$DST" "${F[@]}" --files-from $STATE/fix --ignore-times --backup-dir "$TRASH/$(date +%F)" --transfers 4 --tpslimit 5 --drive-chunk-size 64M --low-level-retries 20 --retries 3 --log-file $LOG --log-level NOTICE || return 1
    rclone cryptcheck "$SRC" "$DST" "${F[@]}" --one-way --files-from $STATE/fix --tpslimit 10 --log-file $LOG --log-level NOTICE
  }
  if verify_full; then
    say "VERIFIED"
    systemctl disable --now hdd1-backup.timer >> $LOG 2>&1
    systemctl stop hdd1-backup.service >> $LOG 2>&1
    if mountpoint -q $B && [ -d "$OLD" ]; then rm -rf --one-file-system "$OLD" && say "REMOVED $OLD"; fi
    touch $STATE/retired; echo 0 > $STATE/verifyfail
    evac_oldtrash
    tg "☁️ hdd1のDriveミラーの初回同期と検証が完了。ローカルミラー(hdd1-backup)を止めて削除し、削除退避分(hdd1-backup-deleted)もDriveへ移した。以後は毎日03:35にDriveへ同期(削除・上書きされた分は${KEEP_DAYS}日保持)"
  else
    n=$(bump verifyfail); say "VERIFY failed run=$n (local mirror kept)"
    [ $n -eq 3 ] && tg "⚠️ hdd1のDriveミラーの検証が3回続けて不一致(ローカルミラーは残してある)。pveの $LOG を確認"
  fi
fi
exit $ret
