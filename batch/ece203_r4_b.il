;; batch job: ECE203 Round 4 stage B -- DRL off / ideal / real: CMRR@60Hz (Cc 1% mismatch and matched), 0.1 uA body interference, DRL stb, 50 ms interference transient
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r4StageB)
exit()
