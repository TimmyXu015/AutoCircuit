;; batch job: ECE203 Round 5 Round 5 stage dsb
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5StageDsb)
exit()
