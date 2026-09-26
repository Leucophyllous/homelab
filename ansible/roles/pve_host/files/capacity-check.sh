#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
set -a; . /root/scripts/.env; set +a
HC=$(awk '$1=="capacity-check"{print $2}' /root/scripts/hc-urls.txt)
STATE=/var/lib/capacity-check.state
DEFAULT=85
declare -A TH=( ["orangepi:/mnt/hdd-c"]=95 ["orangepi:/mnt/hdd-b"]=90 )
O="-o BatchMode=yes -o ConnectTimeout=8"
tmp=$(mktemp)
dfp(){ awk 'NR>1{gsub("%","",$5); print $6, $5}'; }
{ df -P / /mnt/hdd1 /mnt/nfs-share | dfp | sed 's/^/pve:/'
  echo "pve:thin-data $(lvs --noheadings -o data_percent pve/data | awk '{printf "%d",$1}')"
  zpool list -H -o name,cap | awk '{gsub("%","",$2); print "pve:zfs-"$1, $2}'
  ssh $O 192.168.0.100 'df -P / | awk "NR>1{gsub(\"%\",\"\",\$5); print \$6, \$5}"; echo "thin-data $(lvs --noheadings -o data_percent pve/data | awk "{printf \"%d\",\$1}")"; zpool list -H -o name,cap | awk "{gsub(\"%\",\"\",\$2); print \"zfs-\"\$1, \$2}"' | sed 's/^/pve02:/'
  ssh $O orangepi@192.168.0.183 'df -P / /mnt/hdd-a /mnt/hdd-b /mnt/hdd-c' | dfp | sed 's/^/orangepi:/'
  for h in docker-pve:192.168.0.115 docker-vm:192.168.0.113 db-vm:192.168.0.245; do ssh $O leila@${h#*:} 'df -P /' | dfp | sed "s/^/${h%%:*}:/"; done
  ssh $O root@192.168.0.243 'df -P /' | dfp | sed 's/^/pi:/'
  ssh $O -i /root/.ssh/oci_mcp ubuntu@100.69.245.48 'df -P /' | dfp | sed 's/^/mcp-a1:/'
} > "$tmp" 2>/dev/null
over=""; while read -r k v; do [ -z "$v" ] && continue; t=${TH[$k]:-$DEFAULT}; [ "$v" -ge "$t" ] && over+="$k ${v}% (しきい値${t}%)"$'\n'; done < "$tmp"
over=${over%$'\n'}
prev=$(cat "$STATE" 2>/dev/null)
if [ "$over" != "$prev" ]; then
  if [ -n "$over" ]; then msg="💽 容量警告"$'\n'"$over"; else msg="✅ 容量警告は全て解消した"; fi
  curl -s -m 15 -o /dev/null --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$msg" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
  printf '%s' "$over" > "$STATE"
fi
n=$(grep -c . "$tmp"); cp "$tmp" /var/lib/capacity-check.last; rm -f "$tmp"
[ "$n" -ge 15 ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC" || curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "only $n readings" "$HC/fail"
