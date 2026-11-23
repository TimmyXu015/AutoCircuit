;; @gui  batch job: ECE203 R7D ADE state r7d_bias_phaseA (candidate via AC_R7D_CAND)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7dAde)
