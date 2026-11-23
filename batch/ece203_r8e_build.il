;; batch job: ECE203 R8E (build). Env AC_R8E_CASE (g0|c2|c35), AC_R8E_STEP (b1|b2), AC_R8_STEP (PNoise sidebands), AC_R8_PSS (a1|a2 for PNoise), AC_R7E_CASE (= AC_R8E_CASE for tran)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r8eBuild)
exit()
