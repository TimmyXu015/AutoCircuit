;; batch job: one table of all gate-driven configurations (run.sh spsgsum)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('spsgSummary)
exit()
