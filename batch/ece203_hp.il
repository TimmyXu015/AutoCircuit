;; batch job: ECE203 Track D step 1 -- closed-loop ideal VCVS high-pass Project/ece203_hp_ideal_tb,
;; OCEAN dc op + ac + finite-gain sweep (run.sh ece203_hp)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hpAll)
exit()
