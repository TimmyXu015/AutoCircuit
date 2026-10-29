;; @gui  batch job: HW3 P2 ADE L states hw3_p2_vin_sweep + hw3_p2_noise (run.sh hw3ade)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw3Ade)
