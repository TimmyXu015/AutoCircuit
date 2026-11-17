;; ECE203 Round 5N-N: NMOS input-pair area test on the R5N-L best circuit (ece203_r5nl_tb_l36).
;; Base = R5N-L T3: M3/M4 8u/36u, M1/M2 40u/32u, MC 10u/4u, MT 32u/4u (tail x4), MREF 2u/4u, pseudo-R prw 4u.
;; Only M1/M2 W/L change (symmetric): N1 45u/36u, N2 50u/40u. New cells ece203_r5nn_ota_<case> / ece203_r5nn_tb_<case>;
;; existing R5N / R5N-L cells and ADE states are not touched.
;; Power: VDDD is a 0 V ammeter from vddd to vdd in this bench, so I(VDD) already contains the DRL branch; total = I(VDD).
;; Jobs: ece203_r5nn_a (DC/AC/noise of N1, N2), ece203_r5nn_b (signoff of the best valid), ece203_r5nn_ade.

r5nnDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r5nn")
r5nnCases = '(("N1" 45 36) ("N2" 50 40))
procedure( r5nnOtaCell(name) sprintf(nil "ece203_r5nn_ota_%s" lowerCase(name)) )
procedure( r5nnTbCell(name) sprintf(nil "ece203_r5nn_tb_%s" lowerCase(name)) )
procedure( r5nnOtaDevs(wu lu)
  list(list("pfetx" "M3" 8e-6 36e-6 "n1" "n1" "VDD" "VDD")
       list("pfetx" "M4" 8e-6 36e-6 "OUT" "n1" "VDD" "VDD")
       list("nfetx" "M1" wu * 1e-6 lu * 1e-6 "n1" "INP" "tail" "GND")
       list("nfetx" "M2" wu * 1e-6 lu * 1e-6 "x" "INN" "tail" "GND")
       list("nfetx" "MC" 10e-6 4e-6 "OUT" "VCAS" "x" "GND")
       list("nfetx" "MT" 32e-6 4e-6 "tail" "IBIAS" "GND" "GND")
       list("nfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "GND" "GND"))
)
procedure( r5nnBuild(name wu lu)
  let( (cv cell)
    ece203LibInfo()
    cell = r5nnOtaCell(name)
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv append(a3Cfg->pins '(("VCAS" "input"))))
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) r5nnOtaDevs(wu lu)))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
    otaTb(r5nnTbCell(name)
          mapcar(lambda((e) if( caddr(e) == "XA" cons(car(e) cons(cell cddr(e))) e)) r5SpecsE("cs")))
    r5nnTbCell(name)
  )
)
r5nnCols = append(r4ACols '(case m1_W_um m1_L_um m1_area_um2 ota1_area_um2
                             m1_id m1_gm m1_gmid m1_vgs m1_vds m1_vth m1_vdsat m1_margin m1_cgg m1_cgs m1_cgd
                             m2_vds m2_margin m3_id m3_gm m3_gmid m3_vsg m3_vsd m3_margin m4_vsd m4_margin mc_margin margin_X2
                             I_total P_total pr_check valid))
