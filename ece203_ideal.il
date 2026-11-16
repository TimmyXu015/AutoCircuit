;; ece203_ideal.il -- ECE203 ECG project, Track C: the complete BEHAVIOURAL ECG front end.
;; No PDK transistors. Amplifiers are ideal VCVSs (memoryless, rail-free, noiseless).
;;
;; Cells (library Project):
;;   ece203_lp_out     pins IN, OUT: RLP (rlp) IN-OUT, CLP (clp) OUT-gnd. Permanent passive
;;                     250 Hz output low-pass, placed AFTER A3 and OUTSIDE its feedback.
;;   ece203_ideal_ecg  testbench:
;;     body: CBODY (cbody) to gnd, IINT 60 Hz interferer (AC current icm, gnd -> body)
;;     signal: VSP (ac +adm/2) body->ep, VSN (ac -adm/2) body->en
;;     electrodes (each): rs in series with (re || ce); P electrode scaled by (1+delec) in Z
;;     VPP/VPN: 0 V probes between electrode and amplifier input (current = input current)
;;     inp/inn: amplifier inputs ("after the electrodes")
;;     A1: XFB1 ece203_hp_fb (inp, s1, o1) + E1 (vout = aol (vref - s1)); CCX = cc*dcc extra
;;         input cap on A1 only (Cc mismatch); A2: XFB2 (inn, s2, o2) + E2
;;     A3: o3 - vref = (r2/r1) (o2 - o1)  [R1A o2->p3, R2A p3->vref, R1B o1->n3, R2B n3->o3, E3 aol3]
;;         -> overall out = +100 (inp - inn)
;;     XLP ece203_lp_out: o3 -> out
;;     DRL: RCMP/RCMN (rcm) inp,inn -> cm (sense BEFORE the coupling caps);
;;          EDRL: drl - vref = adrl (vref - cm) (inverting); RDRL (rdrl) drl -> rl0;
;;          right-leg electrode rl0 -> body. DRL OFF = rdrl 1e15 (disconnected but keeps a DC path).
;;     VREF ideal 0.9 V (behavioural dependency, flagged)
;;
;; Job ece203_ideal: build + OCEAN runs:
;;   DM  : adm 1, icm 0, DRL on            -> Hdm = v(out)/(v(inp)-v(inn)), corners, Zin(10 Hz)
;;   CM  : adm 0, icm 0.1 uA, DRL off / on -> vcm = (v(inp)+v(inn))/2, v(out) at 60 Hz
;;         Acm(off) = out_off / vcm_off, Acm(on) = out_on / vcm_off (instructor's definition)
;;   for cases matched / Cc mismatch 1 % / electrode mismatch 10 %, plus adrl sweep
;; Outputs: ece203_ideal.txt, ece203_ideal_dm.csv, ece203_ideal_cm_<case>.csv, ece203_ideal_cases.csv

idealCell = "ece203_ideal_ecg"
lpCell = "ece203_lp_out"
idealCfg = list(nil
  'vars list(list("vref" 0.9) list("aol" 1e5) list("aol3" 1e5)
             list("cc" 100e-12) list("cf" 4e-12) list("rp" 398e9)
             list("r1" 1e6) list("r2" 4e6) list("rlp" 3.18e6) list("clp" 200e-12)
             list("rcm" 10e9) list("rs" 2e3) list("re" 1e6) list("ce" 50e-9) list("cbody" 200e-12)
             list("adrl" 100.0) list("rdrl" 1e6) list("icm" 0.0) list("adm" 1.0)
             list("dcc" 0.0) list("delec" 0.0))
  'rdrlOn 1e6 'rdrlOff 1e15 'icm 0.1e-6
  'cases list(list("matched" 0.0 0.0) list("dcc1pct" 0.01 0.0) list("delec10pct" 0.0 0.1))
  'adrlList '(10.0 100.0 1000.0)
  'fStart "1m" 'fStop "10k" 'dec "20" 'f60 60.0 'fZin 10.0)

;; ---------- cells ----------
procedure( lpBuild()
  let( (cv)
    cv = acOpenSch(ece203Lib lpCell)
    ece203Pins(cv '(("IN" "input") ("OUT" "output")))
    ece203Place(cv list(
      list("analogLib" "res" "RLP" '(("r" "rlp")) '(("PLUS" "IN") ("MINUS" "OUT")))
      list("analogLib" "cap" "CLP" '(("c" "clp")) '(("PLUS" "OUT") ("MINUS" "gnd!")))))
    ece203Finish(cv ece203Lib lpCell)
    ece203Symbol(ece203Lib lpCell)
  )
)

procedure( idealVcvs(name ncp ncm p m g)
  list("analogLib" "vcvs" name list(list("egain" g))
       list(list("NC+" ncp) list("NC-" ncm) list("PLUS" p) list("MINUS" m)))
)
procedure( idealR(name val a b) list("analogLib" "res" name list(list("r" val)) list(list("PLUS" a) list("MINUS" b))) )
procedure( idealC(name val a b) list("analogLib" "cap" name list(list("c" val)) list(list("PLUS" a) list("MINUS" b))) )
procedure( idealV(name dc acm a b)
  list("analogLib" "vdc" name list(list("vdc" dc) list("acm" acm)) list(list("PLUS" a) list("MINUS" b)))
)

procedure( idealBuild()
  let( (cv)
    cv = acOpenSch(ece203Lib idealCell)
    ece203Place(cv list(
      ;; row 0: reference, body, interferer, signal sources
      idealV("VREF" "vref" "0" "vref" "gnd!")
      idealC("CBODY" "cbody" "body" "gnd!")
      list("analogLib" "idc" "IINT" '(("idc" "0") ("acm" "icm")) '(("PLUS" "gnd!") ("MINUS" "body")))
      idealV("VSP" "0" "adm/2" "ep" "body")
      idealV("VSN" "0" "-adm/2" "en" "body")
      ;; electrodes
      idealR("RSP" "rs" "ep" "ep1")
      idealR("REP" "re*(1+delec)" "ep1" "inpr")
      idealC("CEP" "ce/(1+delec)" "ep1" "inpr")
      idealR("RSN" "rs" "en" "en1")
      idealR("REN" "re" "en1" "innr")
      idealC("CEN" "ce" "en1" "innr")
      idealV("VPP" "0" "0" "inpr" "inp")
      idealV("VPN" "0" "0" "innr" "inn")
      ;; A1, A2
      list(ece203Lib "ece203_hp_fb" "XFB1" nil '(("VIN" "inp") ("SUM" "s1") ("VOUT" "o1")))
      idealC("CCX" "cc*dcc" "inp" "s1")
      idealVcvs("E1" "vref" "s1" "o1" "gnd!" "aol")
      list(ece203Lib "ece203_hp_fb" "XFB2" nil '(("VIN" "inn") ("SUM" "s2") ("VOUT" "o2")))
      idealVcvs("E2" "vref" "s2" "o2" "gnd!" "aol")
      ;; A3 difference amplifier
      idealR("R1A" "r1" "o2" "p3")
      idealR("R2A" "r2" "p3" "vref")
      idealR("R1B" "r1" "o1" "n3")
      idealR("R2B" "r2" "n3" "o3")
      idealVcvs("E3" "p3" "n3" "o3" "gnd!" "aol3")
      list(ece203Lib lpCell "XLP" nil '(("IN" "o3") ("OUT" "out")))
      ;; DRL
      idealR("RCMP" "rcm" "inp" "cm")
      idealR("RCMN" "rcm" "inn" "cm")
      idealVcvs("EDRL" "vref" "cm" "drl" "vref" "adrl")
      idealR("RDRL" "rdrl" "drl" "rl0")
      idealR("RSR" "rs" "rl0" "rl1")
      idealR("RER" "re" "rl1" "body")
      idealC("CER" "ce" "rl1" "body")))
    ece203GndRef(cv list(-2.0 0.0))
    ece203Finish(cv ece203Lib idealCell)
  )
)

;; ---------- simulation ----------
procedure( idealSet(over)
  ece203Vars(idealCfg->vars)
  ece203Vars(over)
)

;; one run; returns DPL with complex waves dm (Hdm), h3 (gain at o3), vcm, out, body, zinp, zinn
procedure( idealRun(over)
  let( (vp vn out res)
    idealSet(over)
    run()
    vp = car(errset(v("/inp" ?result "ac") nil))
    vn = car(errset(v("/inn" ?result "ac") nil))
    out = car(errset(v("/out" ?result "ac") nil))
    unless( out error("ideal: no ac result -- see the spectre log\n") )
    res = list(nil 'out out 'vcm (vp + vn) / 2.0 'body car(errset(v("/body" ?result "ac") nil)))
    res->dm = car(errset(out / (vp - vn) nil))
    res->h3 = car(errset(v("/o3" ?result "ac") / (vp - vn) nil))
    res->zinp = car(errset(vp / i("/VPP/PLUS" ?result "ac") nil))
    res->zinn = car(errset(vn / i("/VPN/PLUS" ?result "ac") nil))
    res
  )
)

procedure( idealMag(w f) ece203V(mag(w) f) )

;; DM + CM(off) + CM(on) for one mismatch case; returns DPL of numbers and the waves
procedure( idealCase(name dcc delec adrl)
  let( (base dm off on r adm60 vcmOff outOff vcmOn outOn bodyOff bodyOn)
    base = list(list("dcc" dcc) list("delec" delec) list("adrl" adrl))
    dm = idealRun(append(base list(list("adm" 1.0) list("icm" 0.0) list("rdrl" idealCfg->rdrlOn))))
    off = idealRun(append(base list(list("adm" 0.0) list("icm" idealCfg->icm) list("rdrl" idealCfg->rdrlOff))))
    on = idealRun(append(base list(list("adm" 0.0) list("icm" idealCfg->icm) list("rdrl" idealCfg->rdrlOn))))
    adm60 = idealMag(dm->dm idealCfg->f60)
    vcmOff = idealMag(off->vcm idealCfg->f60)  outOff = idealMag(off->out idealCfg->f60)
    vcmOn = idealMag(on->vcm idealCfg->f60)    outOn = idealMag(on->out idealCfg->f60)
    bodyOff = idealMag(off->body idealCfg->f60) bodyOn = idealMag(on->body idealCfg->f60)
    r = list(nil 'name name 'dcc dcc 'delec delec 'adrl adrl 'adm60 adm60
             'vcmOff vcmOff 'outOff outOff 'vcmOn vcmOn 'outOn outOn 'bodyOff bodyOff 'bodyOn bodyOn
             'dmw dm 'offw off 'onw on)
    r->acmOff = and(numberp(outOff) numberp(vcmOff) vcmOff > 0 outOff / vcmOff)
    r->acmOn = and(numberp(outOn) numberp(vcmOff) vcmOff > 0 outOn / vcmOff)
    r->cmrrOff = and(numberp(r->acmOff) r->acmOff > 0 numberp(adm60) ece203Db(adm60 / r->acmOff))
    r->cmrrOn = and(numberp(r->acmOn) r->acmOn > 0 numberp(adm60) ece203Db(adm60 / r->acmOn))
    r->drlAtt = and(numberp(vcmOn) numberp(vcmOff) vcmOff > 0 vcmOn / vcmOff)
    acSay("ideal %s (dcc %g delec %g adrl %g): |Adm(60)| %s, |vcm| off %s on %s V (on/off %s), |out| off %s on %s V, CMRR off %s dB on %s dB\n"
          name dcc delec adrl acNum(adm60 "%.5g") acNum(vcmOff "%.4g") acNum(vcmOn "%.4g")
          acNum(r->drlAtt "%.4g") acNum(outOff "%.4g") acNum(outOn "%.4g")
          acNum(r->cmrrOff "%.2f") acNum(r->cmrrOn "%.2f"))
    r
  )
)

procedure( idealSim()
  let( (res nom dm cases rows port mid fl fh ph10 z10p z10n caps dcv)
    res = acResultsDir()
    ece203Setup(idealCell "_ideal")
    save('i "/VPP/PLUS" "/VPN/PLUS")
    analysis('dc ?saveOppoint t)
    analysis('ac ?start idealCfg->fStart ?stop idealCfg->fStop ?dec idealCfg->dec)

    ;; mismatch cases at the nominal DRL gain
    foreach(c idealCfg->cases
      rows = cons(idealCase(car(c) cadr(c) caddr(c) 100.0) rows))
    rows = reverse(rows)
    nom = car(rows)

    ;; DC operating point of the last run (DRL on)
    dcv = mapcar(lambda((n) list(n car(errset(v(strcat("/" n) ?result "dcOp") nil))))
                 '("inp" "inn" "s1" "o1" "o2" "o3" "out" "cm" "drl" "body"))
    acSay("ideal: DC op %L\n" dcv)

    ;; DM response of the matched case
    dm = nom->dmw
    mid = car(errset(ymax(mag(dm->dm)) nil))
    fl = car(errset(cross(db20(dm->dm) ece203Db(mid) - 3.0 1 "rising") nil))
    fh = car(errset(cross(db20(dm->dm) ece203Db(mid) - 3.0 1 "falling") nil))
    ph10 = ece203V(phase(dm->dm) 10.0)
    z10p = idealMag(dm->zinp idealCfg->fZin)
    z10n = idealMag(dm->zinn idealCfg->fZin)
    acSay("ideal DM: max |Hdm| %s (%s dB), phase(10 Hz) %s deg, f_L %s Hz, f_H %s Hz, |Zin(10 Hz)| P %s N %s ohm, |H| at o3 (before LP) 100 Hz %s\n"
          acNum(mid "%.5g") acNum(ece203Db(mid) "%.3f") acNum(ph10 "%.2f") acNum(fl "%.5g") acNum(fh "%.5g")
          acNum(z10p "%.5g") acNum(z10n "%.5g") acNum(idealMag(dm->h3 100.0) "%.5g"))
    spsWriteWaves(strcat(res "/ece203_ideal_dm.csv")
                  "f_Hz,absHdm,phaseHdm_deg,absH_o3,absZinP_ohm,absZinN_ohm"
                  list(mag(dm->dm) phase(dm->dm) mag(dm->h3) mag(dm->zinp) mag(dm->zinn)))
    foreach(r rows
      spsWriteWaves(strcat(res "/ece203_ideal_cm_" r->name ".csv")
                    "f_Hz,absHdm,abs_vcm_off,abs_out_off,abs_vcm_on,abs_out_on,abs_body_off,abs_body_on"
                    list(mag(r->dmw->dm) mag(r->offw->vcm) mag(r->offw->out) mag(r->onw->vcm)
                         mag(r->onw->out) mag(r->offw->body) mag(r->onw->body))))

    ;; DRL gain sweep on the Cc-mismatch case
    foreach(a idealCfg->adrlList
      unless( a == 100.0 rows = append(rows list(idealCase("dcc1pct" 0.01 0.0 a)))))

    port = outfile(strcat(res "/ece203_ideal_cases.csv") "w")
    fprintf(port "case,dcc,delec,adrl,absAdm60,abs_vcm_off,abs_vcm_on,drl_att,abs_out_off,abs_out_on,Acm_off,Acm_on,CMRR_off_dB,CMRR_on_dB\n")
    foreach(r rows
      fprintf(port "%s,%g,%g,%g,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" r->name r->dcc r->delec r->adrl
              acNum(r->adm60 "%.8g") acNum(r->vcmOff "%.6g") acNum(r->vcmOn "%.6g") acNum(r->drlAtt "%.6g")
              acNum(r->outOff "%.6g") acNum(r->outOn "%.6g") acNum(r->acmOff "%.6g") acNum(r->acmOn "%.6g")
              acNum(r->cmrrOff "%.3f") acNum(r->cmrrOn "%.3f")))
    close(port)

    ;; summary
    caps = 2.0 * (100e-12 + 4e-12) + 200e-12
    port = outfile(strcat(res "/ece203_ideal.txt") "w")
    fprintf(port "%s (Project)  %s  -- ideal VCVS amplifiers, ideal VREF; NOT a power/noise/swing/PM result\n"
            idealCell getCurrentTime())
    fprintf(port "vars: %L\n" idealCfg->vars)
    fprintf(port "DC op (DRL on): %L\n" dcv)
    fprintf(port "DM (matched, DRL on): max|Hdm| %s (%s dB), phase(10Hz) %s deg, f_L %s Hz, f_H %s Hz\n"
            acNum(mid "%.6g") acNum(ece203Db(mid) "%.4f") acNum(ph10 "%.3f") acNum(fl "%.6g") acNum(fh "%.6g"))
    fprintf(port "|Zin(10Hz)| at inp %s ohm, at inn %s ohm (includes Cc path and rcm CM-sense resistor)\n"
            acNum(z10p "%.6g") acNum(z10n "%.6g"))
    fprintf(port "designed on-chip C (2cc + 2cf + clp, nominal) = %g pF; external electrode/body C: 3 x 50 nF + 200 pF (not counted)\n"
            caps * 1e12)
    fprintf(port "%-12s %6s %6s %7s %10s %11s %11s %9s %11s %11s %10s %10s\n" "case" "dcc" "delec" "adrl"
            "|Adm60|" "|vcm|off" "|vcm|on" "on/off" "|out|off" "|out|on" "CMRRoff" "CMRRon")
    foreach(r rows
      fprintf(port "%-12s %6g %6g %7g %10s %11s %11s %9s %11s %11s %10s %10s\n" r->name r->dcc r->delec r->adrl
              acNum(r->adm60 "%.5g") acNum(r->vcmOff "%.4g") acNum(r->vcmOn "%.4g") acNum(r->drlAtt "%.4g")
              acNum(r->outOff "%.4g") acNum(r->outOn "%.4g") acNum(r->cmrrOff "%.2f") acNum(r->cmrrOn "%.2f")))
    close(port)
    ece203SaveNetlist(idealCell "ece203_ideal")
    t
  )
)

procedure( idealAll()
  ece203LibInfo()
  hpFbBuild()
  lpBuild()
  idealBuild()
  idealSim()
  t
)
