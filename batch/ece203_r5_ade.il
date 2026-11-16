;; @gui  batch job: ECE203 Round 5 ADE L states (r5_final_<stage>, r5_B1_CD_S2, r5_B2_CS_S2, r5_D1_CD_S2_demodslot1)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5Ade)
