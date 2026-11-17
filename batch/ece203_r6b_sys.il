;; batch job: ECE203 Round 6B sys (real MOS TG chopper)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r6bStageSys)
exit()
