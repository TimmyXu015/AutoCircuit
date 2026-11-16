;; batch job: ECE203 Round 2A -- build ece203_a12n_* cells, baseline run, probe noise results (run.sh ece203_noise_probe)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('nsProbe)
exit()
