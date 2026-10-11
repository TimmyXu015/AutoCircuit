;; batch job: P1c VDS family, numbers only (run via ~/AutoCircuit/run.sh p1c)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw1P1cTest)
exit()
