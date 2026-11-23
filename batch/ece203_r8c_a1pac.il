;; batch job: ECE203 R8C (a1pac). Env AC_R8C_CASE (l0|l1), AC_R8C_MSB (1|3, a1pac), AC_R8C_STEP (b1|b2, bpss/bpac)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r8cA1pac)
exit()
