;; batch job: simulate the HW1 cells once with OCEAN (run via ~/AutoCircuit/run.sh hw1check)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw1Check)
exit()
