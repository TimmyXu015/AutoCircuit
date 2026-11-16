;; batch job: ECE203 Round 4 C4 read -- per-sample values from the finished mismatch MC psf (no new simulation)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4C4Read)
exit()
