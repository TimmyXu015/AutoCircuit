;; hw1_setup.il -- ECE 203 HW1: every place the homework needs Cadence, ready to play with.
;;
;; Cells in HW1_203 (new cells; the older p1_nfetx is left alone):
;;   p1_nmos    P1 a-f, h   nfetx 5u/1u   drain at vds, gate at vgs, source+bulk to gnd
;;   p1_pmos    P1 g        pfetx 5u/1u   source+bulk to gnd, drain at -vsd, gate at -vsg
;;                          (so the sweep variable vsg and all currents stay positive)
;;   p2_cs_amp  P2          common-source amp of the figure, L = 1.5u, W = wn, VBIAS = vbias
;;
;; Each cell gets a saved ADE L state (Session -> Load State -> Cellview):
;;   hw1_p1_nmos   DC sweep vgs 0..1.8 V (5 mV), vds = 1.8; outputs Ids, log10_Ids, gm_over_Id
;;   hw1_p1_pmos   DC sweep vsg 0..1.8 V (5 mV), vsd = 1.8; outputs Isd, log10_Isd, gm_over_Id
;;   hw1_p2_cs     DC operating point + AC 1 kHz..10 GHz; outputs Vout_dc, Id, gain/attenuation at 2 MHz, gain_dB
;;
;; Build + ADE states (needs a display; run.sh runs it on a virtual one):  ~/AutoCircuit/run.sh hw1setup
;; Helpers for the CIW after loading ac.il:
;;   hw1P1cFamily()           P1c: Ids vs VGS for VDS = 0.1 .. 1.8 V, plotted as a family (OCEAN)
;;   hw1P1cFamily(?pmos t)    same for the PMOS

hw1Lib = "HW1_203"

hw1Nmos = list(nil 'lib hw1Lib 'cell "p1_nmos" 'devLib "cmrf7sf" 'dev "nfetx" 'w "5u" 'l "1u"
               'vds 1.8 'vgsStart 0.0 'vgsStop 1.8 'vgsStep 0.005)
hw1Pmos = list(nil 'lib hw1Lib 'cell "p1_pmos" 'devLib "cmrf7sf" 'dev "pfetx" 'w "5u" 'l "1u"
               'vgsExpr "-vsg" 'vdsExpr "-vsd")

;; ---------- schematics ----------
procedure( hw1Build()
  p1aBuild(hw1Nmos)
  p1aBuild(hw1Pmos)
  csBuild(hw1Lib "p2_cs_amp" ?nW "wn" ?nL "1.5u")
  t
)

;; ---------- ADE L states ----------
;; Ids of the P1 test benches: current into the drain source's + terminal, sign removed
hw1IdExpr = "abs(getData(\"/VDS/PLUS\" ?result \"dc\"))"

