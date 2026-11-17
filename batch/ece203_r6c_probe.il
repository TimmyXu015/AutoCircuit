;; batch job: R6C one-off probe - analogLib vcvs CDF parameter names (for output clipping) and Spectre version
load(strcat(or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit")) "/ac.il"))
let( (cdf)
  foreach(c '("vcvs" "vdc")
    cdf = cdfGetBaseCellCDF(ddGetObj("analogLib" c))
    foreach(p cdf~>parameters printf("AC> %s param %s | %L | default %L\n" c p~>name p~>prompt p~>defValue)))
  printf("AC> spectre: %L\n" car(errset(sh("spectre -W > /tmp/r6c_spver.txt 2>&1") nil)))
)
exit()
