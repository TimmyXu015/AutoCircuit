;; batch job: ECE203 Round 2A noise scan -- Stage 1 breakdown, Stage 2 W/L grid, Stage 3 mirror area (run.sh ece203_noise_scan)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('nsAll)
exit()
