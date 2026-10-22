;; hw2_setup.il -- ECE 203 HW2 Problem 1: f_t of an NMOS (cmrf7sf nfetx), set up in HW2_203.
;;
;; New cells (the user's own cells in HW2_203, e.g. 5T_p4, are never touched):
;;   p1_ft_5u1u    parts a-d   nfetx W/L = 5u/1u
;;   p1_ft_2u018   part  e     nfetx W/L = 2u/0.18u
;; Both: source + bulk to gnd, gate at VGS (dc = vgs, acm = 1), drain at VDS (dc = vdd).
;; The drain source is an AC short, so  h21 = i_d / i_g = IF(/VDS/PLUS) / IF(/VGS/PLUS)
;; is the short-circuit current gain and f_t is where |h21| crosses 1 (0 dB).
;;
;; ADE L state "hw2_p1_ft" in each cell (Session -> Load State -> Cellview):
;;   variables vgs = 0.25, vdd = 1.8; dc operating point (saved) + ac 1 Hz .. 1 THz, 20/dec;
;;   all terminal currents saved; outputs:
;;     Id, gm, gm_over_Id, cgg, cgs, cgd, cgb, region (spectre's OP values of M0)
;;     h21_dB = db20(IF(/VDS/PLUS)/IF(/VGS/PLUS))       current gain vs frequency
;;     ft     = cross(h21_dB 0 1 "falling")             scalar: f where the gain is 0 dB
;;   Part d: Tools -> Parametric Analysis, variable vgs, 0 .. 1.8 -> plots ft vs vgs.
;;
;; Jobs (run.sh):  hw2setup (@gui: cells + ADE states)   hw2check (OCEAN at vgs = 0.25)
;;                 hw2ftsweep (OCEAN loop vgs 0 .. 1.8 -> ~/AutoCircuit_results/hw2_ft_<cell>.csv)

hw2Lib = "HW2_203"

;; junction areas/perimeters (the PDK callback that sets them fails outside the form)
procedure( hw2DiffParams(w)
  list(list("ad" sprintf(nil "%g" w * 0.54e-6)) list("as" sprintf(nil "%g" w * 0.54e-6))
       list("pd" sprintf(nil "%g" 2.0 * (w + 0.54e-6))) list("ps" sprintf(nil "%g" 2.0 * (w + 0.54e-6))))
)

procedure( hw2Cfg(cell w l wm)
  list(nil 'lib hw2Lib 'cell cell 'devLib "cmrf7sf" 'dev "nfetx" 'w w 'l l
       'vdsExpr "vdd" 'vgsAcm "1" 'nParams hw2DiffParams(wm))
)

hw2Cells = list(hw2Cfg("p1_ft_5u1u" "5u" "1u" 5e-6)
                hw2Cfg("p1_ft_2u018" "2u" "0.18u" 2e-6))

;; expressions shared by ADE L and the OCEAN checks
hw2H21 = "db20(IF(\"/VDS/PLUS\") / IF(\"/VGS/PLUS\"))"
hw2Ft  = strcat("cross(" hw2H21 " 0 1 \"falling\")")

procedure( hw2Build()
  foreach(c hw2Cells
    when( ddGetObj(hw2Lib c->cell)
      acSay("hw2: %s exists, redrawing it\n" c->cell))
    p1aBuild(c))
  t
)

;; ---------- ADE L ----------
procedure( hw2AdeFt(cfg)
  let( (sess)
    sess = acAdeStart(cfg->lib cfg->cell)
    unless( sess error("No ADE session for %s\n" cfg->cell) )
    acAdeModels(sess "tt")
    acAdeVars(sess list(list("vgs" "0.25") list("vdd" "1.8")))
    acAdeAnalysis(sess 'dc list(list('saveOppoint t)))
    acAdeAnalysis(sess 'ac
      list(list('start "1") list('stop "1T") list('dec "20"))
      list(list('sweep "freq") list('rangeType "start")
           list('incrType "log") list('stepTypeLog "decade")))
    acAdeSaveCurrents(sess)
    foreach(p '(("Id" "id") ("gm" "gm") ("cgg" "cgg") ("cgs" "cgs") ("cgd" "cgd") ("cgb" "cgb")
                ("region" "region") ("vth" "vth"))
      acAdeOutput(acAdeSev car(p) sprintf(nil "OP(\"/M0\" \"%s\")" cadr(p))))
    acAdeOutput(acAdeSev "gm_over_Id" "OP(\"/M0\" \"gm\") / OP(\"/M0\" \"id\")")
    acAdeOutput(acAdeSev "h21_dB" hw2H21)
    acAdeOutput(acAdeSev "ft" hw2Ft)
    acAdeSave(sess cfg->lib cfg->cell "hw2_p1_ft")
    sess
  )
)

procedure( hw2Setup()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  hw2Build()
  if( hiGraphicMode() then
    foreach(c hw2Cells hw2AdeFt(c))
  else
    acSay("hw2: no display -- schematics built, ADE states skipped\n"))
  t
)

;; ---------- OCEAN ----------
;; one dc-op + ac run at the given vgs; returns DPL: id gm cgg cgs cgd cgb region ft ftop
procedure( hw2Point(cfg vgs)
  let( (res h inst)
    acSimSetup(cfg->lib cfg->cell "tt" "_hw2")
    desVar("vgs" vgs)
    desVar("vdd" 1.8)
    save('i "/VDS/PLUS" "/VGS/PLUS")
    analysis('dc ?saveOppoint t)
    analysis('ac ?start "1" ?stop "1T" ?dec "20")
    run()
    res = list(nil)
    inst = car(setof(n cons("M0" spsM0Names())
                     numberp(car(errset(pv(n "gm" ?result "dcOpInfo") nil)))))
    foreach(p '("id" "gm" "cgg" "cgs" "cgd" "cgb" "region" "vth")
      putprop(res and(inst car(errset(pv(inst p ?result "dcOpInfo") nil))) stringToSymbol(p)))
    h = car(errset(i("/VDS/PLUS" ?result "ac") / i("/VGS/PLUS" ?result "ac") nil))
    putprop(res and(h car(errset(cross(db20(h) 0 1 "falling") nil))) 'ft)
    ;; the same estimate from the OP values: gm / (2 pi Cgg)
    putprop(res when( numberp(res->gm) && numberp(res->cgg) && res->cgg != 0
                  res->gm / (2.0 * 3.14159265 * abs(res->cgg))) 'ftop)
    res
  )
)

procedure( hw2Check()
  let( (r)
    foreach(c hw2Cells
      r = hw2Point(c 0.25)
      acSay("check %s (vgs 0.25, vdd 1.8): Id %s A, gm %s S, Cgg %s F, region %s, ft(AC) %s Hz, gm/(2pi Cgg) %s Hz\n"
            c->cell spsNum(r->id) spsNum(r->gm) spsNum(r->cgg) spsNum(r->region)
            spsNum(r->ft) spsNum(r->ftop)))
    t
  )
)

;; ft vs vgs, one ordinary run per point (OCEAN paramRun is unreliable here, see playbook)
procedure( hw2FtSweep(@key (vgsList nil))
  let( (file port r n)
    unless( vgsList
      for(k 0 36 vgsList = cons(0.05 * k vgsList))
      vgsList = reverse(vgsList))
    foreach(c hw2Cells
      file = strcat(acResultsDir() "/hw2_ft_" c->cell ".csv")
      port = outfile(file "w")
      fprintf(port "vgs_V,Id_A,gm_S,cgg_F,cgs_F,cgd_F,cgb_F,region,ft_ac_Hz,gm_over_2piCgg_Hz\n")
      n = 0
      foreach(vg vgsList
        r = hw2Point(c vg)
        when( numberp(r->ft) n++ )
        fprintf(port "%g,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" vg
                spsNum(r->id) spsNum(r->gm) spsNum(r->cgg) spsNum(r->cgs) spsNum(r->cgd)
                spsNum(r->cgb) spsNum(r->region) spsNum(r->ft) spsNum(r->ftop))
        drain(port))
      close(port)
      acSay("hw2 sweep %s: %d of %d points have an f_t crossing -> %s\n" c->cell n length(vgsList) file))
    t
  )
)
