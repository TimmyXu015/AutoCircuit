;; @gui  batch job: ECE203 Round 5N ADE L states (r5n_submission_baseline, r5n_low_noise_best)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('r5nAde)
