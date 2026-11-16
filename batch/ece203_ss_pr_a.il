;; batch job: ECE203 Round 3B Stage A -- pseudo-resistor cell (pfet33x, lecture slide 30) I-V, -50..+50 mV at 0.9 V CM, DC + AC 1 mHz, default vs tight tolerances
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('prStageAJob)
exit()
