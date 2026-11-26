;; batch job: ECE203 F2 final validation scout -- OCEAN noiseSummary / Calculator read-back of a standalone f2v run. Env AC_F2V_RUN (default nom2)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('f2vOcean)
exit()
