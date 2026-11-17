;; ECE203 Round 5N-L: PMOS mirror channel-length test on the R5N P2 best low-noise circuit.
;; Base = ece203_r5n_tb_n16p16_t4 (OTA1 M1/M2 40u/32u, M3/M4 8u/16u, MT 32u/4u (tail x4), pseudo-R prw 4u).
;; Only M3/M4 L changes (W fixed 8 um): T1 24u, T2 32u, T3 36u. New cells ece203_r5nl_ota_l<L> / ece203_r5nl_tb_l<L>;
;; existing R5N cells and ADE states are not touched (no r5nBuildTb / r5nBuildOta calls).
;; Power: in the real-bias bench VDDD is a 0 V ammeter from vddd to vdd, so I(VDD) already contains I(VDDD) (DRL);
;; both are recorded, total = I(VDD).
;; Jobs: ece203_r5nl_a (DC/AC/noise of T1-T3), ece203_r5nl_c (signoff of the best valid), ece203_r5nl_ade.

r5nlDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r5nl")
procedure( r5nlOtaCell(lu) sprintf(nil "ece203_r5nl_ota_l%d" lu) )
procedure( r5nlTbCell(lu) sprintf(nil "ece203_r5nl_tb_l%d" lu) )
;; P2 devices with M3/M4 L replaced
procedure( r5nlOtaDevs(lu)
  list(list("pfetx" "M3" 8e-6 lu * 1e-6 "n1" "n1" "VDD" "VDD")
       list("pfetx" "M4" 8e-6 lu * 1e-6 "OUT" "n1" "VDD" "VDD")
       list("nfetx" "M1" 40e-6 32e-6 "n1" "INP" "tail" "GND")
       list("nfetx" "M2" 40e-6 32e-6 "x" "INN" "tail" "GND")
       list("nfetx" "MC" 10e-6 4e-6 "OUT" "VCAS" "x" "GND")
       list("nfetx" "MT" 32e-6 4e-6 "tail" "IBIAS" "GND" "GND")
       list("nfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "GND" "GND"))
)
procedure( r5nlBuild(lu)
  let( (cv cell)
    ece203LibInfo()
    cell = r5nlOtaCell(lu)
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv append(a3Cfg->pins '(("VCAS" "input"))))
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) r5nlOtaDevs(lu)))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
    otaTb(r5nlTbCell(lu)
          mapcar(lambda((e) if( caddr(e) == "XA" cons(car(e) cons(cell cddr(e))) e)) r5SpecsE("cs")))
    r5nlTbCell(lu)
  )
)
r5nlCols = append(r4ACols '(case m3_L_um ota1_area_um2 m3_id m3_gm m3_gmid m3_vsg m3_vsd m3_vth m3_vdsat m3_margin m3_region
                             m1_id m1_gm m1_gmid m1_vgs m1_vds m1_margin m2_vds m2_margin mc_margin margin_X2 I_total pr_check valid))
