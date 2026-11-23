;; ECE203 R7C: real MOS pseudo-resistors (existing Project/ece203_ss_pr_cell, cmrf7sf pfet33x thick oxide) replace
;; the two ideal 3.1831 TOhm feedback resistors RFN (fp,n) / RFP (fn,p) of the R7A a2 system (real MOS CMFB a2,
;; FD OTA, two real TG choppers, real DRL, MOS CD, BUFFERED 10 pF). Task: docs/ECE203_round7c_mos_pseudoresistor_integration_task.md.
;; Read-only: ece203_ss_pr_cell, ece203_ss_pr_iv_tb (R3B), ece203_r7a_*; nothing old is rebuilt.
;;   XPRN : A = n, B = fp      XPRP : A = p, B = fn      (B = gate + n-well + one p+, on the low-impedance node)
;; Jobs: ece203_r7c_a (Stage A: device I-V/AC on the R3B bench, read-only), ece203_r7c_build (AC_R7C_CASE = pr_w4 ...),
;;       ece203_r7c_b (Stage B static, AC_R7C_CASE = ideal (R7A a2 cell, read-only) | pr_w4 ...),
;;       ece203_r7c_bnum (one numerical sanity check: iabstol 1e-18), ece203_r7c_c (Stage C 60 ms tran), ece203_r7c_ade.

