;; batch job: ECE203 Round 3 single-stage BioAmp -- build ece203_ss_ideal_tb / ece203_ss_real_tb, OCEAN stages A-D
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('ssRunJob)
exit()
