;; batch job: ECE203 R7D (a). Candidate via env AC_R7D_CAND (a0 | a1)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7dStageA)
exit()
