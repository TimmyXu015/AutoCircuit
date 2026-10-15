;; sps.il -- self-practice: subthreshold vs strong-inversion common-source amp
;;
;; Circuit: the HW1 P2 CS amp (cs_amp.il) unchanged -- nfet L = 1.5u, RD = 100k, VDD = 2 V,
;; C0 = 100f, RLARGE = 1G, VBIAS = design variable vbias. Input V0 is a sine with
;; amplitude = design variable vamp and frequency = design variable fin (acm = 1 for AC).
;;
;; Fair comparison: both circuits are locked to the SAME drain current (Id = 10 uA,
;; so Vout_dc = 1 V); only W (and the VBIAS that gives 10 uA) differs:
;;   cs_strong  small W  -> large VGS - Vt -> strong inversion
;;   cs_sub     large W  -> VGS below Vt   -> subthreshold (weak inversion)
;;
;; Jobs (SSH):
;;   ~/AutoCircuit/run.sh spsscan   W scan at Id = 10 uA: VBIAS, gm, gm/Id, caps -> sps_wscan.csv
;;   ~/AutoCircuit/run.sh sps       build cs_strong + cs_sub, OP + AC + tran (100 Hz, 1 MHz) -> CSVs
;;   ~/AutoCircuit/run.sh spsade    @gui: ADE L states sps_100Hz and sps_1MHz in both cells
;; Outputs in ~/AutoCircuit_results/:
;;   sps_wscan.csv                         W_um, VBIAS, Id, gm, gm_over_Id, region, caps
;;   sps_op.csv                            one row per circuit: bias point and small-signal values
;;   sps_ac_<cell>.csv                     f, Re/Im of v(vout), v(vg) for vin = 1 (AC)
;;   sps_tran_<cell>_<100Hz|1MHz>.csv      t, vin, vg, vout
;; OCEAN results go to ~/simulation/<cell>/spectre/schematic_sps (ADE L's folder is untouched).

spsCfg = list(nil
  'lib "SelfPractice"
  'l "1.5u"
  'idTarget 10e-6  'rd 100e3  'vdd 2.0
  'vamp 1e-3                                  ; 1 mV: small-signal for both (sub needs << n*phi_t ~ 35 mV)
  'scanCell "sps_wscan"
  'scanWidths '(0.75 1.5 3.0 6.0 12.0 25.0 50.0 100.0 200.0 400.0 800.0)   ; um (floats)
  ;; (cell W) -- chosen from the W scan
  'circuits '(("cs_strong" 1.5) ("cs_sub" 400.0))     ; W in um
  ;; (label fin tstop maxstep): 5 periods of 100 Hz, 10 periods of 1 MHz
  'fins '(("100Hz" 100.0 "50m" "20u") ("1MHz" 1e6 "10u" "2n"))
  'acStart "1"  'acStop "10G"  'acDec "20"
)

;; small-signal OP parameters to read from the transistor (spectre BSIM3 names)
;; the PDK subckt adds wiring caps (M0.cw*) next to the intrinsic device: read their "c"
spsExtraParams = '(("M0.cwgs" "c") ("M0.cwgd" "c") ("M0.cwds" "c"))
spsOpParams = '("id" "ids" "gm" "gds" "gmbs" "vgs" "vds" "vth" "vdsat" "region"
                "cgg" "cgs" "cgd" "cgb" "cdd" "cdg" "cdb" "cbd" "cjd" "ft")

;; ---------- helpers ----------
;; acNum for anything: integers (e.g. region = 2) are turned into floats first
procedure( spsNum(x @optional (fmt "%.6g"))
  acNum(if( integerp(x) float(x) x) fmt)
)

;; drain/source diffusion of the nfet. The PDK's CDF callbacks fail outside a form, so
;; ad/as/pd/ps would stay at the defaults of a 0.43u device -- far too small for a wide
;; transistor (the junction caps at the drain set the bandwidth here). Set them the way
;; the PDK default does: diffusion length 0.54u, ad = W*0.54u, pd = 2*(W + 0.54u).
;; w is a number (m) or a design-variable name.
procedure( spsDiffParams(w)
  let( (ad pd)
    if( numberp(w) then
      ad = sprintf(nil "%g" w * 0.54e-6)
      pd = sprintf(nil "%g" 2.0 * (w + 0.54e-6))
    else
      ad = sprintf(nil "%s*0.54e-6" w)
      pd = sprintf(nil "2*(%s+0.54e-6)" w))
    list(list("ad" ad) list("as" ad) list("pd" pd) list("ps" pd))
  )
)

procedure( spsSetup(cell wn vbias fin)
  acSimSetup(spsCfg->lib cell "tt" "_sps")
  when( wn desVar("wn" wn) )
  desVar("vbias" vbias)
  desVar("vamp" spsCfg->vamp)
  desVar("fin" fin)
)

