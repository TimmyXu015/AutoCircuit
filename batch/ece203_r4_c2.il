;; batch job: ECE203 Round 4 stage C2 -- one DRL change: CM-sense compensation 1 pF, before/after (real DRL, VCAS 1.10)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4C2)
exit()
