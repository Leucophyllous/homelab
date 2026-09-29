m=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d",a*100/t}' /proc/meminfo)
echo "memfree $m"
echo "load $(awk -v c=$(nproc) '{printf "%.2f",$3/c}' /proc/loadavg)"
t=0
for z in /sys/class/thermal/thermal_zone*/temp; do
  [ -r "$z" ] || continue
  v=$(( $(cat "$z") / 1000 ))
  [ "$v" -gt "$t" ] && t=$v
done
echo "temp $t"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker ps -a --format '{{.Names}}|{{.State}}|{{.Status}}' | awk -F'|' '$2!="running" || $3 ~ /unhealthy|Restarting/ {print "docker " $1 " " $2}'
fi
