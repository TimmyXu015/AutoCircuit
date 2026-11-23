;; batch job: ECE203 R8D (build). Env AC_R8D_CASE (ii|im|mi), AC_R8D_STEP (b1|b2, pss/pac)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r8dBuild)
exit()
