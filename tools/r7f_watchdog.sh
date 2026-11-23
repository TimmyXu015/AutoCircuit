#!/bin/bash
# R7F transient watchdog (copy of r7e_watchdog.sh with the R7F path). Usage: r7f_watchdog.sh <tag> <psf_dir> <stall_s> <log>
# Kills only THIS task's Spectre run (matched by its "+log .../lix015_r7f/sim_<tag>/psf/spectre.out" argument) when the
# last "tran: time = X" value does not change for <stall_s> seconds.
TAG="$1"; PSF="$2"; STALL="${3:-240}"; LOG="$4"
PAT="lix015_r7f/sim_${TAG}/psf/spectre.out"
echo "$(date '+%F %T') watchdog start tag=$TAG stall=${STALL}s" >> "$LOG"
for i in $(seq 1 90); do pgrep -u "$USER" -f "$PAT" >/dev/null && break; sleep 2; done
last=""; since=$(date +%s)
while pgrep -u "$USER" -f "$PAT" >/dev/null; do
  cur=$(grep -o 'tran: time = [^(]*' "$PSF/spectre.out" 2>/dev/null | tail -1)
  now=$(date +%s)
  if [ "$cur" != "$last" ]; then last="$cur"; since=$now; fi
  if [ -n "$cur" ] && [ $((now - since)) -ge "$STALL" ]; then
    echo "$(date '+%F %T') STALL tag=$TAG: '$cur' unchanged for $((now - since)) s -> killing this run's Spectre" >> "$LOG"
    echo "STALLED $cur" > "$PSF/../WATCHDOG_STALL"
    pkill -u "$USER" -f "$PAT"; sleep 5; pkill -9 -u "$USER" -f "$PAT"
    break
  fi
  sleep 10
done
echo "$(date '+%F %T') watchdog exit tag=$TAG last='$last'" >> "$LOG"
