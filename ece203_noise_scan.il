;; ece203_noise_scan.il -- ECE203 Round 2A: A1/A2 noise diagnosis and M1/M2 W/L sweep.
;; See docs/ECE203_round2_noise_scan.md. Round-1 cells are NOT touched.
;;
;; New cells (library Project):
;;   ece203_a12n_ota    same devices and nets as ece203_a12_ota (a12Cfg->devs), except that the input
;;                      pair M1/M2 has W = w12in, L = l12in (design variables; default 20u / 1u)
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
           if( member(cadr(d) '("M1" "M2"))
             then nsFetSpecVar(nth(0 d) nth(1 d) "w12in" "l12in" nth(4 d) nth(5 d) nth(6 d) nth(7 d))
             else apply('ece203FetSpec d)))
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

;; design variables of one point
procedure( nsVars(w l vcp vcn)
  ece203Vars(a12Cfg->vars)
  ece203Vars(list(list("w12in" w) list("l12in" l) list("vcp" vcp) list("vcn" vcn)))
)

;; sqrt( integral of PSD^2 from a to b ), PSD in V/rtHz
procedure( nsRms(w a b)
  let( (x)
    x = and(w car(errset(integ(w * w a b) nil)))
    and(numberp(x) x >= 0 sqrt(x))
  )
)

;; closed-loop run (dc op + ac + stb + noise) of one point; returns DPL
procedure( nsClRun(w l vcp vcn tag @optional (dec nil))
  let( (h mid fl fh s nin nout zin idd r)
    ece203Setup(nsCl strcat("_" tag))
    save('i "/VDD/PLUS" "/VIN/PLUS")
    analysis('dc ?saveOppoint t)
    analysis('ac ?start "1m" ?stop "1M" ?dec nsCfg->acDec)
    analysis('stb ?start "1m" ?stop "100M" ?dec "10" ?probe "/IPRB")
    analysis('noise ?start "1m" ?stop "100k" ?dec or(dec nsCfg->noiseDec) ?p "/o" ?n "/gnd!" ?iprobe "/VIN")
    nsVars(w l vcp vcn)
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
procedure( nsOlRun(w l vcp vcn tag)
  let( (res h)
    ece203Setup(nsOl strcat("_" tag "ol"))
    analysis('ac ?start "1m" ?stop "100M" ?dec "10")
    foreach(rl '(1e15 1e6)
      nsVars(w l vcp vcn)
      desVar("rl12" rl)
      run()
      h = car(errset(v("/out" ?result "ac") nil))
      res = append(res list(list(ece203V(mag(h) 1e-3) and(h car(errset(cross(db20(h) 0 1 "falling") nil)))))))
    res
  )
)

;; DC-only check of a bias point in the OL (follower) tb: (minMargin worstInst allRegionsOk vout)
procedure( nsOpCheck(w l vcp vcn)
  let( (rows ok m vout)
    nsVars(w l vcp vcn)
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
    r = nsClRun(nsCfg->w0 nsCfg->l0 nsCfg->vcp nsCfg->vcn "nsbase")
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
