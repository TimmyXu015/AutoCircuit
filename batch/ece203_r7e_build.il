;; batch job: ECE203 R7E (build). Case via env AC_R7E_CASE (lp_a0 | lp_load10p)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7eBuild)
exit()
