#!/usr/bin/env bash

khs=0
stats=""

. /hive/miners/custom/neptune_miner/h-manifest.conf

LOG_FILE="/hive/miners/custom/neptune_miner/neptune_miner.log"

last_line=$(grep -E "G[0-9]+:" "$LOG_FILE" | tail -n 1)

if [[ -z "$last_line" ]]; then
  echo "0"
  echo "null"
  exit 0
fi

readarray -t gpu_stats < <( jq --slurp -r -c '.[] | .busids, .brand, .temp, .fan | join(" ")' "$GPU_STATS_JSON" 2>/dev/null)
busids=(${gpu_stats[0]})
brands=(${gpu_stats[1]})
temps=(${gpu_stats[2]})
fans=(${gpu_stats[3]})
gpu_count=${#busids[@]}

declare -a hash_arr
ttl_hr=0

for ((i=1; i<=gpu_count; i++)); do
  hr=$(echo "$last_line" | grep -oP "G${i}:\s*\K[0-9.]+(?=\s*Mh)" | head -n1)
  if [[ -z "$hr" ]]; then
    hr_val=0
  else
    hr_val=$(awk -v v="$hr" 'BEGIN { printf("%.0f", v * 1000000) }')
  fi
  hash_arr+=($hr_val)
  ttl_hr=$(( ttl_hr + hr_val ))
done

khs=$(( ttl_hr / 1000 ))

hash_json=$(printf '%s\n' "${hash_arr[@]}" | jq -cs '.' 2>/dev/null)
bus_numbers=$(printf '%s\n' "${busids[@]}"  | jq -cs '.' 2>/dev/null)
fan_json=$(printf '%s\n' "${fans[@]}"  | jq -cs '.' 2>/dev/null)
temp_json=$(printf '%s\n' "${temps[@]}"  | jq -cs '.' 2>/dev/null)

stats_raw=$(curl -s --connect-timeout 3 --max-time 3 "http://127.0.0.1:${MINER_API_PORT}")
if [[ $? -eq 0 && -n "$stats_raw" ]]; then
  version=$(echo "$stats_raw" | jq -r ".version // empty")
  uptime=$(echo "$stats_raw" | jq -r ".uptime_sec // empty")
  ac=$(echo "$stats_raw" | jq -r '.gpus | map(.accepted) | add // 0')
  rj=$(echo "$stats_raw" | jq -r '.gpus | map(.rejected) | add // 0')
fi

version=${version:-"unknown"}
uptime=${uptime:-0}
ac=${ac:-0}
rj=${rj:-0}

stats=$(jq -nc \
  --arg hs "$hash_json" \
  --arg hs_units "hs" \
  --arg ths "$ttl_hr" \
  --arg algo "BLAKE3" \
  --arg ver "$version" \
  --arg ac "$ac" \
  --arg rj "$rj" \
  --arg uptime "$uptime" \
  --arg bus "$bus_numbers" \
  --arg temp "$temp_json" \
  --arg fan "$fan_json" \
  '{
    hs: ($hs | try fromjson // []),
    hs_units: $hs_units,
    ths: ($ths | tonumber),
    algo: $algo,
    ver: $ver,
    ar: [($ac|tonumber), ($rj|tonumber)],
    uptime: ($uptime|tonumber),
    bus_numbers: ($bus | try fromjson // []),
    temp: ($temp | try fromjson // []),
    fan: ($fan | try fromjson // [])
  }')

echo "$khs"
echo "$stats"
