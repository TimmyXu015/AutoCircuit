;; batch job: ECE203 A3 5T OTA (run.sh ece203_a3)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('a3All)
exit()
