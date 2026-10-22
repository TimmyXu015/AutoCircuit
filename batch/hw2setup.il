;; @gui  batch job: HW2 P1 f_t cells + ADE L states (run via ~/AutoCircuit/run.sh hw2setup)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw2Setup)
