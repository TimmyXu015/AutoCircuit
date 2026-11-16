;; batch job: ECE203 Round 3A 5T input-pair L scan (1/2/4/8 um) in the S2 single-stage BioAmp, DC + AC only
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('lsRunJob)
exit()
