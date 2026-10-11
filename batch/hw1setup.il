;; @gui  batch job: HW1 schematics + ADE L states (run via ~/AutoCircuit/run.sh hw1setup)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw1Setup)
exit()
