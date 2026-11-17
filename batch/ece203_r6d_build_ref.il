;; batch job: ECE203 Round 6D (build_ref)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6dBuildRef)
exit()
