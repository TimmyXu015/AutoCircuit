;; @gui  batch job: ECE203 Round 6B ADE L states (r6b_sys_tg_phaseA, r6b_tg_unit_phaseA)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6bAde)
