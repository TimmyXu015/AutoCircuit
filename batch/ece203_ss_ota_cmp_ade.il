;; @gui  batch job: ECE203 Round 3C ADE L states cmp_s2 in ece203_ss_ota_cmp_b/p/c_tb
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ocAde)
