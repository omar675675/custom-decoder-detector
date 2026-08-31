#!/usr/bin/env bash
# 3 scripts x 2 model sizes = 6 headless runs on the 7 local 1080p .mp4 files.
# Model is held constant across the three configs for each size.
set -u
cd /home/omar/luna/rtsp_trt
PY=/home/omar/luna/venv/bin/python3
OUT=bench
DUR=75
mkdir -p "$OUT"

sampler() {   # $1=python pid  $2=tag  -> pvram gpumem gutil cpu rss
  local pid=$1 tag=$2
  : > "$OUT/$tag.samp"
  while kill -0 "$pid" 2>/dev/null; do
    local pvram gmem gutil cpu rss
    pvram=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits 2>/dev/null \
            | awk -F', *' -v p="$pid" '$1==p{print $2}')
    read -r gmem gutil < <(nvidia-smi --query-gpu=memory.used,utilization.gpu \
            --format=csv,noheader,nounits 2>/dev/null | tr -d ',')
    cpu=$(top -b -n1 -p "$pid" 2>/dev/null | awk -v p="$pid" '$1==p{print $9}')
    rss=$(awk '/VmRSS/{printf "%d",$2/1024}' /proc/"$pid"/status 2>/dev/null)
    echo "${pvram:-0} ${gmem:-0} ${gutil:-0} ${cpu:-0} ${rss:-0}" >> "$OUT/$tag.samp"
    sleep 1
  done
}

run() {   # $1=script  $2=model-flag  $3=tag
  local script=$1 mflag=$2 tag=$3
  local vid="${script%.py}.mp4"
  rm -f "$vid"
  echo "=== $tag  ($script $mflag)  $(date +%T) ==="
  DISPLAY=:1 timeout -s INT -k 20 "$DUR" "$PY" "$script" --headless $mflag \
      > "$OUT/$tag.log" 2>&1 &
  local tpid=$!
  local pid=""
  for _ in $(seq 12); do pid=$(pgrep -P "$tpid" -f "$script" | head -1); [ -n "$pid" ] && break; sleep 0.5; done
  [ -z "$pid" ] && pid=$tpid
  sampler "$pid" "$tag" & local spid=$!
  wait "$tpid"
  kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null
  [ -f "$vid" ] && mv -f "$vid" "$OUT/$tag.mp4"
  sleep 5
}

run ocv.py "--weights models/yolo11n.pt"     ocv_n
run old.py "--weights models/yolo11n.pt"     old_n
run new.py "--engine  models/yolo11n.engine" new_n
run ocv.py "--weights models/yolo11m.pt"     ocv_m
run old.py "--weights models/yolo11m.pt"     old_m
run new.py "--engine  models/yolo11m.engine" new_m

# front-trim the recordings (skip model-load / empty-tile lead-in)
for tag in ocv_n old_n new_n ocv_m old_m new_m; do
  f="$OUT/$tag.mp4"; [ -f "$f" ] || { echo "MISSING $f"; continue; }
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  trim=$(awk -v d="$dur" 'BEGIN{t=d*0.15; if(t>8)t=8; if(t<2)t=2; printf "%.2f",t}')
  ffmpeg -nostdin -y -loglevel error -ss "$trim" -i "$f" -c copy "$OUT/${tag}_t.mp4" \
    && mv -f "$OUT/${tag}_t.mp4" "$f" && echo "trimmed ${trim}s from $tag.mp4 (raw ${dur}s)"
done
echo "=== ALL DONE $(date +%T) ==="
