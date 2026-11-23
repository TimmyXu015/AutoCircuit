;; batch job: ECE203 R7B (build). Case via env AC_R7B_CASE (c0/c1/c2)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7bBuild)
exit()
