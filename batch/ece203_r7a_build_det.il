;; batch job: ECE203 R7A (build_det). Candidate via env AC_R7A_CAND (default a0)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7aBuildDet)
exit()
