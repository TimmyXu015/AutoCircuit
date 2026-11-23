;; @gui  batch job: ECE203 R7F ADE state r7f_<case>_phaseA (case via AC_R7F_CASE)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7fAde)
