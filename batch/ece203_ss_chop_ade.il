;; @gui  batch job: ECE203 Round 3D ADE L states chop_1MHz_step (tran 200u, tight options) in ece203_ss_chop_ideal_tb and ece203_ss_chop_c_tb
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('chAde)