procedure( hw1AdeP1(cfg var other otherVal state idName)
  let( (sess)
    sess = acAdeStart(cfg->lib cfg->cell)
    unless( sess error("No ADE session for %s\n" cfg->cell) )
    acAdeModels(sess "tt")
    acAdeVars(sess list(list(var "0") list(other otherVal)))
    acAdeAnalysis(sess 'dc
      list(list('saveOppoint t) list('designVar var) list('param var)
           list('start "0") list('stop "1.8") list('step "0.005"))
      list(list('sweep "design") list('rangeType "start")
           list('incrType "linear") list('stepTypeLin "step")))
    acAdeSaveCurrents(sess)
    acAdeOutput(acAdeSev idName hw1IdExpr)
    acAdeOutput(acAdeSev strcat("log10_" idName) strcat("log10(" hw1IdExpr ")"))
    ;; gm/Id straight from the definition: d(Id)/dV divided by Id
    acAdeOutput(acAdeSev "gm_over_Id" strcat("deriv(" hw1IdExpr ")/" hw1IdExpr))
    acAdeSave(sess cfg->lib cfg->cell state)
    sess
  )
)

procedure( hw1AdeP2()
  let( (sess)
    sess = acAdeStart(hw1Lib "p2_cs_amp")
    unless( sess error("No ADE session for p2_cs_amp\n") )
    acAdeModels(sess "tt")
    acAdeVars(sess list(list("vbias" "0.45") list("wn" "10u")))
    ;; DC operating point (no sweep) so OP values and Vout are available
    acAdeAnalysis(sess 'dc list(list('saveOppoint t)))
    ;; AC 1 kHz .. 10 GHz, 20 points per decade
    acAdeAnalysis(sess 'ac
      list(list('start "1k") list('stop "10G") list('dec "20"))
      list(list('sweep "freq") list('rangeType "start")
           list('incrType "log") list('stepTypeLog "decade")))
    acAdeOutput(acAdeSev "Vout_dc" "VDC(\"/vout\")")
    acAdeOutput(acAdeSev "Id" "(2 - VDC(\"/vout\"))/100e3")
    acAdeOutput(acAdeSev "gain_2MHz" "value(mag(VF(\"/vout\")) 2e6)")
    acAdeOutput(acAdeSev "atten_vg_2MHz" "value(mag(VF(\"/vg\")) 2e6)")
    acAdeOutput(acAdeSev "gain_dB" "db20(VF(\"/vout\"))")
    acAdeSave(sess hw1Lib "p2_cs_amp" "hw1_p2_cs")
    sess
  )
)

procedure( hw1Ade()
  hw1AdeP1(hw1Nmos "vgs" "vds" "1.8" "hw1_p1_nmos" "Ids")
  hw1AdeP1(hw1Pmos "vsg" "vsd" "1.8" "hw1_p1_pmos" "Isd")
  hw1AdeP2()
  t
)

;; ---------- quick checks with OCEAN (independent of ADE) ----------
procedure( hw1CheckP1(cfg var other)
  let( (w v1 v2)
    acSimSetup(cfg->lib cfg->cell)
    desVar(var 0)
    desVar(other 1.8)
    save('i "/VDS/PLUS")
    analysis('dc ?param var ?start "0" ?stop "1.8" ?step "0.01")
    run()
    w = car(errset(abs(i("/VDS/PLUS" ?result "dc")) nil))
    v1 = car(errset(value(w 0.0) nil))
    v2 = car(errset(value(w 1.8) nil))
    acSay("check %s: |Id| at %s = 0: %s A, at 1.8 V: %s A\n" cfg->cell var acNum(v1) acNum(v2))
    list(v1 v2)
  )
)

procedure( hw1CheckP2()
  let( (vout g)
    acSimSetup(hw1Lib "p2_cs_amp")
    desVar("vbias" 0.45)
    desVar("wn" 10e-6)
    analysis('dc ?saveOppoint t)
    analysis('ac ?start "1k" ?stop "10G" ?dec "20")
    run()
    vout = car(errset(v("/vout" ?result "dcOp") nil))
    g = car(errset(value(mag(v("/vout" ?result "ac")) 2e6) nil))
    acSay("check p2_cs_amp (vbias 0.45, W 10u): Vout = %s V, Id = %s A, |vout/vin| @ 2 MHz = %s\n"
          acNum(vout) if( numberp(vout) acNum((2.0 - vout) / 100e3) "n/a") acNum(g))
  )
)

procedure( hw1Check()
  hw1CheckP1(hw1Nmos "vgs" "vds")
  hw1CheckP1(hw1Pmos "vsg" "vsd")
  hw1CheckP2()
  t
)

;; everything: schematics, OCEAN checks, then ADE states (ADE needs a display)
procedure( hw1Setup()
  hw1Build()
  hw1Check()
  if( hiGraphicMode() then hw1Ade()
  else acSay("hw1: no display -- schematics built, ADE states skipped\n"))
  t
)

;; ---------- P1c helper: Ids vs VGS for several VDS (OCEAN parametric) ----------
procedure( hw1P1cFamily(@key (pmos nil) (vdsList '(0.1 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8)))
  let( (cfg var other)
    cfg   = if( pmos hw1Pmos hw1Nmos)
    var   = if( pmos "vsg" "vgs")
    other = if( pmos "vsd" "vds")
    acSimSetup(cfg->lib cfg->cell)
    desVar(var 0)
    desVar(other 1.8)
    save('i "/VDS/PLUS")
    analysis('dc ?param var ?start "0" ?stop "1.8" ?step "0.005")
    paramAnalysis(other ?values vdsList)
    paramRun()
    when( hiGraphicMode()
      newWindow()
      plot(log10(abs(i("/VDS/PLUS" ?result "dc"))) ?expr list("log10(|Id|) family")))
    acSay("P1c family done for %s, %s = %L\n" cfg->cell other vdsList)
    t
  )
)
