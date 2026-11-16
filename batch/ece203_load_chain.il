;; batch job: ECE203 Round 2B -- Stage A real 3-OTA cascade (run.sh ece203_load_chain)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ldChainJob)
exit()
