;; batch job: ECE203 Round 3D 1 MHz ideal chopper short-window step test (ideal VCVS, real C OTA chopped, real C static)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('chRunJob)
exit()
