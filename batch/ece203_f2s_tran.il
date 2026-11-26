;; batch job: ECE203 F2S -- 10 s transients of the winner (env AC_F2I_CASES / AC_F2I_STOP / AC_F2I_MAXSTEP)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('f2sJobTran)
exit()
