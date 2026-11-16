;; batch job: ECE203 Round 4 stage D read-only -- PSS periodic steady state of the 4 kHz chopper runs
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4DPssRead)
exit()
