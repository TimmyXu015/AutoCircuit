;; batch job: ECE203 Round 5 stage E (e_cs)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5StageEcs)
exit()
