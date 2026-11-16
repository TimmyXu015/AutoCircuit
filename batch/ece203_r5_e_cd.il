;; batch job: ECE203 Round 5 stage E (e_cd)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5StageEcd)
exit()
