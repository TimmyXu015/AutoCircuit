;; ECE203 R7E: symmetric differential output RC low-pass after the MOS CD buffer of the R7D a0 system.
;; New, passive, ideal analogLib parts only:  RLP_P bufp -> outp 31.8 MOhm, CLP_P outp -> gnd! 20 pF (and the n side).
;; Old CLBP/CLBN 10 pF stay on bufp/bufn; the feedback pickoff stays fp/fn. Task: docs/ECE203_round7e_output_lp_integration_task.md
;; Cases (env AC_R7E_CASE): lp_a0 = R7D a0 + 4 LP parts; lp_load10p = lp_a0 + COUTP/COUTN 10 pF on outp/outn (sensitivity only).
;; C0 = Project/ece203_r7d_tb_bias_a0 (read-only; its Stage B/C data are reused from round7d).
;; Jobs: ece203_r7e_build, ece203_r7e_a (static DC/AC/STB + LP transfer), ece203_r7e_b (loaded, static DC/AC only),
;;       ece203_r7e_c (60 ms 2 kHz TG tran), ece203_r7e_ade.

r7eDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r7e")
r7eTmp = "/tmp/lix015_r7e"
r7eStall = 240
r7eCases = list(nil 'lp_a0 list(nil 'cell "ece203_r7e_tb_lp_a0" 'load nil)
                    'lp_load10p list(nil 'cell "ece203_r7e_tb_lp_load10p" 'load t))
procedure( r7eCase() or(getShellEnvVar("AC_R7E_CASE") "lp_a0") )
procedure( r7eC(c) let( (p) p = get(r7eCases stringToSymbol(c)) unless( p error("unknown case %s" c)) p ) )

procedure( r7eSpecs(c)
  append(r7dSpecs("a0")
         append(list(otaR("RLP_P" "31.8M" "bufp" "outp") otaC("CLP_P" "20p" "outp" "gnd!")
                     otaR("RLP_N" "31.8M" "bufn" "outn") otaC("CLP_N" "20p" "outn" "gnd!"))
                if( r7eC(c)->load list(otaC("COUTP" "10p" "outp" "gnd!") otaC("COUTN" "10p" "outn" "gnd!")) nil)))
)
procedure( r7eBuild()
  let( (c cell)
    ece203LibInfo()
    c = r7eCase() cell = r7eC(c)->cell
    foreach(x list("ece203_r7d_tb_bias_a0" "ece203_ss_pr_cell" r7aCmfbCell("a2") r6dCells->cd) unless( ddGetObj(ece203Lib x) error("missing %s" x)))
    when( ddGetObj(ece203Lib cell) error("%s already exists" cell))
    otaTb(cell r7eSpecs(c))
    t
  )
)
procedure( r7eVars() r7dVars() )

;; ---------- LP transfer (static TG phase A, DM AC 1 mHz-100 kHz 50/dec, dcc 0.01) ----------
r7eLCols = '(case cell status reason bufp bufn outp outn out_minus_buf_p out_minus_buf_n I_VDD I_VDDD P_uW
             Hout1 Hout10 Hout60 Hout100 Hout250 Hout500 Hout1k Hout2k Hout100_ph Hbuf100 Hbuf100_ph Hpre100
             HLP1 HLP10 HLP60 HLP100 HLP250 HLP500 HLP1k HLP2k HLP100_ph HLP250_ph
             fH_flat fH_100ref fH_LP fL_out Hout_max CMRR60_out)
