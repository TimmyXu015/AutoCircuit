;; batch job: ECE203 Round 3B Stage A adjustment W 3u, tight tolerances
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('prStageA2Job)
exit()
