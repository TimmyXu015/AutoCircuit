;; batch job: ECE203 Round 5N stage C signoff
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5nStageC)
exit()
