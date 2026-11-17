;; batch job: ECE203 R6D-R (short). Run with AC_SKIP_GIT_PULL=1 from a pinned clone; setting via AC_R6DR_SETTING (A/B/C)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6drShort)
exit()
