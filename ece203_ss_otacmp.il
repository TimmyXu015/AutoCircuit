;; ece203_ss_otacmp.il -- ECE203 Round 3C: B / P / C OTA comparison in the same S2 single-stage bench.
;; Work order: docs/ECE203_round3c_ota_pmos_cascode_microcompare.md. Old cells are read-only.
;;   B  baseline NMOS-input 5T (Round 3A, M1/M2 10u/8u)                      ece203_ss_ota_cmp_b_ota
;;   P  PMOS-input 5T: M1/M2 pfetx 10u/8u (same area as B), NMOS mirror 2u/4u,
;;      PMOS tail 8u/4u + PMOS reference 2u/4u from VDD; IBIAS sinks ib3 (50 nA)  ece203_ss_ota_cmp_p_ota
;;   C  B + one NMOS cascode MC (10u/4u) between M2 drain (x) and OUT, ideal VCAS
;;      (diagnostic bias, not source-count compliant) -- NOT a strict 5T any more  ece203_ss_ota_cmp_c_ota
;; Bench (per variant): ece203_ss_ota_cmp_<v>_tb = Round-3 S2 (cc 50p, cfb 0.5p, ideal rfb 3.1831T, CL 0),
;;                      ece203_ss_ota_cmp_<v>_ol = open-loop A0 (DC follower via 1T/1F, read at 10 Hz).
;; Tight tolerances (gmin = iabstol = 1e-18, reltol 1e-6) for every run. DC + AC + noise 0.1-250 Hz only.
;; Jobs: ece203_ss_ota_cmp (OCEAN), ece203_ss_ota_cmp_ade (@gui states).

ocDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_ss_ota_cmp")
ocVcas = 1.05

