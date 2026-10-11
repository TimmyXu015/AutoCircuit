;; batch job: P1g: PMOS VSD family, numbers only (run via ~/AutoCircuit/run.sh p1cp)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw1P1cTestP)
exit()
