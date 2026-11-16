;; batch job: print symbol pin positions (run.sh ece203_probe)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ece203ProbeSymbols)
exit()
