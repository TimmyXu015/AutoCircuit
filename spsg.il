;; spsg.il -- improved sub vs strong-inversion CS amp: signal straight into the gate
;;
;; Same transistors and bias as sps.il (nfet L = 1.5u, Id = 10 uA, RD = 100k, VDD = 2 V):
;;   cs_strong_gate   W = 0.75u   strong inversion
;;   cs_sub_gate      W = 400u    subthreshold
;; but without the HW coupling network (C0, RLARGE). The gate is driven directly:
;;
;;            VDD (2 V) -- RD (100k) --+-- vout --+
;;                                     |          |
;;   V0 --- RS (rs) --- vg --- gate   M0         CL (cl)
;;   (DC vbias + sine)                 |          |
;;                                    gnd        gnd
;;
;;   V0: vsin, DC and offset = vbias, amplitude = vamp, frequency = fin, AC magnitude 1
;;   RS = design variable rs (source resistance of whatever drives the gate)
;;   CL = design variable cl (load at the output)
;;
;; ADE L states in each cell (Session -> Load State -> Cellview), each = DC OP + AC 1 Hz..10 GHz
;; + tran at fin:
;;   A_ideal_100Hz / A_ideal_1MHz   rs = 1 ohm, cl = 0       transistor alone: gain, output pole
;;   B_rs_100Hz    / B_rs_1MHz      rs = 10k,   cl = 0       + input pole (Cgs + Miller Cgd)
;;   C_rs_cl_100Hz / C_rs_cl_1MHz   rs = 10k,   cl = 100f    + a realistic load
;;
;; Jobs:
;;   ~/AutoCircuit/run.sh spsg       build both cells, check they simulate (OCEAN, pass/fail only)
;;   ~/AutoCircuit/run.sh spsgade    @gui: save the ADE L states

spsgCfg = list(nil
  'circuits '(("cs_strong_gate" 0.75) ("cs_sub_gate" 400.0))   ; W in um, from the sps.il W scan
  ;; (label rs cl)
  'configs '(("A_ideal" "1" "0") ("B_rs" "10k" "0") ("C_rs_cl" "10k" "100f"))
  ;; (label fin tstop): 5 periods of 100 Hz, 10 periods of 1 MHz
  'fins '(("100Hz" "100" "50m") ("1MHz" "1M" "10u"))
)

;; ---------- schematic ----------
procedure( spsgBuild(lib cell wUm)
  let( (cv m0 pG pD pS rd pRDt vdd pCL cl n rs pRp v0)
    cv = acOpenSch(lib cell)

    ;; transistor, gate pin at the origin; W fixed, diffusion areas set for that W
    m0 = acPlace(cv acPdk->lib acPdk->nmos "M0" "R0" "G" list(0.0 0.0))
    acSetParam(m0 acPdk->nmosW sprintf(nil "%gu" wUm))
    acSetParam(m0 acPdk->nmosL spsCfg->l)
    foreach(pv spsDiffParams(wUm * 1e-6) acSetParam(m0 car(pv) cadr(pv)))
    pG = acPinPt(m0 "G")
    pD = acPinPt(m0 "D")
    pS = acPinPt(m0 "S")
    acGnd(cv "GND2" pS)

    ;; RD above the drain, 2 V supply to its right
    rd = acPlace(cv "analogLib" "res" "RD" "R0" "MINUS" acUp(pD 0.5))
    acSetParam(rd "r" "100K")
    acWire(cv pD acPinPt(rd "MINUS") "vout")
    pRDt = acPinPt(rd "PLUS")
    vdd = acPlace(cv "analogLib" "vdc" "VDD" "R0" "PLUS" acRight(pRDt 2.0))
    acSetParam(vdd "vdc" "2")
    acWire(cv pRDt acPinPt(vdd "PLUS") "vdd")
    acGnd(cv "GND1" acPinPt(vdd "MINUS"))

    ;; load capacitor from vout to ground, right of the drain
    pCL = acRight(pD 1.0)
    acWire(cv pD pCL)
    cl = acPlace(cv "analogLib" "cap" "CL" "R0" "PLUS" pCL)
    acSetParam(cl "c" "cl")
    acGnd(cv "GND5" acPinPt(cl "MINUS"))

    ;; gate: RS from the source on the left
    n = acLeft(pG 1.0)
    acWire(cv pG n "vg")
    rs = acPlace(cv "analogLib" "res" "RS" "R90" "MINUS" acLeft(n 0.5))
    acSetParam(rs "r" "rs")
    acWire(cv acPinPt(rs "MINUS") n)
    pRp = acPinPt(rs "PLUS")

    ;; signal source: DC = vbias (sets Id), sine on top, AC magnitude 1
    v0 = acPlace(cv "analogLib" "vsin" "V0" "R0" "PLUS" acDown(acLeft(pRp 1.0) 1.0))
    foreach(pv list(list("vdc" "vbias") list("vo" "vbias") list("va" "vamp")
                    list("freq" "fin") list("acm" "1"))
      acSetParam(v0 car(pv) cadr(pv)))
    acWire(cv pRp acPinPt(v0 "PLUS") "vin")
    acGnd(cv "GND4" acPinPt(v0 "MINUS"))

    acSubTie(cv acRight(acPinPt(vdd "PLUS") 1.5))
    acFinish(cv lib cell)
  )
)

