;; @gui  batch job: ECE203 Round 3A ADE L states lscan_L1u..L8u (dc op + ac) in ece203_ss_lscan_tb and ece203_ss_lscan_ol_tb
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('lsAde)
