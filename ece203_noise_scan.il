;; ece203_noise_scan.il -- ECE203 Round 2A: A1/A2 noise diagnosis and M1/M2 W/L sweep.
;; See docs/ECE203_round2_noise_scan.md. Round-1 cells are NOT touched.
;;
;; New cells (library Project):
;;   ece203_a12n_ota    same devices and nets as ece203_a12_ota (a12Cfg->devs), except that the input
;;                      pair M1/M2 has W = w12in, L = l12in and the NMOS mirror M7/M8 has W = w78in,
;;                      L = l78in (design variables; defaults 20u/1u and 1u/10u = Round-1 sizes)
;;                      -> the user can sweep or explore them in ADE
;;   ece203_a12n_cl_tb  same as ece203_hp_real_tb (OTA + ece203_hp_fb, IPRB for stb, CL 5 pF)
;;   ece203_a12n_ol_tb  same as ece203_a12_ol_tb (1 TOhm / 1 F DC follower, CL 5 pF, RL = rl12 to vcm)
;;
;; Jobs:
;;   ece203_noise_probe  build + baseline (20u/1u) + probe what the noise results offer per device
;;   ece203_noise_scan   Stage 1 breakdown + Stage 2 grid (W 20/40/80/160u x L 1/2/4u)

nsOta = "ece203_a12n_ota"
nsCl = "ece203_a12n_cl_tb"
nsOl = "ece203_a12n_ol_tb"
nsDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_ns")
nsCfg = list(nil
  'wList '(20e-6 40e-6 80e-6 160e-6) 'lList '(1e-6 2e-6 4e-6)
  'vcp 0.70 'vcn 0.75 'w0 20e-6 'l0 1e-6
  'spot '(0.1 1.0 10.0 100.0 250.0 1000.0)
  'noiseDec "20" 'acDec "20"
  ;; bounded rebias for points with a bad DC operating point
  'dVcp '(-0.25 -0.2 -0.15 -0.1 -0.05 0.0 0.05 0.1) 'dVcn '(-0.1 -0.05 0.0 0.05 0.1)
  'insts '("XA.M0" "XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.M5" "XA.M6" "XA.M7" "XA.M8" "XA.MREF")
  'scanInsts '("XA.M0" "XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.M5" "XA.M6" "XA.M7" "XA.M8"))

;; FET spec with W/L given as design-variable names (diffusion params as expressions)
procedure( nsFetSpecVar(dev name wv lv d g s b)
  list("cmrf7sf" dev name
       list(list("w" wv) list("l" lv)
            list("ad" sprintf(nil "%s*0.54e-6" wv)) list("as" sprintf(nil "%s*0.54e-6" wv))
            list("pd" sprintf(nil "2*(%s+0.54e-6)" wv)) list("ps" sprintf(nil "2*(%s+0.54e-6)" wv)))
       list(list("D" d) list("G" g) list("S" s) list("B" b)))
)

