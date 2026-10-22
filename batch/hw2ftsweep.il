;; batch job: HW2 P1 f_t vs vgs, 0 .. 1.8 V, both sizes (run via ~/AutoCircuit/run.sh hw2ftsweep)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw2FtSweep)
exit()
