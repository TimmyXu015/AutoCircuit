#!/bin/bash
# R8E watchdog (copy of r8d_watchdog.sh; path /tmp/lix015_r8e_<case>) for long periodic / tran Spectre runs. Usage: r8e_watchdog.sh <tag> <psf_dir> <stall_s> <hard_s> <log>
# Kills only THIS task's Spectre run (matched by its "+log .../lix015_r8e_<case>/sim_<tag>/psf/spectre.out" argument) when spectre.out
# has not grown for <stall_s> seconds, or when the run exceeds <hard_s> seconds of wall time. Never touches other processes.
TAG="$1"; PSF="$2"; STALL="${3:-900}"; HARD="${4:-5400}"; LOG="$5"
PAT="lix015_r8e_[a-z0-9]*/sim_${TAG}/psf/spectre.out"
echo "$(date '+%F %T') watchdog start tag=$TAG stall=${STALL}s hard=${HARD}s" >> "$LOG"
for i in $(seq 1 90); do pgrep -u "$USER" -f "$PAT" >/dev/null && break; sleep 2; done
start=$(date +%s); last=-1; since=$start
while pgrep -u "$USER" -f "$PAT" >/dev/null; do
  sz=$(stat -c %s "$PSF/spectre.out" 2>/dev/null || echo 0); now=$(date +%s)
  if [ "$sz" != "$last" ]; then last=$sz; since=$now; fi
  why=""
  [ $((now - since)) -ge "$STALL" ] && why="spectre.out unchanged for $((now - since)) s"
  [ $((now - start)) -ge "$HARD" ] && why="wall time $((now - start)) s >= hard limit"
  if [ -n "$why" ]; then
    echo "$(date '+%F %T') STOP tag=$TAG: $why -> killing this run's Spectre" >> "$LOG"
    echo "STALLED $why" > "$PSF/../WATCHDOG_STALL"
    tail -5 "$PSF/spectre.out" >> "$LOG" 2>/dev/null
    pkill -u "$USER" -f "$PAT"; sleep 5; pkill -9 -u "$USER" -f "$PAT"
    break
  fi
  sleep 15
done
echo "$(date '+%F %T') watchdog exit tag=$TAG after $(( $(date +%s) - start )) s, spectre.out $last bytes" >> "$LOG"
