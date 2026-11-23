;; ECE203 R7D: the two ideal 50 nA bias sources of the R7C system (IB vdd->ib, IBD vddd->ibd) are replaced by ONE ideal
;; 100 nA reference (IREF pref -> gnd!) and real PMOS mirrors (pfetx, L 4u): MP0 diode at pref (from vdd), MP1 pref -> ib
;; (from vdd, feeds XA.MREF and the IBIAS gates of XC/XCD), MP2 pref -> ibd (source and bulk on vddd, feeds XD.MREF).
;; Everything else = R7C Project/ece203_r7c_tb_pr_w4 (read-only C0). Task: docs/ECE203_round7d_mos_bias_mirror_integration_task.md
;; Jobs: ece203_r7d_build (AC_R7D_CAND=a0|a1), ece203_r7d_a (Stage A DC: C0 + candidate), ece203_r7d_b (Stage B static),
;;       ece203_r7d_c (Stage C 60 ms tran), ece203_r7d_ade.

r7dDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r7d")
r7dTmp = "/tmp/lix015_r7d"
r7dStall = 240
;; candidates (L 4u fixed). a0 = task's pre-registered 4:2:2 (R4 C3 sizes). a1 only after a registered Stage A failure.
r7dCands = list(nil 'a0 list(nil 'w0 4e-6 'w1 2e-6 'w2 2e-6))
procedure( r7dCand() or(getShellEnvVar("AC_R7D_CAND") "a0") )
procedure( r7dCell(v) strcat("ece203_r7d_tb_bias_" v) )
procedure( r7dP(v) let( (p) p = get(r7dCands stringToSymbol(v)) unless( p error("unknown candidate %s" v)) p ) )
r7dBiasInsts = '("MP0" "MP1" "MP2" "XA.MREF" "XA.MT" "XD.MREF" "XD.MT" "XC.MTA" "XC.MTB" "XCD.MKP" "XCD.MKN")

