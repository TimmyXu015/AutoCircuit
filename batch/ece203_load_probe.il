;; batch job: ECE203 Round 2B -- build ece203_load_* cells + one-point chain sanity (run.sh ece203_load_probe)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ldProbeJob)
exit()
