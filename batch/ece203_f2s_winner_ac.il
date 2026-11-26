;; batch job: ECE203 F2S -- ADE netlist (DC+AC) of the winner with its design variables, for the audit
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('f2sJobWinnerAc)
exit()
