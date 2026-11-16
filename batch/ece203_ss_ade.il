;; @gui  batch job: ECE203 Round 3 ADE L states ss_S1 / ss_S2 in ece203_ss_ideal_tb and ece203_ss_real_tb
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ssAde)
