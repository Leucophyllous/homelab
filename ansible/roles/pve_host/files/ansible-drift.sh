#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export ANSIBLE_DEPRECATION_WARNINGS=False
. /root/scripts/.env
tg(){ curl -s -m15 -o /dev/null --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$1" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"; }
cd /root/ansible || { tg "⚠️ 構成のずれ検知を実行できない(/root/ansible が無い)"; exit 1; }
start=$(date +%s)
out=$(timeout 900 ansible-playbook site.yml --check 2>&1)
rc=$?
sec=$(( $(date +%s) - start ))
if [ $rc -eq 124 ]; then
  tg "⏱ 構成のずれ検知がタイムアウトした(${sec}秒で打ち切り)。pveで cd /root/ansible && ansible-playbook site.yml --check を確認"
  exit 1
fi
if ! printf '%s\n' "$out" | grep -q 'PLAY RECAP'; then
  tg "⚠️ 構成のずれ検知が最後まで実行できなかった(終了コード $rc)。$(printf '%s\n' "$out" | grep -E 'fatal|ERROR' | head -1 | cut -c1-160)"
  exit 1
fi
touch /var/lib/ansible-drift.last
rec=$(printf '%s\n' "$out" | sed -n '/PLAY RECAP/,$p' | awk 'NF>1 && $1!="PLAY"{split($4,c,"=");split($5,u,"=");split($6,f,"="); if(c[2]>0||u[2]>0||f[2]>0) printf "%s(changed=%s unreachable=%s failed=%s) ", $1,c[2],u[2],f[2]}')
[ -z "$rec" ] && exit 0
tg "🧭 構成のずれを検知(Ansible試走、${sec}秒): $rec — pveで cd /root/ansible && ansible-playbook site.yml --check --diff で確認"
