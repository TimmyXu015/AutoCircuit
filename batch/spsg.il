;; batch job: gate-driven sub vs strong CS amp -- build cs_strong_gate/cs_sub_gate and check they simulate (run.sh spsg)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('spsgRun)
exit()