procedure( r7dSpecs(v)
  let( (p old keep)
    p = r7dP(v)
    old = r7cSpecs()
    keep = setof(e old !member(caddr(e) '("IB" "IBD")))
    unless( length(old) - length(keep) == 2 error("expected exactly IB and IBD in r7cSpecs, removed %d" length(old) - length(keep)))
    append(keep
           list(otaI("IREF" "100n" "pref" "gnd!")
                ece203FetSpec("pfetx" "MP0" p->w0 4e-6 "pref" "pref" "vdd" "vdd")
                ece203FetSpec("pfetx" "MP1" p->w1 4e-6 "ib" "pref" "vdd" "vdd")
                ece203FetSpec("pfetx" "MP2" p->w2 4e-6 "ibd" "pref" "vddd" "vddd")))
  )
)
procedure( r7dBuild()
  let( (v cell)
    ece203LibInfo()
    v = r7dCand() cell = r7dCell(v)
    foreach(x list("ece203_ss_pr_cell" r7aCmfbCell("a2") r6dCells->cd "ece203_r7c_tb_pr_w4") unless( ddGetObj(ece203Lib x) error("missing %s" x)))
    when( ddGetObj(ece203Lib cell) error("%s already exists" cell))
    otaTb(cell r7dSpecs(v))
    t
  )
)
;; R7C pr_w4 case variables (r7aSysBase + prw 4u prl 2u); ib3 / ibd stay defined but are unused in the R7D cell
procedure( r7dVars() r7cVars("pr_w4") )

;; ---------- Stage A: DC op, TG static phase A, C0 (R7C cell, read-only) and the candidate ----------
r7dACols = '(case cell status reason V_pref V_ib V_ibd V_vg I_VDD I_VDDD P_uW I_IREF I_IB_ideal I_IBD_ideal
             MP0_id MP1_id MP2_id XA_MREF_id XD_MREF_id MP1_over_MP0 MP2_over_MP0
             MP0_vsg MP0_vsd MP0_vdsat MP0_region MP1_vsd MP1_vdsat MP1_region MP1_margin MP2_vsd MP2_vdsat MP2_region MP2_margin
             op_cm pn_cm minA worstA minC worstC minD worstD minCD worstCD)
procedure( r7dOpCase(r cell tag bias)
  let( (rows ids)
    ece203Setup(cell strcat("_" tag))
    r6bOpt(r6bSysOpts)
    analysis('dc ?saveOppoint t)
    if( bias then car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS" "/IREF/PLUS") nil))
              else car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS" "/IB/PLUS" "/IBD/PLUS") nil)))
    r6bSet(r6Vars append(r7dVars() list(list("dcc" 0.01))))
    run()
    r->V_pref = car(errset(ldDc("pref") nil)) r->V_ib = ldDc("ib") r->V_ibd = ldDc("ibd") r->V_vg = ldDc("vg")
    r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDDD = ldIdc("/VDDD/PLUS") r->P_uW = 1.8e6 * (r->I_VDD + r->I_VDDD)
    if( bias then r->I_IREF = ldIdc("/IREF/PLUS") else r->I_IB_ideal = ldIdc("/IB/PLUS") r->I_IBD_ideal = ldIdc("/IBD/PLUS"))
    r->op_cm = (ldDc("op") + ldDc("on")) / 2.0 r->pn_cm = (ldDc("p") + ldDc("n")) / 2.0
    rows = ece203OpDump(sprintf(nil "%s/%s_dcop.csv" r7dDir tag)
                        append(if( bias '("MP0" "MP1" "MP2") nil)
                               append('("XA.MREF" "XA.MT" "XA.M1" "XA.M2" "XA.MC1" "XA.MC2" "XA.M3" "XA.M4"
                                        "XD.MREF" "XD.MT" "XD.M1" "XD.M2" "XD.M3" "XD.M4"
                                        "XCD.MSP" "XCD.MSN" "XCD.MKP" "XCD.MKN" "XPRN.MP" "XPRP.MP")
                                      r7aCmfbInsts)))
    ids = nil
    foreach(x rows
      let( (n vals m grp)
        n = car(x) vals = caddr(x) m = ece203Margin(vals) grp = car(parseString(n "."))
        ids = cons(list(n vals m) ids)
        when( numberp(m) && !member(n '("XPRN.MP" "XPRP.MP"))
          when( grp == "XA" && (!r->minA || m < r->minA) r->minA = m r->worstA = n)
          when( grp == "XC" && (!r->minC || m < r->minC) r->minC = m r->worstC = n)
          when( grp == "XD" && (!r->minD || m < r->minD) r->minD = m r->worstD = n)
          when( grp == "XCD" && (!r->minCD || m < r->minCD) r->minCD = m r->worstCD = n))))
    foreach(q '(("MP0" MP0_id) ("MP1" MP1_id) ("MP2" MP2_id) ("XA.MREF" XA_MREF_id) ("XD.MREF" XD_MREF_id))
      let( (e) e = assoc(car(q) ids) when( e putprop(r nth(0 cadr(e)) cadr(q)))))
    when( bias
      foreach(q '(("MP0" MP0_vsd MP0_vdsat MP0_region nil) ("MP1" MP1_vsd MP1_vdsat MP1_region MP1_margin) ("MP2" MP2_vsd MP2_vdsat MP2_region MP2_margin))
        let( (e) e = assoc(car(q) ids)
          when( e
            putprop(r and(numberp(nth(4 cadr(e))) -1.0 * nth(4 cadr(e))) nth(1 q))
            putprop(r and(numberp(nth(6 cadr(e))) abs(nth(6 cadr(e)))) nth(2 q))
            putprop(r nth(7 cadr(e)) nth(3 q))
            when( nth(4 q) putprop(r caddr(e) nth(4 q))))))
      let( (e) e = assoc("MP0" ids) when( e r->MP0_vsg = and(numberp(nth(3 cadr(e))) -1.0 * nth(3 cadr(e)))))
      r->MP1_over_MP0 = and(numberp(r->MP1_id) numberp(r->MP0_id) r->MP0_id != 0.0 r->MP1_id / r->MP0_id)
      r->MP2_over_MP0 = and(numberp(r->MP2_id) numberp(r->MP0_id) r->MP0_id != 0.0 r->MP2_id / r->MP0_id))
    sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs; cp %s/simulation/%s/spectre/schematic_%s/psf/spectre.out %s/%s_spectre.out 2>/dev/null; rm -rf %s/simulation/%s/spectre/schematic_%s/psf"
               getShellEnvVar("HOME") cell r7dDir tag getShellEnvVar("HOME") cell tag r7dDir tag getShellEnvVar("HOME") cell tag))
    t
  )
)
procedure( r7dStageA()
  let( (port v)
    ece203LibInfo()
    r7cMkdir(r7dDir)
    v = r7dCand()
    port = outfile(strcat(r7dDir "/A_" v ".csv") "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString r7dACols) ","))
    foreach(c list(list("C0_r7c" "ece203_r7c_tb_pr_w4" nil) list(strcat("C1_" v) r7dCell(v) t))
      let( (r ok)
        r = list(nil 'case car(c) 'cell cadr(c) 'status "ok")
        ok = errset(r7dOpCase(r cadr(c) strcat("A_" car(c)) caddr(c)) t)
        unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
        acSay("r7dA %s: %s %s | V pref %s ib %s ibd %s | IREF %s IB %s IBD %s | id MP0 %s MP1 %s MP2 %s ratio %s %s | XA.MREF %s XD.MREF %s\n"
              car(c) r->status or(r->reason "") r7cNum(r->V_pref) r7cNum(r->V_ib) r7cNum(r->V_ibd) r7cNum(r->I_IREF) r7cNum(r->I_IB_ideal) r7cNum(r->I_IBD_ideal)
              r7cNum(r->MP0_id) r7cNum(r->MP1_id) r7cNum(r->MP2_id) r7cNum(r->MP1_over_MP0) r7cNum(r->MP2_over_MP0) r7cNum(r->XA_MREF_id) r7cNum(r->XD_MREF_id))
        acSay("r7dA %s: MP0 vsg %s vsd %s region %s | MP1 vsd %s vdsat %s region %s margin %s | MP2 vsd %s vdsat %s region %s margin %s | I_VDD %s I_VDDD %s P %s uW | op cm %s pn cm %s | min A %s %s C %s %s D %s %s CD %s %s\n"
              car(c) r7cNum(r->MP0_vsg) r7cNum(r->MP0_vsd) r7cNum(r->MP0_region) r7cNum(r->MP1_vsd) r7cNum(r->MP1_vdsat) r7cNum(r->MP1_region) r7cNum(r->MP1_margin)
              r7cNum(r->MP2_vsd) r7cNum(r->MP2_vdsat) r7cNum(r->MP2_region) r7cNum(r->MP2_margin) r7cNum(r->I_VDD) r7cNum(r->I_VDDD) r7cNum(r->P_uW)
              r7cNum(r->op_cm) r7cNum(r->pn_cm) r7cNum(r->minA) or(r->worstA "") r7cNum(r->minC) or(r->worstC "") r7cNum(r->minD) or(r->worstD "") r7cNum(r->minCD) or(r->worstCD ""))
        fprintf(port "%s\n" buildString(mapcar(lambda((k) r7cNum(get(r k))) r7dACols) ","))))
    close(port)
    t
  )
)

;; ---------- Stage B: TG static phase A via the R7C measurement (r7cStageB1), results into r7dDir ----------
procedure( r7dStageB()
  let( (v oldDir key res r)
    ece203LibInfo()
    v = r7dCand() key = stringToSymbol(strcat("bias_" v))
    putprop(r7cCases list(nil 'cell r7dCell(v) 'prw 4e-6) key)
    oldDir = r7cDir r7cDir = r7dDir
    res = errset(r7cStageB1(strcat("bias_" v) r6bSysOpts "") t)
    ;; bias / DRL operating points at the Stage B condition (dcc 0.01)
    r = list(nil 'case strcat("B_bias_" v))
    when( res errset(r7dOpCase(r r7dCell(v) strcat("B_bias_" v "_biasop") t) t))
    r7cDir = oldDir
    unless( res error("%L" errset.errset))
    acSay("r7dB bias op: V pref %s ib %s ibd %s | id MP0 %s MP1 %s MP2 %s | margins MP1 %s MP2 %s | P %s uW | min D %s %s\n"
          r7cNum(r->V_pref) r7cNum(r->V_ib) r7cNum(r->V_ibd) r7cNum(r->MP0_id) r7cNum(r->MP1_id) r7cNum(r->MP2_id)
          r7cNum(r->MP1_margin) r7cNum(r->MP2_margin) r7cNum(r->P_uW) r7cNum(r->minD) or(r->worstD ""))
    t
  )
)

;; ---------- Stage C: 60 ms 2 kHz TG tran (R7C setting C), + pref / ib / ibd and bias-branch currents ----------
r7dTCols = '(tag cand status reason t_end stalled_at fp_cm_avg op_cm_avg pn_cm_avg vg_min vg_max ib_min ib_max ibd_min ibd_max pref_min pref_max I_VDD I_VDDD rows csv)
procedure( r7dStageC()
  let( (cand cell tag r ok sim psf vid names waves file wlog port t1 t0 out ws iv id nm w)
    cand = r7dCand() cell = r7dCell(cand) tag = sprintf(nil "T_bias_%s" cand)
    out = strcat(r7dTmp "/out") r7cMkdir(out) r7cMkdir(r7dDir)
    port = outfile(sprintf(nil "%s/%s.csv" r7dDir tag) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString r7dTCols) ","))
    r = list(nil 'tag tag 'cand cand 'status "ok")
    sim = sprintf(nil "%s/sim_%s" r7dTmp tag) psf = strcat(sim "/psf")
    sh(sprintf(nil "rm -rf %s" sim))
    wlog = strcat(out "/watchdog.log")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        resultsDir(sim)
        r6bOpt('(gmin "1e-18" iabstol "1e-17" reltol "1e-5"))
        analysis('tran ?stop "60m" ?maxstep "0.5u" ?cmin "1e-17")
        car(errset(saveOption('save "selected") nil))
        car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr" "/bufp" "/bufn" "/p" "/n" "/pref" "/ib" "/ibd") nil))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS" "/IREF/PLUS" "/MP1/D" "/MP2/D" "/MP0/D") nil))
        r6bSet(r6Vars append(r7dVars() list(list("chen" 1.0) list("tch" 500e-6) list("vd" 1e-3))))
        sh(sprintf(nil "nohup bash %s/tools/r7d_watchdog.sh %s %s %d %s > /dev/null 2>&1 &" acRoot tag psf r7dStall wlog))
        run()
        when( isFile(strcat(sim "/WATCHDOG_STALL"))
          r->stalled_at = car(errset(let( (pt l) pt = infile(strcat(sim "/WATCHDOG_STALL")) gets(l pt) close(pt) car(parseString(l "\n"))) nil))
          error("stalled (watchdog)"))
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        r->t_end = r6bTend(vid)
        when( r->t_end < 0.99 * 60e-3 error("tran stopped at %g s" r->t_end))
        ws = list(vid) names = "t_s,vid_V"
        foreach(n '("fp" "fn" "op" "on" "vg" "drlr" "bufp" "bufn" "p" "n" "pref" "ib" "ibd")
          ws = append(ws list(v(strcat("/" n) ?result "tran"))) names = strcat(names "," n "_V"))
        foreach(q '(("/VDD/PLUS" "i_vdd_A") ("/VDDD/PLUS" "i_vddd_A") ("/IREF/PLUS" "i_iref_A") ("/MP0/D" "i_mp0_d_A") ("/MP1/D" "i_mp1_d_A") ("/MP2/D" "i_mp2_d_A"))
          w = car(errset(i(car(q) ?result "tran") nil))
          if( w then ws = append(ws list(w)) names = strcat(names "," cadr(q)) else acSay("r7dT: current %s not saved\n" car(q))))
        t1 = r->t_end t0 = 0.04
        r->fp_cm_avg = chAvg((v("/fp" ?result "tran") + v("/fn" ?result "tran")) / 2.0 t0 t1)
        r->op_cm_avg = chAvg((v("/op" ?result "tran") + v("/on" ?result "tran")) / 2.0 t0 t1)
        r->pn_cm_avg = chAvg((v("/p" ?result "tran") + v("/n" ?result "tran")) / 2.0 t0 t1)
        foreach(q '(("/vg" vg_min vg_max) ("/ib" ib_min ib_max) ("/ibd" ibd_min ibd_max) ("/pref" pref_min pref_max))
          nm = clip(v(car(q) ?result "tran") 0.02 t1)
          putprop(r ymin(nm) cadr(q)) putprop(r ymax(nm) caddr(q)))
        iv = car(errset(i("/VDD/PLUS" ?result "tran") nil)) id = car(errset(i("/VDDD/PLUS" ?result "tran") nil))
        r->I_VDD = and(iv chAvg(iv t0 t1)) r->I_VDDD = and(id chAvg(id t0 t1))
        file = sprintf(nil "%s/%s_tran.csv" out tag)
        r->rows = r6bWrite(file names ws)
        sh(sprintf(nil "cd %s && sha256sum %s_tran.csv > %s_tran.csv.sha256 && gzip -f %s_tran.csv" out tag tag tag))
        r->csv = strcat(file ".gz")
        t)
      t)
    unless( ok r->status = if( isFile(strcat(sim "/WATCHDOG_STALL")) "stalled" "failed") r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "gzip -c %s/spectre.out > %s/%s_spectre.out.gz 2>/dev/null; cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs 2>/dev/null; rm -rf %s"
               psf out tag getShellEnvVar("HOME") cell out tag psf))
    acSay("r7dT %s: %s %s | t_end %s stalled %s | 40-60 ms fp/fn cm %s op/on cm %s p/n cm %s | vg %s..%s | ib %s..%s ibd %s..%s pref %s..%s | I %s %s | rows %s\n"
          tag r->status or(r->reason "") r7cNum(r->t_end) or(r->stalled_at "-") r7cNum(r->fp_cm_avg) r7cNum(r->op_cm_avg) r7cNum(r->pn_cm_avg)
          r7cNum(r->vg_min) r7cNum(r->vg_max) r7cNum(r->ib_min) r7cNum(r->ib_max) r7cNum(r->ibd_min) r7cNum(r->ibd_max) r7cNum(r->pref_min) r7cNum(r->pref_max)
          r7cNum(r->I_VDD) r7cNum(r->I_VDDD) r7cNum(r->rows))
    r4Row(port r7dTCols r)
    close(port)
    t
  )
)
procedure( r7dAde()
  let( (vars outs v)
    hw1NoLicensePrompts()
    when( hiGraphicMode() acAutoOkStart() )
    unless( hiGraphicMode() error("r7dAde needs the GUI (run.sh ece203_r7d_ade)\n") )
    v = r7dCand()
    vars = r6bMerge(r6Vars append(r7dVars() list(list("adm" 1.0) list("dcc" 0.01))))
    outs = list(list("Hpre_dB" "db20((VF(\"/fp\") - VF(\"/fn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("op_cm" "(VDC(\"/op\") + VDC(\"/on\")) / 2")
                list("V_ib" "VDC(\"/ib\")") list("V_ibd" "VDC(\"/ibd\")") list("V_pref" "VDC(\"/pref\")")
                list("cmfbLoopGain" "getData(\"loopGain\" ?result \"stb\")"))
    r6bAdeOne(r7dCell(v) "r7d_bias_phaseA" vars outs "/IPRC")
    t
  )
)
