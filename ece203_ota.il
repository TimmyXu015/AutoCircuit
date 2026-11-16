;; ece203_ota.il -- ECE203 ECG project, Tracks A and B: transistor-level OTAs (IBM cmrf7sf).
;; All sizes below are FIRST GUESSES for characterisation, not a verified design.
;;
;; ece203_a3_ota  (A3, 5T): pins INP INN OUT VDD GND IBIAS
;;   NMOS input pair M1 (INP, diode side) / M2 (INN, output side), PMOS mirror load M3 (diode) / M4,
;;   NMOS tail MT mirrored from diode MREF. Testbench pushes ib3 INTO IBIAS (from VDD).
;;   INP is the non-inverting input.
;; ece203_a12_ota (A1/A2, PMOS-input telescopic cascode, single-ended): pins INP INN OUT VDD GND
;;   IBIAS VCP VCN
;;   PMOS tail M0 mirrored from diode MREF (testbench SINKS ib12 out of IBIAS), PMOS pair M1 (INP) /
;;   M2 (INN), PMOS cascodes M3/M4 (gate VCP), NMOS cascode mirror M5/M6 (gate VCN) on top of
;;   M7/M8 (gates at n1 = drain of M5: low-voltage cascode mirror). Output at M4/M6.
;;   VCP, VCN come from ideal testbench sources (final bias generator is out of Round-1 scope).
;;
;; Jobs:
;;   ece203_a3      build cell + ece203_a3_ol_tb + ece203_a3_cl_tb; OP, A0, GBW, PM, noise, CM range,
;;                  x4 closed loop (stb), output swing
;;   ece203_a12bias build cell + ece203_a12_ol_tb, scan VCP/VCN for the largest saturation margin
;;                  -> ~/AutoCircuit_results/ece203_a12_bias.txt
;;   ece203_a12     OL characterisation + closed loop with ece203_hp_fb (ece203_hp_real_tb)

;; ---------------- A3 ----------------
a3Cell = "ece203_a3_ota"
a3OlTb = "ece203_a3_ol_tb"
a3ClTb = "ece203_a3_cl_tb"
a3Cfg = list(nil
  ;; (dev name W L D G S B)
  'devs list(
    list("pfetx" "M3" 2e-6 4e-6 "n1" "n1" "VDD" "VDD")
    list("pfetx" "M4" 2e-6 4e-6 "OUT" "n1" "VDD" "VDD")
    list("nfetx" "M1" 10e-6 1e-6 "n1" "INP" "tail" "GND")
    list("nfetx" "M2" 10e-6 1e-6 "OUT" "INN" "tail" "GND")
    list("nfetx" "MT" 8e-6 4e-6 "tail" "IBIAS" "GND" "GND")
    list("nfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "GND" "GND"))
  'pins '(("INP" "input") ("INN" "input") ("OUT" "output") ("VDD" "inputOutput") ("GND" "inputOutput") ("IBIAS" "inputOutput"))
  'vars list(list("vdd" 1.8) list("vcm" 0.9) list("vref" 0.9) list("vd" 0.0) list("ib3" 50e-9)
             list("rbig" 1e12) list("cbig" 1.0) list("rlp" 3.18e6) list("clp" 200e-12)
             list("r1" 1e6) list("r2" 4e6))
  'rCases list(list(1e6 4e6) list(100e6 400e6))
  'insts '("XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.MT" "XA.MREF"))

