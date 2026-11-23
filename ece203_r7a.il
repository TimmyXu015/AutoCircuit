;; ECE203 R7A: real MOS continuous-time CMFB (linearity first) replacing the R6D-R ideal linear CMFB.
;; Task: docs/ECE203_round7a_real_mos_cmfb_task.md. New cells only (ece203_r7a_*); every R5N-F / R6A-R6D-R cell is
;; read-only (baseline runs only simulate them; nothing is redrawn).
;;
;; Stage 1 (job ece203_r7a_base): static baseline reproduction on the existing benches
;;   OLD   = Project/ece203_r6c_tb_old  (R6B system with the real DD-pair CMFB ece203_r6a_cmfb, TG static phase A)
;;   IDEAL = Project/ece203_r6d_tb_buf  (R6D/R6D-R BUFFERED bench with the ideal linear CMFB, clb 10 pF, TG phase A)
;; Stage 2 (jobs ece203_r7a_build_det, ece203_r7a_det): standalone detector tests. Candidate cell(s) ece203_r7a_cmfb_<v>
;;   and the old DD-pair (read-only instance) each in a standalone bench ece203_r7a_det_tb_<v>:
;;   OP = vcm + vd/2, ON = vcm - vd/2 (ideal), VREF 0.9 V, IBIAS from an ideal 50 nA into a MREF replica (2u/4u),
;;   vg loaded by two PMOS replicas of the OTA loads M3/M4 (2u/4u, drains at 0.9 V), controller supply on its own source
;;   VDDC (I(VDDC) = controller current). DC sweeps of vd (-0.2..0.2 V) at vcm 0.88/0.899/0.90/0.901/0.92 and oppoints
;;   at vd {-0.2,-0.1,-0.05,0,0.05,0.1,0.2} x vcm {0.88,0.90,0.92}.
;; Stage 3 (jobs ece203_r7a_build_sys, ece203_r7a_sys_a, ece203_r7a_sys_b, ece203_r7a_ade): only if Stage 2 passes.
;;   Bench ece203_r7a_tb_buf_<v> = the R6D BUFFERED spec list with the ideal controller (ESA..ELM) removed and the MOS
;;   CMFB instance XC (same pins/nets as the old XC: OP op, ON on, VREF vrc, VCMFB vcf, VDD vdd, IBIAS ib) added.
;;   vcf -> IPRC (stb probe) -> RCF 1 ohm -> vg = PMOS load gates, exactly as before.
;; Candidate selection: env AC_R7A_CAND (e.g. a0, a1); psf of long runs go to /tmp/lix015_r7a (home quota).

r7aDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r7a")
r7aTmp = "/tmp/lix015_r7a"
r7aStall = 240

