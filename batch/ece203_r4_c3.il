;; batch job: ECE203 Round 4 stage C3 -- real-bias final system (VDD + one 100 nA ref), pseudo-R and ideal Rfb, real DRL
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4C3)
exit()
