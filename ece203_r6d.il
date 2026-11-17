;; ECE203 Round 6D: real MOS differential common-drain (source-follower) output buffer after the demod TG.
;; Task: docs/ECE203_round6d_mos_cd_buffer_task.md. Baseline = R6C-I Project/ece203_r6c_tb_ideal (read-only, incl. the
;; VSPS sinephase 0 fix). New cells only: ece203_r6d_cd, ece203_r6d_tb_ref / _direct / _buf.
;;
;;   real FD OTA op/on -- XCO TG -- fp/fn -- original Cfb/Rfb feedback (unchanged)
;;                                   |  `-- CD_N gate (MSN) -> bufn
;;                                   `---- CD_P gate (MSP) -> bufp      CLBP/CLBN (clb) to ground
;;   REF    : R6C-I ideal bench spec list, nothing added
;;   DIRECT : + CLDP/CLDN (cld) from fp/fn to ground
;;   BUF    : + XCD (two NMOS followers + two NMOS sinks mirrored from the existing ib / MREF reference) + CLB on bufp/bufn
;; Each bench is built in its own Virtuoso session (separate jobs): omitted analogLib instance parameters take the value
;; last used in the session (R6C sticky vsin sinephase); ELM (vcvs with max/min) is in every bench.
;; Jobs: ece203_r6d_build_ref / _build_direct / _build_buf, ece203_r6d_a (Stage A), ece203_r6d_b (Stage B), ece203_r6d_ade.

