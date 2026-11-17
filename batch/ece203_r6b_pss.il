;; batch job: ECE203 Round 6B PSS re-run
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6bStagePss)
exit()