r7cDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r7c")
r7cTmp = "/tmp/lix015_r7c"
r7cStall = 240
;; candidate pseudo-R sizes (L fixed 2u); w4 = task's first candidate (R5N-F value)
r7cCases = list(nil 'ideal list(nil 'cell "ece203_r7a_tb_buf_a2" 'prw nil)
                    'pr_w4 list(nil 'cell "ece203_r7c_tb_pr_w4" 'prw 4e-6))
procedure( r7cCase() or(getShellEnvVar("AC_R7C_CASE") "pr_w4") )
procedure( r7cC(c) let( (p) p = get(r7cCases stringToSymbol(c)) unless( p error("unknown case %s" c)) p ) )
procedure( r7cMkdir(d) unless( isDir(d) sh(sprintf(nil "mkdir -p %s" d))) )
procedure( r7cOpen(name cols)
  let( (port)
    r7cMkdir(r7cDir)
    port = outfile(strcat(r7cDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
procedure( r7cNum(x) cond( (stringp(x) x) (numberp(x) sprintf(nil "%.7g" float(x))) (t "n/a")) )
procedure( r7cRow(port cols r)
  fprintf(port "%s\n" buildString(mapcar(lambda((c) r7cNum(get(r c))) cols) ","))
)
r7cTight = '(gmin "1e-18" iabstol "1e-18" reltol "1e-6")     ;; R3B Stage A precision setting

;; ---------- Stage A: pfet33x pseudo-R I-V / AC on the existing R3B bench (read-only), W 4u L 2u ----------
r7cVds = '(-0.100 -0.050 -0.030 -0.010 0.0 0.010 0.030 0.050 0.100)
r7cACols = '(prw prl vd_mV I_A_into_A I_B_out_of_B I_leak g_ac_S r_ac_ohm r_secant_ohm id_MP vgs_MP vds_MP vth_MP region_MP gds_MP status)
procedure( r7cStageA()
  let( (port r ok ia ib iac)
    ece203LibInfo()
    unless( ddGetObj(ece203Lib "ece203_ss_pr_iv_tb") error("missing ece203_ss_pr_iv_tb"))
    port = r7cOpen("A_pr_iv_w4.csv" r7cACols)
    foreach(vd r7cVds
      r = list(nil 'prw 4e-6 'prl 2e-6 'vd_mV vd * 1e3 'status "ok")
      ok = errset(
        progn(
          ece203Setup("ece203_ss_pr_iv_tb" "_r7c_A")
          r6bOpt(r7cTight)
          analysis('dc ?saveOppoint t)
          analysis('ac ?start "1m" ?stop "10m" ?dec "1")
          car(errset(save('i "/VA/PLUS" "/VB/PLUS") nil))
          ece203Vars(list(list("vcm" 0.9) list("vd" vd) list("prw" 4e-6) list("prl" 2e-6)))
          run()
          ia = ldIdc("/VA/PLUS") ib = car(errset(i("/VB/PLUS" ?result "dcOp") nil))
          iac = car(errset(i("/VA/PLUS" ?result "ac") nil))
          r->I_A_into_A = ia r->I_B_out_of_B = ib
          r->I_leak = and(numberp(ia) numberp(ib) ia - ib)
          r->g_ac_S = and(iac car(errset(-1.0 * real(value(iac 1e-3)) nil)))
          r->r_ac_ohm = and(numberp(r->g_ac_S) r->g_ac_S != 0.0 1.0 / r->g_ac_S)
          r->r_secant_ohm = and(numberp(ia) ia != 0.0 vd != 0.0 vd / ia)
          foreach(q '(("id_MP" "id") ("vgs_MP" "vgs") ("vds_MP" "vds") ("vth_MP" "vth") ("region_MP" "region") ("gds_MP" "gds"))
            putprop(r car(errset(pv("/XP/MP" cadr(q) ?result "dcOpInfo") nil)) stringToSymbol(car(q))))
          t)
        t)
      unless( ok r->status = sprintf(nil "failed %L" errset.errset))
      acSay("r7cA vd %s mV: I_A %s I_B %s g_ac %s r_ac %s r_sec %s | MP id %s vds %s vth %s region %s %s\n"
            r7cNum(r->vd_mV) r7cNum(r->I_A_into_A) r7cNum(r->I_B_out_of_B) r7cNum(r->g_ac_S) r7cNum(r->r_ac_ohm)
            r7cNum(r->r_secant_ohm) r7cNum(r->id_MP) r7cNum(r->vds_MP) r7cNum(r->vth_MP) r7cNum(r->region_MP) r->status)
      r7cRow(port r7cACols r))
    close(port)
    sh(sprintf(nil "cp %s/simulation/ece203_ss_pr_iv_tb/spectre/schematic/netlist/input.scs %s/A_pr_iv_netlist.scs; rm -rf %s/simulation/ece203_ss_pr_iv_tb/spectre/schematic_r7c_A/psf"
               getShellEnvVar("HOME") r7cDir getShellEnvVar("HOME")))
    t
  )
)

;; ---------- new bench: R7A spec list with RFN/RFP replaced by two ece203_ss_pr_cell instances ----------
procedure( r7cSpecs()
  append(setof(e r7aSysSpecs(r7aCmfbCell("a2")) !member(caddr(e) '("RFN" "RFP")))
         list(list(ece203Lib "ece203_ss_pr_cell" "XPRN" nil '(("A" "n") ("B" "fp")))
              list(ece203Lib "ece203_ss_pr_cell" "XPRP" nil '(("A" "p") ("B" "fn")))))
)
procedure( r7cBuild()
  let( (c p)
    ece203LibInfo()
    c = r7cCase() p = r7cC(c)
    unless( p->prw error("case %s is not a pseudo-R case" c))
    foreach(x list("ece203_ss_pr_cell" r7aCmfbCell("a2") r6dCells->cd) unless( ddGetObj(ece203Lib x) error("missing %s" x)))
    when( ddGetObj(ece203Lib p->cell) error("%s already exists" p->cell))
    otaTb(p->cell r7cSpecs())
    t
  )
)
;; (R7F) a case may carry 'extra design-variable overrides (e.g. cc); old cases have none -> unchanged behaviour
procedure( r7cVars(c) append(append(r7aSysBase if( r7cC(c)->prw list(list("prw" r7cC(c)->prw) list("prl" 2e-6)) nil)) r7cC(c)->extra) )

;; ---------- Stage B: TG static phase A ----------
r7cBCols = '(case cell opts status reason op on op_cm fp fn fp_cm p n pn_cm vg bufp bufn I_VDD I_VDDD P_uW
             V_PRN_A_minus_B V_PRP_A_minus_B PRN_id PRN_vds PRN_vgs PRN_region PRP_id PRP_vds PRP_region
             Hmax fL fL_rel100 fH Hpre10 Hpre60 Hpre100 Hpre100_ph Hpre0p1 Hpre0p1_ph Hbuf100 Hbuf100_ph CMRR60_pre CMRR60_buf
             Zin_dm_src_10 cmfb_ugf cmfb_pm cmfb_lgdc drl_ugf drl_pm drl_lg60 minA worstA minC worstC)
;; -3 dB point (rising) relative to |H(100 Hz)|, interpolated on the AC grid (log f)
procedure( r7cFl(h)
  let( (ref) ref = ldMag(h 100.0) and(ref car(errset(cross(db20(h) ece203Db(ref) - 3.0 1 "rising") nil))) )
)
procedure( r7cAc(cell tag vars opts)
  ece203Setup(cell strcat("_" tag))
  r6bOpt(opts)
  analysis('dc ?saveOppoint t)
  analysis('ac ?start "1m" ?stop "100k" ?dec "50")
  car(errset(save('i "/VSP/PLUS" "/VDD/PLUS" "/VDDD/PLUS") nil))
  r6bSet(r6Vars vars)
  run()
)
procedure( r7cStageB1(c opts otag)
  let( (p cell port r ok vars h hb vd bp bn wc rows tag isPr)
    p = r7cC(c) cell = p->cell isPr = numberp(p->prw)
    tag = sprintf(nil "B_%s%s" c otag)
    port = r7cOpen(sprintf(nil "%s.csv" tag) r7cBCols)
    r = list(nil 'case c 'cell cell 'opts sprintf(nil "%L" opts) 'status "ok")
    vars = r7cVars(c)
    ok = errset(
      progn(
        ;; DM AC (1 % Cc mismatch as in R6/R7A Stage A), DC op of the same run
        r7cAc(cell strcat(tag "_dm") append(vars list(list("adm" 1.0) list("dcc" 0.01))) opts)
        vd = ldAc("ep") - ldAc("en")
        h = ldDiv(ldAc("fp") - ldAc("fn") vd) bp = ldAc("bufp") bn = ldAc("bufn") hb = ldDiv(bp - bn vd)
        r->Hmax = car(errset(ymax(mag(h)) nil)) r->fL = r7cFl(h) r->fL_rel100 = "-3dB vs |H(100)|"
        r->fH = car(errset(cross(db20(h) ece203Db(ldMag(h 100.0)) - 3.0 1 "falling") nil))
        r->Hpre10 = ldMag(h 10.0) r->Hpre60 = ldMag(h 60.0) r->Hpre100 = ldMag(h 100.0) r->Hpre100_ph = ldPh(h 100.0)
        r->Hpre0p1 = ldMag(h 0.1) r->Hpre0p1_ph = ldPh(h 0.1)
        r->Hbuf100 = ldMag(hb 100.0) r->Hbuf100_ph = ldPh(hb 100.0)
        r->Zin_dm_src_10 = car(errset(ldMag(vd / i("/VSP/PLUS" ?result "ac") 10.0) nil))
        ldWriteCurves(strcat(r7cDir "/" tag "_dm_ac.csv") list(list("Hpre" h) list("Hbuf" hb)))
        foreach(n '("op" "on" "fp" "fn" "p" "n" "vg" "bufp" "bufn") putprop(r ldDc(n) stringToSymbol(n)))
        r->op_cm = (r->op + r->on) / 2.0 r->fp_cm = (r->fp + r->fn) / 2.0 r->pn_cm = (r->p + r->n) / 2.0
        r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDDD = ldIdc("/VDDD/PLUS") r->P_uW = 1.8e6 * (r->I_VDD + r->I_VDDD)
        when( isPr
          r->V_PRN_A_minus_B = r->n - r->fp r->V_PRP_A_minus_B = r->p - r->fn
          r->PRN_id = car(errset(pv("/XPRN/MP" "id" ?result "dcOpInfo") nil)) r->PRN_vds = car(errset(pv("/XPRN/MP" "vds" ?result "dcOpInfo") nil))
          r->PRN_vgs = car(errset(pv("/XPRN/MP" "vgs" ?result "dcOpInfo") nil)) r->PRN_region = car(errset(pv("/XPRN/MP" "region" ?result "dcOpInfo") nil))
          r->PRP_id = car(errset(pv("/XPRP/MP" "id" ?result "dcOpInfo") nil)) r->PRP_vds = car(errset(pv("/XPRP/MP" "vds" ?result "dcOpInfo") nil))
          r->PRP_region = car(errset(pv("/XPRP/MP" "region" ?result "dcOpInfo") nil)))
        rows = ece203OpDump(strcat(r7cDir "/" tag "_dcop.csv")
                            append('("XA.M1" "XA.M2" "XA.MC1" "XA.MC2" "XA.M3" "XA.M4" "XA.MT" "XA.MREF" "XCD.MSP" "XCD.MSN" "XCD.MKP" "XCD.MKN")
                                   append(r7aCmfbInsts if( isPr '("XPRN.MP" "XPRP.MP") nil))))
        foreach(x rows
          let( (m) m = ece203Margin(caddr(x))
            when( numberp(m) && car(parseString(car(x) ".")) == "XA" && (!r->minA || m < r->minA) r->minA = m r->worstA = car(x))
            when( numberp(m) && car(parseString(car(x) ".")) == "XC" && (!r->minC || m < r->minC) r->minC = m r->worstC = car(x))))
        sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs" getShellEnvVar("HOME") cell r7cDir tag))
        ;; CM AC: CMRR at 60 Hz
        r7cAc(cell strcat(tag "_cm") append(vars list(list("vcmin" 1.0) list("dcc" 0.01))) opts)
        wc = ldAc("fp") - ldAc("fn")
        r->CMRR60_pre = ece203Db(ldMag(h 60.0) / ldMag(wc 60.0))
        r->CMRR60_buf = ece203Db(ldMag(hb 60.0) / ldMag(ldAc("bufp") - ldAc("bufn") 60.0))
        ;; CMFB / DRL loop stability (TG static), same r6Stb as R6/R7A (uses r4TightOpts = opts)
        r7aOnOpts(cell opts 'r6Stb r tag append(vars list(list("dcc" 0.01))))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "rm -rf %s/simulation/%s/spectre/schematic_%s*/psf" getShellEnvVar("HOME") cell tag))
    acSay("r7cB %s: %s %s | op/on cm %s fp/fn cm %s p/n cm %s vg %s | V_PR(A-B) N %s P %s id %s %s region %s | P %s uW\n"
          tag r->status or(r->reason "") r7cNum(r->op_cm) r7cNum(r->fp_cm) r7cNum(r->pn_cm) r7cNum(r->vg)
          r7cNum(r->V_PRN_A_minus_B) r7cNum(r->V_PRP_A_minus_B) r7cNum(r->PRN_id) r7cNum(r->PRP_id) r7cNum(r->PRN_region) r7cNum(r->P_uW))
    acSay("r7cB %s: fL %s Hz fH %s | Hpre 0.1/10/60/100 %s %s %s %s ph100 %s | Hbuf100 %s | CMRR60 %s %s | Zin10 %s | CMFB UGF %s PM %s | DRL UGF %s PM %s | minA %s %s minC %s %s\n"
          tag r7cNum(r->fL) r7cNum(r->fH) r7cNum(r->Hpre0p1) r7cNum(r->Hpre10) r7cNum(r->Hpre60) r7cNum(r->Hpre100) r7cNum(r->Hpre100_ph)
          r7cNum(r->Hbuf100) r7cNum(r->CMRR60_pre) r7cNum(r->CMRR60_buf) r7cNum(r->Zin_dm_src_10) r7cNum(r->cmfb_ugf) r7cNum(r->cmfb_pm)
          r7cNum(r->drl_ugf) r7cNum(r->drl_pm) r7cNum(r->minA) or(r->worstA "") r7cNum(r->minC) or(r->worstC ""))
    r7cRow(port r7cBCols r)
    close(port)
    t
  )
)
;; r7aOn with a given option list
procedure( r7aOnOpts(cell opts fn @rest args)
  let( (oldTb oldDir res)
    oldTb = r6Cells->tb oldDir = r6Dir
    r6Cells->tb = cell r6Dir = r7cDir r4TightOpts = opts
    res = errset(apply(fn args) t)
    r6Cells->tb = oldTb r6Dir = oldDir r4TightOpts = nil
    unless( res error("%L" errset.errset))
    car(res)
  )
)
procedure( r7cStageB() r7cStageB1(r7cCase() r6bSysOpts "") t )
;; one numerical sanity check: iabstol 1e-18 (gmin 1e-18, reltol 1e-5 unchanged)
procedure( r7cStageBnum() r7cStageB1(r7cCase() '(gmin "1e-18" iabstol "1e-18" reltol "1e-5") "_iabstol1e-18") t )

;; ---------- Stage C: 60 ms 2 kHz TG tran, R6D-R setting C ----------
r7cTCols = '(tag case status reason t_end stalled_at fp_cm_avg op_cm_avg pn_cm_avg vg_min vg_max I_VDD I_VDDD rows csv)
procedure( r7cStageC()
  let( (iabs c p cell tag r ok sim psf vid fp fn op on vg dr bp bn pp nn iv id names waves file wlog port t1 t0 out)
    c = r7cCase() p = r7cC(c) cell = p->cell
    ;; AC_R7C_IABSTOL: the one numerical sanity check (default 1e-17 = R6D-R setting C)
    iabs = or(getShellEnvVar("AC_R7C_IABSTOL") "1e-17")
    tag = if( iabs == "1e-17" sprintf(nil "T_%s" c) sprintf(nil "T_%s_iabstol%s" c iabs))
    out = strcat(r7cTmp "/out") r7cMkdir(out)
    port = r7cOpen(sprintf(nil "%s.csv" tag) r7cTCols)
    r = list(nil 'tag tag 'case c 'status "ok")
    sim = sprintf(nil "%s/sim_%s" r7cTmp tag) psf = strcat(sim "/psf")
    sh(sprintf(nil "rm -rf %s" sim))
    wlog = strcat(out "/watchdog.log")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        resultsDir(sim)
        r6bOpt(list('gmin "1e-18" 'iabstol iabs 'reltol "1e-5"))
        analysis('tran ?stop "60m" ?maxstep "0.5u" ?cmin "1e-17")
        car(errset(saveOption('save "selected") nil))
        car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr" "/bufp" "/bufn" "/p" "/n") nil))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars append(r7cVars(c) list(list("chen" 1.0) list("tch" 500e-6) list("vd" 1e-3))))
        sh(sprintf(nil "nohup bash %s/tools/r7c_watchdog.sh %s %s %d %s > /dev/null 2>&1 &" acRoot tag psf r7cStall wlog))
        run()
        when( isFile(strcat(sim "/WATCHDOG_STALL"))
          r->stalled_at = car(errset(let( (pt l) pt = infile(strcat(sim "/WATCHDOG_STALL")) gets(l pt) close(pt) car(parseString(l "\n"))) nil))
          error("stalled (watchdog)"))
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        r->t_end = r6bTend(vid)
        when( r->t_end < 0.99 * 60e-3 error("tran stopped at %g s" r->t_end))
        fp = v("/fp" ?result "tran") fn = v("/fn" ?result "tran") op = v("/op" ?result "tran") on = v("/on" ?result "tran")
        vg = v("/vg" ?result "tran") dr = v("/drlr" ?result "tran") bp = v("/bufp" ?result "tran") bn = v("/bufn" ?result "tran")
        pp = v("/p" ?result "tran") nn = v("/n" ?result "tran")
        iv = car(errset(i("/VDD/PLUS" ?result "tran") nil)) id = car(errset(i("/VDDD/PLUS" ?result "tran") nil))
        t1 = r->t_end t0 = 0.04
        r->fp_cm_avg = chAvg((fp + fn) / 2.0 t0 t1) r->op_cm_avg = chAvg((op + on) / 2.0 t0 t1) r->pn_cm_avg = chAvg((pp + nn) / 2.0 t0 t1)
        r->vg_min = ymin(clip(vg 0.02 t1)) r->vg_max = ymax(clip(vg 0.02 t1))
        r->I_VDD = and(iv chAvg(iv t0 t1)) r->I_VDDD = and(id chAvg(id t0 t1))
        file = sprintf(nil "%s/%s_tran.csv" out tag)
        names = "t_s,vid_V,fp_V,fn_V,op_V,on_V,vg_V,drlr_V,bufp_V,bufn_V,p_V,n_V" waves = list(vid fp fn op on vg dr bp bn pp nn)
        when( and(iv id) names = strcat(names ",i_vdd_A,i_vddd_A") waves = append(waves list(iv id)))
        r->rows = r6bWrite(file names waves)
        sh(sprintf(nil "cd %s && sha256sum %s_tran.csv > %s_tran.csv.sha256 && gzip -f %s_tran.csv" out tag tag tag))
        r->csv = strcat(file ".gz")
        t)
      t)
    unless( ok r->status = if( isFile(strcat(sim "/WATCHDOG_STALL")) "stalled" "failed") r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "gzip -c %s/spectre.out > %s/%s_spectre.out.gz 2>/dev/null; cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs 2>/dev/null; rm -rf %s"
               psf out tag getShellEnvVar("HOME") cell out tag psf))
    acSay("r7cT %s: %s %s | t_end %s stalled %s | 40-60 ms fp/fn cm %s op/on cm %s p/n cm %s | vg %s..%s | I %s %s | rows %s\n"
          tag r->status or(r->reason "") r7cNum(r->t_end) or(r->stalled_at "-") r7cNum(r->fp_cm_avg) r7cNum(r->op_cm_avg)
          r7cNum(r->pn_cm_avg) r7cNum(r->vg_min) r7cNum(r->vg_max) r7cNum(r->I_VDD) r7cNum(r->I_VDDD) r7cNum(r->rows))
    r4Row(port r7cTCols r)
    close(port)
    t
  )
)
;; ADE L state (GUI): TG static phase A, dc / ac / CMFB stb, tight options already in r6bAdeOne? -> set explicitly
procedure( r7cAde()
  let( (vars outs c)
    hw1NoLicensePrompts()
    when( hiGraphicMode() acAutoOkStart() )
    unless( hiGraphicMode() error("r7cAde needs the GUI (run.sh ece203_r7c_ade)\n") )
    c = r7cCase()
    vars = r6bMerge(r6Vars append(r7cVars(c) list(list("adm" 1.0) list("dcc" 0.01))))
    outs = list(list("Hpre_dB" "db20((VF(\"/fp\") - VF(\"/fn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("op_cm" "(VDC(\"/op\") + VDC(\"/on\")) / 2")
                list("V_PRN_AB" "VDC(\"/n\") - VDC(\"/fp\")")
                list("cmfbLoopGain" "getData(\"loopGain\" ?result \"stb\")"))
    r6bAdeOne(r7cC(c)->cell sprintf(nil "r7c_%s_phaseA" c) vars outs "/IPRC")
    t
  )
)
