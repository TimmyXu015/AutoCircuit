;; batch job: HW2 P1 f_t check at vgs = 0.25 V (run via ~/AutoCircuit/run.sh hw2check)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw2Check)
exit()
