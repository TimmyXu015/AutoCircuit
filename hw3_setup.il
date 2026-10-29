;; hw3_setup.il -- ECE 203 HW3 Problem 2: noise of a common-source amplifier, in a NEW
;; library HW3_203 (HW1/HW2 libraries are not used or touched).
;;
;; Cell HW3_203/p2_cs_noise:
;;   vdd --- RL 50k --- vout --- CL 500f --- gnd
;;                       |
;;   vg --- M0 nfetx 50u/5u, source + bulk to gnd
;;   VIN: dc = vin, acm = 1 (AC input and the noise input source);  VDD: dc = vdd = 1.8
;;
;; ADE L states in p2_cs_noise (Session -> Load State -> Cellview):
;;   hw3_p2_vin_sweep  (part b)  dc sweep vin 0..1.8 V (1 mV); outputs Id = (1.8 - vout)/RL,
;;                               vin_at_15uA = cross(Id, 15 uA)
;;   hw3_p2_noise      (c-g)     vin = the value giving 15 uA; dc op + ac + noise, 0.1 Hz .. 1 GHz,
;;                               output noise at vout, input source /VIN; outputs: OP values,
;;                               gain_dB, out_noise, in_noise (V/sqrt(Hz))
;;                               Noise summary: Results -> Print -> Noise Summary
;;
;; Jobs (run.sh):  hw3build   (no GUI) library + schematic + VIN for 15 uA (OCEAN)
;;                 hw3ade     (@gui)   ADE L states (needs hw3build first)
;;                 hw3check   (no GUI) OCEAN noise run at the found vin -> CSVs for checking

hw3Lib  = "HW3_203"
hw3Cell = "p2_cs_noise"
hw3Cfg = list(nil 'w "50u" 'l "5u" 'wm 50e-6 'rl "50K" 'rlOhm 50e3 'cl "500f" 'vdd 1.8
              'idTarget 15e-6 'fStart "0.1" 'fStop "1G" 'dec "20")
hw3VinFile = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/hw3_vin.txt")