;; ---------------- A1/A2 ----------------
a12Cell = "ece203_a12_ota"
a12OlTb = "ece203_a12_ol_tb"
a12ClTb = "ece203_hp_real_tb"
a12Cfg = list(nil
  'devs list(
    list("pfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "VDD" "VDD")
    list("pfetx" "M0" 12e-6 4e-6 "tail" "IBIAS" "VDD" "VDD")
    list("pfetx" "M1" 20e-6 1e-6 "d1" "INP" "tail" "tail")
    list("pfetx" "M2" 20e-6 1e-6 "d2" "INN" "tail" "tail")
    list("pfetx" "M3" 4e-6 0.5e-6 "n1" "VCP" "d1" "d1")
    list("pfetx" "M4" 4e-6 0.5e-6 "OUT" "VCP" "d2" "d2")
    list("nfetx" "M5" 2e-6 1e-6 "n1" "VCN" "x1" "GND")
    list("nfetx" "M6" 2e-6 1e-6 "OUT" "VCN" "x2" "GND")
    list("nfetx" "M7" 1e-6 10e-6 "x1" "n1" "GND" "GND")
    list("nfetx" "M8" 1e-6 10e-6 "x2" "n1" "GND" "GND"))
  'pins '(("INP" "input") ("INN" "input") ("OUT" "output") ("VDD" "inputOutput") ("GND" "inputOutput")
          ("IBIAS" "inputOutput") ("VCP" "input") ("VCN" "input"))
  'vars list(list("vdd" 1.8) list("vcm" 0.9) list("vref" 0.9) list("ib12" 100e-9)
             list("vcp" 0.55) list("vcn" 0.65) list("rbig" 1e12) list("cbig" 1.0)
             list("cl12" 5e-12) list("rl12" 1e15)
             list("cc" 100e-12) list("cf" 4e-12) list("rp" 398e9))
  'vcpList '(0.2 0.3 0.4 0.5 0.6 0.7 0.8) 'vcnList '(0.4 0.5 0.6 0.7 0.8 0.9 1.0)
  'insts '("XA.M0" "XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.M5" "XA.M6" "XA.M7" "XA.M8" "XA.MREF")
  'scanInsts '("XA.M0" "XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.M5" "XA.M6" "XA.M7" "XA.M8"))
a12BiasFile = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_a12_bias.txt")

;; ---------------- cell builder ----------------
procedure( otaBuild(cell cfg)
  let( (cv)
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv cfg->pins)
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) cfg->devs))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
  )
)

;; OTA instance spec: conns ((pin net) ...)
procedure( otaInst(cell conns) list(ece203Lib cell "XA" nil conns) )

procedure( otaV(name dc acm a b)
  list("analogLib" "vdc" name list(list("vdc" dc) list("acm" acm)) list(list("PLUS" a) list("MINUS" b)))
)
procedure( otaI(name dc a b)
  list("analogLib" "idc" name list(list("idc" dc) list("acm" "0")) list(list("PLUS" a) list("MINUS" b)))
)
procedure( otaR(name val a b) list("analogLib" "res" name list(list("r" val)) list(list("PLUS" a) list("MINUS" b))) )
procedure( otaC(name val a b) list("analogLib" "cap" name list(list("c" val)) list(list("PLUS" a) list("MINUS" b))) )
;; iprobe for stb; terminal names looked up at placement
procedure( otaProbe(a b)
  list("analogLib" "iprobe" "IPRB" nil list(list("PLUS" a) list("MINUS" b)))
)

procedure( otaTb(cell specs)
  let( (cv)
    cv = acOpenSch(ece203Lib cell)
    ece203Place(cv specs)
    ece203GndRef(cv list(-2.0 0.0))
    ece203Finish(cv ece203Lib cell)
  )
)

