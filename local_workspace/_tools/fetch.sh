#!/bin/bash
# Copy result files from ieng6 into _raw/<experiment>/ of the lab notebook, and create the
# experiment folder (which will hold only log.md + PNGs).
#   bash _tools/fetch.sh 2026-10-21_p1c_vds_family AutoCircuit_results/p1c_p1_nmos.csv ...
# Remote paths are relative to the home folder on ieng6; quoted globs work: 'AutoCircuit_results/sps_*.csv'
HOST="${AC_HOST:-lix015@ieng6-ece-10.ucsd.edu}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exp="$1"; shift
if [ -z "$exp" ] || [ $# -eq 0 ]; then sed -n 2,6p "$0"; exit 1; fi
mkdir -p "$ROOT/$exp" "$ROOT/_raw/$exp"
for f in "$@"; do
  scp -o BatchMode=yes -o LogLevel=ERROR -q "$HOST:$f" "$ROOT/_raw/$exp/" || echo "fetch failed: $f"
done
ls -l "$ROOT/_raw/$exp"
