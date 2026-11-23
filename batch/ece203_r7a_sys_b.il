;; batch job: ECE203 R7A (sys_b). Candidate via env AC_R7A_CAND (default a0)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7aSysB)
exit()
