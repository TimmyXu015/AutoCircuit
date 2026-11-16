;; batch job: ECE203 ideal VCVS whole ECG (run.sh ece203_ideal)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('idealAll)
exit()