ocVariants = list(
  list(nil 'key "b" 'label "B: NMOS-input 5T, L 8u" 'ibSink nil 'vcas nil
    'devs list(
      list("pfetx" "M3" 2e-6 4e-6 "n1" "n1" "VDD" "VDD")
      list("pfetx" "M4" 2e-6 4e-6 "OUT" "n1" "VDD" "VDD")
      list("nfetx" "M1" 10e-6 8e-6 "n1" "INP" "tail" "GND")
      list("nfetx" "M2" 10e-6 8e-6 "OUT" "INN" "tail" "GND")
      list("nfetx" "MT" 8e-6 4e-6 "tail" "IBIAS" "GND" "GND")
      list("nfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "GND" "GND")))
  list(nil 'key "p" 'label "P: PMOS-input 5T, L 8u" 'ibSink t 'vcas nil
    'devs list(
      list("nfetx" "M3" 2e-6 4e-6 "n1" "n1" "GND" "GND")
      list("nfetx" "M4" 2e-6 4e-6 "OUT" "n1" "GND" "GND")
      list("pfetx" "M1" 10e-6 8e-6 "n1" "INP" "tail" "VDD")
      list("pfetx" "M2" 10e-6 8e-6 "OUT" "INN" "tail" "VDD")
      list("pfetx" "MT" 8e-6 4e-6 "tail" "IBIAS" "VDD" "VDD")
      list("pfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "VDD" "VDD")))
  list(nil 'key "c" 'label "C: B + NMOS cascode MC on M2 (local cascode, not 5T)" 'ibSink nil 'vcas t
    'devs list(
      list("pfetx" "M3" 2e-6 4e-6 "n1" "n1" "VDD" "VDD")
      list("pfetx" "M4" 2e-6 4e-6 "OUT" "n1" "VDD" "VDD")
      list("nfetx" "M1" 10e-6 8e-6 "n1" "INP" "tail" "GND")
      list("nfetx" "M2" 10e-6 8e-6 "x" "INN" "tail" "GND")
      list("nfetx" "MC" 10e-6 4e-6 "OUT" "VCAS" "x" "GND")
      list("nfetx" "MT" 8e-6 4e-6 "tail" "IBIAS" "GND" "GND")
      list("nfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "GND" "GND"))))

procedure( ocCell(v suffix) sprintf(nil "ece203_ss_ota_cmp_%s_%s" v->key suffix) )
procedure( ocInsts(v) mapcar(lambda((d) strcat("XA." cadr(d))) v->devs) )

procedure( ocOtaInst(v inp inn out)
  list(ece203Lib ocCell(v "ota") "XA" nil
       append(list(list("INP" inp) list("INN" inn) list("OUT" out) list("VDD" "vdd")
                   list("GND" "gnd!") list("IBIAS" "ib"))
              if( v->vcas list(list("VCAS" "vcas")) nil)))
)

;; bias sources common to both benches
procedure( ocBias(v)
  append(
    list(ldV("VDD" "vdd" "0" "vdd" "gnd!")
         if( v->ibSink otaI("IB" "ib3" "ib" "gnd!") otaI("IB" "ib3" "vdd" "ib")))
    if( v->vcas list(otaV("VCAS" "vcas" "0" "vcas" "gnd!")) nil))
)

procedure( ocBuild(v)
  let( (cv)
    cv = acOpenSch(ece203Lib ocCell(v "ota"))
    ece203Pins(cv append(a3Cfg->pins if( v->vcas '(("VCAS" "input")) nil)))
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) v->devs))
    ece203Finish(cv ece203Lib ocCell(v "ota"))
    ece203Symbol(ece203Lib ocCell(v "ota"))
    otaTb(ocCell(v "tb") append(
      list(ldV("VREF" "vref" "0" "vref" "gnd!")
           ldSin("VINP" "vref" "ap" "vtp" "vinp" "gnd!")
           ldSin("VINN" "vref" "an" "-vtp" "vinn" "gnd!")
           otaC("CCP" "cc" "vinp" "p")  otaC("CCN" "cc" "vinn" "n")
           otaC("CFP" "cfb" "p" "vref") otaR("RFP" "rfb" "p" "vref")
           otaC("CFN" "cfb" "n" "o")    otaR("RFN" "rfb" "n" "o")
           ldProbe("IPRB" "oa" "o")
           otaC("CL" "cl" "o" "gnd!")
           ocOtaInst(v "p" "n" "oa"))
      ocBias(v)))
    otaTb(ocCell(v "ol") append(
      list(ocOtaInst(v "inp" "inn" "out")
           otaV("VINP" "vcm" "1" "inp" "gnd!")
           otaR("RBIG" "rbig" "out" "inn")
           otaC("CBIG" "cbig" "inn" "gnd!"))
      ocBias(v)))
    t
  )
)

procedure( ocTight() car(errset(option('gmin "1e-18" 'iabstol "1e-18" 'reltol "1e-6") t)) )
procedure( ocVars()
  ece203Vars(ssCfg->vars) ece203Vars(lsS2)
  ece203Vars(list(list("vcm" 0.9) list("rbig" 1e12) list("cbig" 1.0) list("vcas" ocVcas)))
)

ocCols = '(variant label status reason I_VDD P_W dc_o dc_n dc_p vcas
  Hdm_10 Hdm_100 Hdm_100_dB ph_100 fL fH A0_ol_10Hz A0_ol_dB ACL_pred
  ol_vout ol_margin ol_worst margin worst
  gm_M1 gm_M2 id_M1 id_M2 gmid_M1 gds_M2 gds_M4 gds_MC gm_MC vds_M1 vds_M2 vds_MC vdsat_MC region_M1 region_M2 region_M4 region_MC
  in_WL_um2_each
  noise_out_rms noise_app_in_rms noise_deemb_in_rms noise_in_vinp_rms ns_total_V2 ns_integ_out_V2)

procedure( ocWriteRow(port r)
  let( (x first)
    first = t
    foreach(c ocCols
      x = get(r c)
      fprintf(port "%s%s" if( first "" ",")
              cond( (stringp(x) if( rexMatchp("," x) strcat("\"" x "\"") x))
                    (numberp(x) sprintf(nil "%.6g" float(x))) (t "n/a")))
      first = nil)
    fprintf(port "\n") drain(port)
  )
)

procedure( ocRun(var)
  let( (r ok vp vn h c nin nout ndm sum rows m ol gds tag)
    tag = var->key
    r = list(nil 'variant upperCase(tag) 'label var->label 'status "ok" 'vcas if( var->vcas ocVcas nil)
             'in_WL_um2_each 80.0)
    ok = errset(
      progn(
        ;; ---- S2 closed loop: dc op + ac + noise (same grid) ----
        ece203Setup(ocCell(var "tb") strcat("_" tag))
        ocTight()
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1m" ?stop "100k" ?dec "20")
        analysis('noise ?start "1m" ?stop "100k" ?dec "20" ?p "/o" ?n "/gnd!" ?iprobe "/VINP")
        car(errset(save('i "/VDD/PLUS") nil))
        ocVars()
        run()
        vp = ldAc("vinp") vn = ldAc("vinn")
        unless( vp error("no ac result (closed loop)"))
        h = ldDiv(ldAc("o") vp - vn)
        r->Hdm_10 = ldMag(h 10.0) r->Hdm_100 = ldMag(h 100.0) r->Hdm_100_dB = ece203Db(r->Hdm_100)
        r->ph_100 = ldPh(h 100.0)
        c = ldCorners(h) r->fL = cadr(c) r->fH = caddr(c)
        foreach(n '("o" "n" "p") putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        r->I_VDD = ldIdc("/VDD/PLUS") r->P_W = and(r->I_VDD 1.8 * r->I_VDD)
        rows = ece203OpDump(strcat(ocDir "/" tag "_cl_dcop.csv") ocInsts(var))
        m = ldMinMargin(rows "XA.") r->margin = car(m) r->worst = cadr(m)
        foreach(q '(("gm_M1" "/XA/M1" "gm") ("gm_M2" "/XA/M2" "gm") ("id_M1" "/XA/M1" "id") ("id_M2" "/XA/M2" "id")
                    ("gds_M2" "/XA/M2" "gds") ("gds_M4" "/XA/M4" "gds") ("gds_MC" "/XA/MC" "gds") ("gm_MC" "/XA/MC" "gm")
                    ("vds_M1" "/XA/M1" "vds") ("vds_M2" "/XA/M2" "vds") ("vds_MC" "/XA/MC" "vds") ("vdsat_MC" "/XA/MC" "vdsat")
                    ("region_M1" "/XA/M1" "region") ("region_M2" "/XA/M2" "region") ("region_M4" "/XA/M4" "region")
                    ("region_MC" "/XA/MC" "region"))
          putprop(r car(errset(pv(cadr(q) caddr(q) ?result "dcOpInfo") nil)) stringToSymbol(car(q))))
        r->gmid_M1 = and(numberp(r->gm_M1) numberp(r->id_M1) r->id_M1 != 0 r->gm_M1 / abs(r->id_M1))
        nin = car(errset(getData("in" ?result "noise") nil))
        nout = car(errset(getData("out" ?result "noise") nil))
        ndm = and(nout h car(errset(nout / mag(h) nil)))
        r->noise_out_rms = nsRms(nout 0.1 250.0)
        r->noise_app_in_rms = and(r->noise_out_rms r->Hdm_100 r->noise_out_rms / r->Hdm_100)
        r->noise_deemb_in_rms = nsRms(ndm 0.1 250.0)
        r->noise_in_vinp_rms = nsRms(nin 0.1 250.0)
        r->ns_integ_out_V2 = and(r->noise_out_rms r->noise_out_rms ** 2)
        sum = nsSummary(strcat(ocDir "/" tag "_noisesummary_0p1_250.txt") 'integrated 0.1 250.0)
        r->ns_total_V2 = sum->total
        spsWriteWaves(strcat(ocDir "/" tag "_noise.csv") "f_Hz,in_VINP_V_rtHz,out_V_rtHz,out_over_absHdm_V_rtHz"
                      list(nin nout ndm))
        ldWriteCurves(strcat(ocDir "/" tag "_cl_ac.csv") list(list("Hdm" h)))
        ece203SaveNetlist(ocCell(var "tb") strcat("ece203_ota_cmp_" tag "_tb"))
        ;; ---- open-loop A0 ----
        ece203Setup(ocCell(var "ol") strcat("_" tag "ol"))
        ocTight()
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1m" ?stop "100M" ?dec "10")
        ocVars()
        run()
        ol = car(errset(v("/out" ?result "ac") nil))
        unless( ol error("no ac result (open loop)"))
        r->A0_ol_10Hz = ldMag(ol 10.0) r->A0_ol_dB = ece203Db(r->A0_ol_10Hz)
        r->ACL_pred = and(r->A0_ol_10Hz 100.0 * r->A0_ol_10Hz / (r->A0_ol_10Hz + 101.0))
        r->ol_vout = ldDc("out")
        rows = ece203OpDump(strcat(ocDir "/" tag "_ol_dcop.csv") ocInsts(var))
        m = ldMinMargin(rows "XA.") r->ol_margin = car(m) r->ol_worst = cadr(m)
        spsWriteWaves(strcat(ocDir "/" tag "_ol_ac.csv") "f_Hz,absA,phase_deg" list(ece203Mag(ol) ece203Ph(ol)))
        ece203SaveNetlist(ocCell(var "ol") strcat("ece203_ota_cmp_" tag "_ol"))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("ocmp %s: %s %s | Hdm 10/100 %s %s (%s dB) ph %s fL %s fH %s | A0 OL %s (%s dB) pred %s | DC o %s n %s p %s | I %s | margin %s %s, OL vout %s | gm1 %s gmid %s gds2 %s gds4 %s gdsMC %s vdsMC %s | noise out %s app %s deemb %s vinp %s | NS total %s vs integ %s\n"
          tag r->status or(r->reason "") acNum(r->Hdm_10 "%.4g") acNum(r->Hdm_100 "%.4g") acNum(r->Hdm_100_dB "%.2f")
          acNum(r->ph_100 "%.1f") acNum(r->fL "%.4g") acNum(r->fH "%.4g") acNum(r->A0_ol_10Hz "%.4g")
          acNum(r->A0_ol_dB "%.2f") acNum(r->ACL_pred "%.4g") acNum(r->dc_o "%.5g") acNum(r->dc_n "%.5g")
          acNum(r->dc_p "%.5g") acNum(r->I_VDD "%.4g") acNum(r->margin "%.3f") or(r->worst "")
          acNum(r->ol_vout "%.5g") acNum(r->gm_M1 "%.4g") acNum(r->gmid_M1 "%.3g") acNum(r->gds_M2 "%.4g")
          acNum(r->gds_M4 "%.4g") acNum(r->gds_MC "%.4g") acNum(r->vds_MC "%.4g")
          acNum(r->noise_out_rms "%.4g") acNum(r->noise_app_in_rms "%.4g") acNum(r->noise_deemb_in_rms "%.4g")
          acNum(r->noise_in_vinp_rms "%.4g") acNum(r->ns_total_V2 "%.4g") acNum(r->ns_integ_out_V2 "%.4g"))
    r
  )
)

procedure( ocRunJob()
  let( (port)
    ece203LibInfo()
    unless( isDir(ocDir) createDir(ocDir) )
    foreach(v ocVariants ocBuild(v))
    port = outfile(strcat(ocDir "/bpc_summary.csv") "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString ocCols) ","))
    foreach(var ocVariants ocWriteRow(port ocRun(var)))
    close(port)
    t
  )
)

;; ---------------- ADE L states (GUI job): dc op + ac + noise, tight options ----------------
procedure( ocAdeTb(v)
  let( (sess cell)
    cell = ocCell(v "tb")
    sess = acAdeStart(ece203Lib cell)
    unless( sess error("No ADE session for %s\n" cell) )
    acAdeModels(sess "tt")
    acAdeSaveCurrents(sess)
    foreach(o '((gmin "1e-18") (iabstol "1e-18") (reltol "1e-6"))
      acSay("ADE: sim option %L -> %L\n" car(o) car(errset(asiSetSimOptionVal(sess car(o) cadr(o)) nil))))
    acAdeAnalysis(sess 'dc list(list('saveOppoint t)))
    acAdeAnalysis(sess 'ac
      list(list('start "1m") list('stop "100k") list('dec "20"))
      list(list('sweep "freq") list('rangeType "start") list('incrType "log") list('stepTypeLog "decade")))
    acAdeAnalysis(sess 'noise
      list(list('start "100m") list('stop "250") list('dec "20") list('p "/o") list('n "/gnd!") list('inVsrc "/VINP"))
      list(list('sweep "freq") list('rangeType "start") list('incrType "log") list('stepTypeLog "decade")
           list('outType "voltage") list('inType "voltage")))
    acAdeOutput(acAdeSev "Hdm_dB" "db20((VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\"))))")
    acAdeOutput(acAdeSev "Hdm_100Hz" "value(mag((VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\")))) 100)")
    acAdeOutput(acAdeSev "out_noise" "getData(\"out\" ?result \"noise\")")
    acAdeOutput(acAdeSev "I_VDD" "IDC(\"/VDD/PLUS\")")
    acAdeVars(sess
      append(list(list("vdd" "1.8") list("vref" "0.9") list("ib3" "50n") list("cc" "50p") list("cfb" "500f")
                  list("rfb" "3.1831T") list("cl" "0") list("ap" "0.5") list("an" "-0.5") list("vtp" "0")
                  list("ftr" "10"))
             if( v->vcas list(list("vcas" sprintf(nil "%g" ocVcas))) nil)))
    acAdeSave(sess ece203Lib cell "cmp_s2")
    sess
  )
)

procedure( ocAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("ocAde needs the GUI (run.sh ece203_ss_ota_cmp_ade)\n") )
  foreach(v ocVariants ocAdeTb(v))
  t
)
