;; batch job: real capacitor at high frequency (run via ~/AutoCircuit/run.sh capc)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('capcRun)
exit()
