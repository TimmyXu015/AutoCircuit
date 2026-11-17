;; batch job: ECE203 Round 5N bias pilot
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5nStagePilot)
exit()
