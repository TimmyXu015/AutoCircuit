;; batch job: ECE203 Round 4 stage C4 -- mismatch Monte Carlo N=12 on the frozen final config (DM + CM, same seed)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4C4)
exit()
