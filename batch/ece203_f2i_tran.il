;; batch job: ECE203 F2 1 uA interference (tran). Env (tran): AC_F2I_CASES (space-separated), AC_F2I_STOP (s, default 3), AC_F2I_MAXSTEP (default 50u)
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
acBatch('f2iJobTran)
exit()
