;; batch job: ECE203 extract ece203_hp_fb + re-run the VCVS closed loop (run.sh ece203_hpfb)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hpFbAll)
exit()
