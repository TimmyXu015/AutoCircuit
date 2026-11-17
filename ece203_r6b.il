;; ECE203 Round 6B: real MOS transmission-gate (TG) differential chopper microtest.
;; Task: docs/ECE203_round6b_real_mos_chopper_microtest.md. New cells only (ece203_r6b_*); R6A/R5/R4 cells read-only.
;; Jobs: ece203_r6b_unit (TG module unit tests), ece203_r6b_sys (R6A FD OTA + real CMFB + real DRL with two TG choppers),
;;       ece203_r6b_ade (GUI: ADE states).
;; Clocks are ideal 0/1.8 V pulse sources (complementary pairs, 2-phase non-overlapping, ~10 ns dead time) - NOT a
;; transistor clock generator.

r6bDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r6b")
r6bCells = list(nil 'tg "ece203_r6b_tgchop" 'utb "ece203_r6b_tg_tb" 'stb "ece203_r6b_fd_tg_tb")

;; 4 TGs = 8 MOS. Phase A (CKA high, CKAB low): INP->OUTP, INN->OUTN. Phase B (CKB high, CKBB low): INP->OUTN, INN->OUTP.
;; NMOS 1u/0.18u (bulk GND), PMOS 2u/0.18u (bulk VDD).
r6bTgW = list(nil 'wn 1e-6 'ln 0.18e-6 'wp 2e-6 'lp 0.18e-6)
procedure( r6bTgDevs()
  let( (wn ln wp lp)
    wn = r6bTgW->wn ln = r6bTgW->ln wp = r6bTgW->wp lp = r6bTgW->lp
    list(
      list("nfetx" "MN1" wn ln "INP" "CKA" "OUTP" "GND") list("pfetx" "MP1" wp lp "INP" "CKAB" "OUTP" "VDD")
      list("nfetx" "MN2" wn ln "INN" "CKA" "OUTN" "GND") list("pfetx" "MP2" wp lp "INN" "CKAB" "OUTN" "VDD")
      list("nfetx" "MN3" wn ln "INP" "CKB" "OUTN" "GND") list("pfetx" "MP3" wp lp "INP" "CKBB" "OUTN" "VDD")
      list("nfetx" "MN4" wn ln "INN" "CKB" "OUTP" "GND") list("pfetx" "MP4" wp lp "INN" "CKBB" "OUTP" "VDD"))
  )
)
procedure( r6bBuildTg()
  let( (cv cell)
    cell = r6bCells->tg
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv '(("INP" "inputOutput") ("INN" "inputOutput") ("OUTP" "inputOutput") ("OUTN" "inputOutput")
                    ("CKA" "input") ("CKAB" "input") ("CKB" "input") ("CKBB" "input") ("VDD" "inputOutput") ("GND" "inputOutput")))
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) r6bTgDevs()))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
    cell
  )
)
;; ideal clock drivers. pa / pb: static phase levels when chen = 0; chopping (chen 1) needs pa 1, pb 0.
;; A high on [0, tch/2), B high on [tch/2+10n, tch-10n); 1 ns edges; complements are exact mirrors.
procedure( r6bClocks()
  list(
    list("analogLib" "vpulse" "VCKA"
         '(("dc" "1.8*pa") ("v1" "1.8*pa") ("v2" "1.8*pa*(1-chen)") ("td" "tch/2") ("tr" "1n") ("tf" "1n") ("pw" "tch/2-1n")
           ("per" "tch") ("acm" "0") ("pacm" "0") ("pacp" "0")) '(("PLUS" "cka") ("MINUS" "gnd!")))
    list("analogLib" "vpulse" "VCKAB"
         '(("dc" "1.8-1.8*pa") ("v1" "1.8-1.8*pa") ("v2" "1.8-1.8*pa*(1-chen)") ("td" "tch/2") ("tr" "1n") ("tf" "1n")
           ("pw" "tch/2-1n") ("per" "tch") ("acm" "0") ("pacm" "0") ("pacp" "0")) '(("PLUS" "ckab") ("MINUS" "gnd!")))
    list("analogLib" "vpulse" "VCKB"
         '(("dc" "1.8*pb") ("v1" "1.8*pb") ("v2" "1.8*(pb+chen)") ("td" "tch/2+10n") ("tr" "1n") ("tf" "1n")
           ("pw" "tch/2-21n") ("per" "tch") ("acm" "0") ("pacm" "0") ("pacp" "0")) '(("PLUS" "ckb") ("MINUS" "gnd!")))
    list("analogLib" "vpulse" "VCKBB"
         '(("dc" "1.8-1.8*pb") ("v1" "1.8-1.8*pb") ("v2" "1.8-1.8*(pb+chen)") ("td" "tch/2+10n") ("tr" "1n") ("tf" "1n")
           ("pw" "tch/2-21n") ("per" "tch") ("acm" "0") ("pacm" "0") ("pacp" "0")) '(("PLUS" "ckbb") ("MINUS" "gnd!"))))
)
procedure( r6bTgInst(name inp inn outp outn)
  list(ece203Lib r6bCells->tg name nil
       list(list("INP" inp) list("INN" inn) list("OUTP" outp) list("OUTN" outn) list("CKA" "cka") list("CKAB" "ckab")
            list("CKB" "ckb") list("CKBB" "ckbb") list("VDD" "vdd") list("GND" "gnd!")))
)

;; ---------- unit testbench ----------
;; sources: ideal (low-Z) inputs vcm +- vdc/2 + 100 Hz sine vd/2 (antiphase); loads: cl per output (R6A-like: ~OTA gate
;; 0.45 pF + Cfb 0.5 pF -> 1 pF); Ron probe current iro out of OUTP; leakage resistors rl from outputs to vcm.
r6bUVars = list(list("vdd" 1.8) list("vcm" 0.9) list("vdc" 0.0) list("vd" 0.0) list("fin" 100.0) list("cl" 1e-12)
  list("iro" 0.0) list("rl" 1e15) list("pa" 1.0) list("pb" 0.0) list("chen" 0.0) list("tch" 500e-6))
procedure( r6bUSpecs()
  append(
    list(
      otaV("VDD" "vdd" "0" "vdd" "gnd!")
      otaV("VCMO" "vcm" "0" "vcmo" "gnd!")
      list("analogLib" "vsin" "VP" '(("vdc" "vcm+vdc/2") ("vo" "vcm+vdc/2") ("va" "vd/2") ("freq" "fin") ("acm" "0"))
           '(("PLUS" "inp") ("MINUS" "gnd!")))
      list("analogLib" "vsin" "VN" '(("vdc" "vcm-vdc/2") ("vo" "vcm-vdc/2") ("va" "vd/2") ("freq" "fin") ("sinephase" "180") ("acm" "0"))
           '(("PLUS" "inn") ("MINUS" "gnd!")))
      r6bTgInst("XT" "inp" "inn" "outp" "outn")
      otaC("CLP" "cl" "outp" "gnd!") otaC("CLN" "cl" "outn" "gnd!")
      list("analogLib" "idc" "IRO" '(("idc" "iro") ("acm" "0")) '(("PLUS" "outp") ("MINUS" "gnd!")))
      otaR("RLP" "rl" "outp" "vcmo") otaR("RLN" "rl" "outn" "vcmo"))
    r6bClocks())
)
procedure( r6bOpen(name cols)
  let( (port)
    unless( isDir(r6bDir) createDir(r6bDir) )
    port = outfile(strcat(r6bDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
procedure( r6bSet(base over) ece203Vars(base) ece203Vars(over) )
;; fast CSV writer (walks all point lists in parallel; spsWriteWaves uses nth -> quadratic)
procedure( r6bWrite(file header waves)
  let( (cols port n)
    cols = mapcar('acWavePoints waves)
    port = outfile(file "w")
    fprintf(port "%s\n" header)
    n = 0
    while( car(cols)
      fprintf(port "%.10g" car(car(car(cols))))
      foreach(c cols fprintf(port ",%.10g" if( car(c) cadr(car(c)) 0.0)))
      fprintf(port "\n")
      cols = mapcar('cdr cols)
      n = n + 1)
    close(port)
    acSay("wrote %s (%d rows)\n" file n)
    n
  )
)
procedure( r6bDcRun(tag over)
  ece203Setup(r6bCells->utb strcat("_" tag))
  r4Tight()
  analysis('dc ?saveOppoint t)
  r6bSet(r6bUVars over)
  run()
)
r6bUCols = '(tag vcm kind status reason ron_A ron_B vod_A vod_B leak_P leak_N i_vdd)
procedure( r6bUnitStatic(port)
  let( (r ok)
    foreach(vc '(0.75 0.9 1.05)
      r = list(nil 'tag sprintf(nil "U1_static_vcm%g" vc) 'vcm vc 'kind "DC: Ron (100 nA), static polarity (vdc 10 mV), off leakage (0.2 V, rl 1 GOhm)" 'status "ok")
      ok = errset(
        progn(
          r6bDcRun("U1_ronA" list(list("vcm" vc) list("iro" 100e-9) list("pa" 1.0) list("pb" 0.0)))
          r->ron_A = (ldDc("inp") - ldDc("outp")) / 100e-9
          r6bDcRun("U1_ronB" list(list("vcm" vc) list("iro" 100e-9) list("pa" 0.0) list("pb" 1.0)))
          r->ron_B = (ldDc("inn") - ldDc("outp")) / 100e-9
          r6bDcRun("U1_polA" list(list("vcm" vc) list("vdc" 0.01) list("pa" 1.0) list("pb" 0.0)))
          r->vod_A = ldDc("outp") - ldDc("outn")
          r->i_vdd = ldIdc("/VDD/PLUS")
          r6bDcRun("U1_polB" list(list("vcm" vc) list("vdc" 0.01) list("pa" 0.0) list("pb" 1.0)))
          r->vod_B = ldDc("outp") - ldDc("outn")
          r6bDcRun("U1_leak" list(list("vcm" vc) list("vdc" 0.2) list("pa" 0.0) list("pb" 0.0) list("rl" 1e9)))
          r->leak_P = (ldDc("outp") - vc) / 1e9 r->leak_N = (ldDc("outn") - vc) / 1e9
          when( vc == 0.9 ece203OpDump(strcat(r6bDir "/U1_vcm0p9_leak_dcop.csv") '("XT.MN1" "XT.MP1" "XT.MN3" "XT.MP3")))
          t)
        t)
      unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
      acSay("r6bU %s: %s %s | Ron A %s B %s Ohm | static vod (vdc 10 mV) A %s B %s | off leak P %s N %s A | I_VDD %s\n"
            r->tag r->status or(r->reason "") r4Num(r->ron_A "%.4g") r4Num(r->ron_B "%.4g") r4Num(r->vod_A "%.5g")
            r4Num(r->vod_B "%.5g") r4Num(r->leak_P "%.3g") r4Num(r->leak_N "%.3g") r4Num(r->i_vdd "%.3g"))
      r4Row(port r6bUCols r))
  )
)
;; chopped unit tran: vd 1 mV @100 Hz on vcm, ideal clocks, 10 ms (one 100 Hz period)
r6bTCols = '(tag fch vcm status reason gainA gainB fdthru_pp cm_dev_max i_vdd_avg i_cka_avg rows)
procedure( r6bUnitTran(port tag fch vc)
  let( (r ok tch ip in op on ca cb iv ia vid vod cm)
    tch = 1.0 / fch
    r = list(nil 'tag tag 'fch fch 'vcm vc 'status "ok")
    ok = errset(
      progn(
        ece203Setup(r6bCells->utb strcat("_" tag))
        r4Tight()
        analysis('tran ?stop "10m" ?maxstep "50n")
        car(errset(save('i "/VDD/PLUS" "/VCKA/PLUS") nil))
        r6bSet(r6bUVars list(list("vcm" vc) list("vd" 1e-3) list("chen" 1.0) list("tch" tch)))
        run()
        ip = v("/inp" ?result "tran") in = v("/inn" ?result "tran") op = v("/outp" ?result "tran") on = v("/outn" ?result "tran")
        ca = v("/cka" ?result "tran") cb = v("/ckb" ?result "tran")
        iv = car(errset(i("/VDD/PLUS" ?result "tran") nil)) ia = car(errset(i("/VCKA/PLUS" ?result "tran") nil))
        vid = ip - in vod = op - on cm = (op + on) / 2.0
        ;; per-phase sign: A is on [k*tch, k*tch+tch/2), B on [k*tch+tch/2+10n, (k+1)*tch-10n); sample at 90% of each
        ;; phase right after t = 2.5 ms (vid near its +peak; 2.5 ms is a multiple of tch for 2 and 4 kHz)
        r->gainA = value(vod 2.5e-3 + 0.45 * tch) / value(vid 2.5e-3 + 0.45 * tch)
        r->gainB = value(vod 2.5e-3 + 0.95 * tch) / value(vid 2.5e-3 + 0.95 * tch)
        r->cm_dev_max = ymax(abs(cm - vc))
        r->i_vdd_avg = and(iv average(iv)) r->i_cka_avg = and(ia average(ia))
        r->rows = r6bWrite(strcat(r6bDir "/" tag "_tran.csv") "t_s,inp_V,inn_V,outp_V,outn_V,cka_V,ckb_V,i_vdd_A,i_cka_A"
                           list(ip in op on ca cb or(iv 0.0 * ip) or(ia 0.0 * ip)))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r6bU %s: %s %s | quick per-phase vod/vid A %s B %s | max |Vcm_out - vcm| %s | I_VDD avg %s I_CKA avg %s\n"
          tag r->status or(r->reason "") r4Num(r->gainA "%.4g") r4Num(r->gainB "%.4g") r4Num(r->cm_dev_max "%.4g")
          r4Num(r->i_vdd_avg "%.3g") r4Num(r->i_cka_avg "%.3g"))
    r4Row(port r6bTCols r)
    r
  )
)
procedure( r6bStageUnit()
  let( (port)
    ece203LibInfo()
    r6bBuildTg()
    otaTb(r6bCells->utb r6bUSpecs())
    port = r6bOpen("r6b_unit_static.csv" r6bUCols)
    r6bUnitStatic(port)
    close(port)
    port = r6bOpen("r6b_unit_tran.csv" r6bTCols)
    r6bUnitTran(port "U2_2k_vcm0p9" 2000.0 0.9)
    r6bUnitTran(port "U3_4k_vcm0p9" 4000.0 0.9)
    r6bUnitTran(port "U4_2k_vcm1p05" 2000.0 1.05)
    close(port)
    t
  )
)

;; ---------- system: R6A FD OTA + real CMFB + real DRL, ideal relays replaced by two TG chopper instances ----------
;; Everything else is the R6A ece203_r6a_tb netlist (same OTA/CMFB/DRL/electrodes/ideal bias/ideal Rfb). The ECG input is
;; a 100 Hz differential sine (vd) added in series with the R6A AC/PAC sources.
r6bRelays = '("S1P" "S1N" "S2P" "S2N" "S3P" "S3N" "S4P" "S4N" "VCK1" "VCK2" "VSP" "VSN")
procedure( r6bSSpecs()
  append(append(
    setof(e r6Specs() !member(caddr(e) r6bRelays))
    list(
      r6VP("VSP" "adm/2+vcmin" "0" "ep0" "body")
      r6VP("VSN" "-adm/2+vcmin" "180" "en0" "body")
      list("analogLib" "vsin" "VSPS" '(("vdc" "0") ("vo" "0") ("va" "vd/2") ("freq" "fin") ("acm" "0")) '(("PLUS" "ep") ("MINUS" "ep0")))
      list("analogLib" "vsin" "VSNS" '(("vdc" "0") ("vo" "0") ("va" "vd/2") ("freq" "fin") ("sinephase" "180") ("acm" "0"))
           '(("PLUS" "en") ("MINUS" "en0")))
      r6bTgInst("XCI" "p" "n" "ia" "ibx")
      r6bTgInst("XCO" "op" "on" "fp" "fn")))
    r6bClocks())
)
r6bSysBase = append(r6Real list(list("pa" 1.0) list("pb" 0.0) list("vd" 0.0) list("fin" 100.0)))
r6bSCols = '(tag fch status reason H100 H100_ph Hcm100 ratio vod_avg vod_pp ocm_avg ocm_pp icm_pp op_min op_max on_min on_max
             p_avg n_avg vg_min vg_max I_VDD I_VDDD rows)
;; run an R6A measurement function on the R6B system cell (temporarily rebinding the R6A cell name and output dir)
procedure( r6bOnSys(fn @rest args)
  let( (oldTb oldDir res)
    oldTb = r6Cells->tb oldDir = r6Dir
    r6Cells->tb = r6bCells->stb r6Dir = r6bDir
    res = errset(apply(fn args) t)
    r6Cells->tb = oldTb r6Dir = oldDir
    unless( res error("%L" errset.errset))
    car(res)
  )
)
procedure( r6bSysTran(port tag fch)
  let( (r ok tch vid vod op on ocm icm pp nn vg)
    tch = 1.0 / fch
    r = list(nil 'tag tag 'fch fch 'status "ok")
    ok = errset(
      progn(
        ece203Setup(r6bCells->stb strcat("_" tag))
        r4Tight()
        analysis('tran ?stop "60m" ?maxstep sprintf(nil "%g" tch / 1000.0))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars append(r6bSysBase list(list("chen" 1.0) list("tch" tch) list("vd" 1e-3))))
        run()
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        vod = v("/fp" ?result "tran") - v("/fn" ?result "tran")
        op = v("/op" ?result "tran") on = v("/on" ?result "tran") ocm = (op + on) / 2.0
        icm = (v("/inp" ?result "tran") + v("/inn" ?result "tran")) / 2.0
        pp = v("/p" ?result "tran") nn = v("/n" ?result "tran") vg = v("/vg" ?result "tran")
        r->vod_pp = chPp(vod 40e-3 60e-3) r->ocm_avg = chAvg(ocm 40e-3 60e-3) r->ocm_pp = chPp(ocm 40e-3 60e-3)
        r->icm_pp = chPp(icm 40e-3 60e-3) r->op_min = ymin(clip(op 40e-3 60e-3)) r->op_max = ymax(clip(op 40e-3 60e-3))
        r->on_min = ymin(clip(on 40e-3 60e-3)) r->on_max = ymax(clip(on 40e-3 60e-3))
        r->p_avg = chAvg(pp 40e-3 60e-3) r->n_avg = chAvg(nn 40e-3 60e-3)
        r->vg_min = ymin(clip(vg 40e-3 60e-3)) r->vg_max = ymax(clip(vg 40e-3 60e-3))
        r->I_VDD = car(errset(chAvg(i("/VDD/PLUS" ?result "tran") 40e-3 60e-3) nil))
        r->I_VDDD = car(errset(chAvg(i("/VDDD/PLUS" ?result "tran") 40e-3 60e-3) nil))
        r->rows = r6bWrite(strcat(r6bDir "/" tag "_tran.csv") "t_s,vid_V,vod_V,op_V,on_V,ocm_V,icm_V,p_V,n_V,vg_V"
                           list(vid vod op on ocm icm pp nn vg))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r6bS %s: %s %s | 40-60 ms: vod pp %s | ocm avg %s pp %s | icm pp %s | op %s..%s on %s..%s | p %s n %s | vg %s..%s | I %s %s\n"
          tag r->status or(r->reason "") r4Num(r->vod_pp "%.4g") r4Num(r->ocm_avg "%.5g") r4Num(r->ocm_pp "%.4g")
          r4Num(r->icm_pp "%.4g") r4Num(r->op_min "%.4g") r4Num(r->op_max "%.4g") r4Num(r->on_min "%.4g") r4Num(r->on_max "%.4g")
          r4Num(r->p_avg "%.5g") r4Num(r->n_avg "%.5g") r4Num(r->vg_min "%.5g") r4Num(r->vg_max "%.5g")
          r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g"))
    r4Row(port r6bSCols r)
    r
  )
)
;; the one PSS: 2 kHz, controlled 100 uV OTA input offset (ideal VOS after the input chopper), PAC 1-250 Hz
procedure( r6bSysPss(port tag)
  let( (r ok res w m vd h hc)
    r = list(nil 'tag tag 'fch 2000.0 'status "ok")
    ok = errset(
      progn(
        ece203Setup(r6bCells->stb strcat("_" tag))
        r4Tight()
        analysis('pss ?fund "2k" ?harms "40" ?errpreset "moderate")
        analysis('pac ?sweeptype "relative" ?relharmnum "0" ?start "1" ?stop "250" ?dec "20" ?maxsideband "3")
        r6bSet(r6Vars append(r6bSysBase list(list("chen" 1.0) list("tch" 500e-6) list("pacd" 0.5) list("vos" 100e-6))))
        run()
        res = strcat(getShellEnvVar("HOME") "/simulation/" r6bCells->stb "/spectre/schematic_" tag)
        openResults(strcat(res "/psf")) selectResult('pss_td)
        w = list(nil 'op v("/op") 'on v("/on") 'fp v("/fp") 'fn v("/fn") 'ocm v("/ocm") 'icm v("/icm") 'vg v("/vg") 'p v("/p") 'n v("/n"))
        m = w->fp - w->fn
        r->vod_avg = average(m) r->vod_pp = ymax(m) - ymin(m)
        r->ocm_avg = average(w->ocm) r->ocm_pp = ymax(w->ocm) - ymin(w->ocm) r->icm_pp = ymax(w->icm) - ymin(w->icm)
        r->op_min = ymin(w->op) r->op_max = ymax(w->op) r->on_min = ymin(w->on) r->on_max = ymax(w->on)
        r->p_avg = average(w->p) r->n_avg = average(w->n) r->vg_min = ymin(w->vg) r->vg_max = ymax(w->vg)
        r6bWrite(strcat(r6bDir "/" tag "_pss_td.csv") "t_s,op_V,on_V,fp_V,fn_V,ocm_V,vg_V,p_V,n_V"
                 list(w->op w->on w->fp w->fn w->ocm w->vg w->p w->n))
        vd = harmonic(v("/ep" ?result "pac") - v("/en" ?result "pac") 0)
        h = harmonic(v("/fp" ?result "pac") - v("/fn" ?result "pac") 0) / vd
        hc = harmonic(v("/ocm" ?result "pac") 0) / vd
        r->H100 = ldMag(h 100.0) r->H100_ph = ldPh(h 100.0) r->Hcm100 = ldMag(hc 100.0)
        ldWriteCurves(strcat(r6bDir "/" tag "_pac.csv") list(list("Hdm" h) list("Hcm_from_dm" hc)))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r6bS %s: %s %s | PAC |Hdm(100)| %s ph %s | ocm from DM %s | PSS vod avg %s pp %s | ocm avg %s pp %s | icm pp %s | op %s..%s on %s..%s | p %s n %s | vg %s..%s\n"
          tag r->status or(r->reason "") r4Num(r->H100 "%.4g") r4Num(r->H100_ph "%.1f") r4Num(r->Hcm100 "%.3g")
          r4Num(r->vod_avg "%.4g") r4Num(r->vod_pp "%.4g") r4Num(r->ocm_avg "%.5g") r4Num(r->ocm_pp "%.4g") r4Num(r->icm_pp "%.4g")
          r4Num(r->op_min "%.4g") r4Num(r->op_max "%.4g") r4Num(r->on_min "%.4g") r4Num(r->on_max "%.4g")
          r4Num(r->p_avg "%.5g") r4Num(r->n_avg "%.5g") r4Num(r->vg_min "%.5g") r4Num(r->vg_max "%.5g"))
    r4Row(port r6bSCols r)
    r
  )
)
procedure( r6bStageSys()
  let( (port portG r)
    ece203LibInfo()
    r6bBuildTg()
    r6Build()
    otaTb(r6bCells->stb r6bSSpecs())
    unless( isDir(r6bDir) createDir(r6bDir) )
    ;; (i) chopper OFF: TGs held in phase A (real MOS conducting) - DC, 100 Hz gain, CMRR, CMFB + DRL stb
    portG = r6bOpen("r6b_sys_off.csv" r6GCols)
    r = list(nil 'tag "S0_off_phaseA" 'mode "TG static phase A (chen 0)" 'status "ok")
    r6bOnSys('r6Gains r "S0_off" append(r6bSysBase list(list("dcc" 0.01))))
    r6bOnSys('r6Stb r "S0_off" append(r6bSysBase list(list("dcc" 0.01))))
    acSay("r6bS S0_off: Hdm 10/100 %s %s ph %s | CMRR60 %s dB | op %s on %s vg %s body %s | I %s %s | CMFB UGF %s PM %s | DRL UGF %s PM %s\n"
          r4Num(r->Hdm10 "%.4g") r4Num(r->Hdm100 "%.4g") r4Num(r->ph100 "%.1f") r4Num(r->CMRR60_dB "%.2f")
          r4Num(r->op "%.5g") r4Num(r->on "%.5g") r4Num(r->vg "%.5g") r4Num(r->body "%.5g") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g")
          r4Num(r->cmfb_ugf "%.4g") r4Num(r->cmfb_pm "%.1f") r4Num(r->drl_ugf "%.4g") r4Num(r->drl_pm "%.1f"))
    acSay("r6bS S0_off DC: p %s n %s ia %s ibx %s fp %s fn %s\n" r4Num(ldDc("p") "%.6g") r4Num(ldDc("n") "%.6g")
          r4Num(ldDc("ia") "%.6g") r4Num(ldDc("ibx") "%.6g") r4Num(ldDc("fp") "%.6g") r4Num(ldDc("fn") "%.6g"))
    r4Row(portG r6GCols r)
    close(portG)
    port = r6bOpen("r6b_sys_chop.csv" r6bSCols)
    r6bSysTran(port "S1_tg2k_tran" 2000.0)
    r6bSysTran(port "S2_tg4k_tran" 4000.0)
    r6bSysPss(port "S3_tg2k_pss_vos100u")
    close(port)
    t
  )
)
