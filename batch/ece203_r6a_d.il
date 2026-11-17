;; batch job: ECE203 Round 6A stage D (DRL/CMFB PoC)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6StageD)
exit()
