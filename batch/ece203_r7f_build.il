;; batch job: ECE203 R7F (build). Case via env AC_R7F_CASE (lp_l0 | lp_l0_load10p | gain_g0_load10p | gain_g0_unloaded)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r7fBuild)
exit()
