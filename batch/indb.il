;; batch job: planar inductor model at high frequency (run via ~/AutoCircuit/run.sh indb)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('indbRun)
exit()