;; ---------------- shared measurements ----------------
;; open-loop run: dc op + ac + noise (input source /VINP); returns DPL
procedure( otaOlRun(cell tag cfg over insts)
  let( (res h ugf r idd)
    res = acResultsDir()
    ece203Setup(cell strcat("_" tag))
    save('i "/VDD/PLUS")
    analysis('dc ?saveOppoint t)
    analysis('ac ?start "1m" ?stop "100M" ?dec "10")
    analysis('noise ?start "1m" ?stop "100k" ?dec "10" ?p "/out" ?n "/gnd!" ?iprobe "/VINP")
    ece203Vars(cfg->vars)
    ece203Vars(over)
    run()
    h = car(errset(v("/out" ?result "ac") nil))
    unless( h error("%s: no ac result -- see the spectre log\n" tag) )
    ugf = car(errset(cross(db20(h) 0 1 "falling") nil))
    idd = car(errset(-1.0 * i("/VDD/PLUS" ?result "dcOp") nil))
    r = list(nil 'h h 'a0 ece203V(mag(h) 1e-3) 'a1 ece203V(mag(h) 1.0) 'ugf ugf
             'phUgf and(ugf ece203V(phase(h) ugf)) 'idd idd
             'vout car(errset(v("/out" ?result "dcOp") nil))
             'nin car(errset(getData("in" ?result "noise") nil))
             'nout car(errset(getData("out" ?result "noise") nil)))
    acSay("%s: V(out) %s V, I(VDD) %s A, |A(1mHz)| %s (%s dB), |A(1Hz)| %s, UGF %s Hz, phase(UGF) %s deg, in-noise @1/10/100 Hz %s %s %s V/rtHz\n"
          tag acNum(r->vout "%.5g") acNum(idd "%.5g") acNum(r->a0 "%.5g") acNum(ece203Db(r->a0) "%.2f")
          acNum(r->a1 "%.5g") acNum(ugf "%.5g") acNum(r->phUgf "%.2f")
          acNum(ece203V(r->nin 1.0) "%.4g") acNum(ece203V(r->nin 10.0) "%.4g") acNum(ece203V(r->nin 100.0) "%.4g"))
    when( insts ece203OpDump(strcat(res "/ece203_" tag "_op.csv") insts) )
    spsWriteWaves(strcat(res "/ece203_" tag "_ac.csv") "f_Hz,absA,A_dB,phase_deg" list(ece203Mag(h) and(h db20(h)) ece203Ph(h)))
    spsWriteWaves(strcat(res "/ece203_" tag "_noise.csv") "f_Hz,in_V_rtHz,out_V_rtHz" list(r->nin r->nout))
    r
  )
)

;; follower dc sweep of vcm -> CM range (open-loop tb is a unity follower at DC)
procedure( otaCmSweep(cell tag cfg over)
  let( (w)
    ece203Setup(cell strcat("_" tag "sw"))
    ece203Vars(cfg->vars)
    ece203Vars(over)
    analysis('dc ?param "vcm" ?start "0" ?stop "1.8" ?step "10m")
    run()
    w = car(errset(v("/out" ?result "dc") nil))
    spsWriteWaves(strcat(acResultsDir() "/ece203_" tag "_cmsweep.csv") "vcm_V,vout_V" list(w))
    w
  )
)

;; closed-loop stb: loop gain through /IPRB; returns (ugf phase_at_ugf PM lgWave phase_at_first_f)
;; Spectre's stb loopGain has phase +180 deg for plain negative feedback (the calculator's
;; phaseMargin() assumes 0 deg and returned PM - 180), so PM = phase(loopGain) at |loopGain| = 1.
;; Do NOT reference the phase at the lowest frequency: with the capacitive high-pass feedback
;; network the low-frequency loop phase is not 180 deg (that gave a wrong 104 deg for A1/A2).
procedure( otaStb()
  let( (lg ugf ph0 phu)
    lg = car(errset(getData("loopGain" ?result "stb") nil))
    ugf = and(lg car(errset(cross(db20(lg) 0 1 "falling") nil)))
    ph0 = and(lg car(errset(value(phase(lg) drGetElem(drGetWaveformXVec(lg) 0)) nil)))
    phu = and(ugf ece203V(phase(lg) ugf))
    ;; phase() wraps: a loop that starts at +180 can report e.g. -212 at the UGF (= +148)
    when( numberp(phu) && phu < 0.0 phu = phu + 360.0)
    list(ugf phu phu lg ph0)
  )
)

;; ---------------- A3 ----------------
procedure( a3Build()
  ece203LibInfo()
  otaBuild(a3Cell a3Cfg)
  otaTb(a3OlTb list(
    otaV("VDD" "vdd" "0" "vdd" "gnd!")
    otaI("IB" "ib3" "vdd" "ib")
    otaInst(a3Cell '(("INP" "inp") ("INN" "inn") ("OUT" "out") ("VDD" "vdd") ("GND" "gnd!") ("IBIAS" "ib")))
    otaV("VINP" "vcm" "1" "inp" "gnd!")
    otaR("RBIG" "rbig" "out" "inn")
    otaC("CBIG" "cbig" "inn" "gnd!")
    otaR("RLPL" "rlp" "out" "lpo")
    otaC("CLPL" "clp" "lpo" "gnd!")))
  otaTb(a3ClTb list(
    otaV("VDD" "vdd" "0" "vdd" "gnd!")
    otaI("IB" "ib3" "vdd" "ib")
    otaInst(a3Cell '(("INP" "p") ("INN" "n") ("OUT" "oa") ("VDD" "vdd") ("GND" "gnd!") ("IBIAS" "ib")))
    otaV("VREF" "vref" "0" "vref" "gnd!")
    otaV("VA" "vref-vd/2" "-0.5" "in1" "gnd!")
    otaV("VB" "vref+vd/2" "0.5" "in2" "gnd!")
    otaR("R1A" "r1" "in2" "p")
    otaR("R2A" "r2" "p" "vref")
    otaR("R1B" "r1" "in1" "n")
    otaR("R2B" "r2" "n" "o")
    otaProbe("oa" "o")
    otaR("RLPL" "rlp" "o" "lpo")
    otaC("CLPL" "clp" "lpo" "gnd!")))
  t
)

procedure( a3Sim()
  let( (ol res port rows h hl mid bw s w)
    res = acResultsDir()
    ol = otaOlRun(a3OlTb "a3ol" a3Cfg nil a3Cfg->insts)
    otaCmSweep(a3OlTb "a3ol" a3Cfg nil)
    ece203SaveNetlist(a3OlTb "ece203_a3ol")

    ;; x4 closed loop for each resistor pair
    foreach(rc a3Cfg->rCases
      ece203Setup(a3ClTb "_a3cl")
      analysis('dc ?saveOppoint t)
      analysis('ac ?start "1m" ?stop "100M" ?dec "10")
      analysis('stb ?start "1m" ?stop "100M" ?dec "10" ?probe "/IPRB")
      ece203Vars(a3Cfg->vars)
      ece203Vars(list(list("r1" car(rc)) list("r2" cadr(rc))))
      run()
      h = car(errset(v("/o" ?result "ac") nil))
      hl = car(errset(v("/lpo" ?result "ac") nil))
      mid = ece203V(mag(h) 10.0)
      bw = and(mid car(errset(cross(db20(h) ece203Db(mid) - 3.0 1 "falling") nil)))
      s = otaStb()
      acSay("a3cl r1 %g r2 %g: V(o) %s V, |Hcl(10Hz)| %s (ideal %g), -3dB BW at o %s Hz, |H(lpo) 250Hz| %s, loop UGF %s Hz, phase(UGF) %s deg, PM %s deg\n"
            car(rc) cadr(rc) acNum(car(errset(v("/o" ?result "dcOp") nil)) "%.5g") acNum(mid "%.5g")
            cadr(rc) / car(rc) acNum(bw "%.5g") acNum(ece203V(mag(hl) 250.0) "%.4g")
            acNum(car(s) "%.5g") acNum(cadr(s) "%.2f") acNum(caddr(s) "%.2f"))
      when( car(rc) == 1e6 ece203OpDump(strcat(res "/ece203_a3cl_op.csv") a3Cfg->insts) )
      spsWriteWaves(strcat(res sprintf(nil "/ece203_a3cl_r1_%g.csv" car(rc)))
                    "f_Hz,absHcl_o,absH_lpo,absLoopGain,phaseLoopGain_deg"
                    list(ece203Mag(h) ece203Mag(hl) ece203Mag(cadddr(s)) ece203Ph(cadddr(s))))
      rows = cons(list(car(rc) cadr(rc) mid bw s) rows))
    ece203SaveNetlist(a3ClTb "ece203_a3cl")

    ;; output swing: dc sweep of the differential input, both resistor pairs
    foreach(rc a3Cfg->rCases
      ece203Setup(a3ClTb "_a3sw")
      ece203Vars(a3Cfg->vars)
      ece203Vars(list(list("r1" car(rc)) list("r2" cadr(rc))))
      analysis('dc ?param "vd" ?start "-0.6" ?stop "0.6" ?step "5m")
      run()
      w = car(errset(v("/o" ?result "dc") nil))
      spsWriteWaves(strcat(res sprintf(nil "/ece203_a3sw_r1_%g.csv" car(rc))) "vd_V,vo_V" list(w)))

    port = outfile(strcat(res "/ece203_a3.txt") "w")
    fprintf(port "%s  %s  (first-guess sizes, ideal ib3 = %g A from VDD into IBIAS)\n" a3Cell getCurrentTime() 50e-9)
    fprintf(port "devices (dev name W L D G S B): %L\n" a3Cfg->devs)
    fprintf(port "open loop (unity DC feedback via rbig/cbig, load rlp + clp): V(out) %s V, I(VDD) %s A (includes ib3)\n"
            acNum(ol->vout "%.5g") acNum(ol->idd "%.5g"))
    fprintf(port "  |A(1mHz)| %s (%s dB), |A(1Hz)| %s, UGF %s Hz, phase(UGF) %s deg\n"
            acNum(ol->a0 "%.5g") acNum(ece203Db(ol->a0) "%.2f") acNum(ol->a1 "%.5g") acNum(ol->ugf "%.5g")
            acNum(ol->phUgf "%.2f"))
    fprintf(port "  input noise V/rtHz @0.1/1/10/100/1k Hz: %s %s %s %s %s\n"
            acNum(ece203V(ol->nin 0.1) "%.4g") acNum(ece203V(ol->nin 1.0) "%.4g") acNum(ece203V(ol->nin 10.0) "%.4g")
            acNum(ece203V(ol->nin 100.0) "%.4g") acNum(ece203V(ol->nin 1e3) "%.4g"))
    foreach(r reverse(rows)
      fprintf(port "x4 closed loop r1 %g r2 %g: |Hcl(10Hz)| %s, BW(-3dB at o) %s Hz, loop UGF %s Hz, phase(UGF) %s, PM %s deg\n"
              nth(0 r) nth(1 r) acNum(nth(2 r) "%.5g") acNum(nth(3 r) "%.5g")
              acNum(car(nth(4 r)) "%.5g") acNum(cadr(nth(4 r)) "%.2f") acNum(caddr(nth(4 r)) "%.2f")))
    close(port)
    t
  )
)

procedure( a3All() a3Build() a3Sim() t )

;; ---------------- A1/A2 ----------------
procedure( a12Bias()
  let( (port val)
    when( isFile(a12BiasFile)
      port = infile(a12BiasFile)
      gets(val port)
      close(port))
    if( val then
      mapcar(lambda((x) evalstring(x)) parseString(val))
    else
      list(0.55 0.65))
  )
)

procedure( a12OlSpecs()
  list(
    otaV("VDD" "vdd" "0" "vdd" "gnd!")
    otaI("IB" "ib12" "ib" "gnd!")
    otaV("VCP" "vcp" "0" "vcp" "gnd!")
    otaV("VCN" "vcn" "0" "vcn" "gnd!")
    otaInst(a12Cell '(("INP" "inp") ("INN" "inn") ("OUT" "out") ("VDD" "vdd") ("GND" "gnd!")
                      ("IBIAS" "ib") ("VCP" "vcp") ("VCN" "vcn")))
    otaV("VINP" "vcm" "1" "inp" "gnd!")
    otaR("RBIG" "rbig" "out" "inn")
    otaC("CBIG" "cbig" "inn" "gnd!")
    otaC("CL" "cl12" "out" "gnd!")
    otaR("RL" "rl12" "out" "vrl")
    otaV("VRL" "vcm" "0" "vrl" "gnd!"))
)

procedure( a12Build()
  ece203LibInfo()
  otaBuild(a12Cell a12Cfg)
  otaTb(a12OlTb a12OlSpecs())
  t
)

;; VCP/VCN scan in the open-loop (follower) tb: maximise the smallest saturation margin
procedure( a12Scan(vcps vcns)
  let( (best m port)
    ece203Setup(a12OlTb "_a12scan")
    analysis('dc ?saveOppoint t)
    port = outfile(strcat(acResultsDir() "/ece203_a12_scan.csv") "a")
    foreach(p vcps
      foreach(n vcns
        ece203Vars(a12Cfg->vars)
        ece203Vars(list(list("vcp" p) list("vcn" n)))
        run()
        m = ece203MinMargin(a12Cfg->scanInsts)
        fprintf(port "%g,%g,%s,%s,%s\n" p n acNum(car(m) "%.5g") cadr(m)
                acNum(car(errset(v("/out" ?result "dcOp") nil)) "%.5g"))
        when( !best || car(m) > car(best) best = list(car(m) p n cadr(m)))))
    close(port)
    acSay("a12 scan: best min margin %s V at vcp %g vcn %g (worst device %s)\n"
          acNum(car(best) "%.4g") cadr(best) caddr(best) cadddr(best))
    best
  )
)

procedure( a12BiasAll()
  let( (b1 b2 port d)
    a12Build()
    port = outfile(strcat(acResultsDir() "/ece203_a12_scan.csv") "w")
    fprintf(port "vcp,vcn,min_margin_V,worst_inst,vout_V\n")
    close(port)
    b1 = a12Scan(a12Cfg->vcpList a12Cfg->vcnList)
    d = '(-0.05 -0.025 0.0 0.025 0.05)
    b2 = a12Scan(mapcar(lambda((x) cadr(b1) + x) d) mapcar(lambda((x) caddr(b1) + x) d))
    port = outfile(a12BiasFile "w")
    fprintf(port "%.4f %.4f\n" cadr(b2) caddr(b2))
    close(port)
    acSay("a12 bias chosen: vcp %.4f vcn %.4f, min margin %s V (worst %s)\n" cadr(b2) caddr(b2)
          acNum(car(b2) "%.4g") cadddr(b2))
    t
  )
)

procedure( a12ClBuild()
  otaTb(a12ClTb list(
    otaV("VDD" "vdd" "0" "vdd" "gnd!")
    otaI("IB" "ib12" "ib" "gnd!")
    otaV("VCP" "vcp" "0" "vcp" "gnd!")
    otaV("VCN" "vcn" "0" "vcn" "gnd!")
    otaV("VREF" "vref" "0" "vref" "gnd!")
    otaV("VIN" "vref" "1" "vin" "gnd!")
    list(ece203Lib "ece203_hp_fb" "XFB" nil '(("VIN" "vin") ("SUM" "sum") ("VOUT" "o")))
    otaInst(a12Cell '(("INP" "vref") ("INN" "sum") ("OUT" "oa") ("VDD" "vdd") ("GND" "gnd!")
                      ("IBIAS" "ib") ("VCP" "vcp") ("VCN" "vcn")))
    otaProbe("oa" "o")
    otaC("CL" "cl12" "o" "gnd!")))
)

procedure( a12Sim()
  let( (res bias over ol olr cl h mid fl fh s port nin zin idd)
    res = acResultsDir()
    bias = a12Bias()
    over = list(list("vcp" car(bias)) list("vcn" cadr(bias)))
    acSay("a12: using vcp %g vcn %g\n" car(bias) cadr(bias))
    ol = otaOlRun(a12OlTb "a12ol" a12Cfg over a12Cfg->insts)
    ;; same, loaded by 1 MOhm to vcm (the input resistor of the A3 difference amplifier)
    olr = otaOlRun(a12OlTb "a12olR1M" a12Cfg append(over list(list("rl12" 1e6))) nil)
    otaCmSweep(a12OlTb "a12ol" a12Cfg over)
    ece203SaveNetlist(a12OlTb "ece203_a12ol")

    ;; closed loop with the real feedback network
    ece203Setup(a12ClTb "_a12cl")
    save('i "/VDD/PLUS" "/VIN/PLUS")
    analysis('dc ?saveOppoint t)
    analysis('ac ?start "1m" ?stop "1M" ?dec "20")
    analysis('stb ?start "1m" ?stop "100M" ?dec "10" ?probe "/IPRB")
    analysis('noise ?start "1m" ?stop "100k" ?dec "20" ?p "/o" ?n "/gnd!" ?iprobe "/VIN")
    ece203Vars(a12Cfg->vars)
    ece203Vars(over)
    run()
    h = car(errset(v("/o" ?result "ac") nil))
    mid = ece203V(mag(h) 100.0)
    fl = and(mid car(errset(cross(db20(h) ece203Db(mid) - 3.0 1 "rising") nil)))
    fh = and(mid car(errset(cross(db20(h) ece203Db(mid) - 3.0 1 "falling") nil)))
    s = otaStb()
    nin = car(errset(getData("in" ?result "noise") nil))
    acSay("a12cl: V(o) %s V(sum) %s V, I(VDD) %s A, |H(100Hz)| %s, phase %s, f_L %s Hz, f_H %s Hz, |Zin(10Hz)| %s, loop UGF %s Hz, phase(UGF) %s, PM %s deg, in-noise @1/10/100 Hz %s %s %s V/rtHz\n"
          acNum(car(errset(v("/o" ?result "dcOp") nil)) "%.5g") acNum(car(errset(v("/sum" ?result "dcOp") nil)) "%.5g")
          acNum(car(errset(-1.0 * i("/VDD/PLUS" ?result "dcOp") nil)) "%.5g")
          acNum(mid "%.5g") acNum(ece203V(phase(h) 100.0) "%.2f") acNum(fl "%.5g") acNum(fh "%.5g")
          acNum(car(errset(value(mag(v("/vin" ?result "ac") / i("/VIN/PLUS" ?result "ac")) 10.0) nil)) "%.5g")
          acNum(car(s) "%.5g") acNum(cadr(s) "%.2f") acNum(caddr(s) "%.2f")
          acNum(ece203V(nin 1.0) "%.4g") acNum(ece203V(nin 10.0) "%.4g") acNum(ece203V(nin 100.0) "%.4g"))
    zin = car(errset(value(mag(v("/vin" ?result "ac") / i("/VIN/PLUS" ?result "ac")) 10.0) nil))
    idd = car(errset(-1.0 * i("/VDD/PLUS" ?result "dcOp") nil))
    ece203OpDump(strcat(res "/ece203_a12cl_op.csv") a12Cfg->insts)
    spsWriteWaves(strcat(res "/ece203_a12cl_ac.csv") "f_Hz,absH,phase_deg" list(ece203Mag(h) ece203Ph(h)))
    spsWriteWaves(strcat(res "/ece203_a12cl_stb.csv") "f_Hz,absLoopGain,phaseLoopGain_deg"
                  list(ece203Mag(cadddr(s)) ece203Ph(cadddr(s))))
    spsWriteWaves(strcat(res "/ece203_a12cl_noise.csv") "f_Hz,in_V_rtHz,out_V_rtHz"
                  list(nin car(errset(getData("out" ?result "noise") nil))))
    ece203SaveNetlist(a12ClTb "ece203_a12cl")

    port = outfile(strcat(res "/ece203_a12.txt") "w")
    fprintf(port "%s  %s  (first-guess sizes; ideal ib12 = 100 nA sunk from IBIAS; ideal VCP/VCN)\n" a12Cell getCurrentTime())
    fprintf(port "devices (dev name W L D G S B): %L\n" a12Cfg->devs)
    fprintf(port "bias: vcp %g vcn %g (from ece203_a12bias scan if present)\n" car(bias) cadr(bias))
    fprintf(port "open loop (follower DC, CL %g F): V(out) %s V, I(VDD) %s A, |A(1mHz)| %s (%s dB), |A(1Hz)| %s, UGF %s Hz, phase(UGF) %s deg\n"
            5e-12 acNum(ol->vout "%.5g") acNum(ol->idd "%.5g") acNum(ol->a0 "%.5g") acNum(ece203Db(ol->a0) "%.2f")
            acNum(ol->a1 "%.5g") acNum(ol->ugf "%.5g") acNum(ol->phUgf "%.2f"))
    fprintf(port "open loop with 1 MOhm load to vcm: |A(1mHz)| %s (%s dB), UGF %s Hz\n"
            acNum(olr->a0 "%.5g") acNum(ece203Db(olr->a0) "%.2f") acNum(olr->ugf "%.5g"))
    fprintf(port "  OL input noise V/rtHz @0.1/1/10/100/1k Hz: %s %s %s %s %s\n"
            acNum(ece203V(ol->nin 0.1) "%.4g") acNum(ece203V(ol->nin 1.0) "%.4g") acNum(ece203V(ol->nin 10.0) "%.4g")
            acNum(ece203V(ol->nin 100.0) "%.4g") acNum(ece203V(ol->nin 1e3) "%.4g"))
    fprintf(port "closed loop (ece203_hp_real_tb, CL %g F): I(VDD) %s A, |Zin(10Hz)| %s ohm, |H(100Hz)| %s, f_L %s Hz, f_H %s Hz, loop UGF %s Hz, phase(UGF) %s, PM %s deg\n"
            5e-12 acNum(idd "%.5g") acNum(zin "%.5g") acNum(mid "%.5g") acNum(fl "%.5g") acNum(fh "%.5g") acNum(car(s) "%.5g") acNum(cadr(s) "%.2f") acNum(caddr(s) "%.2f"))
    fprintf(port "  CL input-referred noise V/rtHz @0.1/1/10/100 Hz: %s %s %s %s\n"
            acNum(ece203V(nin 0.1) "%.4g") acNum(ece203V(nin 1.0) "%.4g") acNum(ece203V(nin 10.0) "%.4g")
            acNum(ece203V(nin 100.0) "%.4g"))
    close(port)
    t
  )
)

procedure( a12All()
  a12Build()
  hpFbBuild()
  a12ClBuild()
  a12Sim()
  t
)
