#!/bin/bash
PVE02=root@192.168.0.100
SSHO="-o BatchMode=yes -o ConnectTimeout=5"
ME=$(hostname)
onnode() { local n=$1; shift; if [ "$ME" = "$n" ]; then bash -c "$*"; else ssh $SSHO root@$([ "$n" = pve ] && echo 192.168.0.150 || echo 192.168.0.100) "$*"; fi; }
APTCMD='l=$(apt-get -s -o Debug::NoLocking=1 dist-upgrade 2>/dev/null | grep ^Inst); t=$(printf "%s" "$l" | grep -c .); s=$(printf "%s" "$l" | grep -ci security); r=0; [ -f /var/run/reboot-required ] && r=1; echo "$t $s $r"'
declare -A APT APP
APT[pve]=$(onnode pve "$APTCMD" 2>/dev/null)
while read -r id n; do
  APT["ct$id-$n"]=$(timeout 60 /usr/local/sbin/pct-any exec $id -- bash -c "$APTCMD" 2>/dev/null </dev/null)
done < <(pvesh get /cluster/resources --type vm --output-format json | python3 -c 'import sys,json;[print(r["vmid"],r.get("name","")) for r in json.load(sys.stdin) if r.get("type")=="lxc" and r.get("status")=="running"]')
APT[pve02]=$(onnode pve02 "$APTCMD" 2>/dev/null)
APT[docker-vm]=$(onnode pve02 "ssh $SSHO leila@192.168.0.113 '$APTCMD'" 2>/dev/null)
APT[mcp-a1]=$(onnode pve02 "ssh $SSHO -i /root/.ssh/oci_mcp ubuntu@100.69.245.48 '$APTCMD'" 2>/dev/null)
APT[orangepi]=$(timeout 60 ssh $SSHO orangepi@192.168.0.183 "$APTCMD" 2>/dev/null)
j(){ timeout 8 curl -s -m6 "$1" | python3 -c "import sys,json;d=json.load(sys.stdin);print($2)" 2>/dev/null; }
APP[n8n]=$(timeout 20 /usr/local/sbin/pct-any exec 142 -- n8n --version 2>/dev/null | tail -1)
APP[grafana]=$(j http://192.168.0.113:3001/api/health "d['version']")
APP[ollama-a1]=$(j http://100.69.245.48:11434/api/version "d['version']")
APP[ollama-pve]=$(timeout 20 /usr/local/sbin/pct-any exec 146 -- curl -s -m6 http://127.0.0.1:11434/api/version 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['version'])" 2>/dev/null)
APP[prometheus]=$(j http://192.168.0.113:9090/api/v1/status/buildinfo "d['data']['version']")
APP[paper]=$(/usr/local/sbin/pct-any exec 121 -- bash -c 'ls /opt/minecraft/data/paper-*.jar 2>/dev/null | sed -E "s#.*/paper-(.*)\.jar#\1#" | sort -V | tail -1' 2>/dev/null)
PLUGINS=$(timeout 60 /usr/local/sbin/pct-any exec 121 -- /usr/local/bin/mc-plugin-versions 2>/dev/null)
{
  for k in "${!APT[@]}"; do echo "apt	$k	${APT[$k]}"; done
  for k in "${!APP[@]}"; do echo "app	$k	${APP[$k]}"; done
  echo "plugins	x	$PLUGINS"
} | python3 -c '
import sys,json
out={"apt":{},"apps":{},"plugins":{},"errors":[]}
for line in sys.stdin:
    p=line.rstrip("\n").split("\t")
    if p[0]=="plugins":
        try: out["plugins"]=json.loads(p[2])
        except Exception: out["errors"].append("plugins")
        continue
    if p[0]=="apt":
        v=p[2].split()
        if len(v)==3: out["apt"][p[1]]={"total":int(v[0]),"security":int(v[1]),"reboot":v[2]=="1"}
        else: out["errors"].append("apt:"+p[1])
    else:
        if p[2]: out["apps"][p[1]]=p[2]
        else: out["errors"].append("app:"+p[1])
print(json.dumps(out,ensure_ascii=False))'
