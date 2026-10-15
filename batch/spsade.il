;; @gui  batch job: ADE L states sps_100Hz / sps_1MHz in cs_strong and cs_sub (run.sh spsade)
;; No exit(): run.sh stops Virtuoso when the job prints its done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('spsAde)