procedure( r7eLp(c)
  let( (p cell port r ok vars tag vd hp hb ho hlp ref wc)
    p = r7eC(c) cell = p->cell tag = sprintf(nil "L_%s" c)
    port = r7cOpen(sprintf(nil "%s.csv" tag) r7eLCols)
    r = list(nil 'case c 'cell cell 'status "ok")
    vars = r7eVars()
    ok = errset(
      progn(
        r7cAc(cell strcat(tag "_dm") append(vars list(list("adm" 1.0) list("dcc" 0.01))) r6bSysOpts)
        vd = ldAc("ep") - ldAc("en")
        hp = ldDiv(ldAc("fp") - ldAc("fn") vd) hb = ldDiv(ldAc("bufp") - ldAc("bufn") vd) ho = ldDiv(ldAc("outp") - ldAc("outn") vd)
        hlp = ldDiv(ldAc("outp") - ldAc("outn") ldAc("bufp") - ldAc("bufn"))
        foreach(n '("bufp" "bufn" "outp" "outn") putprop(r ldDc(n) stringToSymbol(n)))
        r->out_minus_buf_p = r->outp - r->bufp r->out_minus_buf_n = r->outn - r->bufn
        r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDDD = ldIdc("/VDDD/PLUS") r->P_uW = 1.8e6 * (r->I_VDD + r->I_VDDD)
        foreach(q '((1.0 Hout1 HLP1) (10.0 Hout10 HLP10) (60.0 Hout60 HLP60) (100.0 Hout100 HLP100) (250.0 Hout250 HLP250)
                    (500.0 Hout500 HLP500) (1000.0 Hout1k HLP1k) (2000.0 Hout2k HLP2k))
          putprop(r ldMag(ho car(q)) cadr(q)) putprop(r ldMag(hlp car(q)) caddr(q)))
        r->Hout100_ph = ldPh(ho 100.0) r->Hbuf100 = ldMag(hb 100.0) r->Hbuf100_ph = ldPh(hb 100.0) r->Hpre100 = ldMag(hp 100.0)
        r->HLP100_ph = ldPh(hlp 100.0) r->HLP250_ph = ldPh(hlp 250.0)
        r->Hout_max = car(errset(ymax(mag(ho)) nil))
        ref = ldMag(ho 10.0)
        r->fH_flat = car(errset(cross(db20(ho) ece203Db(ref) - 3.0 1 "falling") nil))
        r->fH_100ref = car(errset(cross(db20(ho) ece203Db(ldMag(ho 100.0)) - 3.0 1 "falling") nil))
        r->fH_LP = car(errset(cross(db20(hlp) ece203Db(ldMag(hlp 1.0)) - 3.0 1 "falling") nil))
        r->fL_out = car(errset(cross(db20(ho) ece203Db(ldMag(ho 100.0)) - 3.0 1 "rising") nil))
        ldWriteCurves(strcat(r7eDir "/" tag "_dm_ac.csv") list(list("Hpre" hp) list("Hbuf" hb) list("Hout" ho) list("HLP" hlp)))
        sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs" getShellEnvVar("HOME") cell r7eDir tag))
        ;; CM AC at 60 Hz on the filtered output (same 1 % Cc mismatch)
        r7cAc(cell strcat(tag "_cm") append(vars list(list("vcmin" 1.0) list("dcc" 0.01))) r6bSysOpts)
        wc = ldAc("outp") - ldAc("outn")
        r->CMRR60_out = ece203Db(ldMag(ho 60.0) / ldMag(wc 60.0))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "rm -rf %s/simulation/%s/spectre/schematic_%s*/psf" getShellEnvVar("HOME") cell tag))
    acSay("r7eL %s: %s %s | DC buf %s %s out %s %s | Hout 1/10/60/100/250/500/1k %s %s %s %s %s %s %s ph100 %s | Hbuf100 %s | HLP 100 %s ph %s, 250 %s ph %s | fH flat %s 100ref %s LP %s | fL %s | CMRR60 out %s | P %s uW\n"
          c r->status or(r->reason "") r7cNum(r->bufp) r7cNum(r->bufn) r7cNum(r->outp) r7cNum(r->outn)
          r7cNum(r->Hout1) r7cNum(r->Hout10) r7cNum(r->Hout60) r7cNum(r->Hout100) r7cNum(r->Hout250) r7cNum(r->Hout500) r7cNum(r->Hout1k) r7cNum(r->Hout100_ph)
          r7cNum(r->Hbuf100) r7cNum(r->HLP100) r7cNum(r->HLP100_ph) r7cNum(r->HLP250) r7cNum(r->HLP250_ph)
          r7cNum(r->fH_flat) r7cNum(r->fH_100ref) r7cNum(r->fH_LP) r7cNum(r->fL_out) r7cNum(r->CMRR60_out) r7cNum(r->P_uW))
    r7cRow(port r7eLCols r)
    close(port)
    t
  )
)
;; Stage A: the full R7C/R7D static measurement (DC op, DM/CM AC, STB, margins) + the LP transfer, results in r7eDir
procedure( r7eStageA()
  let( (c key oldDir res)
    ece203LibInfo()
    c = r7eCase() key = stringToSymbol(c)
    putprop(r7cCases list(nil 'cell r7eC(c)->cell 'prw 4e-6) key)
    oldDir = r7cDir r7cDir = r7eDir
    res = errset(progn(r7cStageB1(c r6bSysOpts "") r7eLp(c)) t)
    r7cDir = oldDir
    unless( res error("%L" errset.errset))
    t
  )
)
;; Stage B (loaded case): static DC/AC only
procedure( r7eStageB()
  let( (oldDir res)
    ece203LibInfo()
    oldDir = r7cDir r7cDir = r7eDir
    res = errset(r7eLp(r7eCase()) t)
    r7cDir = oldDir
    unless( res error("%L" errset.errset))
    t
  )
)

;; ---------- Stage C: 60 ms 2 kHz TG tran (R7C/R7D setting C), + outp/outn ----------
r7eTCols = '(tag case status reason t_end stalled_at fp_cm_avg op_cm_avg pn_cm_avg out_cm_avg vg_min vg_max ib_min ib_max I_VDD I_VDDD rows csv)
procedure( r7eStageC()
  let( (c cell tag r ok sim psf vid names file wlog port t1 t0 out ws iv id nm w)
    c = r7eCase() cell = r7eC(c)->cell tag = sprintf(nil "T_%s" c)
    out = strcat(r7eTmp "/out") r7cMkdir(out) r7cMkdir(r7eDir)
    port = outfile(sprintf(nil "%s/%s.csv" r7eDir tag) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString r7eTCols) ","))
    r = list(nil 'tag tag 'case c 'status "ok")
    sim = sprintf(nil "%s/sim_%s" r7eTmp tag) psf = strcat(sim "/psf")
    sh(sprintf(nil "rm -rf %s" sim))
    wlog = strcat(out "/watchdog.log")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        resultsDir(sim)
        r6bOpt('(gmin "1e-18" iabstol "1e-17" reltol "1e-5"))
        analysis('tran ?stop "60m" ?maxstep "0.5u" ?cmin "1e-17")
        car(errset(saveOption('save "selected") nil))
        car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr" "/bufp" "/bufn" "/outp" "/outn" "/p" "/n" "/pref" "/ib" "/ibd") nil))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS" "/IREF/PLUS" "/MP1/D" "/MP2/D") nil))
        r6bSet(r6Vars append(r7eVars() list(list("chen" 1.0) list("tch" 500e-6) list("vd" 1e-3))))
        sh(sprintf(nil "nohup bash %s/tools/r7e_watchdog.sh %s %s %d %s > /dev/null 2>&1 &" acRoot tag psf r7eStall wlog))
        run()
        when( isFile(strcat(sim "/WATCHDOG_STALL"))
          r->stalled_at = car(errset(let( (pt l) pt = infile(strcat(sim "/WATCHDOG_STALL")) gets(l pt) close(pt) car(parseString(l "\n"))) nil))
          error("stalled (watchdog)"))
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        r->t_end = r6bTend(vid)
        when( r->t_end < 0.99 * 60e-3 error("tran stopped at %g s" r->t_end))
        ws = list(vid) names = "t_s,vid_V"
        foreach(n '("fp" "fn" "op" "on" "vg" "drlr" "bufp" "bufn" "outp" "outn" "p" "n" "pref" "ib" "ibd")
          ws = append(ws list(v(strcat("/" n) ?result "tran"))) names = strcat(names "," n "_V"))
        foreach(q '(("/VDD/PLUS" "i_vdd_A") ("/VDDD/PLUS" "i_vddd_A") ("/IREF/PLUS" "i_iref_A") ("/MP1/D" "i_mp1_d_A") ("/MP2/D" "i_mp2_d_A"))
          w = car(errset(i(car(q) ?result "tran") nil))
          if( w then ws = append(ws list(w)) names = strcat(names "," cadr(q)) else acSay("r7eT: current %s not saved\n" car(q))))
        t1 = r->t_end t0 = 0.04
        r->fp_cm_avg = chAvg((v("/fp" ?result "tran") + v("/fn" ?result "tran")) / 2.0 t0 t1)
        r->op_cm_avg = chAvg((v("/op" ?result "tran") + v("/on" ?result "tran")) / 2.0 t0 t1)
        r->pn_cm_avg = chAvg((v("/p" ?result "tran") + v("/n" ?result "tran")) / 2.0 t0 t1)
        r->out_cm_avg = chAvg((v("/outp" ?result "tran") + v("/outn" ?result "tran")) / 2.0 t0 t1)
        nm = clip(v("/vg" ?result "tran") 0.02 t1) r->vg_min = ymin(nm) r->vg_max = ymax(nm)
        nm = clip(v("/ib" ?result "tran") 0.02 t1) r->ib_min = ymin(nm) r->ib_max = ymax(nm)
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
    acSay("r7eT %s: %s %s | t_end %s stalled %s | 40-60 ms fp/fn cm %s op/on cm %s p/n cm %s out cm %s | vg %s..%s | ib %s..%s | I %s %s | rows %s\n"
          tag r->status or(r->reason "") r7cNum(r->t_end) or(r->stalled_at "-") r7cNum(r->fp_cm_avg) r7cNum(r->op_cm_avg) r7cNum(r->pn_cm_avg)
          r7cNum(r->out_cm_avg) r7cNum(r->vg_min) r7cNum(r->vg_max) r7cNum(r->ib_min) r7cNum(r->ib_max) r7cNum(r->I_VDD) r7cNum(r->I_VDDD) r7cNum(r->rows))
    r4Row(port r7eTCols r)
    close(port)
    t
  )
)
procedure( r7eAde()
  let( (vars outs)
    hw1NoLicensePrompts()
    when( hiGraphicMode() acAutoOkStart() )
    unless( hiGraphicMode() error("r7eAde needs the GUI (run.sh ece203_r7e_ade)\n") )
    vars = r6bMerge(r6Vars append(r7eVars() list(list("adm" 1.0) list("dcc" 0.01))))
    outs = list(list("Hout_dB" "db20((VF(\"/outp\") - VF(\"/outn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("Hbuf_dB" "db20((VF(\"/bufp\") - VF(\"/bufn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("Hpre_dB" "db20((VF(\"/fp\") - VF(\"/fn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("op_cm" "(VDC(\"/op\") + VDC(\"/on\")) / 2")
                list("cmfbLoopGain" "getData(\"loopGain\" ?result \"stb\")"))
    r6bAdeOne(r7eC("lp_a0")->cell "r7e_lp_phaseA" vars outs "/IPRC")
    t
  )
)
