#!/bin/bash
# R6D-R transient watchdog. Usage: r6dr_watchdog.sh <tag> <psf_dir> <stall_seconds> <log_file>
# Watches <psf_dir>/spectre.out of THIS task's Spectre run (process matched by its own "+log .../lix015_r6dr/sim_<tag>/psf/spectre.out"
# argument). If the last "tran: time = X" value does not change for <stall_seconds>, it kills only that Spectre run.
TAG="$1"; PSF="$2"; STALL="${3:-180}"; LOG="$4"
PAT="lix015_r6dr/sim_${TAG}/psf/spectre.out"
echo "$(date '+%F %T') watchdog start tag=$TAG stall=${STALL}s" >> "$LOG"
for i in $(seq 1 90); do pgrep -u "$USER" -f "$PAT" >/dev/null && break; sleep 2; done
last=""; since=$(date +%s)
while pgrep -u "$USER" -f "$PAT" >/dev/null; do
  cur=$(grep -o 'tran: time = [^(]*' "$PSF/spectre.out" 2>/dev/null | tail -1)
  now=$(date +%s)
  if [ "$cur" != "$last" ]; then last="$cur"; since=$now; fi
  if [ -n "$cur" ] && [ $((now - since)) -ge "$STALL" ]; then
    echo "$(date '+%F %T') STALL tag=$TAG: '$cur' unchanged for $((now - since)) s -> killing this run's Spectre" >> "$LOG"
    pkill -u "$USER" -f "$PAT"; sleep 5; pkill -9 -u "$USER" -f "$PAT"
    echo "STALLED $cur" > "$PSF/../WATCHDOG_STALL"
    break
  fi
  sleep 10
done
echo "$(date '+%F %T') watchdog exit tag=$TAG last='$last'" >> "$LOG"
