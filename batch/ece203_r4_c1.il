;; batch job: ECE203 Round 4 stage C1 -- VCAS 1.05/1.10/1.15 (LP 31.8M/20p, ideal Rfb, DRL off)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4C1)
exit()
