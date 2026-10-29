;; batch job: HW3 P2 -- new library HW3_203, CS amp schematic, VIN for 15 uA (run.sh hw3build)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw3BuildAll)
exit()
