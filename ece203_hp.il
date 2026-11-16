;; ece203_hp.il -- ECE203 ECG project, Track D step 1: the COMPLETE closed-loop ideal high-pass.
;;
;; Cell Project/ece203_hp_ideal_tb (testbench, golden reference -- keep it):
;;
;;                 +---- CF (cf) ----+
;;                 +---- RP (rp) ----+
;;   VIN --- CC (cc) --- sum --------+--- vout
;;                        |               |
;;           E1 vcvs: NC- = sum, NC+ = vref, out PLUS = vout, MINUS = gnd, gain = aol
;;   VREF: dc = vref (ideal testbench source, acm 0)   VIN: dc = vref, acm = 1 (AC input)
;;
;; Expected (design numbers, to be checked): midband H = -cc/cf = -25, f_L = 1/(2 pi rp cf) = 0.1 Hz,
;; |Zin(10 Hz)| ~ 1/(2 pi 10 cc) = 159 MOhm (sum is a virtual ground). The ideal VCVS has no pole,
;; so there is no upper corner here.
;;
;; Job (run.sh):  ece203_hp   build the schematic + OCEAN dc op + ac (1 mHz..10 kHz) at aol = 1e5,
;;                            then aol = 1e3/1e4/1e6 for finite-gain sensitivity
;; Outputs in ~/AutoCircuit_results:  ece203_hp.txt (summary), ece203_hp_ac.csv (curves, aol 1e5),
;;                                    ece203_hp_aol.csv (one row per aol), ece203_hp_netlist.scs

