;; batch job: sub vs strong CS amp -- W scan at Id = 10 uA (run.sh spsscan)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('spsScan)
exit()
