;; batch job: ECE203 Round 3C B/P/C OTA comparison in the S2 bench (ideal Rfb, tight tolerances): DC + AC + noise 0.1-250 Hz
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ocRunJob)
exit()
