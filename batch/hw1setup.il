;; @gui  batch job: HW1 schematics + ADE L states (run via ~/AutoCircuit/run.sh hw1setup)
;; No exit() here: in GUI replay the next line runs as soon as the job yields to the event
;; loop (e.g. while spectre runs), which would quit mid-job. run.sh stops Virtuoso when
;; the job prints its done/failed marker in the log.
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('hw1Setup)