procedure( r5nlPv(inst p) car(errset(pv(inst p ?result "dcOpInfo") nil)) )
procedure( r5nlCase(port caseName lu)
  let( (cell tag r ok oldDir oldInsts nl m rows)
    cell = r5nlTbCell(lu) tag = sprintf(nil "%s_l%d" caseName lu)
    oldDir = r4Dir oldInsts = r4OpInsts
    r4Dir = r5nlDir r4OpInsts = append(r4OpInsts '("X2.MCS" "X2.MCL"))
    unless( isDir(r5nlDir) createDir(r5nlDir) )
    ok = errset(r = r4Ac(cell tag 'dm r5nOver(4e-6) t) t)
    unless( ok r = list(nil 'tag tag 'cell cell 'status "failed" 'reason sprintf(nil "%L" errset.errset)))
    when( ok
      r->m3_id = r5nlPv("/XA/M3" "id") r->m3_gm = r5nlPv("/XA/M3" "gm")
      r->m3_gmid = and(numberp(r->m3_gm) numberp(r->m3_id) abs(r->m3_gm / r->m3_id))
      r->m3_vsg = and(r5nlPv("/XA/M3" "vgs") -r5nlPv("/XA/M3" "vgs")) r->m3_vsd = and(r5nlPv("/XA/M3" "vds") -r5nlPv("/XA/M3" "vds"))
      r->m3_vth = r5nlPv("/XA/M3" "vth") r->m3_vdsat = r5nlPv("/XA/M3" "vdsat") r->m3_region = r5nlPv("/XA/M3" "region")
      r->m1_id = r5nlPv("/XA/M1" "id") r->m1_gm = r5nlPv("/XA/M1" "gm")
      r->m1_gmid = and(numberp(r->m1_gm) numberp(r->m1_id) abs(r->m1_gm / r->m1_id))
      r->m1_vgs = r5nlPv("/XA/M1" "vgs") r->m1_vds = r5nlPv("/XA/M1" "vds") r->m2_vds = r5nlPv("/XA/M2" "vds")
      rows = ece203OpDump(strcat(r5nlDir "/" tag "_ota1_dcop.csv") '("XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.MC" "XA.MT" "XA.MREF"))
      foreach(x rows
        cond( (car(x) == "XA.M3" r->m3_margin = ece203Margin(caddr(x)))
              (car(x) == "XA.M1" r->m1_margin = ece203Margin(caddr(x)))
              (car(x) == "XA.M2" r->m2_margin = ece203Margin(caddr(x)))
              (car(x) == "XA.MC" r->mc_margin = ece203Margin(caddr(x)))))
      m = ldMinMargin(ece203OpDump(strcat(r5nlDir "/" tag "_x2_dcop.csv") '("X2.MCS" "X2.MCL")) "X2.") r->margin_X2 = car(m)
      r->I_total = r->I_VDD
      nl = strcat(r5nlDir "/" tag "_netlist.scs")
      sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s" getShellEnvVar("HOME") cell nl))
      r->pr_check = if( sh(sprintf(nil "grep -q 'prw=4e-06' %s" nl)) "prw=4e-06" "check")
      sh(sprintf(nil "grep -n 'M3\\|M4' %s | grep -i 'pfet' | sed 's/^/AC>   m34: /' | cut -c1-220" nl))
      for(k 0 length(r5nNsBins) - 2
        nsSummary(strcat(r5nlDir "/" tag sprintf(nil "_ns_b%02d.txt" k)) 'integrated nth(k r5nNsBins) nth(k + 1 r5nNsBins))))
    r4Dir = oldDir r4OpInsts = oldInsts
    r->case = caseName r->m3_L_um = lu
    r->ota1_area_um2 = 2.0 * 8.0 * lu + 2.0 * 40.0 * 32.0 + 40.0 + 128.0 + 8.0
    r->valid = if( and(numberp(r->margin_A) r->margin_A > 0.03 numberp(r->Hout_100_dB) r->Hout_100_dB > 38.0
                       r->Hout_100_dB < 42.0 numberp(r->fH_out) r->fH_out > 225.0) "valid" "INVALID")
    acSay("r5nl %s: %s %s | H10/60/100 %s %s %s (%s dB) fL %s fH %s | I_VDD %s (incl. I_VDDD %s) | M3 id %s gm %s gm/id %s vsg %s vsd %s vth %s vdsat %s margin %s reg %s | M1 id %s gm/id %s vgs %s vds %s margin %s | M2 vds %s margin %s | MC %s | minA %s %s | X2 %s | noise app %s deemb %s | %s %s\n"
          tag r->status or(r->reason "") r4Num(r->Hout_10 "%.4g") r4Num(r->Hout_60 "%.4g") r4Num(r->Hout_100 "%.4g")
          r4Num(r->Hout_100_dB "%.2f") r4Num(r->fL_out "%.4g") r4Num(r->fH_out "%.4g") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g")
          r4Num(r->m3_id "%.4g") r4Num(r->m3_gm "%.4g") r4Num(r->m3_gmid "%.3g") r4Num(r->m3_vsg "%.4g") r4Num(r->m3_vsd "%.4g")
          r4Num(r->m3_vth "%.4g") r4Num(r->m3_vdsat "%.4g") r4Num(r->m3_margin "%.3f") r4Num(r->m3_region "%g")
          r4Num(r->m1_id "%.4g") r4Num(r->m1_gmid "%.3g") r4Num(r->m1_vgs "%.4g") r4Num(r->m1_vds "%.4g") r4Num(r->m1_margin "%.3f")
          r4Num(r->m2_vds "%.4g") r4Num(r->m2_margin "%.3f") r4Num(r->mc_margin "%.3f") r4Num(r->margin_A "%.3f") or(r->worst_A "")
          r4Num(r->margin_X2 "%.3f") r4Num(r->noise_app_in "%.4g") r4Num(r->noise_deemb_in "%.4g") or(r->pr_check "") r->valid)
    r4Row(port r5nlCols r)
    r
  )
)
procedure( r5nlOpen(name cols)
  let( (port)
    unless( isDir(r5nlDir) createDir(r5nlDir) )
    port = outfile(strcat(r5nlDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
;; T1-T3, plus a re-measurement of P2 (L 16 um) in the same script for the M3/M4 OP columns (rebuilds nothing: a NEW
;; cell ece203_r5nl_tb_l16 with the identical P2 devices)
procedure( r5nlStageA()
  let( (port)
    port = r5nlOpen("r5nl_cases.csv" r5nlCols)
    foreach(lu '(16 24 32 36)
      r5nlBuild(lu)
      r5nlCase(port if( lu == 16 "P2ref" "T") lu))
    close(port)
    t
  )
)
;; signoff of the best valid L (set after stage A)
r5nlBest = 36
procedure( r5nlStageC()
  let( (cell extra pre oldDir oldR5 oldInsts portS portB ok)
    cell = r5nlTbCell(r5nlBest) pre = sprintf(nil "C_l%d" r5nlBest)
    extra = append(r4RbVars list(list("cm2" 0.5e-12) list("prw" 4e-6) list("prl" 2e-6)))
    oldDir = r4Dir oldR5 = r5Dir oldInsts = r4OpInsts
    r4Dir = r5nlDir r5Dir = r5nlDir r4OpInsts = append(r4OpInsts '("X2.MCS" "X2.MCL"))
    ok = errset(
      progn(
        portS = r5nlOpen("r5nl_signoff_mainstb.csv" r5ECols)
        r5EMainStb(portS cell strcat(pre "_mainstb") r5nOver(4e-6))
        close(portS)
        portB = r5nlOpen("r5nl_signoff_drl.csv" r4BCols)
        r4BCase(portB "off" 0.01 extra pre cell)
        r4BCase(portB "real" 0.01 extra pre cell)
        close(portB)
        t)
      t)
    unless( ok acSay("r5nl signoff failed: %L\n" errset.errset))
    r4Dir = oldDir r5Dir = oldR5 r4OpInsts = oldInsts
    t
  )
)
procedure( r5nlAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("r5nlAde needs the GUI (run.sh ece203_r5nl_ade)\n") )
  r4AdeTb(r5nlTbCell(r5nlBest) sprintf(nil "r5nl_mirrorL%d_best" r5nlBest)
          append(r5nOver(4e-6) list(list("dcc" 0.01) list("itr" 1e-7))) t t t)
  t
)
