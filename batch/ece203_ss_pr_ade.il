;; @gui  batch job: ECE203 Round 3B ADE L states pr_w3u in ece203_ss_pr_iv_tb and ece203_ss_pr_tb (dc op + ac, tight options)
;; No exit() here (GUI replay): run.sh stops Virtuoso after the done/failed marker.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('prAde)
