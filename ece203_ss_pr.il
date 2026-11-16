;; ece203_ss_pr.il -- ECE203 Round 3B: classroom MOS-bipolar pseudo-resistor microtest.
;; Work order: docs/ECE203_round3b_pseudoresistor_microtest.md.
;; Lecture 9 slide 30 (Lec8-9-10-BioAmp.pdf p.15): one PMOS whose gate, n-well (bulk) and the V0-side p+
;; are tied together; the other p+ is the Vf terminal. Slide 32: use thick-oxide devices (higher Vt).
;;   Project/ece203_ss_pr_cell   two pins: A = Vf (plain p+),  B = V0 (gate + n-well + p+)
;;                               device: cmrf7sf pfet33x (3.3 V thick oxide), W = prw, L = prl (design vars)
;;   Project/ece203_ss_pr_iv_tb  VB = vcm (DC) on B,  VA = vcm + vd (DC, ac 1) on A
;; Stage A: vd = -50..+50 mV, DC op + AC at 1 mHz per point (incremental g = Re(I_A)/1 V),
;;          once with default Spectre tolerances and once with gmin = iabstol = 1e-18 (precision check).
;; Stage B (only if Stage A is credible): separate job, see ssPrStageB.

prCells = list(nil 'cell "ece203_ss_pr_cell" 'iv "ece203_ss_pr_iv_tb" 's2 "ece203_ss_pr_tb")
prDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_ss_pr")
prDev = "pfet33x"
prVds = '(-50e-3 -20e-3 -10e-3 -5e-3 -2e-3 -1e-3 0.0 1e-3 2e-3 5e-3 10e-3 20e-3 50e-3)
prVars = list(list("vcm" 0.9) list("vd" 0.0) list("prw" 1e-6) list("prl" 2e-6))

;; what the PDK says about the device (pins, CDF defaults) -- logged, used to check the build
procedure( prProbeDev(dev)
  let( (m cdf)
    m = dbOpenCellViewByType("cmrf7sf" dev "symbol")
    if( m then
      foreach(tm m~>terminals
        acSay("pr: %s pin %s at %L\n" dev tm~>name mapcar(lambda((p) centerBox(p~>fig~>bBox)) tm~>pins)))
    else acSay("pr: cannot open cmrf7sf/%s symbol\n" dev))
    cdf = car(errset(cdfGetBaseCellCDF(ddGetObj("cmrf7sf" dev)) nil))
    when( cdf
      foreach(p cdf~>parameters
        when( member(p~>name '("w" "l" "wr" "lr" "nf" "model" "ad" "as" "pd" "ps"))
          acSay("pr: %s CDF %s default %L\n" dev p~>name p~>defValue))))
    t
  )
)

procedure( prBuild()
  let( (cv)
    ece203LibInfo()
    prProbeDev(prDev)
    cv = acOpenSch(ece203Lib prCells->cell)
    ece203Pins(cv '(("A" "inputOutput") ("B" "inputOutput")))
    ece203Place(cv list(nsFetSpecVar(prDev "MP" "prw" "prl" "B" "B" "A" "B")))
    ece203Finish(cv ece203Lib prCells->cell)
    ece203Symbol(ece203Lib prCells->cell)
    otaTb(prCells->iv list(
      otaV("VB" "vcm" "0" "b" "gnd!")
      otaV("VA" "vcm+vd" "1" "a" "gnd!")
      list(ece203Lib prCells->cell "XP" nil '(("A" "a") ("B" "b")))))
    t
  )
)

prCols = '(setting vd_mV I_A_into_A I_B_out_of_B I_leak_A_minus_B g_ac_S r_ac_ohm r_secant_ohm
  id_MP vgs_MP vds_MP vth_MP region_MP gds_MP status)

procedure( prWriteRow(port r)
  let( (x first)
    first = t
    foreach(c prCols
      x = get(r c)
      fprintf(port "%s%s" if( first "" ",")
              cond( (stringp(x) x) (numberp(x) sprintf(nil "%.6g" float(x))) (t "n/a")))
      first = nil)
    fprintf(port "\n") drain(port)
  )
)

procedure( prIvSet(port setting tight)
  let( (r ia ib iac ok)
    foreach(vd prVds
      r = list(nil 'setting setting 'vd_mV vd * 1e3 'status "ok")
      ok = errset(
        progn(
          ece203Setup(prCells->iv strcat("_" setting))
          when( tight
            car(errset(option('gmin "1e-18" 'iabstol "1e-18" 'reltol "1e-6") t)))
          analysis('dc ?saveOppoint t)
          analysis('ac ?start "1m" ?stop "10m" ?dec "1")
          car(errset(save('i "/VA/PLUS" "/VB/PLUS") nil))
          ece203Vars(prVars) desVar("vd" vd)
          run()
          ia = ldIdc("/VA/PLUS")
          ib = car(errset(i("/VB/PLUS" ?result "dcOp") nil))
          iac = car(errset(i("/VA/PLUS" ?result "ac") nil))
          r->I_A_into_A = ia
          r->I_B_out_of_B = ib
          r->I_leak_A_minus_B = and(numberp(ia) numberp(ib) ia - ib)
          r->g_ac_S = and(iac car(errset(-1.0 * real(value(iac 1e-3)) nil)))
          r->r_ac_ohm = and(numberp(r->g_ac_S) r->g_ac_S != 0.0 1.0 / r->g_ac_S)
          r->r_secant_ohm = and(numberp(ia) ia != 0.0 vd != 0.0 vd / ia)
          foreach(q '(("id_MP" "id") ("vgs_MP" "vgs") ("vds_MP" "vds") ("vth_MP" "vth")
                      ("region_MP" "region") ("gds_MP" "gds"))
            putprop(r car(errset(pv("/XP/MP" cadr(q) ?result "dcOpInfo") nil)) stringToSymbol(car(q))))
          t)
        t)
      unless( ok r->status = sprintf(nil "failed %L" errset.errset))
      acSay("pr %s vd %s mV: I_A %s A, I_B %s A, g_ac %s S, r_ac %s, r_sec %s, MP id %s vth %s region %s %s\n"
            setting acNum(r->vd_mV "%g") acNum(r->I_A_into_A "%.4g") acNum(r->I_B_out_of_B "%.4g")
            acNum(r->g_ac_S "%.4g") acNum(r->r_ac_ohm "%.4g") acNum(r->r_secant_ohm "%.4g")
            acNum(r->id_MP "%.4g") acNum(r->vth_MP "%.4g")
            acNum(and(numberp(r->region_MP) float(r->region_MP)) "%g") r->status)
      prWriteRow(port r))
    ece203SaveNetlist(prCells->iv strcat("ece203_pr_iv_" setting))
  )
)

procedure( prStageAJob()
  let( (port)
    prBuild()
    unless( isDir(prDir) createDir(prDir) )
    port = outfile(strcat(prDir "/pr_iv.csv") "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString prCols) ","))
    prIvSet(port "default" nil)
    prIvSet(port "tight" t)
    close(port)
    t
  )
)

;; ---------------- Stage A, one justified adjustment ----------------
;; Base (W 1u, L 2u) gave ~9.7 TOhm at 0 V with tight tolerances (3x the 3.18 TOhm target). Sub-threshold
;; current ~ W/L, so the single adjustment is W = 3u (same L); tight tolerances only (default is gmin-bound).
procedure( prStageA2Job()
  let( (port)
    prBuild()
    prVars = list(list("vcm" 0.9) list("vd" 0.0) list("prw" 3e-6) list("prl" 2e-6))
    unless( isDir(prDir) createDir(prDir) )
    port = outfile(strcat(prDir "/pr_iv_w3u.csv") "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString prCols) ","))
    prIvSet(port "tight_w3u" t)
    close(port)
    t
  )
)

;; ---------------- Stage B: one S2 comparison, ideal Rfb vs pseudo-R ----------------
;; Pseudo-R orientation: B (gate + n-well) on the low-impedance node (OUT / VREF), A (plain p+) on the
;; high-impedance OTA input node, so the well is not hung on the floating summing node.
prB = list(nil 'w 3e-6 'l 2e-6 'lin 8e-6)

procedure( prBuildS2()
  otaTb(prCells->s2 list(
    ldV("VREF" "vref" "0" "vref" "gnd!")
    ldSin("VINP" "vref" "ap" "vtp" "vinp" "gnd!")
    ldSin("VINN" "vref" "an" "-vtp" "vinn" "gnd!")
    otaC("CCP" "cc" "vinp" "p")  otaC("CCN" "cc" "vinn" "n")
    otaC("CFP" "cfb" "p" "vref")
    list(ece203Lib prCells->cell "XPP" nil '(("A" "p") ("B" "vref")))
    otaC("CFN" "cfb" "n" "o")
    list(ece203Lib prCells->cell "XPN" nil '(("A" "n") ("B" "o")))
    ldProbe("IPRB" "oa" "o")
    otaC("CL" "cl" "o" "gnd!")
    ldV("VDD" "vdd" "0" "vdd" "gnd!")
    otaI("IB" "ib3" "vdd" "ib")
    lsInst('(("INP" "p") ("INN" "n") ("OUT" "oa") ("VDD" "vdd") ("GND" "gnd!") ("IBIAS" "ib")))))
)

prBCols = '(case cell tolerances status Hdm_10 Hdm_100 Hdm_100_dB Hdm_0p1 Hdm_max_dB fL fH
  dc_o dc_n dc_p dc_vref V_PRN_A_minus_B V_PRP_A_minus_B I_PRN_id I_PRP_id I_VDD)

procedure( prBRun(port name cell tight pr)
  let( (r ok vp vn h c)
    r = list(nil 'case name 'cell cell 'tolerances if( tight "gmin=iabstol=1e-18 reltol=1e-6" "spectre default") 'status "ok")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" name))
        when( tight car(errset(option('gmin "1e-18" 'iabstol "1e-18" 'reltol "1e-6") t)))
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1m" ?stop "100k" ?dec "20")
        car(errset(save('i "/VDD/PLUS") nil))
        ece203Vars(ssCfg->vars) ece203Vars(lsS2)
        desVar("lin" prB->lin) desVar("prw" prB->w) desVar("prl" prB->l)
        run()
        vp = ldAc("vinp") vn = ldAc("vinn")
        unless( vp error("no ac result"))
        h = ldDiv(ldAc("o") vp - vn)
        r->Hdm_10 = ldMag(h 10.0) r->Hdm_100 = ldMag(h 100.0) r->Hdm_100_dB = ece203Db(r->Hdm_100)
        r->Hdm_0p1 = ldMag(h 0.1)
        c = ldCorners(h) r->Hdm_max_dB = ece203Db(car(c)) r->fL = cadr(c) r->fH = caddr(c)
        foreach(n '("o" "n" "p" "vref") putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        r->I_VDD = ldIdc("/VDD/PLUS")
        when( pr
          r->V_PRN_A_minus_B = and(numberp(r->dc_n) numberp(r->dc_o) r->dc_n - r->dc_o)
          r->V_PRP_A_minus_B = and(numberp(r->dc_p) numberp(r->dc_vref) r->dc_p - r->dc_vref)
          r->I_PRN_id = car(errset(pv("/XPN/MP" "id" ?result "dcOpInfo") nil))
          r->I_PRP_id = car(errset(pv("/XPP/MP" "id" ?result "dcOpInfo") nil)))
        ldWriteCurves(strcat(prDir "/" name "_ac.csv") list(list("Hdm" h)))
        ece203SaveNetlist(cell strcat("ece203_pr_" name))
        t)
      t)
    unless( ok r->status = sprintf(nil "failed %L" errset.errset))
    acSay("prB %s: %s | |Hdm| 0.1/10/100 Hz %s %s %s (%s dB) max %s dB fL %s fH %s | DC o %s n %s p %s | V_PRN %s V_PRP %s | I_PRN %s I_PRP %s | I_VDD %s\n"
          name r->status acNum(r->Hdm_0p1 "%.4g") acNum(r->Hdm_10 "%.4g") acNum(r->Hdm_100 "%.4g")
          acNum(r->Hdm_100_dB "%.2f") acNum(r->Hdm_max_dB "%.2f") acNum(r->fL "%.4g") acNum(r->fH "%.4g")
          acNum(r->dc_o "%.6g") acNum(r->dc_n "%.6g") acNum(r->dc_p "%.6g")
          acNum(r->V_PRN_A_minus_B "%.4g") acNum(r->V_PRP_A_minus_B "%.4g")
          acNum(r->I_PRN_id "%.4g") acNum(r->I_PRP_id "%.4g") acNum(r->I_VDD "%.4g"))
    let( (x first)
      first = t
      foreach(col prBCols
        x = get(r col)
        fprintf(port "%s%s" if( first "" ",")
                cond( (stringp(x) if( rexMatchp("," x) strcat("\"" x "\"") x))
                      (numberp(x) sprintf(nil "%.6g" float(x))) (t "n/a")))
        first = nil)
      fprintf(port "\n") drain(port))
    r
  )
)

procedure( prStageBJob()
  let( (port)
    prBuildS2()
    unless( isDir(prDir) createDir(prDir) )
    port = outfile(strcat(prDir "/pr_s2_compare.csv") "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString prBCols) ","))
    prBRun(port "ideal_Rfb_tight" lsCells->tb t nil)
    prBRun(port "pseudoR_tight" prCells->s2 t t)
    prBRun(port "pseudoR_default_tol" prCells->s2 nil t)
    close(port)
    t
  )
)

;; ---------------- ADE L states (GUI job): DC op + AC, tight simulator options ----------------
;; Spectre default gmin (1e-12 S) swamps a TOhm pseudo-R (fL 18.9 Hz instead of 0.057 Hz), so the
;; states try to carry gmin = iabstol = 1e-18, reltol = 1e-6. The setter's name is probed; if none works
;; the log says so and the user must set them in ADE: Simulation -> Options -> Analog.
procedure( prAdeOptions(sess)
  let( (done)
    foreach(fn '(asiSetSimOptionVal asiSetAnalogSimulatorOptionVal)
      when( isCallable(fn)
        foreach(o '((gmin "1e-18") (iabstol "1e-18") (reltol "1e-6"))
          done = car(errset(funcall(fn sess car(o) cadr(o)) nil))
          acSay("ADE: %s(%L %L) -> %L, reads back %L\n" fn car(o) cadr(o) done
                car(errset(funcall(if( fn == 'asiSetSimOptionVal 'asiGetSimOptionVal 'asiGetAnalogSimulatorOptionVal)
                                   sess car(o)) nil))))))
    done
  )
)

procedure( prAdeTb(cell s2)
  let( (sess)
    sess = acAdeStart(ece203Lib cell)
    unless( sess error("No ADE session for %s\n" cell) )
    acAdeModels(sess "tt")
    acAdeSaveCurrents(sess)
    prAdeOptions(sess)
    acAdeAnalysis(sess 'dc list(list('saveOppoint t)))
    acAdeAnalysis(sess 'ac
      list(list('start "1m") list('stop if( s2 "100k" "10m")) list('dec if( s2 "20" "1")))
      list(list('sweep "freq") list('rangeType "start") list('incrType "log") list('stepTypeLog "decade")))
    if( s2
      then
        acAdeOutput(acAdeSev "Hdm_dB" "db20((VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\"))))")
        acAdeOutput(acAdeSev "Hdm_100Hz" "value(mag((VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\")))) 100)")
        acAdeOutput(acAdeSev "PRN_id" "OP(\"/XPN/MP\" \"id\")")
        acAdeAcVars(sess t)
      else
        acAdeOutput(acAdeSev "I_A_dc" "IDC(\"/VA/PLUS\")")
        acAdeOutput(acAdeSev "g_ac" "-real(IF(\"/VA/PLUS\"))")
        acAdeOutput(acAdeSev "MP_id" "OP(\"/XP/MP\" \"id\")")
        acAdeAcVars(sess nil))
    acAdeSave(sess ece203Lib cell "pr_w3u")
    sess
  )
)

procedure( acAdeAcVars(sess s2)
  acAdeVars(sess
    append(list(list("prw" "3u") list("prl" "2u"))
           if( s2
             list(list("vdd" "1.8") list("vref" "0.9") list("ib3" "50n") list("lin" "8u")
                  list("cc" "50p") list("cfb" "500f") list("cl" "0")
                  list("ap" "0.5") list("an" "-0.5") list("vtp" "0") list("ftr" "10"))
             list(list("vcm" "0.9") list("vd" "0")))))
)

procedure( prAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("prAde needs the GUI (run.sh ece203_ss_pr_ade)\n") )
  prAdeTb(prCells->iv nil)
  prAdeTb(prCells->s2 t)
  t
)
