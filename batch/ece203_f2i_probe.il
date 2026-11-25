;; batch job: ECE203 F2 interference - read-only library / ECG_tb probe
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('f2iProbe)
exit()
