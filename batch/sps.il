;; batch job: sub vs strong CS amp -- build cs_strong/cs_sub, OP + AC + tran CSVs (run.sh sps)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('spsRun)
exit()
