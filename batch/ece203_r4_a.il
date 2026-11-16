;; batch job: ECE203 Round 4 stage A -- build r4 cells, signal chain DC/AC/Zin/noise (ideal Rfb, LP loading, LP alt, pseudo-R)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4StageA)
exit()
