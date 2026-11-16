;; ece203_ss_chop.il -- ECE203 Round 3D: 1 MHz ideal-clock / ideal-switch chopper around the single-stage S2 BioAmp.
;; Work order: docs/ECE203_round3d_ideal_chopper_ceiling_microtest.md.

;; probe analogLib pieces used here (symbol pins + CDF parameter names/defaults)
procedure( chProbe()
  foreach(c '("switch" "vpulse" "vcvs" "relay")
    let( (m cdf)
      m = dbOpenCellViewByType("analogLib" c "symbol")
      if( m then
        foreach(tm m~>terminals
          acSay("chp: analogLib/%s pin %s at %L\n" c tm~>name mapcar(lambda((p) centerBox(p~>fig~>bBox)) tm~>pins)))
      else acSay("chp: no analogLib/%s symbol\n" c))
      cdf = car(errset(cdfGetBaseCellCDF(ddGetObj("analogLib" c)) nil))
      when( cdf
        foreach(p cdf~>parameters
          acSay("chp: analogLib/%s CDF %s (%s) default %L\n" c p~>name p~>prompt p~>defValue)))))
  t
)

;; ---------------- testbenches ----------------
;; Clock: VCK1 / VCK2 two-phase NON-overlapping vpulse 0/1.8 V, per 1u, edges 1n, 10 ns dead time (phase 1 first 0.5u). chen = 0 freezes
;; phase 1 (static, unchopped bench with the same parts). Switches: analogLib switch, closed above vt2 = 1.0 V,
;; open below vt1 = 0.8 V, rc = 1 Ohm, ro = 1e20 Ohm (>> Rfb 3.18 TOhm; thermal noise of rc/ro not studied).
;; Input commutator (around the whole OTA): phase 1 p->INP, n->INN; phase 2 n->INP, p->INN.
;; Output demodulator: phase 1 o <- oa; phase 2 o <- oinv = 2 vref - oa (EINV: ideal, noiseless,
;; NON-PHYSICAL unity inverter around VREF). Feedback (CFN||RFN) returns from o, i.e. after demodulation.
;; Input: 1 mV differential step at tst (vpulse), before the coupling capacitors. S2 network unchanged.
chCells = list(nil 'ideal "ece203_ss_chop_ideal_tb" 'real "ece203_ss_chop_c_tb")
chDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_ss_chop")

procedure( chSw(name a b ck)
  list("analogLib" "switch" name
       list(list("vt1" "0.8") list("vt2" "1.0") list("ro" "1e20") list("rc" "1"))
       list(list("N+" a) list("N-" b) list("NC+" ck) list("NC-" "gnd!")))
)
procedure( chPulse(name v1 v2 td pw per a)
  list("analogLib" "vpulse" name
       list(list("dc" v1) list("v1" v1) list("v2" v2) list("td" td) list("tr" "1n") list("tf" "1n")
            list("pw" pw) list("per" per) list("acm" "0"))
       list(list("PLUS" a) list("MINUS" "gnd!")))
)

