;; batch job: ECE203 F2S -- build OTA1 + system cells for the cases in AC_F2S_CASES and write their ADE netlists (ece203_f2s.il)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('f2sJobBuild)
exit()
