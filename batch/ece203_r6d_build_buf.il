;; batch job: ECE203 Round 6D (build_buf)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6dBuildBuf)
exit()