procedure( chSpecs(real)
  append(
    list(ldV("VREF" "vref" "0" "vref" "gnd!")
         chPulse("VINP" "vref" "vref+vst/2" "tst" "1" "2" "vinp")
         chPulse("VINN" "vref" "vref-vst/2" "tst" "1" "2" "vinn")
         ;; non-overlapping (break-before-make): ck1 low 0.5u..1.0u, ck2 high 0.511u..0.990u -> 10 ns dead
         ;; time on each edge (fix after the first run: overlapping edges shorted p/n and the OTA inputs)
         chPulse("VCK1" "1.8" "1.8*(1-chen)" "0.5u" "0.499u" "1u" "ck1")
         chPulse("VCK2" "0" "1.8*chen" "0.51u" "0.479u" "1u" "ck2")
         otaC("CCP" "cc" "vinp" "p")  otaC("CCN" "cc" "vinn" "n")
         otaC("CFP" "cfb" "p" "vref") otaR("RFP" "rfb" "p" "vref")
         otaC("CFN" "cfb" "n" "o")    otaR("RFN" "rfb" "n" "o")
         chSw("S1P" "p" "ia" "ck1") chSw("S1N" "n" "ib_" "ck1")
         chSw("S2P" "n" "ia" "ck2") chSw("S2N" "p" "ib_" "ck2")
         ldE("EINV" "oa" "vref" "oinv" "vref" "-1")
         chSw("S3" "oa" "o" "ck1") chSw("S4" "oinv" "o" "ck2")
         otaC("CL" "cl" "o" "gnd!"))
    if( real
      list(ldV("VDD" "vdd" "0" "vdd" "gnd!")
           otaI("IB" "ib3" "vdd" "ib")
           otaV("VCAS" "vcas" "0" "vcas" "gnd!")
           list(ece203Lib "ece203_ss_ota_cmp_c_ota" "XA" nil
                '(("INP" "ia") ("INN" "ib_") ("OUT" "oa") ("VDD" "vdd") ("GND" "gnd!") ("IBIAS" "ib") ("VCAS" "vcas"))))
      list(ldE("E1" "ia" "ib_" "oa" "gnd!" "aol"))))
)

procedure( chBuild()
  ece203LibInfo()
  otaTb(chCells->ideal chSpecs(nil))
  otaTb(chCells->real chSpecs(t))
  t
)

chCols = '(case cell chen status reason o_pre o_post step_gain o_ripple_pp_post oa_min_post oa_max_post
  ia_minus_ib_pp_post dc_o dc_oa dc_n dc_p I_VDD)

procedure( chAvg(w a b) car(errset(average(clip(w a b)) nil)) )
procedure( chPp(w a b) car(errset(ymax(clip(w a b)) - ymin(clip(w a b)) nil)) )

procedure( chRun(port name cell chen real)
  let( (r ok o oa d)
    r = list(nil 'case name 'cell cell 'chen chen 'status "ok")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" name))
        car(errset(option('gmin "1e-18" 'iabstol "1e-18" 'reltol "1e-6") t))
        analysis('dc ?saveOppoint t)
        analysis('tran ?stop "200u" ?maxstep "5n")
        when( real car(errset(save('i "/VDD/PLUS") nil)))
        ece203Vars(ssCfg->vars) ece203Vars(lsS2)
        ece203Vars(list(list("vst" 1e-3) list("tst" 50e-6) list("chen" chen) list("vcas" 1.05)))
        run()
        foreach(n '("o" "oa" "n" "p") putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        when( real r->I_VDD = ldIdc("/VDD/PLUS"))
        o = car(errset(v("/o" ?result "tran") nil))
        oa = car(errset(v("/oa" ?result "tran") nil))
        d = car(errset(v("/ia" ?result "tran") - v("/ib_" ?result "tran") nil))
        unless( o error("no tran result"))
        ;; averages over whole clock periods: 10 periods before the step, the last 10 periods
        r->o_pre = chAvg(o 40e-6 50e-6) r->o_post = chAvg(o 190e-6 200e-6)
        r->step_gain = and(numberp(r->o_pre) numberp(r->o_post) (r->o_post - r->o_pre) / 1e-3)
        r->o_ripple_pp_post = chPp(o 190e-6 200e-6)
        r->oa_min_post = car(errset(ymin(clip(oa 190e-6 200e-6)) nil))
        r->oa_max_post = car(errset(ymax(clip(oa 190e-6 200e-6)) nil))
        r->ia_minus_ib_pp_post = chPp(d 190e-6 200e-6)
        spsWriteWaves(strcat(chDir "/" name "_tran.csv") "t_s,o_V,oa_V,ia_minus_ib_V,ck1_V"
                      list(o oa d car(errset(v("/ck1" ?result "tran") nil))))
        ece203SaveNetlist(cell strcat("ece203_chop_" name))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("chop %s: %s %s | o pre %s post %s -> step gain %s | ripple pp %s | oa %s..%s | ia-ib pp %s | DC o %s oa %s n %s p %s | I %s\n"
          name r->status or(r->reason "") acNum(r->o_pre "%.6g") acNum(r->o_post "%.6g") acNum(r->step_gain "%.4g")
          acNum(r->o_ripple_pp_post "%.4g") acNum(r->oa_min_post "%.4g") acNum(r->oa_max_post "%.4g")
          acNum(r->ia_minus_ib_pp_post "%.4g") acNum(r->dc_o "%.5g") acNum(r->dc_oa "%.5g") acNum(r->dc_n "%.5g")
          acNum(r->dc_p "%.5g") acNum(r->I_VDD "%.4g"))
    let( (x first)
      first = t
      foreach(c chCols
        x = get(r c)
        fprintf(port "%s%s" if( first "" ",")
                cond( (stringp(x) if( rexMatchp("," x) strcat("\"" x "\"") x)) (numberp(x) sprintf(nil "%.6g" float(x))) (t "n/a")))
        first = nil)
      fprintf(port "\n") drain(port))
    r
  )
)

procedure( chRunJob()
  let( (port)
    chBuild()
    unless( isDir(chDir) createDir(chDir) )
    port = outfile(strcat(chDir "/chop_summary.csv") "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString chCols) ","))
    chRun(port "A_ideal_vcvs_chop1MHz" chCells->ideal 1.0 nil)
    chRun(port "A_realC_chop1MHz" chCells->real 1.0 t)
    chRun(port "A_realC_static" chCells->real 0.0 t)
    close(port)
    t
  )
)
