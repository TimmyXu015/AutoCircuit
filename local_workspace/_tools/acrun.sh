#!/bin/bash
# Run an AutoCircuit job on ieng6 from the user's Windows PC (Git Bash).
#   bash _tools/acrun.sh <job>          run ~/AutoCircuit/run.sh <job> and print its report (most jobs < 2 min)
#   bash _tools/acrun.sh --bg <job>     start it detached (GUI / long jobs); returns at once
#   bash _tools/acrun.sh --poll <job>   show the report of a detached run ("[run] status:" = finished)
#   bash _tools/acrun.sh --ssh "<cmd>"  run any command on ieng6
# Another host: AC_HOST=lix015@ieng6-ece-20.ucsd.edu bash _tools/acrun.sh ...
HOST="${AC_HOST:-lix015@ieng6-ece-10.ucsd.edu}"
WORK=/home/linux/ieng6/ECE203_FA26_001/lix015      # Cadence workdir (holds cds.lib)
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=20 -o LogLevel=ERROR "$HOST")
case "$1" in
  --bg)   "${SSH[@]}" "cd $WORK && nohup bash -lc '~/AutoCircuit/run.sh $2' > ~/AutoCircuit_results/$2_run.out 2>&1 < /dev/null & echo started $2" ;;
  --poll) "${SSH[@]}" "tail -60 ~/AutoCircuit_results/$2_run.out" ;;
  --ssh)  shift; "${SSH[@]}" "$*" ;;
  ""|-h|--help) sed -n 2,8p "$0" ;;
  *)      "${SSH[@]}" "cd $WORK && bash -lc '~/AutoCircuit/run.sh $1'" ;;
esac
