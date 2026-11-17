;; batch job: ECE203 Round 6A stage D2 (offset diagnostic, chopper)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6StageD2)
exit()
