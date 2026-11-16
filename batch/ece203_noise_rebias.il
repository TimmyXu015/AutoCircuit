;; batch job: ECE203 Round 2A follow-up -- bounded VCP/VCN rebias of points with negative saturation margin (run.sh ece203_noise_rebias)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('nsRebiasAll)
exit()
