;; batch job: ECE203 A1/A2 cascode OTA + closed loop (run.sh ece203_a12)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('a12All)
exit()
