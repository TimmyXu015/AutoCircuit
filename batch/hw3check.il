;; batch job: HW3 P2 OCEAN noise check at the found vin (run.sh hw3check)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw3Check)
exit()
