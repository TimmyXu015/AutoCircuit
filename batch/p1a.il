;; batch job: HW1 P1a (run via ~/AutoCircuit/run.sh p1a)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('p1aRun)
exit()
