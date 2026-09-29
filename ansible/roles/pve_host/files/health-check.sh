#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
set -a; . /root/scripts/.env; set +a
HC=$(awk '$1=="health-check"{print $2}' /root/scripts/hc-urls.txt)
CNTF=/var/lib/health-check.cnt
STATE=/var/lib/health-check.state
PROBE=/root/scripts/health-probe.sh
O="-o BatchMode=yes -o ConnectTimeout=8"
tmp=$(mktemp)
run(){ local n=$1; shift; "$@" < "$PROBE" 2>/dev/null | sed "s/^/$n /"; }
smart(){ local h=$1 d=$2 out=$3; [ -z "$out" ] && return 0; if echo "$out" | grep -q PASSED; then echo "$h smart$d ok"; else echo "$h smart$d NG"; fi; }
{
  run pve bash -s
  run pve02 ssh $O 192.168.0.101 bash -s
  run orangepi ssh $O orangepi@192.168.0.183 bash -s
  run pi ssh $O root@192.168.0.243 bash -s
  run docker-vm ssh $O leila@192.168.0.113 bash -s
  run mcp-a1 ssh $O -i /root/.ssh/oci_mcp ubuntu@100.69.245.48 bash -s
  pct exec 121 -- bash -c "$(cat $PROBE)" 2>/dev/null | sed "s/^/minecraft-ct /"
  for d in /dev/sda /dev/sdb /dev/nvme0n1; do smart pve $d "$(smartctl -H $d 2>/dev/null)"; done
  smart pve02 /dev/sda "$(ssh $O 192.168.0.101 'smartctl -H /dev/sda' 2>/dev/null)"
} > "$tmp"
declare -A CNT NEW
while read -r k c; do CNT[$k]=$c; done < <(cat "$CNTF" 2>/dev/null)
add(){ NEW[$1]=$2; }
while read -r h k v rest; do
  case $k in
    memfree)
      t=10; [ "$h" = pve ] && t=8
      [ "$v" -lt "$t" ] && add "$h:mem" "$h メモリ空き ${v}%"
      [ "$h" = mcp-a1 ] && [ $((100-v)) -lt 23 ] && add "$h:idle" "$h メモリ使用率 $((100-v))% (OCI回収基準の20%に近い)"
      ;;
    load) awk -v a="$v" 'BEGIN{exit !(a>2)}' && add "$h:load" "$h 負荷 ${v}/コア" ;;
    temp) [ "$v" -ge 80 ] && add "$h:temp" "$h 温度 ${v}°C" ;;
    docker) add "$h:docker:$v" "$h コンテナ $v が異常 ($rest)" ;;
    smart*) [ "$v" = NG ] && add "$h:$k" "$h SMART異常 ${k#smart}" ;;
  esac
done < "$tmp"
if [ -n "$DRY" ]; then
  cat "$tmp"; echo "--- problems"; for k in "${!NEW[@]}"; do echo "$k: ${NEW[$k]}"; done; rm -f "$tmp"; exit 0
fi
: > "$CNTF.new"
alert=""
for k in "${!NEW[@]}"; do
  c=$(( ${CNT[$k]:-0} + 1 ))
  echo "$k $c" >> "$CNTF.new"
  [ "$c" -ge 2 ] && alert+="${NEW[$k]}"$'\n'
done
mv "$CNTF.new" "$CNTF"
alert=$(printf '%s' "$alert" | sort)
prev=$(cat "$STATE" 2>/dev/null)
if [ "$alert" != "$prev" ]; then
  if [ -n "$alert" ]; then msg="🩺 ホスト状態の警告"$'\n'"$alert"; else msg="✅ ホスト状態の警告は全て解消した"; fi
  curl -s -m 15 -o /dev/null --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$msg" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
  printf '%s' "$alert" > "$STATE"
fi
n=$(grep -c ' memfree ' "$tmp")
rm -f "$tmp"
[ "$n" -ge 6 ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC" || curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "only $n hosts" "$HC/fail"
