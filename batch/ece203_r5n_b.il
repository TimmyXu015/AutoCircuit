;; batch job: ECE203 Round 5N stage B (no-chopper submission + noise sprint)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5nStageB)
exit()
