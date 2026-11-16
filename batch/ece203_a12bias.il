;; batch job: ECE203 A1/A2 VCP/VCN scan (run.sh ece203_a12bias)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('a12BiasAll)
exit()
