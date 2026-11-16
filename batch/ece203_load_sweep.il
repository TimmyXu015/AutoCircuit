;; batch job: ECE203 Round 2B -- Stage C R1/R2 sweep (run.sh ece203_load_sweep)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ldSweepJob)
exit()
