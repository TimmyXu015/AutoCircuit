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