procedure( nsDevSpecs()
  mapcar(lambda((d)
           cond(
             ( member(cadr(d) '("M1" "M2"))
               nsFetSpecVar(nth(0 d) nth(1 d) "w12in" "l12in" nth(4 d) nth(5 d) nth(6 d) nth(7 d)))
             ( member(cadr(d) '("M7" "M8"))
               nsFetSpecVar(nth(0 d) nth(1 d) "w78in" "l78in" nth(4 d) nth(5 d) nth(6 d) nth(7 d)))
             ( t apply('ece203FetSpec d))))
         a12Cfg->devs)
)

procedure( nsBuild()
  let( (cv)
    ece203LibInfo()
    hpFbBuild()
    cv = acOpenSch(ece203Lib nsOta)
    ece203Pins(cv a12Cfg->pins)
    ece203Place(cv nsDevSpecs())
    ece203Finish(cv ece203Lib nsOta)
    ece203Symbol(ece203Lib nsOta)
    otaTb(nsOl list(
      otaV("VDD" "vdd" "0" "vdd" "gnd!")
      otaI("IB" "ib12" "ib" "gnd!")
      otaV("VCP" "vcp" "0" "vcp" "gnd!")
      otaV("VCN" "vcn" "0" "vcn" "gnd!")
      otaInst(nsOta '(("INP" "inp") ("INN" "inn") ("OUT" "out") ("VDD" "vdd") ("GND" "gnd!")
                      ("IBIAS" "ib") ("VCP" "vcp") ("VCN" "vcn")))
      otaV("VINP" "vcm" "1" "inp" "gnd!")
      otaR("RBIG" "rbig" "out" "inn")
      otaC("CBIG" "cbig" "inn" "gnd!")
      otaC("CL" "cl12" "out" "gnd!")
      otaR("RL" "rl12" "out" "vrl")
      otaV("VRL" "vcm" "0" "vrl" "gnd!")))
    otaTb(nsCl list(
      otaV("VDD" "vdd" "0" "vdd" "gnd!")
      otaI("IB" "ib12" "ib" "gnd!")
      otaV("VCP" "vcp" "0" "vcp" "gnd!")
      otaV("VCN" "vcn" "0" "vcn" "gnd!")
      otaV("VREF" "vref" "0" "vref" "gnd!")
      otaV("VIN" "vref" "1" "vin" "gnd!")
      list(ece203Lib "ece203_hp_fb" "XFB" nil '(("VIN" "vin") ("SUM" "sum") ("VOUT" "o")))
      otaInst(nsOta '(("INP" "vref") ("INN" "sum") ("OUT" "oa") ("VDD" "vdd") ("GND" "gnd!")
                      ("IBIAS" "ib") ("VCP" "vcp") ("VCN" "vcn")))
      otaProbe("oa" "o")
      otaC("CL" "cl12" "o" "gnd!")))
    t
  )
)

;; a point: DPL w l w78 l78 vcp vcn
procedure( nsP(w l w78 l78 vcp vcn)
  list(nil 'w w 'l l 'w78 w78 'l78 l78 'vcp vcp 'vcn vcn)
)
procedure( nsVars(p)
  ece203Vars(a12Cfg->vars)
  ece203Vars(list(list("w12in" p->w) list("l12in" p->l) list("w78in" p->w78) list("l78in" p->l78)
                  list("vcp" p->vcp) list("vcn" p->vcn)))
)

;; sqrt( integral of PSD^2 from a to b ), PSD in V/rtHz
procedure( nsRms(w a b)
  let( (x)
    x = and(w car(errset(integ(w * w a b) nil)))
    and(numberp(x) x >= 0 sqrt(x))
  )
)

;; closed-loop run (dc op + ac + stb + noise) of one point; returns DPL
procedure( nsClRun(p tag @optional (dec nil))
  let( (h mid fl fh s nin nout zin idd r)
    ece203Setup(nsCl strcat("_" tag))
    save('i "/VDD/PLUS" "/VIN/PLUS")
    analysis('dc ?saveOppoint t)
    analysis('ac ?start "1m" ?stop "1M" ?dec nsCfg->acDec)
    analysis('stb ?start "1m" ?stop "100M" ?dec "10" ?probe "/IPRB")
    analysis('noise ?start "1m" ?stop "100k" ?dec or(dec nsCfg->noiseDec) ?p "/o" ?n "/gnd!" ?iprobe "/VIN")
    nsVars(p)
    run()
    h = car(errset(v("/o" ?result "ac") nil))
    mid = and(h ece203V(mag(h) 100.0))
    fl = and(mid car(errset(cross(db20(h) ece203Db(mid) - 3.0 1 "rising") nil)))
    fh = and(mid car(errset(cross(db20(h) ece203Db(mid) - 3.0 1 "falling") nil)))
    s = otaStb()
    nin = car(errset(getData("in" ?result "noise") nil))
    nout = car(errset(getData("out" ?result "noise") nil))
    zin = car(errset(value(mag(v("/vin" ?result "ac") / i("/VIN/PLUS" ?result "ac")) 10.0) nil))
    idd = car(errset(-1.0 * i("/VDD/PLUS" ?result "dcOp") nil))
    r = list(nil 'h h 'mid mid 'fl fl 'fh fh 'ugf car(s) 'pm cadr(s) 'lg cadddr(s) 'nin nin 'nout nout
             'zin zin 'idd idd 'vout car(errset(v("/o" ?result "dcOp") nil))
             'vsum car(errset(v("/sum" ?result "dcOp") nil))
             'rmsIn nil)
    r->rmsIn = nsRms(nin 0.1 250.0)
    r->rmsInFull = nsRms(nin 1e-3 1e5)
    r->rmsOutFull = nsRms(nout 1e-3 1e5)
    r->rmsOutOverGain = and(numberp(r->rmsOutFull) numberp(mid) mid > 0 r->rmsOutFull / mid)
    r->ops = ece203OpRows(nsCfg->insts)
    r
  )
)

;; open-loop A0 / UGF, unloaded and with 1 MOhm to vcm
procedure( nsOlRun(p tag)
  let( (res h)
    ece203Setup(nsOl strcat("_" tag "ol"))
    analysis('ac ?start "1m" ?stop "100M" ?dec "10")
    foreach(rl '(1e15 1e6)
      nsVars(p)
      desVar("rl12" rl)
      run()
      h = car(errset(v("/out" ?result "ac") nil))
      res = append(res list(list(ece203V(mag(h) 1e-3) and(h car(errset(cross(db20(h) 0 1 "falling") nil)))))))
    res
  )
)

;; DC-only check of a bias point in the OL (follower) tb: (minMargin worstInst allRegionsOk vout)
procedure( nsOpCheck(p)
  let( (rows ok m vout)
    nsVars(p)
    run()
    rows = ece203OpRows(nsCfg->scanInsts)
    ok = t
    foreach(r rows
      unless( member(float(or(nth(7 caddr(r)) -1)) '(2.0 3.0)) ok = nil))
    vout = car(errset(v("/out" ?result "dcOp") nil))
    m = ece203MinMargin(nsCfg->scanInsts)
    list(car(m) cadr(m) ok vout)
  )
)

;; ---------------- probe ----------------
procedure( nsProbe()
  let( (r names port file s1 s2 x)
    unless( isDir(nsDir) createDir(nsDir) )
    nsBuild()
    r = nsClRun(nsP(nsCfg->w0 nsCfg->l0 1e-6 10e-6 nsCfg->vcp nsCfg->vcn) "nsbase")
    acSay("ns base: V(o) %s, I(VDD) %s, |H(100)| %s, fL %s, fH %s, UGF %s, PM %s, Zin10 %s, in-noise 1/10/100 Hz %s %s %s, rms(0.1-250) %s, rms in(1m-100k) %s, rms out(1m-100k)/|H| %s\n"
          acNum(r->vout "%.5g") acNum(r->idd "%.5g") acNum(r->mid "%.5g") acNum(r->fl "%.5g") acNum(r->fh "%.5g")
          acNum(r->ugf "%.5g") acNum(r->pm "%.2f") acNum(r->zin "%.5g")
          acNum(ece203V(r->nin 1.0) "%.4g") acNum(ece203V(r->nin 10.0) "%.4g") acNum(ece203V(r->nin 100.0) "%.4g")
          acNum(r->rmsIn "%.4g") acNum(r->rmsInFull "%.4g") acNum(r->rmsOutOverGain "%.4g"))
    ece203SaveNetlist(nsCl "ece203_nscl")
    ;; what does the noise result offer?
    names = car(errset(progn(selectResult('noise) outputs()) nil))
    acSay("ns probe: %d noise outputs; first 120: %L\n" length(names) firstN(names 120))
    foreach(n '("XA.M1" "/XA/M1" "XA/M1" "XFB.RP" "/XFB/RP")
      x = car(errset(getData(n ?result "noise") nil))
      acSay("ns probe: getData(%L noise) -> %L type %L\n" n x type(x)))
    file = strcat(nsDir "/probe_noisesummary_integrated.txt")
    port = outfile(file "w")
    s1 = errset(noiseSummary('integrated ?result 'noise ?from 0.1 ?to 250.0 ?output port) t)
    close(port)
    acSay("ns probe: noiseSummary integrated -> %L, file %s\n" s1 file)
    file = strcat(nsDir "/probe_noisesummary_spot1Hz.txt")
    port = outfile(file "w")
    s2 = errset(noiseSummary('spot ?result 'noise ?frequency 1.0 ?output port) t)
    close(port)
    acSay("ns probe: noiseSummary spot 1 Hz -> %L, file %s\n" s2 file)
    t
  )
)

procedure( firstN(l n)
  let( (out k)
    k = 0
    foreach(x l when( k < n out = cons(x out) k = k + 1))
    reverse(out)
  )
)

;; ================= Stage 1/2/3 driver =================
;; noise-source groups (device names as they appear in noiseSummary)
nsGroups = list(
  list("inpair"  '("/XA/M1" "/XA/M2"))
  list("pcas"    '("/XA/M3" "/XA/M4"))
  list("ncas"    '("/XA/M5" "/XA/M6"))
  list("mirror"  '("/XA/M7" "/XA/M8"))
  list("tailref" '("/XA/M0" "/XA/MREF"))
  list("rp"      '("/XFB/RP")))
nsGroupNames = '("inpair" "pcas" "ncas" "mirror" "tailref" "rp" "other")

;; run noiseSummary into file and parse it: returns DPL 'rows ((dev param V2) ...) 'total 'inref
procedure( nsSummary(file type @optional (from 0.1) (to 250.0) (freq 1.0))
  let( (port ok line f rows total inref x)
    port = outfile(file "w")
    ok = if( type == 'spot
           then errset(noiseSummary('spot ?result 'noise ?frequency freq ?output port) t)
           else errset(noiseSummary('integrated ?result 'noise ?from from ?to to ?output port) t))
    close(port)
    unless( ok acSay("ns: noiseSummary %L failed: %L\n" type errset.errset) )
    port = infile(file)
    while( gets(line port)
      f = parseString(line)
      cond(
        ( rexMatchp("^Total Summarized Noise" line) total = atof(car(last(f))))
        ( rexMatchp("^Total Input Referred Noise" line) inref = atof(car(last(f))))
        ( length(f) >= 3 && (x = atof(nth(2 f))) && f && car(f) != "Device"
          rows = cons(list(car(f) cadr(f) x) rows))))
    close(port)
    list(nil 'rows reverse(rows) 'total total 'inref inref)
  )
)

;; group sums: DPL key -> (total flicker) in V^2
procedure( nsGroup(rows)
  let( (res key g)
    res = list(nil)
    foreach(k nsGroupNames putprop(res list(0.0 0.0) stringToSymbol(k)))
    foreach(r rows
      key = "other"
      foreach(gr nsGroups when( member(car(r) cadr(gr)) key = car(gr)))
      g = get(res stringToSymbol(key))
      putprop(res list(car(g) + caddr(r) cadr(g) + if( cadr(r) == "fn" caddr(r) 0.0))
              stringToSymbol(key)))
    res
  )
)

;; one long-format breakdown block: tag,kind,freq,group,device,param,V2,pct
procedure( nsWriteBreakdown(port tag kind freq sum)
  let( (key)
    foreach(r sum->rows
      when( caddr(r) > 0.0
        key = "other"
        foreach(gr nsGroups when( member(car(r) cadr(gr)) key = car(gr)))
        fprintf(port "%s,%s,%g,%s,%s,%s,%.6g,%.4f\n" tag kind float(freq) key car(r) cadr(r) caddr(r)
                if( sum->total && sum->total > 0 100.0 * caddr(r) / sum->total 0.0))))
  )
)

nsHeader = strcat(
  "tag,stage,w_um,l_um,wl_um2,w78_um,l78_um,bias_mode,vcp_V,vcn_V,run_status,reason,flags,"
  "idd_A,id_M1_A,gm_M1_S,gmid_M1,gds_M1_S,vgs_M1_V,vds_M1_V,vdsat_M1_V,region_M1,"
  "id_M7_A,gm_M7_S,vds_M7_V,min_margin_V,worst_inst,all_regions_ok,vout_dc_V,"
  "A0_unloaded,UGF_unloaded_Hz,A0_with_1Mohm,absH_100Hz,fL_Hz,fH_Hz,loop_UGF_Hz,PM_deg,absZin_10Hz_ohm,"
  "nin_0.1Hz,nin_1Hz,nin_10Hz,nin_100Hz,nin_250Hz,nin_1kHz,"
  "rms_in_0.1_250_V,rms_in_1m_100k_V,rms_out_1m_100k_over_absH_V,sqrt2_paired_est_V,"
  "sum_total_out_V2,sum_inref_V2,"
  "pct_inpair,pct_pcas,pct_ncas,pct_mirror,pct_tailref,pct_rp,pct_other,"
  "flick_share_inpair,flick_share_mirror")

procedure( nsN(x @optional (fmt "%.6g")) spsNum(x fmt) )

procedure( nsWriteRow(port r)
  let( (op1 op7 g tot)
    op1 = r->op1 op7 = r->op7 g = r->groups tot = r->sumTotal
    fprintf(port "%s,%s,%g,%g,%g,%g,%g,%s,%g,%g,%s,%s,%s,"
            r->tag r->stage r->p->w * 1e6 r->p->l * 1e6 r->p->w * r->p->l * 1e12 r->p->w78 * 1e6 r->p->l78 * 1e6
            r->mode r->p->vcp r->p->vcn r->status or(r->reason "") or(r->flags ""))
    fprintf(port "%s,%s,%s,%s,%s,%s,%s,%s,%s,"
            nsN(r->idd) nsN(nth(0 op1)) nsN(nth(1 op1))
            nsN(and(numberp(nth(0 op1)) numberp(nth(1 op1)) nth(0 op1) != 0 abs(nth(1 op1) / nth(0 op1))))
            nsN(nth(2 op1)) nsN(nth(3 op1)) nsN(nth(4 op1)) nsN(nth(6 op1)) nsN(nth(7 op1) "%g"))
    fprintf(port "%s,%s,%s,%s,%s,%s,%s,"
            nsN(nth(0 op7)) nsN(nth(1 op7)) nsN(nth(4 op7)) nsN(r->margin) or(r->worst "") if( r->regionsOk "1" "0")
            nsN(r->vout))
    fprintf(port "%s,%s,%s,%s,%s,%s,%s,%s,%s,"
            nsN(r->a0) nsN(r->ugfOl) nsN(r->a0r) nsN(r->mid) nsN(r->fl) nsN(r->fh) nsN(r->ugf) nsN(r->pm) nsN(r->zin))
    foreach(f nsCfg->spot fprintf(port "%s," nsN(and(r->nin ece203V(r->nin f)))))
    fprintf(port "%s,%s,%s,%s,%s,%s,"
            nsN(r->rmsIn) nsN(r->rmsInFull) nsN(r->rmsOutOverGain) nsN(and(r->rmsIn sqrt(2.0) * r->rmsIn))
            nsN(tot) nsN(r->sumInref))
    foreach(k nsGroupNames
      fprintf(port "%s," nsN(and(g tot tot > 0 100.0 * car(get(g stringToSymbol(k))) / tot) "%.3f")))
    fprintf(port "%s,%s\n"
            nsN(and(g car(g->inpair) > 0 cadr(g->inpair) / car(g->inpair)) "%.4f")
            nsN(and(g car(g->mirror) > 0 cadr(g->mirror) / car(g->mirror)) "%.4f"))
    drain(port)
  )
)

;; measure one point; never throws -- failures become run_status
procedure( nsPoint(tag stage p mode bkPort)
  let( (r cl ol ok sum op1 op7 vout regionsOk m)
    r = list(nil 'tag tag 'stage stage 'p p 'mode mode 'status "ok")
    ok = errset(
      progn(
        cl = nsClRun(p tag)
        unless( cl->h error("no ac result") )
        foreach(x '(mid fl fh ugf pm zin idd vout nin rmsIn rmsInFull rmsOutOverGain)
          putprop(r get(cl x) x))
        op1 = caddr(car(setof(o cl->ops car(o) == "XA.M1")))
        op7 = caddr(car(setof(o cl->ops car(o) == "XA.M7")))
        r->op1 = op1 r->op7 = op7
        regionsOk = t
        foreach(o cl->ops
          when( member(car(o) nsCfg->scanInsts) && !member(float(or(nth(7 caddr(o)) -1)) '(2.0 3.0))
            regionsOk = nil))
        r->regionsOk = regionsOk
        m = ece203MinMargin(nsCfg->scanInsts)
        r->margin = car(m) r->worst = cadr(m)
        ;; noise breakdown (integrated 0.1-250 Hz, output-referred V^2)
        sum = nsSummary(strcat(nsDir "/" tag "_summary_0p1_250.txt") 'integrated 0.1 250.0)
        r->sumTotal = sum->total r->sumInref = sum->inref r->groups = nsGroup(sum->rows)
        when( bkPort nsWriteBreakdown(bkPort tag "integrated_0.1_250Hz" 0.0 sum))
        ;; per-point curves
        ece203OpDump(strcat(nsDir "/" tag "_op.csv") nsCfg->insts)
        spsWriteWaves(strcat(nsDir "/" tag "_noise.csv") "f_Hz,in_V_rtHz,out_V_rtHz" list(cl->nin cl->nout))
        spsWriteWaves(strcat(nsDir "/" tag "_ac.csv") "f_Hz,absH,phase_deg" list(ece203Mag(cl->h) ece203Ph(cl->h)))
        spsWriteWaves(strcat(nsDir "/" tag "_stb.csv") "f_Hz,absLoopGain,phaseLoopGain_deg"
                      list(ece203Mag(cl->lg) ece203Ph(cl->lg)))
        ;; open loop
        ol = nsOlRun(p tag)
        r->a0 = car(car(ol)) r->ugfOl = cadr(car(ol)) r->a0r = car(cadr(ol))
        t)
      t)
    unless( ok
      r->status = "error" r->reason = sprintf(nil "%L" car(errset.errset)))
    when( ok
      vout = r->vout
      cond(
        ( !r->regionsOk  r->status = "badop" r->reason = "a device outside region 2/3")
        ( !numberp(vout) || abs(vout - 0.9) > 0.05  r->status = "badop" r->reason = "output DC not at vref")
        ( t nil))
      r->flags = buildString(
        append(
          if( numberp(r->margin) && r->margin < 0.1 list("margin<0.1V") nil)
          append(if( numberp(r->pm) && r->pm < 60.0 list("PM<60") nil)
                 if( numberp(r->idd) && r->idd > 0.7e-6 list("I>0.7uA") nil)))
        "|"))
    acSay("ns %s [%s %s]: W %gu L %gu W78 %gu L78 %gu vcp %g vcn %g -> %s %s | I %s rms(0.1-250) %s |H| %s fL %s fH %s PM %s Zin %s margin %s (%s) A0 %s A0(1M) %s pct inpair %s mirror %s\n"
          tag stage mode p->w * 1e6 p->l * 1e6 p->w78 * 1e6 p->l78 * 1e6 p->vcp p->vcn r->status or(r->reason "")
          acNum(r->idd "%.4g") acNum(r->rmsIn "%.4g") acNum(r->mid "%.5g") acNum(r->fl "%.4g") acNum(r->fh "%.4g")
          acNum(r->pm "%.1f") acNum(r->zin "%.4g") acNum(r->margin "%.3f") or(r->worst "") acNum(r->a0 "%.4g")
          acNum(r->a0r "%.4g")
          acNum(and(r->groups r->sumTotal 100.0 * car(r->groups->inpair) / r->sumTotal) "%.1f")
          acNum(and(r->groups r->sumTotal 100.0 * car(r->groups->mirror) / r->sumTotal) "%.1f"))
    r
  )
)

;; bounded VCP/VCN rescue in the OL (follower) tb: returns a point or nil
procedure( nsRescue(p)
  let( (best c q)
    ece203Setup(nsOl "_nsrb")
    analysis('dc ?saveOppoint t)
    foreach(dp nsCfg->dVcp
      foreach(dn nsCfg->dVcn
        q = nsP(p->w p->l p->w78 p->l78 nsCfg->vcp + dp nsCfg->vcn + dn)
        c = car(errset(nsOpCheck(q) nil))
        when( c && caddr(c) && numberp(cadddr(c)) && abs(cadddr(c) - 0.9) < 0.02 && numberp(car(c))
          when( !best || car(c) > car(best) best = list(car(c) q)))))
    q = and(best cadr(best))
    acSay("ns rescue W %gu L %gu: %s\n" p->w * 1e6 p->l * 1e6
          if( q sprintf(nil "vcp %g vcn %g margin %.4g" q->vcp q->vcn car(best)) "no valid bias found"))
    q
  )
)

procedure( nsTag(p) sprintf(nil "w%g_l%g" p->w * 1e6 p->l * 1e6) )

procedure( nsAll()
  let( (port bk rows r p q base best rs sum spot conv m78 tag)
    unless( isDir(nsDir) createDir(nsDir) )
    nsBuild()
    port = outfile(strcat(nsDir "/ece203_ns_sweep.csv") "w")
    fprintf(port "%s\n" nsHeader)
    bk = outfile(strcat(nsDir "/ece203_noise_breakdown.csv") "w")
    fprintf(bk "tag,kind,freq_Hz,group,device,param,V2_out,pct_of_total\n")

    ;; ---- Stage 2 grid (the 20u/1u point doubles as the Stage-1 baseline) ----
    foreach(l nsCfg->lList
      foreach(w nsCfg->wList
        p = nsP(w l 1e-6 10e-6 nsCfg->vcp nsCfg->vcn)
        r = nsPoint(nsTag(p) "S2grid" p "fixed" bk)
        nsWriteRow(port r)
        rows = cons(r rows)
        when( w == nsCfg->w0 && l == nsCfg->l0 base = r)
        when( r->status == "badop"
          q = nsRescue(p)
          if( q then
            r = nsPoint(strcat(nsTag(p) "_rb") "S2grid" q "rebiased" bk)
            nsWriteRow(port r)
            rows = cons(r rows)
          else
            acSay("ns: %s could not be rebiased within the bounded scan\n" nsTag(p))))))

    ;; ---- Stage 1 extras on the baseline: spot breakdowns + convergence ----
    foreach(f nsCfg->spot
      ;; baseline was not the last run: rerun it so the noise result is the baseline's
      unless( spot nsClRun(base->p "w20_l1_spot") spot = t)
      sum = nsSummary(strcat(nsDir sprintf(nil "/w20_l1_summary_spot_%gHz.txt" f)) 'spot 0.1 250.0 f)
      nsWriteBreakdown(bk "w20_l1" "spot_V2_per_Hz" f sum))
    sum = nsSummary(strcat(nsDir "/w20_l1_summary_1m_100k.txt") 'integrated 1e-3 1e5)
    nsWriteBreakdown(bk "w20_l1" "integrated_1m_100kHz" 0.0 sum)

    ;; ---- Stage 3: mirror M7/M8 area x2, x4 at fixed W/L ratio (0.1) and fixed current ----
    foreach(a '((1.41e-6 14.1e-6 "m78x2") (2e-6 20e-6 "m78x4"))
      p = nsP(nsCfg->w0 nsCfg->l0 car(a) cadr(a) nsCfg->vcp nsCfg->vcn)
      r = nsPoint(strcat("w20_l1_" caddr(a)) "S3mirror" p "fixed" bk)
      nsWriteRow(port r)
      rows = cons(r rows))

    ;; best valid grid point (fixed or rebiased), then combined with the mirror x4 (labelled)
    foreach(x rows
      when( x->stage == "S2grid" && x->status == "ok" && numberp(x->rmsIn)
        when( !best || x->rmsIn < best->rmsIn best = x)))
    when( best
      acSay("ns: best grid point %s rms %.4g\n" best->tag best->rmsIn)
      p = best->p
      q = nsP(p->w p->l 2e-6 20e-6 p->vcp p->vcn)
      r = nsPoint(strcat(best->tag "_m78x4") "S3combo" q best->mode bk)
      nsWriteRow(port r)
      rows = cons(r rows))

    ;; ---- convergence: 50 points/decade noise on baseline and on the lowest-noise valid point ----
    foreach(x list(base car(sort(setof(y rows y->status == "ok" && numberp(y->rmsIn))
                                 lambda((a b) a->rmsIn < b->rmsIn))))
      when( x
        conv = nsClRun(x->p strcat(x->tag "_dec50") "50")
        acSay("ns convergence %s: rms(0.1-250) dec20 %s dec50 %s; rms in(1m-100k) dec20 %s dec50 %s\n" x->tag
              acNum(x->rmsIn "%.5g") acNum(conv->rmsIn "%.5g") acNum(x->rmsInFull "%.5g") acNum(conv->rmsInFull "%.5g"))
        rs = cons(list(x->tag x->rmsIn conv->rmsIn x->rmsInFull conv->rmsInFull) rs)))
    close(port)
    close(bk)
    port = outfile(strcat(nsDir "/ece203_ns_convergence.csv") "w")
    fprintf(port "tag,rms_in_0.1_250_dec20,rms_in_0.1_250_dec50,rms_in_1m_100k_dec20,rms_in_1m_100k_dec50\n")
    foreach(x rs fprintf(port "%s,%s,%s,%s,%s\n" car(x) nsN(nth(1 x)) nsN(nth(2 x)) nsN(nth(3 x)) nsN(nth(4 x))))
    close(port)
    ece203SaveNetlist(nsCl "ece203_nscl")
    acSay("ns: done, %d rows\n" length(rows))
    t
  )
)

;; ---- follow-up: bounded VCP/VCN rebias for points whose saturation margin went below 0
;; (Spectre still reports region 3 there, so nsAll's region check did not trigger a rescue).
;; Rows go to ece203_ns_rebias.csv (same columns); the fixed-bias rows in ece203_ns_sweep.csv stay.
nsRebiasPoints = list(
  list(80e-6 1e-6 1e-6 10e-6 "S2grid") list(160e-6 1e-6 1e-6 10e-6 "S2grid")
  list(160e-6 2e-6 1e-6 10e-6 "S2grid") list(160e-6 1e-6 2e-6 20e-6 "S3combo"))

procedure( nsRebiasAll()
  let( (port bk p q r tag)
    unless( isDir(nsDir) createDir(nsDir) )
    port = outfile(strcat(nsDir "/ece203_ns_rebias.csv") "w")
    fprintf(port "%s\n" nsHeader)
    bk = outfile(strcat(nsDir "/ece203_noise_breakdown_rebias.csv") "w")
    fprintf(bk "tag,kind,freq_Hz,group,device,param,V2_out,pct_of_total\n")
    foreach(x nsRebiasPoints
      p = nsP(nth(0 x) nth(1 x) nth(2 x) nth(3 x) nsCfg->vcp nsCfg->vcn)
      tag = strcat(nsTag(p) if( nth(2 x) == 2e-6 "_m78x4" "") "_rb")
      q = nsRescue(p)
      if( q then
        r = nsPoint(tag nth(4 x) q "rebiased" bk)
        nsWriteRow(port r)
      else
        fprintf(port "%s,%s,%g,%g,%g,%g,%g,rebiased,,,no_bias_found,bounded scan found no valid bias,\n"
                tag nth(4 x) p->w * 1e6 p->l * 1e6 p->w * p->l * 1e12 p->w78 * 1e6 p->l78 * 1e6)))
    close(port)
    close(bk)
    t
  )
)
