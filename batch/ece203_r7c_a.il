;; batch job: ECE203 R7C (a). Case via env AC_R7C_CASE (ideal | pr_w4 ...)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7cStageA)
exit()
