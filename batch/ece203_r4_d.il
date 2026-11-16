;; batch job: ECE203 Round 4 stage D -- chopper bonus: real C OTA + ideal switches at 4 kHz, step check then PSS+PNoise
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4StageD)
exit()
