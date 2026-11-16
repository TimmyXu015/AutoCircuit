;; batch job: ECE203 Round 3B Stage B S2 ideal Rfb vs pseudo-R (L 8u 5T), DC + AC
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('prStageBJob)
exit()
