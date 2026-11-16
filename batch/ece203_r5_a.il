;; batch job: ECE203 Round 5 stage A -- isolated S2 + frozen C OTA: no LP / LP / LP + ideal unity buffer, Zout, stb, noise
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5StageA)
exit()
