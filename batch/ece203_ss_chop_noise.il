;; batch job: ECE203 Round 3E ideal 1 MHz chopper noise demo (calibrated noisy ideal OTA): U static noise, U and C PSS+PNoise+PAC
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('cnRunJob)
exit()
