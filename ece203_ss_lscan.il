;; ece203_ss_lscan.il -- ECE203 Round 3A: 5T input-pair length scan in the single-stage S2 BioAmp.
;; Work order: docs/ECE203_round3a_5t_input_length_scan.md. DC + AC only, L = 1/2/4/8 um, then stop.
;; New isolated cells (library Project); old cells (ece203_a3_ota, ece203_ss_real_tb) are not touched:
;;   ece203_ss_lscan_ota     copy of ece203_a3_ota topology/sizes, M1/M2 W = 10u, L = design variable "lin"
;;   ece203_ss_lscan_tb      Round-3 S2 network (cc 50p, cfb 0.5p, rfb 3.1831T, CL 0) around that OTA
;;   ece203_ss_lscan_ol_tb   open-loop A0 test: VINP = vcm + ac 1, OUT -- RBIG 1T -- INN, INN -- CBIG 1F -- gnd
;;                           (unity follower at DC, open loop above ~1e-12 Hz); A0 read at 1 Hz and 10 Hz
;; Jobs: ece203_ss_lscan (OCEAN), ece203_ss_lscan_ade (@gui: ADE L states lscan_L1u..L8u in both tbs)

lsCells = list(nil 'ota "ece203_ss_lscan_ota" 'tb "ece203_ss_lscan_tb" 'ol "ece203_ss_lscan_ol_tb")
lsDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_ss_lscan")
lsLs = '(1.0 2.0 4.0 8.0)
lsS2 = list(list("cc" 50e-12) list("cfb" 0.5e-12) list("rfb" 3.1831e12) list("cl" 0.0)
            list("ap" 0.5) list("an" -0.5) list("vtp" 0.0))
lsOlVars = list(list("vcm" 0.9) list("rbig" 1e12) list("cbig" 1.0))

procedure( lsDevSpecs()
  mapcar(lambda((d)
           if( member(cadr(d) '("M1" "M2"))
             nsFetSpecVar(nth(0 d) nth(1 d) "10u" "lin" nth(4 d) nth(5 d) nth(6 d) nth(7 d))
             apply('ece203FetSpec d)))
         a3Cfg->devs)
)

procedure( lsInst(conns) list(ece203Lib lsCells->ota "XA" nil conns) )

procedure( lsBuild()
  let( (cv)
    ece203LibInfo()
    cv = acOpenSch(ece203Lib lsCells->ota)
    ece203Pins(cv a3Cfg->pins)
    ece203Place(cv lsDevSpecs())
    ece203Finish(cv ece203Lib lsCells->ota)
    ece203Symbol(ece203Lib lsCells->ota)
    ;; closed loop: identical to ece203_ss_real_tb except the OTA cell
    otaTb(lsCells->tb list(
      ldV("VREF" "vref" "0" "vref" "gnd!")
      ldSin("VINP" "vref" "ap" "vtp" "vinp" "gnd!")
      ldSin("VINN" "vref" "an" "-vtp" "vinn" "gnd!")
      otaC("CCP" "cc" "vinp" "p")  otaC("CCN" "cc" "vinn" "n")
      otaC("CFP" "cfb" "p" "vref") otaR("RFP" "rfb" "p" "vref")
      otaC("CFN" "cfb" "n" "o")    otaR("RFN" "rfb" "n" "o")
      ldProbe("IPRB" "oa" "o")
      otaC("CL" "cl" "o" "gnd!")
      ldV("VDD" "vdd" "0" "vdd" "gnd!")
      otaI("IB" "ib3" "vdd" "ib")
      lsInst('(("INP" "p") ("INN" "n") ("OUT" "oa") ("VDD" "vdd") ("GND" "gnd!") ("IBIAS" "ib")))))
    ;; open loop A0
    otaTb(lsCells->ol list(
      otaV("VDD" "vdd" "0" "vdd" "gnd!")
      otaI("IB" "ib3" "vdd" "ib")
      lsInst('(("INP" "inp") ("INN" "inn") ("OUT" "out") ("VDD" "vdd") ("GND" "gnd!") ("IBIAS" "ib")))
      otaV("VINP" "vcm" "1" "inp" "gnd!")
      otaR("RBIG" "rbig" "out" "inn")
      otaC("CBIG" "cbig" "inn" "gnd!")))
    t
  )
)

lsCols = '(L_um status reason netlist_M1 netlist_M2
  Hdm_100 Hdm_100_dB ph_100 A0_ol_1Hz A0_ol_10Hz A0_ol_10Hz_dB A0_est_gm_gds ACL_pred_from_A0ol pass_38dB
  gm_M1 gm_M2 gds_M2 gds_M4 id_M1 id_M2 gmid_M1 gmid_M2 region_M1 region_M2 vds_M1 vds_M2 vdsat_M2
  margin worst I_VDD P_W dc_o dc_n dc_p ol_vout ol_margin ol_worst ol_I_VDD)

procedure( lsOpen(name)
  let( (port)
    unless( isDir(lsDir) createDir(lsDir) )
    port = outfile(strcat(lsDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString lsCols) ","))
    port
  )
)
procedure( lsWriteRow(port r)
  let( (x first)
    first = t
    foreach(c lsCols
      x = get(r c)
      fprintf(port "%s%s" if( first "" ",")
              cond( (stringp(x) if( rexMatchp("," x) strcat("\"" x "\"") x))
                    (numberp(x) sprintf(nil "%.6g" float(x))) (t "n/a")))
      first = nil)
    fprintf(port "\n")
    drain(port)
  )
)

procedure( lsPv(inst p) car(errset(pv(inst p ?result "dcOpInfo") nil)) )

;; first netlist line of an instance inside the OTA subckt (to verify the L actually used)
procedure( lsNetLine(file inst)
  let( (port line hit)
    when( isFile(file)
      port = infile(file)
      while( !hit && gets(line port)
        when( rexMatchp(strcat("^ *" inst " ") line) hit = line))
      close(port))
    and(hit car(parseString(hit "\n")))
  )
)

procedure( lsPoint(lum)
  let( (r ok tag vp vn h ol rows m nl gds)
    tag = sprintf(nil "L%gu" lum)
    r = list(nil 'L_um lum 'status "ok")
    ok = errset(
      progn(
        ;; ---- closed-loop S2: DC op + differential AC ----
        ece203Setup(lsCells->tb strcat("_" tag))
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1" ?stop "100k" ?dec "20")
        car(errset(save('i "/VDD/PLUS") nil))
        ece203Vars(ssCfg->vars) ece203Vars(lsS2) desVar("lin" lum * 1e-6)
        run()
        vp = ldAc("vinp") vn = ldAc("vinn")
        unless( vp error("no ac result (closed loop)"))
        h = ldDiv(ldAc("o") vp - vn)
        r->Hdm_100 = ldMag(h 100.0) r->Hdm_100_dB = ece203Db(r->Hdm_100) r->ph_100 = ldPh(h 100.0)
        foreach(n '("o" "n" "p") putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        r->I_VDD = ldIdc("/VDD/PLUS") r->P_W = and(r->I_VDD 1.8 * r->I_VDD)
        rows = ece203OpDump(strcat(lsDir "/" tag "_cl_dcop.csv") a3Cfg->insts)
        m = ldMinMargin(rows "XA.") r->margin = car(m) r->worst = cadr(m)
        ;; worst of all six devices incl. MREF as the task asks for "all transistors"
        foreach(row rows
          let( (mm) mm = ece203Margin(caddr(row))
            when( numberp(mm) && (!numberp(r->margin) || mm < r->margin) r->margin = mm r->worst = car(row))))
        foreach(q '(("gm_M1" "/XA/M1" "gm") ("gm_M2" "/XA/M2" "gm") ("gds_M2" "/XA/M2" "gds")
                    ("gds_M4" "/XA/M4" "gds") ("id_M1" "/XA/M1" "id") ("id_M2" "/XA/M2" "id")
                    ("region_M1" "/XA/M1" "region") ("region_M2" "/XA/M2" "region")
                    ("vds_M1" "/XA/M1" "vds") ("vds_M2" "/XA/M2" "vds") ("vdsat_M2" "/XA/M2" "vdsat"))
          putprop(r lsPv(cadr(q) caddr(q)) stringToSymbol(car(q))))
        r->gmid_M1 = and(numberp(r->gm_M1) numberp(r->id_M1) r->gm_M1 / abs(r->id_M1))
        r->gmid_M2 = and(numberp(r->gm_M2) numberp(r->id_M2) r->gm_M2 / abs(r->id_M2))
        gds = and(numberp(r->gds_M2) numberp(r->gds_M4) r->gds_M2 + abs(r->gds_M4))
        r->A0_est_gm_gds = and(gds numberp(r->gm_M1) r->gm_M1 / gds)
        nl = ece203SaveNetlist(lsCells->tb strcat("ece203_lscan_" tag))
        r->netlist_M1 = lsNetLine(nl "M1") r->netlist_M2 = lsNetLine(nl "M2")
        ldWriteCurves(strcat(lsDir "/" tag "_cl_ac.csv") list(list("Hdm" h)))
        ;; ---- open-loop A0 ----
        ece203Setup(lsCells->ol strcat("_" tag "ol"))
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1m" ?stop "100M" ?dec "10")
        car(errset(save('i "/VDD/PLUS") nil))
        ece203Vars(ssCfg->vars) ece203Vars(lsOlVars) desVar("lin" lum * 1e-6)
        run()
        ol = car(errset(v("/out" ?result "ac") nil))
        unless( ol error("no ac result (open loop)"))
        r->A0_ol_1Hz = ldMag(ol 1.0) r->A0_ol_10Hz = ldMag(ol 10.0) r->A0_ol_10Hz_dB = ece203Db(r->A0_ol_10Hz)
        r->ACL_pred_from_A0ol = and(r->A0_ol_10Hz 100.0 * r->A0_ol_10Hz / (r->A0_ol_10Hz + 101.0))
        r->ol_vout = ldDc("out") r->ol_I_VDD = ldIdc("/VDD/PLUS")
        rows = ece203OpDump(strcat(lsDir "/" tag "_ol_dcop.csv") a3Cfg->insts)
        m = ldMinMargin(rows "XA.") r->ol_margin = car(m) r->ol_worst = cadr(m)
        spsWriteWaves(strcat(lsDir "/" tag "_ol_ac.csv") "f_Hz,absA,phase_deg" list(ece203Mag(ol) ece203Ph(ol)))
        ece203SaveNetlist(lsCells->ol strcat("ece203_lscanol_" tag))
        r->pass_38dB = if( and(r->Hdm_100 r->Hdm_100 >= 79.4) "yes" "no")
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("lscan %s: %s %s | |Hdm(100)| %s (%s dB) | A0 OL 1/10 Hz %s %s (%s dB), gm/gds est %s, pred ACL %s | gm1 %s gds2 %s gds4 %s id1 %s gm/Id %s reg %s | margin %s %s | I %s | DC o %s n %s | OL vout %s margin %s | %s\n"
          tag r->status or(r->reason "") acNum(r->Hdm_100 "%.4g") acNum(r->Hdm_100_dB "%.2f")
          acNum(r->A0_ol_1Hz "%.4g") acNum(r->A0_ol_10Hz "%.4g") acNum(r->A0_ol_10Hz_dB "%.2f")
          acNum(r->A0_est_gm_gds "%.4g") acNum(r->ACL_pred_from_A0ol "%.4g")
          acNum(r->gm_M1 "%.4g") acNum(r->gds_M2 "%.4g") acNum(r->gds_M4 "%.4g") acNum(r->id_M1 "%.4g")
          acNum(r->gmid_M1 "%.3g") acNum(r->region_M1 "%g") acNum(r->margin "%.3f") or(r->worst "")
          acNum(r->I_VDD "%.4g") acNum(r->dc_o "%.5g") acNum(r->dc_n "%.5g") acNum(r->ol_vout "%.5g")
          acNum(r->ol_margin "%.3f") or(r->netlist_M1 ""))
    r
  )
)

procedure( lsRunJob()
  let( (port)
    lsBuild()
    port = lsOpen("length_scan.csv")
    foreach(l lsLs lsWriteRow(port lsPoint(l)))
    close(port)
    t
  )
)

;; ---------------- ADE L states (GUI job): DC op + AC only ----------------
procedure( lsAdeTb(cell ol)
  let( (sess)
    sess = acAdeStart(ece203Lib cell)
    unless( sess error("No ADE session for %s\n" cell) )
    acAdeModels(sess "tt")
    acAdeSaveCurrents(sess)
    acAdeAnalysis(sess 'dc list(list('saveOppoint t)))
    acAdeAnalysis(sess 'ac
      list(list('start if( ol "1m" "1")) list('stop if( ol "100M" "100k")) list('dec if( ol "10" "20")))
      list(list('sweep "freq") list('rangeType "start") list('incrType "log") list('stepTypeLog "decade")))
    if( ol
      then
        acAdeOutput(acAdeSev "A0_dB" "db20(VF(\"/out\"))")
        acAdeOutput(acAdeSev "A0_10Hz" "value(mag(VF(\"/out\")) 10)")
      else
        acAdeOutput(acAdeSev "Hdm_dB" "db20((VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\"))))")
        acAdeOutput(acAdeSev "Hdm_100Hz" "value(mag((VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\")))) 100)"))
    acAdeOutput(acAdeSev "I_VDD" "IDC(\"/VDD/PLUS\")")
    foreach(p '(("M1_gm" "/XA/M1" "gm") ("M1_id" "/XA/M1" "id") ("M2_gds" "/XA/M2" "gds")
                ("M4_gds" "/XA/M4" "gds") ("M1_region" "/XA/M1" "region"))
      acAdeOutput(acAdeSev car(p) sprintf(nil "OP(\"%s\" \"%s\")" cadr(p) caddr(p))))
    foreach(l lsLs
      acAdeVars(sess
        append(list(list("vdd" "1.8") list("vref" "0.9") list("ib3" "50n") list("lin" sprintf(nil "%gu" l)))
               if( ol
                 list(list("vcm" "0.9") list("rbig" "1T") list("cbig" "1"))
                 list(list("cc" "50p") list("cfb" "500f") list("rfb" "3.1831T") list("cl" "0")
                      list("ap" "0.5") list("an" "-0.5") list("vtp" "0") list("ftr" "10")))))
      acAdeSave(sess ece203Lib cell sprintf(nil "lscan_L%gu" l)))
    sess
  )
)

procedure( lsAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("lsAde needs the GUI (run.sh ece203_ss_lscan_ade)\n") )
  lsAdeTb(lsCells->tb nil)
  lsAdeTb(lsCells->ol t)
  t
)
