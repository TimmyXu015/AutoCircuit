;; batch job: ECE203 Round 5 stage B -- real CD follower vs C OTA + PMOS CS second stage (Miller), DC/AC/noise/stb/Zout
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5StageB)
exit()
