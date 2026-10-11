;; batch job: gm/Id of an NMOS vs VGS (run via ~/AutoCircuit/run.sh gmid)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('gmidRun)
exit()
