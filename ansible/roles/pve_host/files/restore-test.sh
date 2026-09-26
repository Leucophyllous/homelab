#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
set -a; . /root/scripts/.env; set +a
HC=$(awk '$1=="restore-test"{print $2}' /root/scripts/hc-urls.txt)
ORDER=(112 121 126)
STATE=/var/lib/restore-test.idx
N=192.168.0.100
R(){ ssh -o BatchMode=yes -o ConnectTimeout=10 root@$N "$@"; }
tg(){ curl -s -m15 -o /dev/null --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$1" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"; }
if [ -n "$1" ]; then vmid=$1; rot=0; else i=$(( ($(cat $STATE 2>/dev/null || echo -1) + 1) % ${#ORDER[@]} )); vmid=${ORDER[$i]}; rot=1; fi
tid=$((9000+vmid))
curl -fsS -m10 -o /dev/null "$HC/start" || true
vol=$(pvesm list backup-storage --content backup --vmid $vmid 2>/dev/null | awk 'NR>1{print $1}' | sort | tail -1)
cleanup(){ R "qm stop $tid --skiplock 1 >/dev/null 2>&1; qm destroy $tid --purge 1 >/dev/null 2>&1; pct stop $tid >/dev/null 2>&1; pct destroy $tid --purge 1 >/dev/null 2>&1; true"; }
fail(){ cleanup; tg "🧪❌ 復元テスト失敗: ID$vmid ($1) ${vol##*/}"; curl -fsS -m10 -o /dev/null --data-raw "$vmid: $1" "$HC/fail"; exit 1; }
[ -z "$vol" ] && fail "バックアップが見つからない"
cleanup
t0=$(date +%s)
case "$vol" in
  *vzdump-qemu-*)
    R "qmrestore $vol $tid --storage hapool --unique 1 --bwlimit 40960" >/tmp/restore-test.log 2>&1 || fail "qmrestore失敗"
    net=$(R "qm config $tid" | awk -F': ' '/^net0:/{print $2}')
    R "qm set $tid --net0 '$net,link_down=1' --memory 2048 --balloon 0 --onboot 0 >/dev/null && qm start $tid" >>/tmp/restore-test.log 2>&1 || fail "起動失敗"
    ok=0; for n in $(seq 1 30); do sleep 8; R "qm agent $tid ping" >/dev/null 2>&1 && { ok=1; break; }; done
    [ $ok = 1 ] || fail "ゲストエージェントが応答しない(OSが起動しない?)"; how="OS起動・ゲストエージェント応答";;
  *vzdump-lxc-*)
    R "pct restore $tid $vol --storage hapool --unique 1 --bwlimit 40960" >/tmp/restore-test.log 2>&1 || fail "pct restore失敗"
    R "pct set $tid --delete net0 --memory 2048 --swap 512 --onboot 0 && pct start $tid" >>/tmp/restore-test.log 2>&1 || fail "起動失敗"
    ok=0; for n in $(seq 1 20); do sleep 6; s=$(R "pct exec $tid -- systemctl is-system-running" 2>/dev/null); case "$s" in running|degraded) ok=1; break;; esac; done
    [ $ok = 1 ] || fail "systemdが起動完了しない(状態: ${s:-不明})"; how="systemd起動完了($s)";;
  *) fail "種類不明";;
esac
dt=$(( $(date +%s) - t0 ))
cleanup
[ $rot = 1 ] && echo $i > $STATE
tg "🧪✅ 復元テスト成功: ID$vmid (${vol##*/}) をpve02に別ID$tid・ネット切断で復元し、$how を確認して削除した(${dt}秒)"
curl -fsS -m10 --retry 3 -o /dev/null "$HC"
