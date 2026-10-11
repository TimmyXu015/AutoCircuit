#!/bin/bash
# AutoCircuit batch runner -- runs a job in a windowless Virtuoso over SSH.
#
#   ECE203_FA26_001              # first, load the course environment (once per SSH login)
#   ~/AutoCircuit/run.sh p1a     # then run a job (batch/<job>.il)
#
# Run it from the folder where you normally start Virtuoso (the one holding cds.lib);
# if cds.lib is not in the current folder, the course folder is tried.

JOB="${1:-}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
START_DIR="$PWD"

if [ -z "$JOB" ] || [ ! -f "$ROOT/batch/$JOB.il" ]; then
  echo "usage: $0 <job>     jobs:" $(ls "$ROOT/batch" 2>/dev/null | sed 's/\.il$//')
  exit 1
fi

# 1. latest scripts
( cd "$ROOT" && git pull -q ) && echo "[run] git pull ok" || echo "[run] git pull failed, using local copy"

# 2. Cadence environment
if ! command -v virtuoso >/dev/null 2>&1; then
  echo "[run] virtuoso not found. Type the course name first:  ECE203_FA26_001"
  exit 1
fi

# 3. folder with cds.lib
WORK=""
for d in "$START_DIR" "/home/linux/ieng6/ECE203_FA26_001/$USER" "$HOME"; do
  if [ -f "$d/cds.lib" ]; then WORK="$d"; break; fi
done
if [ -z "$WORK" ]; then
  echo "[run] no cds.lib found. cd to the folder where you start Virtuoso and run again."
  exit 1
fi
echo "[run] working folder: $WORK"

# 4. run
RES="$HOME/AutoCircuit_results"
mkdir -p "$RES"
LOG="$RES/$JOB.log"
echo "[run] running job '$JOB' (log: $LOG) ..."
START=$(date +%s)
STAMP="$RES/.$JOB.stamp"; touch "$STAMP"
( cd "$WORK" && AC_ROOT="$ROOT" virtuoso -nograph -log "$LOG.cds" < "$ROOT/batch/$JOB.il" > "$LOG" 2>&1 )
echo "[run] finished in $(( $(date +%s) - START )) s"

# 5. report
if grep -q "AC_BATCH_DONE" "$LOG"; then
  echo "[run] status: OK"
else
  echo "[run] status: FAILED -- messages:"
fi
echo "------------------------------------------------------------"
grep -E "\*Error\*|AC_BATCH_FAILED|^INFO: |^AC> |M0 size|schCheck|Wrote |Built " "$LOG" \
  | grep -v -e "ddGetObj: invalid libId" -e "Could not open display" -e "/tmp/.X[0-9]*-lock" \
          -e "redefines" | head -40
echo "------------------------------------------------------------"
[ -f "$RES/$JOB.txt" ] && cat "$RES/$JOB.txt"
NET="$HOME/simulation"
# only a netlist written by this run
NETFILE=$(find "$NET" -path "*/netlist/input.scs" -newer "$STAMP" 2>/dev/null | head -1)
if [ -n "$NETFILE" ]; then
  echo "------------------------------------------------------------"
  echo "[run] transistor line in netlist ($NETFILE):"
  grep -n -i -A2 "^M0\|^ *M0 " "$NETFILE" | head -8
fi
