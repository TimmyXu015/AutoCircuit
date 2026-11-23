;; @gui  batch job: ECE203 R7E ADE state r7e_lp_phaseA (cell ece203_r7e_tb_lp_a0)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7eAde)
