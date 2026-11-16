;; @gui  batch job: ECE203 Round 4 ADE L states (r4_final, r4_final_idealRfb, r4_A1_baseline_drloff, r4_C2_idealbias_realDRL)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4Ade)
