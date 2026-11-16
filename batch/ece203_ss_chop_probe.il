;; batch job: ECE203 Round 3D probe of analogLib switch/vpulse pins and CDF
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('chProbe)
exit()
