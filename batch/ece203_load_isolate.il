;; batch job: ECE203 Round 2B -- Stage B loading controls (run.sh ece203_load_isolate)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ldIsolateJob)
exit()
