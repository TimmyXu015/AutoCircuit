;; @gui  batch job: ADE L states A_ideal/B_rs/C_rs_cl x 100Hz/1MHz in cs_strong_gate and cs_sub_gate (run.sh spsgade)
;; No exit(): run.sh stops Virtuoso when the job prints its done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('spsgAde)
