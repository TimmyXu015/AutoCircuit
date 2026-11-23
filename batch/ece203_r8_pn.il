;; batch job: ECE203 R8 (pn). Env AC_R8_STEP (PSS attempt a1|a2, or PNoise maxsideband 10|30|60|90), AC_R8_PSS (converged attempt)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r8Pn)
exit()
