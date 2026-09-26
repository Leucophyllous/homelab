#!/bin/bash
set -a; . /root/scripts/.env; set +a
HC=$(awk '$1=="telegram-bot"{print $2}' /root/scripts/hc-urls.txt)
r=$(curl -s -m 15 "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe")
if echo "$r" | grep -q '"ok":true'; then curl -fsS -m 10 --retry 3 -o /dev/null "$HC"; else curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "getMe failed: $(echo "$r" | head -c 200)" "$HC/fail"; fi
