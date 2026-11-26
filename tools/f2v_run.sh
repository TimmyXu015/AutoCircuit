#!/bin/bash
# F2 final validation scout: build a standalone netlist (tools/f2v_netlist.py) from an audited f2i ADE netlist and run
# Spectre directly (psfascii) in /tmp/lix015_f2v/<tag>. Usage: f2v_run.sh <tag> <nominal|mc|ref> [netlist args...]
# Base netlists: ~/AutoCircuit_results/ece203_f2i/A_prof_dm_netlist.scs (instructor fixture copy + F2) and
# A_ref_f2fixture_dm_netlist.scs (archived F2 fixture). Timeout AC_F2V_TIMEOUT seconds (default 3600).
set -u
tag=$1; kind=$2; shift 2
here=$(cd "$(dirname "$0")" && pwd)
src=$HOME/AutoCircuit_results/ece203_f2i
base=$src/A_prof_dm_netlist.scs; [ "$kind" = ref ] && base=$src/A_ref_f2fixture_dm_netlist.scs
d=/tmp/lix015_f2v/$tag; rm -rf "$d"; mkdir -p "$d"; cd "$d" || exit 1
python3 "$here/f2v_netlist.py" "$base" input.scs "$kind" "$@" || exit 1
if ! command -v spectre >/dev/null 2>&1; then
  . "$MODULESHOME/init/bash" 2>/dev/null
  module use /home/linux/ieng6/ECE203_FA26_001/public/modulefiles 2>/dev/null
  module load ECE203_FA26_001 >/dev/null 2>&1
fi
SP=/software/nonrdist64/mmsim151/tools/bin/spectre
MOD=/software/linux/IBM7RF/IBM_PDK/cmrf7sf/V2.0.0.2AM/Spectre/models
echo "[f2v] $tag $kind $* start $(date)"
timeout "${AC_F2V_TIMEOUT:-3600}" "$SP" -64 input.scs +escchars +log spectre.out -format psfascii -raw psf -I"$MOD" \
  +lqtimeout 900 -maxw 5 -maxn 5 > run.log 2>&1
rc=$?
echo "[f2v] $tag rc $rc end $(date)"; tail -5 spectre.out
du -sh psf; ls psf | head -20; ls psf | wc -l
