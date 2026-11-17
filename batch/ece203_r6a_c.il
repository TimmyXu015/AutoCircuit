;; batch job: ECE203 Round 6A stage C (DRL/CMFB PoC)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6StageC)
exit()
