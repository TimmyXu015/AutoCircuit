;; ECE203 R8B: isolate the R6A-era diagnostic EOC (vcvs, gain 1) + CHP (1 MF) from the R7F G0 loaded bench and retry the R8 PSS.
;; New cell Project/ece203_r8b_tb_noeoc_chp = r7fSpecs("gain_g0_load10p") minus exactly EOC and CHP (RHP 1 TOhm and EB2 kept).
;; Task: docs/ECE203_round8b_pss_fixture_isolation_task.md; plan docs/ece203_data/round8b/r8b_plan.md.
;; Measurement code = R8 (ece203_r8_noise.il: r8StageA, r8Tran0, r8Periodic) with r8Cell / r8Dir / r8Tmp / r8Wd rebound.
;; Jobs: ece203_r8b_build, ece203_r8b_a (Gate A OFF), ece203_r8b_t0, ece203_r8b_pss (AC_R8_STEP a1|a2),
;;       ece203_r8b_pac (AC_R8_PSS = converged attempt), ece203_r8b_pn (AC_R8_STEP = 10|30|60|90).

r8bCell = "ece203_r8b_tb_noeoc_chp"
r8bDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r8b")
r8bTmp = "/tmp/lix015_r8b"
procedure( r8bSpecs()
  let( (all keep gone)
    all = r7fSpecs("gain_g0_load10p")
    keep = setof(e all !member(caddr(e) '("EOC" "CHP")))
    gone = setof(e all member(caddr(e) '("EOC" "CHP")))
    unless( length(gone) == 2 && length(all) - length(keep) == 2 error("expected exactly EOC and CHP once each, found %L" mapcar('caddr gone)))
    keep
  )
)
procedure( r8bBuild()
  ece203LibInfo()
  foreach(x list("ece203_r7f_tb_gain_g0_load10p" "ece203_ss_pr_cell" r7aCmfbCell("a2") r6dCells->cd) unless( ddGetObj(ece203Lib x) error("missing %s" x)))
  when( ddGetObj(ece203Lib r8bCell) error("%s already exists" r8bCell))
  otaTb(r8bCell r8bSpecs())
  t
)
;; run an R8 stage function on the R8B cell with R8B output / tmp / watchdog
procedure( r8bOn(fn @rest args)
  let( (oc od ot ow res)
    oc = r8Cell od = r8Dir ot = r8Tmp ow = r8Wd
    r8Cell = r8bCell r8Dir = r8bDir r8Tmp = r8bTmp r8Wd = "r8b_watchdog.sh"
    res = errset(apply(fn args) t)
    r8Cell = oc r8Dir = od r8Tmp = ot r8Wd = ow
    unless( res error("%L" errset.errset))
    t
  )
)
procedure( r8bA() r8bOn('r8StageA) )
procedure( r8bT0() r8bOn('r8Tran0) )
procedure( r8bPss() r8bOn('r8Pss) )
procedure( r8bPac() r8bOn('r8Pac) )
procedure( r8bPn() r8bOn('r8Pn) )