;; ---------- candidate A: linearised DD-pair (long-L moderate-inversion inputs, larger tails), diode PMOS output ----------
;;   MA1 (OP) / MA2 (VREF) share tail ta (MTA), MB1 (ON) / MB2 (VREF) share tail tb (MTB); tails mirrored from IBIAS.
;;   Input-side drains -> VDD; VREF-side drains summed into the diode PMOS MD -> VCMFB (= vg of the OTA loads).
;;   Vout,cm up -> more current in MA1/MB1 -> less in MA2/MB2 -> less MD current -> VCMFB up -> loads source less
;;   -> Vout,cm down (negative). Linearity: input pairs at gm/Id ~9 (W/L 0.5u/40u, ~60 nA each) instead of the old
;;   weak-inversion 4u/2u pairs (gm/Id ~27): ~3.5x wider tanh/square-law range, so the DM-to-CM even term (which scales
;;   with the pair imbalance a divided by the linear range squared) drops by ~10x at equal imbalance.
;;   MD sized so that VCMFB = the vg the OTA needs (1.32506 V from the ideal baseline) when the pairs are balanced.
r7aCands = list(nil
  'a0 list(nil 'kind "A" 'win 0.5e-6 'lin 40e-6 'wt 10e-6 'lt 8e-6 'wmd 2.085e-6 'lmd 4e-6
           'note "A round 0: initial sizing from the single-device characterisation"))
procedure( r7aCand() or(getShellEnvVar("AC_R7A_CAND") "a0") )
procedure( r7aCandP(v) let( (p) p = get(r7aCands stringToSymbol(v)) unless( p error("unknown candidate %s" v)) p ) )
procedure( r7aCmfbCell(v) strcat("ece203_r7a_cmfb_" v) )
procedure( r7aDetCell(v) strcat("ece203_r7a_det_tb_" v) )
procedure( r7aSysCell(v) strcat("ece203_r7a_tb_buf_" v) )
procedure( r7aCmfbDevs(p)
  cond(
    ( p->kind == "A"
      list(list("nfetx" "MA1" p->win p->lin "VDD" "OP" "ta" "GND")
           list("nfetx" "MA2" p->win p->lin "VCMFB" "VREF" "ta" "GND")
           list("nfetx" "MB1" p->win p->lin "VDD" "ON" "tb" "GND")
           list("nfetx" "MB2" p->win p->lin "VCMFB" "VREF" "tb" "GND")
           list("nfetx" "MTA" p->wt p->lt "ta" "IBIAS" "GND" "GND")
           list("nfetx" "MTB" p->wt p->lt "tb" "IBIAS" "GND" "GND")
           list("pfetx" "MD" p->wmd p->lmd "VCMFB" "VCMFB" "VDD" "VDD")))
    ( t error("unknown candidate kind %L" p->kind)))
)
r7aCmfbInsts = '("XC.MA1" "XC.MA2" "XC.MB1" "XC.MB2" "XC.MTA" "XC.MTB" "XC.MD")
r7aPins = '(("OP" "input") ("ON" "input") ("VREF" "input") ("VCMFB" "output") ("VDD" "inputOutput")
            ("GND" "inputOutput") ("IBIAS" "input"))