;; ---------- job 1: build + check (no GUI) ----------
;; Builds both cells, finds VBIAS for 10 uA, and runs OP + AC + a short tran once in
;; configuration C so a broken netlist shows up here. Prints pass/fail only -- the
;; numbers are for the user to read in ADE L.
procedure( spsgRun()
  let( (cell vb ok vout g)
    foreach(c spsgCfg->circuits
      cell = car(c)
      spsgBuild(spsCfg->lib cell cadr(c))
      vb = spsFindVbias(cell)
      unless( numberp(vb) error("%s: no vbias for Id = 10 uA\n" cell) )
      spsSetup(cell nil vb 1e6)
      desVar("rs" 10e3)
      desVar("cl" 100e-15)
      analysis('dc ?saveOppoint t)
      analysis('ac ?start spsCfg->acStart ?stop spsCfg->acStop ?dec spsCfg->acDec)
      analysis('tran ?stop "2u")
      run()
      vout = car(errset(v("/vout" ?result "dcOp") nil))
      g    = car(errset(value(mag(v("/vout" ?result "ac")) 1.0) nil))
      ok = and(numberp(vout) abs(vout - 1.0) < 0.01 numberp(g) g > 1.0
               car(errset(v("/vout" ?result "tran") nil)))
      acSay("%s: W = %gu, vbias = %s V -> check %s\n" cell cadr(c) acNum(vb "%.5f")
            if( ok "PASS (Id = 10 uA, AC and tran ran)" "FAIL"))
      unless( ok error("%s: check failed\n" cell) ))
    t
  )
)

;; ---------- job 2: ADE L states (GUI) ----------
procedure( spsgAdeCell(cell)
  let( (vb sess)
    vb = spsFindVbias(cell)
    unless( numberp(vb) error("%s: no vbias\n" cell) )
    sess = acAdeStart(spsCfg->lib cell)
    unless( sess error("No ADE session for %s\n" cell) )
    acAdeModels(sess "tt")
    acAdeAnalysis(sess 'dc list(list('saveOppoint t)))
    acAdeAnalysis(sess 'ac
      list(list('start spsCfg->acStart) list('stop spsCfg->acStop) list('dec spsCfg->acDec))
      list(list('sweep "freq") list('rangeType "start")
           list('incrType "log") list('stepTypeLog "decade")))
    acAdeSaveCurrents(sess)
    ;; bias point and gm/Id (OP of the transistor)
    acAdeOutput(acAdeSev "Id"         "OP(\"/M0\" \"id\")")
    acAdeOutput(acAdeSev "gm"         "OP(\"/M0\" \"gm\")")
    acAdeOutput(acAdeSev "gm_over_Id" "OP(\"/M0\" \"gm\") / OP(\"/M0\" \"id\")")
    acAdeOutput(acAdeSev "Vov"        "OP(\"/M0\" \"vgs\") - OP(\"/M0\" \"vth\")")
    acAdeOutput(acAdeSev "region"     "OP(\"/M0\" \"region\")")
    acAdeOutput(acAdeSev "Vout_dc"    "VDC(\"/vout\")")
    ;; AC: vin is the source (before RS), vg the gate
    acAdeOutput(acAdeSev "gain_dB"    "db20(VF(\"/vout\"))")
    acAdeOutput(acAdeSev "vout_vg_dB" "db20(VF(\"/vout\") / VF(\"/vg\"))")
    acAdeOutput(acAdeSev "vg_vin_dB"  "db20(VF(\"/vg\"))")
    acAdeOutput(acAdeSev "gain_lowf"  "value(mag(VF(\"/vout\")) 1)")
    acAdeOutput(acAdeSev "f3dB"       "bandwidth(VF(\"/vout\") 3 \"low\")")
    acAdeOutput(acAdeSev "GBW"        "value(mag(VF(\"/vout\")) 1) * bandwidth(VF(\"/vout\") 3 \"low\")")
    acAdeOutput(acAdeSev "gain_at_fin" "value(mag(VF(\"/vout\")) VAR(\"fin\"))")
    acAdeOutput(acAdeSev "vin_tran"   "VT(\"/vin\")")
    acAdeOutput(acAdeSev "vout_tran"  "VT(\"/vout\")")
    foreach(cf spsgCfg->configs
      foreach(fc spsgCfg->fins
        acAdeVars(sess list(list("vbias" sprintf(nil "%.5f" vb))
                            list("vamp" sprintf(nil "%g" spsCfg->vamp))
                            list("fin" cadr(fc))
                            list("rs" cadr(cf))
                            list("cl" caddr(cf))))
        ;; only 'stop: maxstep is not settable from SKILL (see playbook)
        acAdeAnalysis(sess 'tran list(list('stop caddr(fc))))
        acAdeSave(sess spsCfg->lib cell strcat(car(cf) "_" car(fc)))))
    sess
  )
)

procedure( spsgAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("spsgAde needs a display (run.sh spsgade)\n") )
  foreach(c spsgCfg->circuits spsgAdeCell(car(c)))
  t
)