;; VBIAS that gives Id = idTarget (vout = vdd - Id*RD), by a fine DC sweep of vbias
procedure( spsFindVbias(cell @optional (wn nil))
  let( (vt vbx)
    vt = spsCfg->vdd - spsCfg->idTarget * spsCfg->rd
    spsSetup(cell wn 0.5 1e6)
    analysis('dc ?param "vbias" ?start "0" ?stop "1.5" ?step "0.5m")
    run()
    vbx = car(errset(cross(v("/vout" ?result "dc") vt 1 "falling") nil))
    acSay("%s: vbias for Id = %g A -> %s V\n" cell spsCfg->idTarget acNum(vbx "%.5f"))
    vbx
  )
)

;; instance names in the dcOpInfo results that belong to M0 (the PDK wraps nfet in a subckt)
procedure( spsM0Names()
  let( (names)
    names = car(errset(progn(selectResult('dcOpInfo) outputs()) nil))
    setof(n names stringp(n) && strncmp(upperCase(n) "M0" 2) == 0)
  )
)

;; OP at the given bias; returns a DPL param -> value plus 'inst and 'vout
procedure( spsOp(cell wn vbias)
  let( (cands inst res val)
    spsSetup(cell wn vbias 1e6)
    analysis('dc ?saveOppoint t)
    run()
    cands = spsM0Names()
    acSay("%s: dcOpInfo names starting with M0: %L\n" cell cands)
    acSay("%s: other dcOpInfo names: %L\n" cell
          setof(n car(errset(outputs() nil)) stringp(n) && !member(n cands)))
    cands = append(cands '("M0"))
    foreach(c cands
      unless( inst
        when( numberp(car(errset(pv(c "gm" ?result "dcOpInfo") nil)))
          inst = c)))
    res = list(nil 'inst inst)
    putprop(res car(errset(v("/vout" ?result "dcOp") nil)) 'vout)
    putprop(res car(errset(v("/vg" ?result "dcOp") nil)) 'vg)
    when( inst
      foreach(p spsOpParams
        val = car(errset(pv(inst p ?result "dcOpInfo") nil))
        putprop(res val stringToSymbol(p))))
    acSay("%s: OP read from instance %L\n" cell inst)
    foreach(e spsExtraParams
      putprop(res car(errset(pv(car(e) cadr(e) ?result "dcOpInfo") nil))
              stringToSymbol(strcat(car(e) "_" cadr(e)))))
    unless( inst acSay("%s: no OP parameters found for M0 (tried %L)\n" cell cands) )
    res
  )
)

;; one CSV row of OP values (header from spsOpHeader)
procedure( spsOpHeader(port)
  fprintf(port "cell,W,vbias_V,vout_V,Id_A,gm_over_Id_per_V")
  foreach(p spsOpParams fprintf(port ",%s" p))
  foreach(e spsExtraParams fprintf(port ",%s_%s" car(e) cadr(e)))
  fprintf(port "\n")
)
procedure( spsOpRow(port cell w vb op)
  let( (id gm)
    id = if( numberp(op->vout) (spsCfg->vdd - op->vout) / spsCfg->rd nil)
    gm = op->gm
    fprintf(port "%s,%s,%s,%s,%s,%s" cell w spsNum(vb) spsNum(op->vout) spsNum(id)
            if( numberp(gm) && numberp(id) && id > 0 spsNum(gm / id "%.5g") "n/a"))
    foreach(p spsOpParams
      fprintf(port ",%s" spsNum(get(op stringToSymbol(p)))))
    foreach(e spsExtraParams
      fprintf(port ",%s" spsNum(get(op stringToSymbol(strcat(car(e) "_" cadr(e)))))))
    fprintf(port "\n")
  )
)

;; write several waveforms of one run, sharing the x vector, to a CSV
procedure( spsWriteWaves(file header waves)
  let( (cols port n)
    cols = mapcar('acWavePoints waves)
    port = outfile(file "w")
    fprintf(port "%s\n" header)
    n = apply('min mapcar('length cols))
    for(k 0 n - 1
      fprintf(port "%.10g" car(nth(k car(cols))))
      foreach(c cols fprintf(port ",%.10g" cadr(nth(k c))))
      fprintf(port "\n"))
    close(port)
    acSay("wrote %s (%d rows)\n" file n)
    n
  )
)

;; ---------- job 1: W scan at Id = 10 uA ----------
procedure( spsScan()
  let( (cell port vb op file)
    cell = spsCfg->scanCell
    csBuild(spsCfg->lib cell ?nW "wn" ?nL spsCfg->l ?vamp "vamp" ?vfreq "fin"
            ?nParams spsDiffParams("wn"))
    file = strcat(acResultsDir() "/sps_wscan.csv")
    port = outfile(file "w")
    spsOpHeader(port)
    foreach(wu spsCfg->scanWidths
      vb = spsFindVbias(cell wu * 1e-6)
      if( numberp(vb) then
        op = spsOp(cell wu * 1e-6 vb)
        spsOpRow(port cell sprintf(nil "%gu" wu) vb op)
        acSay("W = %g um: vbias %s V, gm %s S, gm/Id %s, region %s\n" wu acNum(vb "%.4f")
              acNum(op->gm) if( numberp(op->gm) acNum(op->gm / spsCfg->idTarget "%.2f") "n/a")
              spsNum(op->region "%g"))
      else
        acSay("W = %g um: Id = 10 uA not reached in the vbias sweep\n" wu))
      drain(port))
    close(port)
    acSay("wrote %s\n" file)
    t
  )
)

;; ---------- job 2: the two circuits ----------
procedure( spsSimCell(cell w port)
  let( (vb op res)
    vb = spsFindVbias(cell)
    unless( numberp(vb) error("%s: no vbias for Id = 10 uA\n" cell) )
    op = spsOp(cell nil vb)
    spsOpRow(port cell w vb op)
    drain(port)

    ;; AC: vin = 1 V (acm = 1) from 1 Hz to 10 GHz; complex v(vout), v(vg)
    spsSetup(cell nil vb 1e6)
    analysis('ac ?start spsCfg->acStart ?stop spsCfg->acStop ?dec spsCfg->acDec)
    run()
    res = list(real(v("/vout" ?result "ac")) imag(v("/vout" ?result "ac"))
               real(v("/vg" ?result "ac"))   imag(v("/vg" ?result "ac")))
    spsWriteWaves(strcat(acResultsDir() "/sps_ac_" cell ".csv")
                  "f_Hz,vout_re,vout_im,vg_re,vg_im" res)
    acSay("%s: |vout/vin| at 100 Hz %s, at 1 MHz %s\n" cell
          acNum(car(errset(value(mag(v("/vout" ?result "ac")) 100.0) nil)))
          acNum(car(errset(value(mag(v("/vout" ?result "ac")) 1e6) nil))))

    ;; transient with a real sine input at each frequency
    foreach(fc spsCfg->fins
      spsSetup(cell nil vb cadr(fc))
      analysis('tran ?stop caddr(fc) ?maxstep nth(3 fc))
      run()
      spsWriteWaves(strcat(acResultsDir() "/sps_tran_" cell "_" car(fc) ".csv")
                    "t_s,vin,vg,vout"
                    list(v("/vin" ?result "tran") v("/vg" ?result "tran") v("/vout" ?result "tran"))))
    vb
  )
)

procedure( spsBuild()
  foreach(c spsCfg->circuits
    csBuild(spsCfg->lib car(c) ?nW sprintf(nil "%gu" cadr(c)) ?nL spsCfg->l ?vamp "vamp" ?vfreq "fin"
            ?nParams spsDiffParams(cadr(c) * 1e-6)))
  t
)

procedure( spsRun()
  let( (port file)
    spsBuild()
    file = strcat(acResultsDir() "/sps_op.csv")
    port = outfile(file "w")
    spsOpHeader(port)
    foreach(c spsCfg->circuits
      spsSimCell(car(c) sprintf(nil "%gu" cadr(c)) port))
    close(port)
    acSay("wrote %s\n" file)
    t
  )
)

;; ---------- job 3: ADE L states (GUI) ----------
;; Each cell gets two states: sps_100Hz and sps_1MHz. Both hold the DC operating point,
;; the AC sweep 1 Hz .. 10 GHz and a transient with the sine at fin.
procedure( spsAdeCell(cell)
  let( (vb sess vars)
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
    acAdeOutput(acAdeSev "Vout_dc"       "VDC(\"/vout\")")
    acAdeOutput(acAdeSev "Id"            "(2 - VDC(\"/vout\"))/100e3")
    acAdeOutput(acAdeSev "gain_dB"       "db20(VF(\"/vout\"))")
    acAdeOutput(acAdeSev "gate_atten_dB" "db20(VF(\"/vg\"))")
    acAdeOutput(acAdeSev "vout_vg_dB"    "db20(VF(\"/vout\") / VF(\"/vg\"))")
    acAdeOutput(acAdeSev "gain_at_fin"   "value(mag(VF(\"/vout\")) VAR(\"fin\"))")
    acAdeOutput(acAdeSev "vin_tran"      "VT(\"/vin\")")
    acAdeOutput(acAdeSev "vout_tran"     "VT(\"/vout\")")
    foreach(fc spsCfg->fins
      vars = list(list("vbias" sprintf(nil "%.5f" vb))
                  list("vamp" sprintf(nil "%g" spsCfg->vamp))
                  list("fin" sprintf(nil "%g" cadr(fc))))
      acAdeVars(sess vars)
      acAdeAnalysis(sess 'tran list(list('stop caddr(fc)) list('maxstep nth(3 fc))))
      acAdeSave(sess spsCfg->lib cell strcat("sps_" car(fc))))
    sess
  )
)

procedure( spsAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("spsAde needs a display (run.sh spsade)\n") )
  foreach(c spsCfg->circuits spsAdeCell(car(c)))
  t
)