procedure( r7aMkdir(d) unless( isDir(d) sh(sprintf(nil "mkdir -p %s" d))) )
procedure( r7aOpen(name cols)
  let( (port)
    r7aMkdir(r7aDir)
    port = outfile(strcat(r7aDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
procedure( r7aCopyNetlist(cell tag)
  sh(sprintf(nil "f=$(ls -t $(find %s/simulation/%s -name input.scs 2>/dev/null) 2>/dev/null | head -1); [ -n \"$f\" ] && cp \"$f\" %s/%s_netlist.scs"
             getShellEnvVar("HOME") cell r7aDir tag))
)
;; quota: AC/STB/DC psf of a finished case are rebuildable -> removed after the CSVs are written
procedure( r7aRmPsf(cell)
  sh(sprintf(nil "rm -rf %s/simulation/%s/spectre/schematic_*/psf" getShellEnvVar("HOME") cell))
)
;; run an R6A/R6D measurement function on another bench with output to r7aDir
procedure( r7aOn(cell fn @rest args)
  let( (oldTb oldDir res)
    oldTb = r6Cells->tb oldDir = r6Dir
    r6Cells->tb = cell r6Dir = r7aDir r4TightOpts = r6bSysOpts
    res = errset(apply(fn args) t)
    r6Cells->tb = oldTb r6Dir = oldDir r4TightOpts = nil
    unless( res error("%L" errset.errset))
    car(res)
  )
)

;; ---------- Stage 1: static baselines (read-only benches) ----------
r7aBCols = '(tag bench status reason op on ocm fp fn fp_cm vg vcf I_VDD I_VDDD Hdm10 Hdm100 ph100 CMRR60_dB
             cmfb_ugf cmfb_pm cmfb_lgdc cmfb_ph0 drl_ugf drl_pm drl_lg60 drl_lgdc ctrl_I)
procedure( r7aBaseCase(port tag bench cell over)
  let( (r ok rows)
    r = list(nil 'tag tag 'bench bench 'status "ok")
    ok = errset(
      progn(
        r7aOn(cell 'r6Gains r tag over)
        r->ocm = and(numberp(r->op) numberp(r->on) (r->op + r->on) / 2.0)
        ;; r6Gains' last run is the CM AC run; fp/fn DC and the op dump come from its dc point (same DC as the DM run)
        r->fp = ldDc("fp") r->fn = ldDc("fn") r->fp_cm = and(numberp(r->fp) numberp(r->fn) (r->fp + r->fn) / 2.0)
        rows = ece203OpDump(strcat(r7aDir "/" tag "_dcop.csv")
                            '("XA.M1" "XA.M2" "XA.MC1" "XA.MC2" "XA.M3" "XA.M4" "XA.MT" "XA.MREF"
                              "XC.MA1" "XC.MA2" "XC.MB1" "XC.MB2" "XC.MTA" "XC.MTB" "XC.MD"))
        r->ctrl_I = let( (s) s = 0.0 foreach(x rows when( member(car(x) '("XC.MTA" "XC.MTB")) && numberp(nth(0 caddr(x)))
                                                       s = s + nth(0 caddr(x)))) s)
        r7aCopyNetlist(cell tag)
        r7aOn(cell 'r6Stb r tag over)
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    r7aRmPsf(cell)
    acSay("r7aB %s [%s]: %s %s | op %s on %s ocm %s fp/fn cm %s vg %s | Hdm 10/100 %s %s ph %s CMRR60 %s | I %s %s ctrl %s\n"
          tag bench r->status or(r->reason "") r4Num(r->op "%.6g") r4Num(r->on "%.6g") r4Num(r->ocm "%.6g")
          r4Num(r->fp_cm "%.6g") r4Num(r->vg "%.6g") r4Num(r->Hdm10 "%.5g") r4Num(r->Hdm100 "%.5g") r4Num(r->ph100 "%.2f")
          r4Num(r->CMRR60_dB "%.2f") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->ctrl_I "%.4g"))
    acSay("r7aB %s: CMFB UGF %s PM %s LGdc %s | DRL UGF %s PM %s LG60 %s\n" tag r4Num(r->cmfb_ugf "%.4g")
          r4Num(r->cmfb_pm "%.2f") r4Num(r->cmfb_lgdc "%.4g") r4Num(r->drl_ugf "%.4g") r4Num(r->drl_pm "%.2f") r4Num(r->drl_lg60 "%.4g"))
    r4Row(port r7aBCols r)
    r
  )
)
procedure( r7aBaseline()
  let( (port)
    ece203LibInfo()
    port = r7aOpen("r7a_baseline.csv" r7aBCols)
    r7aBaseCase(port "B_old_dd" "R6C old: real DD-pair CMFB (R6B system, TG phase A)" "ece203_r6c_tb_old"
                append(r6cBase list(list("dcc" 0.01))))
    r7aBaseCase(port "B_ideal_buf10p" "R6D BUFFERED 10 pF: ideal linear CMFB (TG phase A)" "ece203_r6d_tb_buf"
                append(r6dBase list(list("clb" 10e-12) list("dcc" 0.01))))
    close(port)
    t
  )
)

;; ---------- Stage 2: candidate cell + standalone detector benches ----------
procedure( r7aBuildCmfb(cand)
  let( (cv cell p)
    p = r7aCandP(cand) cell = r7aCmfbCell(cand)
    when( ddGetObj(ece203Lib cell) error("%s already exists: new revisions get a new name" cell))
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv r7aPins)
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) r7aCmfbDevs(p)))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
    cell
  )
)
r7aDetVars = list(list("vdd" 1.8) list("vref" 0.9) list("ib3" 50e-9) list("vcm" 0.9) list("vd" 0.0))
procedure( r7aDetSpecs(cmfbCell)
  list(
    otaV("VDD" "vdd" "0" "vdd" "gnd!")
    otaV("VDDC" "vdd" "0" "vddc" "gnd!")
    otaV("VREF" "vref" "0" "vref" "gnd!")
    otaV("VLD" "vref" "0" "vld" "gnd!")
    otaI("IB" "ib3" "vdd" "ib")
    ece203FetSpec("nfetx" "MREF" 2e-6 4e-6 "ib" "ib" "gnd!" "gnd!")
    otaV("VOP" "vcm+vd/2" "0" "op" "gnd!")
    otaV("VON" "vcm-vd/2" "0" "on" "gnd!")
    ece203FetSpec("pfetx" "M3R" 2e-6 4e-6 "vld" "vg" "vdd" "vdd")
    ece203FetSpec("pfetx" "M4R" 2e-6 4e-6 "vld" "vg" "vdd" "vdd")
    list(ece203Lib cmfbCell "XC" nil '(("OP" "op") ("ON" "on") ("VREF" "vref") ("VCMFB" "vg") ("VDD" "vddc")
                                         ("GND" "gnd!") ("IBIAS" "ib"))))
)
;; job ece203_r7a_build_det: the old-DD standalone bench (once) + the selected candidate cell and its bench
procedure( r7aBuildDet()
  let( (cand)
    ece203LibInfo()
    unless( ddGetObj(ece203Lib r6Cells->cmfb) error("missing %s" r6Cells->cmfb))
    unless( ddGetObj(ece203Lib r7aDetCell("old")) otaTb(r7aDetCell("old") r7aDetSpecs(r6Cells->cmfb)))
    cand = r7aCand()
    r7aBuildCmfb(cand)
    otaTb(r7aDetCell(cand) r7aDetSpecs(r7aCmfbCell(cand)))
    t
  )
)
r7aSweepVcm = '(0.88 0.899 0.90 0.901 0.92)
r7aOpVcm = '(0.88 0.90 0.92)
r7aOpVd = '(-0.2 -0.1 -0.05 0.0 0.05 0.1 0.2)
r7aOpCols = '(tag vcm vd inst id_A gm_S gds_S vgs_V vds_V vth_V vdsat_V region margin_V vg_V ta_V tb_V i_vddc_A)
procedure( r7aDetOne(cand)
  let( (cell port tag vg ic ta tb rows i0 m)
    cell = r7aDetCell(cand)
    ;; DC sweeps
    foreach(vc r7aSweepVcm
      tag = sprintf(nil "D_%s_sw_vcm%.0f" cand vc * 1000.0)
      ece203Setup(cell strcat("_" tag))
      r6bOpt(r6bSysOpts)
      ece203Vars(r7aDetVars)
      desVar("vcm" vc)
      analysis('dc ?param "vd" ?start "-0.2" ?stop "0.2" ?step "0.002")
      run()
      vg = v("/vg" ?result "dc") ic = i("/VDDC/PLUS" ?result "dc")
      ta = car(errset(v("/XC/ta" ?result "dc") nil)) tb = car(errset(v("/XC/tb" ?result "dc") nil))
      r6bWrite(strcat(r7aDir "/" tag ".csv") "vd_V,vg_V,i_vddc_A,ta_V,tb_V"
               list(vg ic or(ta vg) or(tb vg))))
    r7aCopyNetlist(cell sprintf(nil "D_%s" cand))
    ;; oppoints (controller devices) at the registered points
    port = r7aOpen(sprintf(nil "D_%s_op.csv" cand) r7aOpCols)
    foreach(vc r7aOpVcm
      foreach(vdx r7aOpVd
        tag = sprintf(nil "D_%s_op" cand)
        ece203Setup(cell strcat("_" tag))
        r6bOpt(r6bSysOpts)
        ece203Vars(r7aDetVars)
        desVar("vcm" vc) desVar("vd" vdx)
        analysis('dc ?saveOppoint t)
        run()
        rows = ece203OpRows(r7aCmfbInsts)
        i0 = ldIdc("/VDDC/PLUS")
        foreach(x rows
          m = ece203Margin(caddr(x))
          fprintf(port "%s,%g,%g,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" tag vc vdx car(x)
                  spsNum(nth(0 caddr(x)) "%.6g") spsNum(nth(1 caddr(x)) "%.6g") spsNum(nth(2 caddr(x)) "%.6g")
                  spsNum(nth(3 caddr(x)) "%.6g") spsNum(nth(4 caddr(x)) "%.6g") spsNum(nth(5 caddr(x)) "%.6g")
                  spsNum(nth(6 caddr(x)) "%.6g") spsNum(nth(7 caddr(x)) "%g") spsNum(m "%.5g")
                  spsNum(ldDc("vg") "%.7g") spsNum(ldDc("XC/ta") "%.6g") spsNum(ldDc("XC/tb") "%.6g") spsNum(i0 "%.6g")))
        acSay("r7aD %s vcm %g vd %g: vg %s i_vddc %s\n" cand vc vdx r4Num(ldDc("vg") "%.7g") r4Num(i0 "%.5g"))))
    close(port)
    r7aRmPsf(cell)
    t
  )
)
;; job ece203_r7a_det: old DD-pair (once, if its op file is missing) and the selected candidate
procedure( r7aDet()
  r7aMkdir(r7aDir)
  unless( isFile(strcat(r7aDir "/D_old_op.csv")) r7aDetOne("old"))
  r7aDetOne(r7aCand())
  t
)

;; ---------- Stage 3: system integration (only after the Stage 2 gate) ----------
procedure( r7aSysSpecs(cmfbCell)
  append(setof(e mapcar('r6cFixSpec r6bSSpecs()) caddr(e) != "XC")
         list(list(ece203Lib r6dCells->cd "XCD" nil '(("FP" "fp") ("FN" "fn") ("BUFP" "bufp") ("BUFN" "bufn") ("VDD" "vdd")
                                                       ("GND" "gnd!") ("IBIAS" "ib")))
              otaC("CLBP" "clb" "bufp" "gnd!") otaC("CLBN" "clb" "bufn" "gnd!")
              list(ece203Lib cmfbCell "XC" nil '(("OP" "op") ("ON" "on") ("VREF" "vrc") ("VCMFB" "vcf") ("VDD" "vdd")
                                                   ("GND" "gnd!") ("IBIAS" "ib")))))
)
;; job ece203_r7a_build_sys (own Virtuoso session: sticky analogLib parameters)
procedure( r7aBuildSys()
  let( (cand)
    ece203LibInfo()
    cand = r7aCand()
    unless( ddGetObj(ece203Lib r7aCmfbCell(cand)) error("missing %s" r7aCmfbCell(cand)))
    unless( ddGetObj(ece203Lib r6dCells->cd) error("missing %s" r6dCells->cd))
    when( ddGetObj(ece203Lib r7aSysCell(cand)) error("%s already exists" r7aSysCell(cand)))
    otaTb(r7aSysCell(cand) r7aSysSpecs(r7aCmfbCell(cand)))
    t
  )
)
r7aSysBase = append(r6dBase list(list("clb" 10e-12)))
r7aACols = '(tag status reason fp fn fp_cm op on op_cm bufp bufn buf_cm vg vcf ib I_VDD I_VDDD ctrl_I
             Hpre10 Hpre100 Hpre100_ph Hpre1k Hbuf100 Hbuf100_ph Acd100 CMRR60_pre CMRR60_buf
             minA worstA minC worstC cmfb_ugf cmfb_pm cmfb_lgdc cmfb_ph0 drl_ugf drl_pm drl_lg60 drl_lgdc drl_ph0)
procedure( r7aSysA()
  let( (cand cell port r ok w vd hpre hbuf bp bn acd wc rows)
    cand = r7aCand() cell = r7aSysCell(cand)
    port = r7aOpen(sprintf(nil "S_%s_stageA.csv" cand) r7aACols)
    r = list(nil 'tag sprintf(nil "S_%s_buf10p" cand) 'status "ok")
    ok = errset(
      progn(
        w = r7aOn(cell 'r6AcRun strcat(r->tag "_dm") append(r7aSysBase list(list("adm" 1.0) list("dcc" 0.01))))
        vd = w->vd hpre = ldDiv(w->vod vd) bp = ldAc("bufp") bn = ldAc("bufn")
        hbuf = and(bp bn ldDiv(bp - bn vd)) acd = and(hbuf ldDiv(bp - bn w->vod))
        r->Hpre10 = ldMag(hpre 10.0) r->Hpre100 = ldMag(hpre 100.0) r->Hpre100_ph = ldPh(hpre 100.0) r->Hpre1k = ldMag(hpre 1000.0)
        when( hbuf r->Hbuf100 = ldMag(hbuf 100.0) r->Hbuf100_ph = ldPh(hbuf 100.0) r->Acd100 = ldMag(acd 100.0))
        ldWriteCurves(strcat(r7aDir "/" r->tag "_dm_ac.csv") list(list("Hpre" hpre) list("Hbuf" hbuf) list("Acd" acd)))
        foreach(n '("fp" "fn" "op" "on" "bufp" "bufn" "vg" "vcf" "ib") putprop(r ldDc(n) stringToSymbol(n)))
        r->fp_cm = (r->fp + r->fn) / 2.0 r->op_cm = (r->op + r->on) / 2.0 r->buf_cm = (r->bufp + r->bufn) / 2.0
        r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDDD = ldIdc("/VDDD/PLUS")
        rows = ece203OpDump(strcat(r7aDir "/" r->tag "_dcop.csv")
                            append('("XA.M1" "XA.M2" "XA.MC1" "XA.MC2" "XA.M3" "XA.M4" "XA.MT" "XA.MREF"
                                     "XCD.MSP" "XCD.MSN" "XCD.MKP" "XCD.MKN") r7aCmfbInsts))
        foreach(x rows
          let( (m) m = ece203Margin(caddr(x))
            when( numberp(m) && car(parseString(car(x) ".")) == "XA" && (!r->minA || m < r->minA) r->minA = m r->worstA = car(x))
            when( numberp(m) && car(parseString(car(x) ".")) == "XC" && (!r->minC || m < r->minC) r->minC = m r->worstC = car(x))))
        r->ctrl_I = let( (s) s = 0.0 foreach(x rows when( member(car(x) '("XC.MTA" "XC.MTB")) && numberp(nth(0 caddr(x)))
                                                       s = s + nth(0 caddr(x)))) s)
        r7aCopyNetlist(cell r->tag)
        wc = r7aOn(cell 'r6AcRun strcat(r->tag "_cm") append(r7aSysBase list(list("vcmin" 1.0) list("dcc" 0.01))))
        r->CMRR60_pre = ece203Db(ldMag(hpre 60.0) / ldMag(wc->vod 60.0))
        bp = ldAc("bufp") bn = ldAc("bufn")
        when( and(hbuf bp bn) r->CMRR60_buf = ece203Db(ldMag(hbuf 60.0) / ldMag(bp - bn 60.0)))
        r7aOn(cell 'r6Stb r r->tag append(r7aSysBase list(list("dcc" 0.01))))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    r7aRmPsf(cell)
    acSay("r7aS %s: %s %s | fp/fn %s %s cm %s | op/on cm %s | buf cm %s | vg %s ib %s | I %s %s ctrl %s | Hpre 10/100/1k %s %s %s ph %s | Hbuf100 %s Acd %s | CMRR60 %s %s\n"
          r->tag r->status or(r->reason "") r4Num(r->fp "%.6g") r4Num(r->fn "%.6g") r4Num(r->fp_cm "%.6g") r4Num(r->op_cm "%.6g")
          r4Num(r->buf_cm "%.5g") r4Num(r->vg "%.6g") r4Num(r->ib "%.5g") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g")
          r4Num(r->ctrl_I "%.4g") r4Num(r->Hpre10 "%.5g") r4Num(r->Hpre100 "%.5g") r4Num(r->Hpre1k "%.5g")
          r4Num(r->Hpre100_ph "%.2f") r4Num(r->Hbuf100 "%.5g") r4Num(r->Acd100 "%.5g") r4Num(r->CMRR60_pre "%.2f") r4Num(r->CMRR60_buf "%.2f"))
    acSay("r7aS %s: OTA min margin %s %s | CMFB min margin %s %s | CMFB UGF %s PM %s LGdc %s ph0 %s | DRL UGF %s PM %s LG60 %s\n"
          r->tag r4Num(r->minA "%.3f") or(r->worstA "") r4Num(r->minC "%.3f") or(r->worstC "")
          r4Num(r->cmfb_ugf "%.4g") r4Num(r->cmfb_pm "%.2f") r4Num(r->cmfb_lgdc "%.4g") r4Num(r->cmfb_ph0 "%.1f")
          r4Num(r->drl_ugf "%.4g") r4Num(r->drl_pm "%.2f") r4Num(r->drl_lg60 "%.4g"))
    r4Row(port r7aACols r)
    close(port)
    t
  )
)
;; 60 ms, 2 kHz TG, 100 Hz 1 mV DM; R6D-R setting C (gmin 1e-18, iabstol 1e-17, reltol 1e-5, tran cmin 1e-17 F)
r7aTCols = '(tag status reason t_end stalled_at fp_cm_avg op_cm_avg buf_cm_avg vg_min vg_max I_VDD I_VDDD rows csv)
procedure( r7aSysB()
  let( (cand cell tag r ok sim psf vid fp fn op on vg dr bp bn iv id names waves file wlog port t1 t0)
    cand = r7aCand() cell = r7aSysCell(cand) tag = sprintf(nil "T_%s_buf10p" cand)
    port = r7aOpen(sprintf(nil "T_%s.csv" cand) r7aTCols)
    r = list(nil 'tag tag 'status "ok")
    sim = sprintf(nil "%s/sim_%s" r7aTmp tag) psf = strcat(sim "/psf")
    sh(sprintf(nil "rm -rf %s" sim)) r7aMkdir(strcat(r7aTmp "/out"))
    wlog = strcat(r7aTmp "/out/watchdog.log")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        resultsDir(sim)
        r6bOpt('(gmin "1e-18" iabstol "1e-17" reltol "1e-5"))
        analysis('tran ?stop "60m" ?maxstep "0.5u" ?cmin "1e-17")
        car(errset(saveOption('save "selected") nil))
        car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr" "/bufp" "/bufn" "/XC/ta" "/XC/tb") nil))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars append(r7aSysBase list(list("chen" 1.0) list("tch" 500e-6) list("vd" 1e-3))))
        sh(sprintf(nil "nohup bash %s/tools/r7a_watchdog.sh %s %s %d %s > /dev/null 2>&1 &" acRoot tag psf r7aStall wlog))
        run()
        when( isFile(strcat(sim "/WATCHDOG_STALL"))
          r->stalled_at = car(errset(let( (p l) p = infile(strcat(sim "/WATCHDOG_STALL")) gets(l p) close(p) car(parseString(l "\n"))) nil))
          error("stalled (watchdog)"))
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        r->t_end = r6bTend(vid)
        when( r->t_end < 0.99 * 60e-3 error("tran stopped at %g s" r->t_end))
        fp = v("/fp" ?result "tran") fn = v("/fn" ?result "tran") op = v("/op" ?result "tran") on = v("/on" ?result "tran")
        vg = v("/vg" ?result "tran") dr = v("/drlr" ?result "tran") bp = v("/bufp" ?result "tran") bn = v("/bufn" ?result "tran")
        iv = car(errset(i("/VDD/PLUS" ?result "tran") nil)) id = car(errset(i("/VDDD/PLUS" ?result "tran") nil))
        t1 = r->t_end t0 = 0.04
        r->fp_cm_avg = chAvg((fp + fn) / 2.0 t0 t1) r->op_cm_avg = chAvg((op + on) / 2.0 t0 t1)
        r->buf_cm_avg = chAvg((bp + bn) / 2.0 t0 t1)
        r->vg_min = ymin(clip(vg 0.02 t1)) r->vg_max = ymax(clip(vg 0.02 t1))
        r->I_VDD = and(iv chAvg(iv t0 t1)) r->I_VDDD = and(id chAvg(id t0 t1))
        file = sprintf(nil "%s/out/%s_tran.csv" r7aTmp tag)
        names = "t_s,vid_V,fp_V,fn_V,op_V,on_V,vg_V,drlr_V,bufp_V,bufn_V" waves = list(vid fp fn op on vg dr bp bn)
        when( and(iv id) names = strcat(names ",i_vdd_A,i_vddd_A") waves = append(waves list(iv id)))
        r->rows = r6bWrite(file names waves)
        sh(sprintf(nil "cd %s/out && sha256sum %s_tran.csv > %s_tran.csv.sha256 && gzip -f %s_tran.csv" r7aTmp tag tag tag))
        r->csv = strcat(file ".gz")
        t)
      t)
    unless( ok r->status = if( isFile(strcat(sim "/WATCHDOG_STALL")) "stalled" "failed") r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "gzip -c %s/spectre.out > %s/out/%s_spectre.out.gz 2>/dev/null; cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/out/%s_netlist.scs 2>/dev/null; rm -rf %s"
               psf r7aTmp tag getShellEnvVar("HOME") cell r7aTmp tag psf))
    acSay("r7aT %s: %s %s | t_end %s stalled %s | 40-60 ms fp/fn cm %s op/on cm %s buf cm %s | 20-60 ms vg %s..%s | I %s %s | rows %s\n"
          tag r->status or(r->reason "") r4Num(r->t_end "%.6g") or(r->stalled_at "-") r4Num(r->fp_cm_avg "%.6g")
          r4Num(r->op_cm_avg "%.6g") r4Num(r->buf_cm_avg "%.5g") r4Num(r->vg_min "%.5g") r4Num(r->vg_max "%.5g")
          r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->rows "%.0f"))
    r4Row(port r7aTCols r)
    close(port)
    t
  )
)
;; ADE L state (GUI job ece203_r7a_ade): integrated bench, TG static phase A, dc / ac / CMFB stb
procedure( r7aAde()
  let( (vars outs cand)
    hw1NoLicensePrompts()
    when( hiGraphicMode() acAutoOkStart() )
    unless( hiGraphicMode() error("r7aAde needs the GUI (run.sh ece203_r7a_ade)\n") )
    cand = r7aCand()
    vars = r6bMerge(r6Vars append(r7aSysBase list(list("adm" 1.0) list("dcc" 0.01))))
    outs = list(list("Hpre_dB" "db20((VF(\"/fp\") - VF(\"/fn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("op_cm" "(VDC(\"/op\") + VDC(\"/on\")) / 2")
                list("vg" "VDC(\"/vg\")")
                list("cmfbLoopGain" "getData(\"loopGain\" ?result \"stb\")"))
    r6bAdeOne(r7aSysCell(cand) sprintf(nil "r7a_%s_buf10p_phaseA" cand) vars outs "/IPRC")
    t
  )
)