;; ---------- library ----------
;; new library next to the others (folder of HW2_203/HW1_203), technology from cmrf7sf
procedure( hw3MakeLib()
  let( (lib dir)
    lib = ddGetObj(hw3Lib)
    if( lib then
      acSay("hw3: library %s exists (%s)\n" hw3Lib lib~>readPath)
    else
      ;; run.sh starts Virtuoso in the course folder, where HW1_203/HW2_203 also live
      dir = strcat(getWorkingDir() "/" hw3Lib)
      lib = ddCreateLib(hw3Lib dir)
      acSay("hw3: ddCreateLib(%s %s) -> %L\n" hw3Lib dir lib)
      unless( lib error("hw3: could not create library %s\n" hw3Lib) ))
    ;; attach the PDK technology (what Library Manager's "attach to cmrf7sf" does)
    unless( car(errset(techGetTechLibName(lib) nil)) == "cmrf7sf"
      acSay("hw3: techSetTechLibName -> %L\n" car(errset(techSetTechLibName(lib "cmrf7sf") t))))
    acSay("hw3: %s tech library = %L, path %s\n" hw3Lib car(errset(techGetTechLibName(lib) nil))
          lib~>readPath)
    lib
  )
)

;; ---------- schematic ----------
procedure( hw3Build()
  let( (cv m0 tD tG tS pG pD pS n d vin rl pTop vdd cl others k)
    cv = acOpenSch(hw3Lib hw3Cell)
    m0 = acPlace(cv "cmrf7sf" "nfetx" "M0" "R0" "G" list(0.0 0.0))
    acSetParam(m0 "w" hw3Cfg->w)
    acSetParam(m0 "l" hw3Cfg->l)
    acSetParam(m0 "wt" hw3Cfg->w t)
    foreach(pv hw2DiffParams(hw3Cfg->wm) acSetParam(m0 car(pv) cadr(pv)))
    tD = acTerm(m0 '("D")) tG = acTerm(m0 '("G")) tS = acTerm(m0 '("S"))
    pG = acPinPt(m0 tG) pD = acPinPt(m0 tD) pS = acPinPt(m0 tS)

    ;; gate: VIN below a node to the left
    n = acLeft(pG 1.0)
    acWire(cv pG n "vg")
    vin = acPlace(cv "analogLib" "vdc" "VIN" "R0" "PLUS" acDown(n 0.5))
    acSetParam(vin "vdc" "vin")
    acSetParam(vin "acm" "1")
    acWire(cv n acPinPt(vin "PLUS"))
    acGnd(cv "GND1" acPinPt(vin "MINUS"))

    ;; drain: vout node, RL up to the vdd net, CL down to gnd
    d = acUp(pD 0.5)
    acWire(cv pD d "vout")
    rl = acPlace(cv "analogLib" "res" "RL" "R0" "MINUS" acUp(d 0.5))
    acSetParam(rl "r" hw3Cfg->rl)
    acWire(cv d acPinPt(rl "MINUS"))
    pTop = acUp(acPinPt(rl "PLUS") 0.25)
    acWire(cv acPinPt(rl "PLUS") pTop)
    vdd = acPlace(cv "analogLib" "vdc" "VDD" "R0" "PLUS" acRight(pTop 2.5))
    acSetParam(vdd "vdc" "vdd")
    acDcOnly(vdd)
    acWire(cv pTop acPinPt(vdd "PLUS") "vdd")
    acGnd(cv "GND2" acPinPt(vdd "MINUS"))
    cl = acPlace(cv "analogLib" "cap" "CL" "R0" "PLUS" acRight(d 1.25))
    acSetParam(cl "c" hw3Cfg->cl)
    acWire(cv d acPinPt(cl "PLUS"))
    acGnd(cv "GND3" acPinPt(cl "MINUS"))

    ;; source and bulk (and any other terminal) to ground
    acGnd(cv "GND4" pS)
    others = setof(tn m0~>master~>terminals~>name !member(tn list(tD tG tS)))
    k = 0
    foreach(tn others
      k++
      acGnd(cv sprintf(nil "GNDB%d" k) acPinPt(m0 tn)))
    acSubTie(cv acRight(acPinPt(vdd "PLUS") 1.5))
    acFinish(cv hw3Lib hw3Cell)
    m0
  )
)

;; ---------- part b: VIN for exactly 15 uA (OCEAN) ----------
procedure( hw3IdWave()
  (hw3Cfg->vdd - v("/vout" ?result "dc")) / hw3Cfg->rlOhm
)

procedure( hw3FindVin()
  let( (v1 v2 port idv)
    ;; coarse: 1 mV steps over the whole range
    acSimSetup(hw3Lib hw3Cell "tt" "_hw3")
    desVar("vdd" hw3Cfg->vdd) desVar("vin" 0)
    analysis('dc ?param "vin" ?start "0" ?stop "1.8" ?step "1m")
    run()
    v1 = car(errset(cross(hw3IdWave() hw3Cfg->idTarget 1 "rising") nil))
    acSay("hw3: coarse vin for 15 uA = %s V\n" acNum(v1 "%.5f"))
    unless( numberp(v1) error("hw3: Id never reaches 15 uA in 0..1.8 V\n") )
    ;; fine: 1 uV steps, +-2 mV around it
    analysis('dc ?param "vin" ?start sprintf(nil "%.6f" v1 - 0.002)
                  ?stop sprintf(nil "%.6f" v1 + 0.002) ?step "1u")
    run()
    v2 = car(errset(cross(hw3IdWave() hw3Cfg->idTarget 1 "rising") nil))
    ;; confirm with an operating point at that vin
    desVar("vin" v2)
    analysis('dc ?saveOppoint t)
    run()
    idv = car(errset((hw3Cfg->vdd - v("/vout" ?result "dcOp")) / hw3Cfg->rlOhm nil))
    acSay("hw3: vin for Id = 15 uA -> %s V (OP check: Id = %s A, vout = %s V)\n"
          acNum(v2 "%.6f") acNum(idv "%.6g") acNum(car(errset(v("/vout" ?result "dcOp") nil)) "%.5f"))
    port = outfile(hw3VinFile "w")
    fprintf(port "%.6f\n" v2)
    close(port)
    v2
  )
)

procedure( hw3Vin()
  let( (port val)
    when( isFile(hw3VinFile)
      port = infile(hw3VinFile)
      gets(val port)
      close(port))
    or(and(val evalstring(car(parseString(val)))) 0.5)
  )
)

procedure( hw3BuildAll()
  hw3MakeLib()
  hw3Build()
  hw3FindVin()
  t
)

;; ---------- ADE L ----------
;; print every field of an analysis with its value and choices (to learn this install's names)
procedure( hw3ProbeAnalysis(sess type)
  let( (ana names)
    ana = car(errset(asiGetAnalysis(sess type) nil))
    names = car(errset(asiGetAnalysisParamNameList(ana) nil))
    acSay("PROBE %L fields: %L\n" type names)
    foreach(f names
      acSay("PROBE %L.%L = %L  choices %L\n" type f
            car(errset(asiGetAnalysisFieldVal(ana f) nil))
            car(errset(asiGetAnalysisFieldChoices(ana f) nil))))
  )
)

procedure( hw3AdeSweep()
  let( (sess idExpr)
    sess = acAdeStart(hw3Lib hw3Cell)
    unless( sess error("No ADE session for %s\n" hw3Cell) )
    acAdeModels(sess "tt")
    acAdeVars(sess list(list("vin" "0") list("vdd" "1.8")))
    acAdeAnalysis(sess 'dc
      list(list('designVar "vin") list('param "vin")
           list('start "0") list('stop "1.8") list('step "1m"))
      list(list('sweep "design") list('rangeType "start")
           list('incrType "linear") list('stepTypeLin "step")))
    idExpr = "(1.8 - VS(\"/vout\")) / 50e3"
    acAdeOutput(acAdeSev "Id" idExpr)
    acAdeOutput(acAdeSev "vin_at_15uA" strcat("cross(" idExpr " 15e-6 1 \"rising\")"))
    acAdeSave(sess hw3Lib hw3Cell "hw3_p2_vin_sweep")
    sess
  )
)

procedure( hw3AdeNoise()
  let( (sess)
    sess = acAdeStart(hw3Lib hw3Cell)
    unless( sess error("No ADE session for %s\n" hw3Cell) )
    acAdeModels(sess "tt")
    acAdeVars(sess list(list("vin" sprintf(nil "%.6f" hw3Vin())) list("vdd" "1.8")))
    acAdeAnalysis(sess 'dc list(list('saveOppoint t)))
    acAdeAnalysis(sess 'ac
      list(list('start hw3Cfg->fStart) list('stop hw3Cfg->fStop) list('dec hw3Cfg->dec))
      list(list('sweep "freq") list('rangeType "start")
           list('incrType "log") list('stepTypeLog "decade")))
    ;; field names of this install (probed): outType voltage|probe, p/n output nodes,
    ;; inType voltage|current|port|none, inVsrc = the input voltage source
    acAdeAnalysis(sess 'noise
      list(list('start hw3Cfg->fStart) list('stop hw3Cfg->fStop) list('dec hw3Cfg->dec)
           list('p "/vout") list('n "/gnd!") list('inVsrc "/VIN") list('iprobe "/VIN"))
      list(list('sweep "freq") list('rangeType "start")
           list('incrType "log") list('stepTypeLog "decade")
           list('outType "voltage") list('inType "voltage")))
    foreach(p '(("Id" "id") ("gm" "gm") ("gds" "gds") ("region" "region") ("vgs" "vgs") ("vth" "vth"))
      acAdeOutput(acAdeSev car(p) sprintf(nil "OP(\"/M0\" \"%s\")" cadr(p))))
    acAdeOutput(acAdeSev "gain_dB" "db20(VF(\"/vout\"))")
    acAdeOutput(acAdeSev "out_noise" "getData(\"out\" ?result \"noise\")")
    acAdeOutput(acAdeSev "in_noise" "getData(\"in\" ?result \"noise\")")
    acAdeSave(sess hw3Lib hw3Cell "hw3_p2_noise")
    sess
  )
)

procedure( hw3Ade()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("hw3Ade needs the GUI (run.sh hw3ade)\n") )
  hw3AdeSweep()
  hw3AdeNoise()
  t
)

;; ---------- OCEAN noise check ----------
procedure( hw3Check()
  let( (vin res file)
    vin = hw3Vin()
    acSimSetup(hw3Lib hw3Cell "tt" "_hw3")
    desVar("vdd" hw3Cfg->vdd) desVar("vin" vin)
    analysis('dc ?saveOppoint t)
    analysis('ac ?start hw3Cfg->fStart ?stop hw3Cfg->fStop ?dec hw3Cfg->dec)
    analysis('noise ?start hw3Cfg->fStart ?stop hw3Cfg->fStop ?dec hw3Cfg->dec
             ?p "/vout" ?n "/gnd!" ?iprobe "/VIN")
    run()
    acSay("hw3 check: vin %s V, Id %s A, gm %s S, region %s, |gain| at 1 kHz %s\n" acNum(vin "%.6f")
          acNum(car(errset(pv("M0" "id" ?result "dcOpInfo") nil)))
          acNum(car(errset(pv("M0" "gm" ?result "dcOpInfo") nil)))
          spsNum(car(errset(pv("M0" "region" ?result "dcOpInfo") nil)))
          acNum(car(errset(value(mag(v("/vout" ?result "ac")) 1e3) nil))))
    res = list(car(errset(mag(v("/vout" ?result "ac")) nil))
               car(errset(getData("out" ?result "noise") nil))
               car(errset(getData("in" ?result "noise") nil)))
    acSay("hw3 check: waves gain %L out %L in %L\n" car(res) cadr(res) caddr(res))
    file = strcat(acResultsDir() "/hw3_noise.csv")
    spsWriteWaves(file "f_Hz,gain_mag,out_noise_V_rtHz,in_noise_V_rtHz" res)
    acSay("hw3 check: wrote %s\n" file)
    t
  )
)