ece203Lib = "Project"
hpCell = "ece203_hp_ideal_tb"
hpCfg = list(nil 'vref 0.9 'aol 1e5 'cc 100e-12 'cf 4e-12 'rp 398e9
             'aolList '(1e3 1e4 1e6) 'fStart "1m" 'fStop "10k" 'dec "20" 'fMid 100.0 'fZin 10.0)

;; short labelled wire from a pin, pointing away from the instance centre (avoids touching
;; neighbouring pins); returns the far end
procedure( ece203Stub(cv inst term net @optional (len 0.375))
  let( (p c dx dy end)
    p = acPinPt(inst term)
    unless( p error("%s: no terminal %s\n" inst~>name term) )
    c = centerBox(inst~>bBox)
    dx = xCoord(p) - xCoord(c)
    dy = yCoord(p) - yCoord(c)
    end = if( abs(dx) >= abs(dy)
            then if( dx < 0 acLeft(p len) acRight(p len))
            else if( dy < 0 acDown(p len) acUp(p len)))
    acWire(cv p end net)
    end
  )
)

;; report the technology library of the project library (needed later for PDK cells; not changed here)
procedure( ece203LibInfo()
  let( (lib)
    lib = ddGetObj(ece203Lib)
    unless( lib error("Library %s not found in cds.lib\n" ece203Lib) )
    acSay("ece203: library %s at %s, tech library = %L\n" ece203Lib lib~>readPath
          car(errset(techGetTechLibName(lib) nil)))
    lib
  )
)

;; ---------- schematic ----------
procedure( hpBuild()
  let( (cv vin cc cf rp e1 vref pV pS pO p1 p2 ox terms)
    ece203LibInfo()
    cv = acOpenSch(ece203Lib hpCell)

    ;; forward path: vin -- CC -- sum
    cc = acPlace(cv "analogLib" "cap" "CC" "R90" "PLUS" list(1.0 0.0))
    acSetParam(cc "c" "cc")
    pV = list(0.0 0.0)
    acWire(cv acPinPt(cc "PLUS") pV "vin")
    pS = acRight(acPinPt(cc "MINUS") 0.75)
    acWire(cv acPinPt(cc "MINUS") pS "sum")

    ;; feedback: CF and RP in parallel from sum (left) to vout (right)
    cf = acPlace(cv "analogLib" "cap" "CF" "R90" "PLUS" acUp(pS 1.0))
    acSetParam(cf "c" "cf")
    rp = acPlace(cv "analogLib" "res" "RP" "R90" "PLUS" acUp(pS 2.0))
    acSetParam(rp "r" "rp")
    acWire(cv pS acPinPt(cf "PLUS"))
    acWire(cv acPinPt(cf "PLUS") acPinPt(rp "PLUS"))
    ox = max(xCoord(acPinPt(cf "MINUS")) xCoord(acPinPt(rp "MINUS"))) + 0.5
    p1 = list(ox yCoord(acPinPt(rp "MINUS")))
    p2 = list(ox yCoord(acPinPt(cf "MINUS")))
    pO = list(ox yCoord(pS))
    acWire(cv acPinPt(rp "MINUS") p1)
    acWire(cv p1 p2)
    acWire(cv acPinPt(cf "MINUS") p2)
    acWire(cv p2 pO "vout")
    acWire(cv pO acRight(pO 0.75) "vout")

    ;; input source: dc = vref (no dc across CC), AC magnitude 1
    vin = acPlace(cv "analogLib" "vdc" "VIN" "R0" "PLUS" acDown(pV 1.0))
    acSetParam(vin "vdc" "vref")
    acSetParam(vin "acm" "1")
    acWire(cv pV acPinPt(vin "PLUS"))
    acGnd(cv "GND1" acPinPt(vin "MINUS"))

    ;; ideal amplifier: vout = aol * (V(vref) - V(sum))
    e1 = acPlace(cv "analogLib" "vcvs" "E1" "R0" "PLUS" list(ox + 3.0 -2.5))
    terms = e1~>master~>terminals~>name
    acSay("hp: vcvs terminals %L\n" terms)
    acSetParam(e1 "egain" "aol")
    ece203Stub(cv e1 acTerm(e1 '("NC+" "NCP")) "vref")
    ece203Stub(cv e1 acTerm(e1 '("NC-" "NCM" "NCN")) "sum")
    ece203Stub(cv e1 "PLUS" "vout")
    acGnd(cv "GND2" acPinPt(e1 "MINUS"))

    ;; reference (ideal, testbench only)
    vref = acPlace(cv "analogLib" "vdc" "VREF" "R0" "PLUS" list(ox + 6.5 -1.5))
    acSetParam(vref "vdc" "vref")
    acDcOnly(vref)
    acWire(cv acPinPt(vref "PLUS") acUp(acPinPt(vref "PLUS") 0.375) "vref")
    acGnd(cv "GND3" acPinPt(vref "MINUS"))

    acFinish(cv ece203Lib hpCell)
    t
  )
)

;; ---------- simulation ----------
procedure( hpVars(aol)
  desVar("vref" hpCfg->vref)
  desVar("aol" aol)
  desVar("cc" hpCfg->cc)
  desVar("cf" hpCfg->cf)
  desVar("rp" hpCfg->rp)
)

;; run dc op + ac at one aol; returns (h zin) waveforms
procedure( hpRun(aol)
  hpVars(aol)
  run()
  list(car(errset(v("/vout" ?result "ac") nil))
       car(errset(v("/vin" ?result "ac") / (-1.0 * i("/VIN/PLUS" ?result "ac")) nil)))
)

;; midband gain, phase, f_L, |Zin(10 Hz)| of one run
procedure( hpMeasure(h zin)
  let( (mid ph fl z10)
    mid = car(errset(value(mag(h) hpCfg->fMid) nil))
    ph = car(errset(value(phase(h) hpCfg->fMid) nil))
    fl = car(errset(cross(db20(h) 20.0 * log(mid) / log(10.0) - 3.0 1 "rising") nil))
    z10 = car(errset(value(mag(zin) hpCfg->fZin) nil))
    list(nil 'mid mid 'ph ph 'fl fl 'z10 z10)
  )
)

procedure( hpSim()
  let( (res r h zin m port mg ph db zm sumDc voutDc vinDc dir nl rows)
    res = acResultsDir()
    acSimSetup(ece203Lib hpCell "tt" "_hp")
    analysis('dc ?saveOppoint t)
    analysis('ac ?start hpCfg->fStart ?stop hpCfg->fStop ?dec hpCfg->dec)
    acSay("hp: save VIN current -> %L\n" car(errset(save('i "/VIN/PLUS") t)))

    ;; nominal run
    r = hpRun(hpCfg->aol)
    h = car(r) zin = cadr(r)
    unless( h error("hp: no ac result for /vout -- see the spectre log\n") )
    sumDc = car(errset(v("/sum" ?result "dcOp") nil))
    voutDc = car(errset(v("/vout" ?result "dcOp") nil))
    vinDc = car(errset(v("/vin" ?result "dcOp") nil))
    m = hpMeasure(h zin)
    acSay("hp: DC op  V(vin) = %s  V(sum) = %s  V(vout) = %s V\n"
          acNum(vinDc "%.6g") acNum(sumDc "%.6g") acNum(voutDc "%.6g"))
    acSay("hp: aol %g: |H(%g Hz)| = %s (%s dB), phase %s deg, f_L(-3 dB) = %s Hz, |Zin(%g Hz)| = %s ohm\n"
          float(hpCfg->aol) hpCfg->fMid acNum(m->mid "%.5g") acNum(and(m->mid 20.0 * log(m->mid) / log(10.0)) "%.4f")
          acNum(m->ph "%.2f") acNum(m->fl "%.5g") hpCfg->fZin acNum(m->z10 "%.5g"))

    ;; curves of the nominal run
    mg = acWavePoints(mag(h))
    db = acWavePoints(db20(h))
    ph = acWavePoints(phase(h))
    zm = if( zin acWavePoints(mag(zin)) nil )
    port = outfile(strcat(res "/ece203_hp_ac.csv") "w")
    fprintf(port "f_Hz,absH,H_dB,phase_deg,absZin_ohm\n")
    for(k 0 length(mg) - 1
      fprintf(port "%g,%g,%g,%g,%s\n" car(nth(k mg)) cadr(nth(k mg)) cadr(nth(k db))
              cadr(nth(k ph)) if( zm acNum(cadr(nth(k zm)) "%g") "")))
    close(port)

    ;; netlist of this run (check that only VIN has mag=)
    dir = strcat(acSimDir(hpCell) "_hp")
    nl = strcat(res "/ece203_hp_netlist.scs")
    sh(sprintf(nil "f=$(find %s -name input.scs | head -1); [ -n \"$f\" ] && cp \"$f\" %s" dir nl))
    acSay("hp: netlist copied: %L; lines with mag=:\n" isFile(nl))
    when( isFile(nl)
      sh(sprintf(nil "grep -n 'mag=' %s | sed 's/^/AC>   /'" nl)))

    ;; finite-gain sensitivity
    rows = list(list(hpCfg->aol m))
    foreach(a hpCfg->aolList
      r = hpRun(a)
      m = hpMeasure(car(r) cadr(r))
      acSay("hp: aol %g: |H(%g Hz)| = %s, phase %s deg, f_L = %s Hz, |Zin(%g Hz)| = %s ohm\n"
            float(a) hpCfg->fMid acNum(m->mid "%.5g") acNum(m->ph "%.2f") acNum(m->fl "%.5g")
            hpCfg->fZin acNum(m->z10 "%.5g"))
      rows = cons(list(a m) rows))
    ;; sort is destructive: keep its result
    rows = sort(rows lambda((x y) car(x) < car(y)))
    port = outfile(strcat(res "/ece203_hp_aol.csv") "w")
    fprintf(port "aol,absH_mid,phase_mid_deg,fL_Hz,absZin10_ohm\n")
    foreach(row rows
      m = cadr(row)
      fprintf(port "%g,%s,%s,%s,%s\n" float(car(row)) acNum(m->mid "%.8g") acNum(m->ph "%.4f")
              acNum(m->fl "%.8g") acNum(m->z10 "%.8g")))
    close(port)
    hpVars(hpCfg->aol)

    ;; summary file
    port = outfile(strcat(res "/ece203_hp.txt") "w")
    fprintf(port "ece203_hp_ideal_tb  (Project library)  %s\n" getCurrentTime())
    fprintf(port "vars: vref %g  aol %g  cc %g  cf %g  rp %g\n" hpCfg->vref float(hpCfg->aol)
            hpCfg->cc hpCfg->cf hpCfg->rp)
    fprintf(port "DC op: V(vin) %s  V(sum) %s  V(vout) %s\n"
            acNum(vinDc "%.6g") acNum(sumDc "%.6g") acNum(voutDc "%.6g"))
    fprintf(port "%10s %12s %10s %12s %14s\n" "aol" "|H(100Hz)|" "ph(deg)" "f_L(Hz)" "|Zin(10Hz)|")
    foreach(row rows
      m = cadr(row)
      fprintf(port "%10g %12s %10s %12s %14s\n" float(car(row)) acNum(m->mid "%.6g")
              acNum(m->ph "%.3f") acNum(m->fl "%.6g") acNum(m->z10 "%.6g")))
    close(port)
    t
  )
)

procedure( hpAll()
  hpBuild()
  hpSim()
  t
)
