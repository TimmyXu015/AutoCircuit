;; batch job: gm vs W at locked Ids (run via ~/AutoCircuit/run.sh wsub)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('wsubRun)
exit()