procedure( r5nnPv(inst p) car(errset(pv(inst p ?result "dcOpInfo") nil)) )
procedure( r5nnCase(port name wu lu)
  let( (cell tag r ok oldDir oldInsts nl m rows)
    cell = r5nnTbCell(name) tag = name
    oldDir = r4Dir oldInsts = r4OpInsts
    r4Dir = r5nnDir r4OpInsts = append(r4OpInsts '("X2.MCS" "X2.MCL"))
    unless( isDir(r5nnDir) createDir(r5nnDir) )
    ok = errset(r = r4Ac(cell tag 'dm r5nOver(4e-6) t) t)
    unless( ok r = list(nil 'tag tag 'cell cell 'status "failed" 'reason sprintf(nil "%L" errset.errset)))
    when( ok
      r->m1_id = r5nnPv("/XA/M1" "id") r->m1_gm = r5nnPv("/XA/M1" "gm")
      r->m1_gmid = and(numberp(r->m1_gm) numberp(r->m1_id) abs(r->m1_gm / r->m1_id))
      r->m1_vgs = r5nnPv("/XA/M1" "vgs") r->m1_vds = r5nnPv("/XA/M1" "vds")
      r->m1_vth = r5nnPv("/XA/M1" "vth") r->m1_vdsat = r5nnPv("/XA/M1" "vdsat")
      r->m1_cgg = r5nnPv("/XA/M1" "cgg") r->m1_cgs = r5nnPv("/XA/M1" "cgs") r->m1_cgd = r5nnPv("/XA/M1" "cgd")
      r->m2_vds = r5nnPv("/XA/M2" "vds")
      r->m3_id = r5nnPv("/XA/M3" "id") r->m3_gm = r5nnPv("/XA/M3" "gm")
      r->m3_gmid = and(numberp(r->m3_gm) numberp(r->m3_id) abs(r->m3_gm / r->m3_id))
      r->m3_vsg = and(r5nnPv("/XA/M3" "vgs") -r5nnPv("/XA/M3" "vgs")) r->m3_vsd = and(r5nnPv("/XA/M3" "vds") -r5nnPv("/XA/M3" "vds"))
      r->m4_vsd = and(r5nnPv("/XA/M4" "vds") -r5nnPv("/XA/M4" "vds"))
      rows = ece203OpDump(strcat(r5nnDir "/" tag "_ota1_dcop.csv") '("XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.MC" "XA.MT" "XA.MREF"))
      foreach(x rows
        cond( (car(x) == "XA.M1" r->m1_margin = ece203Margin(caddr(x)))
              (car(x) == "XA.M2" r->m2_margin = ece203Margin(caddr(x)))
              (car(x) == "XA.M3" r->m3_margin = ece203Margin(caddr(x)))
              (car(x) == "XA.M4" r->m4_margin = ece203Margin(caddr(x)))
              (car(x) == "XA.MC" r->mc_margin = ece203Margin(caddr(x)))))
      m = ldMinMargin(ece203OpDump(strcat(r5nnDir "/" tag "_x2_dcop.csv") '("X2.MCS" "X2.MCL")) "X2.") r->margin_X2 = car(m)
      r->I_total = r->I_VDD
      r->P_total = and(numberp(r->I_VDD) r->I_VDD * 1.8)
      nl = strcat(r5nnDir "/" tag "_netlist.scs")
      sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s" getShellEnvVar("HOME") cell nl))
      r->pr_check = if( sh(sprintf(nil "grep -q 'prw=4e-06' %s" nl)) "prw=4e-06" "check")
      sh(sprintf(nil "grep -n ' M1 \\| M2 \\| M3 \\| M4 ' %s | sed 's/^/AC>   dev: /' | cut -c1-220" nl))
      for(k 0 length(r5nNsBins) - 2
        nsSummary(strcat(r5nnDir "/" tag sprintf(nil "_ns_b%02d.txt" k)) 'integrated nth(k r5nNsBins) nth(k + 1 r5nNsBins))))
    r4Dir = oldDir r4OpInsts = oldInsts
    r->case = name r->m1_W_um = wu r->m1_L_um = lu r->m1_area_um2 = float(wu * lu)
    r->ota1_area_um2 = 2.0 * 8.0 * 36.0 + 2.0 * wu * lu + 40.0 + 128.0 + 8.0
    r->valid = if( and(numberp(r->margin_A) r->margin_A > 0.03 numberp(r->Hout_100_dB) r->Hout_100_dB > 38.0
                       r->Hout_100_dB < 42.0 numberp(r->fH_out) r->fH_out > 225.0) "valid" "INVALID")
    acSay("r5nn %s: %s %s | H10/60/100 %s %s %s (%s dB) fL %s fH %s | Zin P/N %s %s | I_VDD %s (incl. I_VDDD %s) P %s | M1 id %s gm %s gm/id %s vgs %s vds %s vth %s vdsat %s margin %s cgg %s cgs %s cgd %s | M2 vds %s margin %s | M3 gm/id %s vsg %s margin %s | M4 vsd %s margin %s | MC %s | minA %s %s | X2 %s | noise app %s deemb %s | %s %s\n"
          tag r->status or(r->reason "") r4Num(r->Hout_10 "%.4g") r4Num(r->Hout_60 "%.4g") r4Num(r->Hout_100 "%.4g")
          r4Num(r->Hout_100_dB "%.2f") r4Num(r->fL_out "%.4g") r4Num(r->fH_out "%.4g")
          r4Num(r->Zin_amp_P_10 "%.4g") r4Num(r->Zin_amp_N_10 "%.4g") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->P_total "%.4g")
          r4Num(r->m1_id "%.4g") r4Num(r->m1_gm "%.4g") r4Num(r->m1_gmid "%.3g") r4Num(r->m1_vgs "%.4g") r4Num(r->m1_vds "%.4g")
          r4Num(r->m1_vth "%.4g") r4Num(r->m1_vdsat "%.4g") r4Num(r->m1_margin "%.3f") r4Num(r->m1_cgg "%.4g") r4Num(r->m1_cgs "%.4g") r4Num(r->m1_cgd "%.4g")
          r4Num(r->m2_vds "%.4g") r4Num(r->m2_margin "%.3f") r4Num(r->m3_gmid "%.3g") r4Num(r->m3_vsg "%.4g") r4Num(r->m3_margin "%.3f")
          r4Num(r->m4_vsd "%.4g") r4Num(r->m4_margin "%.3f") r4Num(r->mc_margin "%.3f") r4Num(r->margin_A "%.3f") or(r->worst_A "")
          r4Num(r->margin_X2 "%.3f") r4Num(r->noise_app_in "%.4g") r4Num(r->noise_deemb_in "%.4g") or(r->pr_check "") r->valid)
    r4Row(port r5nnCols r)
    r
  )
)
procedure( r5nnOpen(name cols)
  let( (port)
    unless( isDir(r5nnDir) createDir(r5nnDir) )
    port = outfile(strcat(r5nnDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
;; Stage A: N1, N2 only (T3 reference = R5N-L T_l36 data)
procedure( r5nnStageA()
  let( (port)
    port = r5nnOpen("r5nn_cases.csv" r5nnCols)
    foreach(c r5nnCases
      r5nnBuild(car(c) cadr(c) caddr(c))
      r5nnCase(port car(c) cadr(c) caddr(c)))
    close(port)
    t
  )
)
;; Stage B: signoff of the best valid case (set after stage A)
r5nnBest = "N2"
procedure( r5nnStageB()
  let( (cell extra pre oldDir oldR5 oldInsts portS portB ok)
    cell = r5nnTbCell(r5nnBest) pre = sprintf(nil "B_%s" r5nnBest)
    extra = append(r4RbVars list(list("cm2" 0.5e-12) list("prw" 4e-6) list("prl" 2e-6)))
    oldDir = r4Dir oldR5 = r5Dir oldInsts = r4OpInsts
    r4Dir = r5nnDir r5Dir = r5nnDir r4OpInsts = append(r4OpInsts '("X2.MCS" "X2.MCL"))
    ok = errset(
      progn(
        portS = r5nnOpen("r5nn_signoff_mainstb.csv" r5ECols)
        r5EMainStb(portS cell strcat(pre "_mainstb") r5nOver(4e-6))
        close(portS)
        portB = r5nnOpen("r5nn_signoff_drl.csv" r4BCols)
        r4BCase(portB "off" 0.01 extra pre cell)
        r4BCase(portB "real" 0.01 extra pre cell)
        close(portB)
        t)
      t)
    unless( ok acSay("r5nn signoff failed: %L\n" errset.errset))
    r4Dir = oldDir r5Dir = oldR5 r4OpInsts = oldInsts
    t
  )
)
procedure( r5nnAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("r5nnAde needs the GUI (run.sh ece203_r5nn_ade)\n") )
  r4AdeTb(r5nnTbCell(r5nnBest) sprintf(nil "r5nn_inputpair_%s_best" lowerCase(r5nnBest))
          append(r5nOver(4e-6) list(list("dcc" 0.01) list("itr" 1e-7))) t t t)
  t
)