r6dDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r6d")
;; large tran CSVs go to /tmp on the server (home quota), gzipped, fetched from there
r6dTmp = "/tmp/lix015_r6d"
r6dCells = list(nil 'cd "ece203_r6d_cd" 'ref "ece203_r6d_tb_ref" 'direct "ece203_r6d_tb_direct" 'buf "ece203_r6d_tb_buf")
;; CD: follower NMOS 6u/1u (D VDD, G FP/FN, S BUF, B GND); sink NMOS 4u/4u (D BUF, G IBIAS, S/B GND) = 2x MREF 2u/4u
r6dCdW = list(nil 'wf 6e-6 'lf 1e-6 'wk 4e-6 'lk 4e-6)
procedure( r6dCdDevs()
  list(list("nfetx" "MSP" r6dCdW->wf r6dCdW->lf "VDD" "FP" "BUFP" "GND")
       list("nfetx" "MSN" r6dCdW->wf r6dCdW->lf "VDD" "FN" "BUFN" "GND")
       list("nfetx" "MKP" r6dCdW->wk r6dCdW->lk "BUFP" "IBIAS" "GND" "GND")
       list("nfetx" "MKN" r6dCdW->wk r6dCdW->lk "BUFN" "IBIAS" "GND" "GND"))
)
r6dVars = list(list("cld" 1e-12) list("clb" 1e-12))
r6dBase = append(r6cBase r6dVars)
procedure( r6dBaseSpecs()
  append(setof(e mapcar('r6cFixSpec r6bSSpecs()) caddr(e) != "XC") r6cCtrlSpecs())
)
procedure( r6dPre()
  ece203LibInfo()
  unless( ddGetObj(ece203Lib r6bCells->tg) error("missing %s" r6bCells->tg))
  unless( ddGetObj(ece203Lib r6Cells->ota) error("missing %s" r6Cells->ota))
)
procedure( r6dBuildRef() r6dPre() otaTb(r6dCells->ref r6dBaseSpecs()) t )
procedure( r6dBuildDirect()
  r6dPre()
  otaTb(r6dCells->direct append(r6dBaseSpecs() list(otaC("CLDP" "cld" "fp" "gnd!") otaC("CLDN" "cld" "fn" "gnd!"))))
  t
)
procedure( r6dBuildBuf()
  let( (cv cell)
    r6dPre()
    cell = r6dCells->cd
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv '(("FP" "input") ("FN" "input") ("BUFP" "output") ("BUFN" "output") ("VDD" "inputOutput")
                    ("GND" "inputOutput") ("IBIAS" "input")))
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) r6dCdDevs()))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
    otaTb(r6dCells->buf
          append(r6dBaseSpecs()
                 list(list(ece203Lib cell "XCD" nil '(("FP" "fp") ("FN" "fn") ("BUFP" "bufp") ("BUFN" "bufn") ("VDD" "vdd")
                                                       ("GND" "gnd!") ("IBIAS" "ib")))
                      otaC("CLBP" "clb" "bufp" "gnd!") otaC("CLBN" "clb" "bufn" "gnd!"))))
    t
  )
)
procedure( r6dOpen(name cols)
  let( (port)
    unless( isDir(r6dDir) createDir(r6dDir) )
    port = outfile(strcat(r6dDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
procedure( r6dOn(cell fn @rest args)
  let( (oldTb oldDir res)
    oldTb = r6Cells->tb oldDir = r6Dir
    r6Cells->tb = cell r6Dir = r6dDir r4TightOpts = r6bSysOpts
    res = errset(apply(fn args) t)
    r6Cells->tb = oldTb r6Dir = oldDir r4TightOpts = nil
    unless( res error("%L" errset.errset))
    car(res)
  )
)
procedure( r6dSaveNetlist(cell tag)
  sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs"
             getShellEnvVar("HOME") cell r6dDir tag))
)

;; ---------- Stage A: TG static phase A ----------
r6dACols = '(tag bench cl status reason fp fn fp_cm op on op_cm bufp bufn buf_cm vg ib I_VDD I_VDDD
             Hpre10 Hpre100 Hpre100_ph Hpre1k Hbuf100 Hbuf100_ph Acd100 Acd100_ph Acd1k Acd10k CMRR60_pre CMRR60_buf
             msp_id msp_gm msp_vgs msp_vds msp_vdsat msp_margin mkp_id mkp_vgs mkp_vds mkp_vdsat mkp_margin
             msn_id msn_margin mkn_id mkn_margin minA worstA
             cmfb_ugf cmfb_pm cmfb_lgdc cmfb_ph0 drl_ugf drl_pm drl_lg60 drl_lgdc drl_ph0)
procedure( r6dOpVals(r rows)
  foreach(x rows
    let( (v m p)
      v = caddr(x) m = ece203Margin(v) p = lowerCase(cadr(parseString(car(x) ".")))
      when( member(p '("msp" "mkp" "msn" "mkn"))
        putprop(r nth(0 v) stringToSymbol(strcat(p "_id"))) putprop(r m stringToSymbol(strcat(p "_margin")))
        putprop(r nth(1 v) stringToSymbol(strcat(p "_gm"))) putprop(r nth(3 v) stringToSymbol(strcat(p "_vgs")))
        putprop(r nth(4 v) stringToSymbol(strcat(p "_vds"))) putprop(r nth(6 v) stringToSymbol(strcat(p "_vdsat"))))
      when( and(numberp(m) car(parseString(car(x) ".")) == "XA" (!r->minA || m < r->minA)) r->minA = m r->worstA = car(x))))
)
procedure( r6dCaseA(port tag bench cell cl over)
  let( (r ok w vd hpre hbuf acd wc bp bn rows)
    r = list(nil 'tag tag 'bench bench 'cl cl 'status "ok")
    ok = errset(
      progn(
        ;; DM AC (1 % Cc mismatch, as in R6C-I Stage A)
        w = r6dOn(cell 'r6AcRun strcat(tag "_dm") append(over list(list("adm" 1.0) list("dcc" 0.01))))
        vd = w->vd hpre = ldDiv(w->vod vd)
        bp = ldAc("bufp") bn = ldAc("bufn")
        hbuf = and(bp bn ldDiv(bp - bn vd)) acd = and(hbuf ldDiv(bp - bn w->vod))
        r->Hpre10 = ldMag(hpre 10.0) r->Hpre100 = ldMag(hpre 100.0) r->Hpre100_ph = ldPh(hpre 100.0) r->Hpre1k = ldMag(hpre 1000.0)
        when( hbuf
          r->Hbuf100 = ldMag(hbuf 100.0) r->Hbuf100_ph = ldPh(hbuf 100.0)
          r->Acd100 = ldMag(acd 100.0) r->Acd100_ph = ldPh(acd 100.0) r->Acd1k = ldMag(acd 1000.0) r->Acd10k = ldMag(acd 1e4))
        ldWriteCurves(strcat(r6dDir "/" tag "_dm_ac.csv")
                      if( hbuf list(list("Hpre" hpre) list("Hbuf" hbuf) list("Acd" acd)) list(list("Hpre" hpre))))
        ;; DC (same run)
        foreach(n '("fp" "fn" "op" "on" "bufp" "bufn" "vg" "ib") putprop(r ldDc(n) stringToSymbol(n)))
        r->fp_cm = and(numberp(r->fp) numberp(r->fn) (r->fp + r->fn) / 2.0)
        r->op_cm = and(numberp(r->op) numberp(r->on) (r->op + r->on) / 2.0)
        r->buf_cm = and(numberp(r->bufp) numberp(r->bufn) (r->bufp + r->bufn) / 2.0)
        r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDDD = ldIdc("/VDDD/PLUS")
        rows = ece203OpDump(strcat(r6dDir "/" tag "_dcop.csv")
                            '("XA.M1" "XA.M2" "XA.MC1" "XA.MC2" "XA.M3" "XA.M4" "XA.MT" "XA.MREF" "XCD.MSP" "XCD.MSN" "XCD.MKP" "XCD.MKN"))
        r6dOpVals(r rows)
        r6dSaveNetlist(cell tag)
        ;; CM AC: CMRR at 60 Hz, pre and buffered
        wc = r6dOn(cell 'r6AcRun strcat(tag "_cm") append(over list(list("vcmin" 1.0) list("dcc" 0.01))))
        r->CMRR60_pre = ece203Db(ldMag(hpre 60.0) / ldMag(wc->vod 60.0))
        bp = ldAc("bufp") bn = ldAc("bufn")
        when( and(hbuf bp bn) r->CMRR60_buf = ece203Db(ldMag(hbuf 60.0) / ldMag(bp - bn 60.0)))
        ;; loop stability (TG static phase A; NOT a proof for the time-varying chopped system)
        r6dOn(cell 'r6Stb r tag append(over list(list("dcc" 0.01))))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    ;; quota: this case's AC/stb psf (rebuildable) is deleted once the CSVs are written
    sh(sprintf(nil "rm -rf %s/simulation/%s/spectre/schematic_%s_*/psf" getShellEnvVar("HOME") cell tag))
    acSay("r6dA %s [%s cl %g]: %s %s | fp/fn %s %s cm %s | op/on cm %s | buf %s %s cm %s | vg %s ib %s | I %s %s\n"
          tag bench cl r->status or(r->reason "") r4Num(r->fp "%.6g") r4Num(r->fn "%.6g") r4Num(r->fp_cm "%.6g")
          r4Num(r->op_cm "%.6g") r4Num(r->bufp "%.5g") r4Num(r->bufn "%.5g") r4Num(r->buf_cm "%.5g") r4Num(r->vg "%.6g")
          r4Num(r->ib "%.5g") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g"))
    acSay("r6dA %s: Hpre 10/100/1k %s %s %s ph %s | Hbuf100 %s ph %s | Acd 100/1k/10k %s %s %s ph %s | CMRR60 pre %s buf %s dB\n"
          tag r4Num(r->Hpre10 "%.5g") r4Num(r->Hpre100 "%.5g") r4Num(r->Hpre1k "%.5g") r4Num(r->Hpre100_ph "%.2f")
          r4Num(r->Hbuf100 "%.5g") r4Num(r->Hbuf100_ph "%.2f") r4Num(r->Acd100 "%.5g") r4Num(r->Acd1k "%.5g")
          r4Num(r->Acd10k "%.5g") r4Num(r->Acd100_ph "%.2f") r4Num(r->CMRR60_pre "%.2f") r4Num(r->CMRR60_buf "%.2f"))
    acSay("r6dA %s: MSP id %s gm %s vgs %s vds %s vdsat %s margin %s | MKP id %s vgs %s vds %s vdsat %s margin %s | MSN id %s m %s | MKN id %s m %s | OTA min %s %s\n"
          tag r4Num(r->msp_id "%.4g") r4Num(r->msp_gm "%.4g") r4Num(r->msp_vgs "%.4g") r4Num(r->msp_vds "%.4g")
          r4Num(r->msp_vdsat "%.4g") r4Num(r->msp_margin "%.3f") r4Num(r->mkp_id "%.4g") r4Num(r->mkp_vgs "%.4g")
          r4Num(r->mkp_vds "%.4g") r4Num(r->mkp_vdsat "%.4g") r4Num(r->mkp_margin "%.3f") r4Num(r->msn_id "%.4g")
          r4Num(r->msn_margin "%.3f") r4Num(r->mkn_id "%.4g") r4Num(r->mkn_margin "%.3f") r4Num(r->minA "%.3f") or(r->worstA ""))
    acSay("r6dA %s: CMFB stb UGF %s PM %s LGdc %s ph0 %s | DRL UGF %s PM %s LG60 %s\n" tag
          r4Num(r->cmfb_ugf "%.4g") r4Num(r->cmfb_pm "%.2f") r4Num(r->cmfb_lgdc "%.4g") r4Num(r->cmfb_ph0 "%.1f")
          r4Num(r->drl_ugf "%.4g") r4Num(r->drl_pm "%.2f") r4Num(r->drl_lg60 "%.4g"))
    r4Row(port r6dACols r)
    r
  )
)
procedure( r6dStageA()
  let( (port)
    port = r6dOpen("r6d_stageA.csv" r6dACols)
    r6dCaseA(port "A_ref" "REF" r6dCells->ref 0.0 r6dBase)
    r6dCaseA(port "A_direct_1p" "DIRECT" r6dCells->direct 1e-12 append(r6dBase list(list("cld" 1e-12))))
    r6dCaseA(port "A_buf_1p" "BUFFERED" r6dCells->buf 1e-12 append(r6dBase list(list("clb" 1e-12))))
    r6dCaseA(port "A_direct_10p" "DIRECT" r6dCells->direct 10e-12 append(r6dBase list(list("cld" 10e-12))))
    r6dCaseA(port "A_buf_10p" "BUFFERED" r6dCells->buf 10e-12 append(r6dBase list(list("clb" 10e-12))))
    close(port)
    t
  )
)

;; ---------- Stage B: 2 kHz TG chopper, 100 Hz 1 mV DM, 60 ms ----------
r6dTCols = '(tag bench cl status reason fp_cm_avg buf_cm_avg vpre_pp vbuf_pp vg_min vg_max bufp_min bufp_max bufn_min bufn_max
             I_VDD I_VDDD rows csv)
procedure( r6dTran(port tag bench cell cl over)
  let( (r ok vid fp fn op on bp bn vg dr names waves file res)
    r = list(nil 'tag tag 'bench bench 'cl cl 'status "ok")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        ;; quota: the 60 ms tran psf (~21 MB) is written to /tmp on the server, not to the home directory
        unless( isDir(r6dTmp) createDir(r6dTmp) )
        resultsDir(sprintf(nil "%s/sim_%s" r6dTmp tag))
        r6bOpt(r6bSysOpts)
        analysis('tran ?stop "60m" ?maxstep "0.5u")
        car(errset(saveOption('save "selected") nil))
        if( cell == r6dCells->buf
          car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr" "/bufp" "/bufn") nil))
          car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr") nil)))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars append(over list(list("chen" 1.0) list("tch" 500e-6) list("vd" 1e-3))))
        run()
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        when( r6bTend(vid) < 59e-3 error("tran stopped at %g s" r6bTend(vid)))
        fp = v("/fp" ?result "tran") fn = v("/fn" ?result "tran") op = v("/op" ?result "tran") on = v("/on" ?result "tran")
        vg = v("/vg" ?result "tran") dr = v("/drlr" ?result "tran")
        bp = and(cell == r6dCells->buf v("/bufp" ?result "tran")) bn = and(cell == r6dCells->buf v("/bufn" ?result "tran"))
        r->fp_cm_avg = chAvg((fp + fn) / 2.0 40e-3 60e-3) r->vpre_pp = chPp(fp - fn 40e-3 60e-3)
        r->vg_min = ymin(clip(vg 20e-3 60e-3)) r->vg_max = ymax(clip(vg 20e-3 60e-3))
        when( and(bp bn)
          r->buf_cm_avg = chAvg((bp + bn) / 2.0 40e-3 60e-3) r->vbuf_pp = chPp(bp - bn 40e-3 60e-3)
          r->bufp_min = ymin(clip(bp 20e-3 60e-3)) r->bufp_max = ymax(clip(bp 20e-3 60e-3))
          r->bufn_min = ymin(clip(bn 20e-3 60e-3)) r->bufn_max = ymax(clip(bn 20e-3 60e-3)))
        r->I_VDD = car(errset(chAvg(i("/VDD/PLUS" ?result "tran") 40e-3 60e-3) nil))
        r->I_VDDD = car(errset(chAvg(i("/VDDD/PLUS" ?result "tran") 40e-3 60e-3) nil))
        unless( isDir(r6dTmp) createDir(r6dTmp) )
        file = strcat(r6dTmp "/" tag "_tran.csv")
        names = "t_s,vid_V,fp_V,fn_V,op_V,on_V,vg_V,drlr_V" waves = list(vid fp fn op on vg dr)
        when( and(bp bn) names = strcat(names ",bufp_V,bufn_V") waves = append(waves list(bp bn)))
        r->rows = r6bWrite(file names waves)
        sh(sprintf(nil "sha256sum %s > %s.sha256; gzip -f %s" file file file))
        r->csv = strcat(file ".gz")
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    ;; quota: this round's tran psf is rebuildable -> delete it after extraction
    res = sprintf(nil "%s/sim_%s/psf" r6dTmp tag)
    sh(sprintf(nil "tail -40 %s/spectre.out > %s/%s_spectre_tail.txt 2>/dev/null; rm -rf %s" res r6dDir tag res))
    acSay("r6dB %s [%s cl %g]: %s %s | 40-60 ms: fp/fn cm %s vpre pp %s | buf cm %s vbuf pp %s | 20-60 ms vg %s..%s bufp %s..%s bufn %s..%s | I %s %s | rows %s\n"
          tag bench cl r->status or(r->reason "") r4Num(r->fp_cm_avg "%.6g") r4Num(r->vpre_pp "%.4g") r4Num(r->buf_cm_avg "%.5g")
          r4Num(r->vbuf_pp "%.4g") r4Num(r->vg_min "%.5g") r4Num(r->vg_max "%.5g") r4Num(r->bufp_min "%.4g") r4Num(r->bufp_max "%.4g")
          r4Num(r->bufn_min "%.4g") r4Num(r->bufn_max "%.4g") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->rows "%.0f"))
    r4Row(port r6dTCols r)
    r
  )
)
procedure( r6dStageB()
  let( (port)
    port = r6dOpen("r6d_stageB.csv" r6dTCols)
    r6dTran(port "B_ref" "REF" r6dCells->ref 0.0 r6dBase)
    r6dTran(port "B_direct_1p" "DIRECT" r6dCells->direct 1e-12 append(r6dBase list(list("cld" 1e-12))))
    r6dTran(port "B_buf_1p" "BUFFERED" r6dCells->buf 1e-12 append(r6dBase list(list("clb" 1e-12))))
    r6dTran(port "B_direct_10p" "DIRECT" r6dCells->direct 10e-12 append(r6dBase list(list("cld" 10e-12))))
    r6dTran(port "B_buf_10p" "BUFFERED" r6dCells->buf 10e-12 append(r6dBase list(list("clb" 10e-12))))
    close(port)
    t
  )
)

;; ---------- ADE L states (GUI job ece203_r6d_ade): TG static phase A, dc / ac / CMFB stb, 10 pF loads ----------
procedure( r6dAde()
  let( (vars outs)
    hw1NoLicensePrompts()
    when( hiGraphicMode() acAutoOkStart() )
    unless( hiGraphicMode() error("r6dAde needs the GUI (run.sh ece203_r6d_ade)\n") )
    vars = r6bMerge(r6Vars append(r6dBase list(list("adm" 1.0) list("dcc" 0.01) list("cld" 10e-12) list("clb" 10e-12))))
    outs = list(list("Hpre_dB" "db20((VF(\"/fp\") - VF(\"/fn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("fp_cm" "(VDC(\"/fp\") + VDC(\"/fn\")) / 2")
                list("cmfbLoopGain" "getData(\"loopGain\" ?result \"stb\")"))
    r6bAdeOne(r6dCells->ref "r6d_ref_phaseA" vars outs "/IPRC")
    r6bAdeOne(r6dCells->direct "r6d_direct_10p_phaseA" vars outs "/IPRC")
    r6bAdeOne(r6dCells->buf "r6d_buf_10p_phaseA" vars
              append(outs list(list("Hbuf_dB" "db20((VF(\"/bufp\") - VF(\"/bufn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                               list("buf_cm" "(VDC(\"/bufp\") + VDC(\"/bufn\")) / 2"))) "/IPRC")
    t
  )
)
