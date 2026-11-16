;; ece203_ss.il -- ECE203 Round 3: classroom single-stage capacitively coupled BioAmp (Lec8-10 p.23-27).
;; Work order: docs/ECE203_round3_single_stage_bioamp_task.md. Old cells are only instantiated
;; (ece203_a3_ota = the ordinary 5T OTA, frozen sizes/bias), never rebuilt.
;;
;; New cells (library Project):
;;   ece203_ss_ideal_tb  ONE differential amplifier = ideal VCVS (gain aol) + the classroom network
;;   ece203_ss_real_tb   same network, amplifier = Project/ece203_a3_ota (5T, ib3 = 50 nA from VDD)
;; Network (both tbs, symmetric):
;;   VINN -- CCN (cc) -- n (OTA INN);  n -- CFN (cfb) || RFN (rfb) -- o   (negative feedback)
;;   VINP -- CCP (cc) -- p (OTA INP);  p -- CFP (cfb) || RFP (rfb) -- vref (reference branch)
;;   OTA OUT = oa -- IPRB (iprobe, 0 V except in stb) -- o ;  CL (cl) from o to ground.
;;   Ideal: o = +(cc/cfb) (vinp - vinn).  No electrodes, body, DRL, no output RC.
;; Configurations: S1 cc 50 p, cfb 5 p, rfb 318.31 G (|A| 10);  S2 cc 50 p, cfb 0.5 p, rfb 3.1831 T (|A| 100).
;; Jobs: ece203_ss_run (build + OCEAN A-D), ece203_ss_ade (@gui: ADE L states ss_S1 / ss_S2 in both tbs).

ssDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_ss")
ssCells = list(nil 'ideal "ece203_ss_ideal_tb" 'real "ece203_ss_real_tb")
ssCfg = list(nil
  'vars list(list("vdd" 1.8) list("vref" 0.9) list("ib3" 50e-9) list("aol" 1e5)
             list("cc" 50e-12) list("cfb" 5e-12) list("rfb" 318.31e9) list("cl" 0.0)
             list("ap" 0.5) list("an" -0.5) list("vtp" 0.0) list("ftr" 10.0))
  'S list(list("S1" 50e-12 5e-12 318.31e9) list("S2" 50e-12 0.5e-12 3.1831e12))
  'fStart "1m" 'fStop "100k" 'dec "20")

;; ---------------- testbenches ----------------
procedure( ssSpecs(real)
  append(
    list(ldV("VREF" "vref" "0" "vref" "gnd!")
         ldSin("VINP" "vref" "ap" "vtp" "vinp" "gnd!")
         ldSin("VINN" "vref" "an" "-vtp" "vinn" "gnd!")
         otaC("CCP" "cc" "vinp" "p")
         otaC("CCN" "cc" "vinn" "n")
         otaC("CFP" "cfb" "p" "vref")
         otaR("RFP" "rfb" "p" "vref")
         otaC("CFN" "cfb" "n" "o")
         otaR("RFN" "rfb" "n" "o")
         ldProbe("IPRB" "oa" "o")
         otaC("CL" "cl" "o" "gnd!"))
    if( real
      list(ldV("VDD" "vdd" "0" "vdd" "gnd!")
           otaI("IB" "ib3" "vdd" "ib")
           list(ece203Lib "ece203_a3_ota" "XA" nil
                '(("INP" "p") ("INN" "n") ("OUT" "oa") ("VDD" "vdd") ("GND" "gnd!") ("IBIAS" "ib"))))
      list(ldE("E1" "p" "n" "oa" "gnd!" "aol"))))
)

procedure( ssBuild()
  ece203LibInfo()
  otaTb(ssCells->ideal ssSpecs(nil))
  otaTb(ssCells->real ssSpecs(t))
  t
)

;; ---------------- measurement ----------------
ssCols = '(tag cell variant config cc cfb rfb cl status reason
  I_VDD P_W dc_o dc_p dc_n dc_vref
  gain_0p1 ph_0p1 gain_10 gain_60 gain_100 dB_100 ph_100 gain_max dB_max fL fH ideal_gain shortfall_dB_100
  G_P_100 G_N_100 CM_60 CMRR_60_dB
  gain_100_cl5 fH_cl5
  ugf pm LG_10
  margin worst cgg_M1 cgg_M2 cgs_M1 gm_M1 gds_M2 gds_M4 id_M1
  noise_in_vinp_rms noise_out_rms noise_dm_rms
  tran1_vdpk tran1_pp tran1_gain tran2_vdpk tran2_pp tran2_gain)

procedure( ssOpen(name)
  let( (port)
    unless( isDir(ssDir) createDir(ssDir) )
    port = outfile(strcat(ssDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString ssCols) ","))
    port
  )
)
procedure( ssWriteRow(port r)
  let( (x first)
    first = t
    foreach(c ssCols
      x = get(r c)
      fprintf(port "%s%s" if( first "" ",")
              cond( (stringp(x) if( rexMatchp("," x) strcat("\"" x "\"") x))
                    (numberp(x) sprintf(nil "%.6g" float(x))) (t "n/a")))
      first = nil)
    fprintf(port "\n")
    drain(port)
  )
)

procedure( ssVars(over)
  ece203Vars(ssCfg->vars)
  ece203Vars(over)
)

procedure( ssSetup(cell tag noise)
  ece203Setup(cell strcat("_" tag))
  analysis('dc ?saveOppoint t)
  analysis('ac ?start ssCfg->fStart ?stop ssCfg->fStop ?dec ssCfg->dec)
  when( noise
    ;; same grid as ac so out/|Hdm| can be formed point by point
    analysis('noise ?start ssCfg->fStart ?stop ssCfg->fStop ?dec ssCfg->dec ?p "/o" ?n "/gnd!" ?iprobe "/VINP"))
  when( cell == ssCells->real car(errset(save('i "/VDD/PLUS") nil)))
  t
)

;; one configuration of one testbench; real = t for the transistor OTA
procedure( ssRun(cell tag config sOver real)
  let( (r ok vp vn h c pw nw cw s nin nout ndm cl5 tr pp sum op m)
    r = list(nil 'tag tag 'cell cell 'config config 'status "ok"
             'variant if( real "real 5T ece203_a3_ota (frozen)" "ideal VCVS aol 1e5"))
    foreach(p sOver putprop(r cadr(p) stringToSymbol(car(p))))
    unless( r->cl r->cl = 0.0)
    r->ideal_gain = r->cc / r->cfb
    ok = errset(
      progn(
        ;; ---- A/B: differential AC + DC op + noise ----
        ssSetup(cell tag t)
        ssVars(append(sOver list(list("ap" 0.5) list("an" -0.5))))
        run()
        vp = ldAc("vinp") vn = ldAc("vinn")
        unless( vp error("no ac result"))
        h = ldDiv(ldAc("o") vp - vn)
        r->gain_0p1 = ldMag(h 0.1) r->ph_0p1 = ldPh(h 0.1)
        foreach(f '(10.0 60.0 100.0) putprop(r ldMag(h f) stringToSymbol(sprintf(nil "gain_%d" fix(f)))))
        r->dB_100 = ece203Db(r->gain_100) r->ph_100 = ldPh(h 100.0)
        c = ldCorners(h) r->gain_max = car(c) r->dB_max = ece203Db(car(c)) r->fL = cadr(c) r->fH = caddr(c)
        r->shortfall_dB_100 = and(r->gain_100 ece203Db(r->gain_100) - ece203Db(r->ideal_gain))
        foreach(n '("o" "p" "n" "vref") putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        when( real
          r->I_VDD = ldIdc("/VDD/PLUS") r->P_W = and(r->I_VDD 1.8 * r->I_VDD)
            op = ece203OpDump(strcat(ssDir "/" tag "_dcop.csv") '("XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.MT" "XA.MREF"))
          m = ldMinMargin(op "XA.") r->margin = car(m) r->worst = cadr(m)
          foreach(q '(("cgg_M1" "/XA/M1" "cgg") ("cgg_M2" "/XA/M2" "cgg") ("cgs_M1" "/XA/M1" "cgs")
                      ("gm_M1" "/XA/M1" "gm") ("gds_M2" "/XA/M2" "gds") ("gds_M4" "/XA/M4" "gds") ("id_M1" "/XA/M1" "id"))
            putprop(r car(errset(pv(cadr(q) caddr(q) ?result "dcOpInfo") nil)) stringToSymbol(car(q)))))
        nin = car(errset(getData("in" ?result "noise") nil))
        nout = car(errset(getData("out" ?result "noise") nil))
        ndm = and(nout h car(errset(nout / mag(h) nil)))
        r->noise_in_vinp_rms = nsRms(nin 0.1 250.0)
        r->noise_out_rms = nsRms(nout 0.1 250.0)
        r->noise_dm_rms = nsRms(ndm 0.1 250.0)
        sum = nsSummary(strcat(ssDir "/" tag "_noisesummary_0p1_250.txt") 'integrated 0.1 250.0)
        spsWriteWaves(strcat(ssDir "/" tag "_noise.csv") "f_Hz,in_VINP_V_rtHz,out_V_rtHz,out_over_absHdm_V_rtHz"
                      list(nin nout ndm))
        ;; ---- single-ended and common-mode ----
        ssVars(append(sOver list(list("ap" 1.0) list("an" 0.0)))) run()
        pw = ldDiv(ldAc("o") ldAc("vinp"))
        ssVars(append(sOver list(list("ap" 0.0) list("an" 1.0)))) run()
        nw = ldDiv(ldAc("o") ldAc("vinn"))
        ssVars(append(sOver list(list("ap" 0.5) list("an" 0.5)))) run()
        cw = ldDiv(ldAc("o") (ldAc("vinp") + ldAc("vinn")) / 2.0)
        r->G_P_100 = ldMag(pw 100.0) r->G_N_100 = ldMag(nw 100.0) r->CM_60 = ldMag(cw 60.0)
        r->CMRR_60_dB = and(r->CM_60 r->CM_60 > 0 r->gain_60 ece203Db(r->gain_60 / r->CM_60))
        ;; ---- CL = 5 pF ----
        ssVars(append(sOver list(list("ap" 0.5) list("an" -0.5) list("cl" 5e-12)))) run()
        cl5 = ldDiv(ldAc("o") ldAc("vinp") - ldAc("vinn"))
        r->gain_100_cl5 = ldMag(cl5 100.0) r->fH_cl5 = caddr(ldCorners(cl5))
        ldWriteCurves(strcat(ssDir "/" tag "_ac.csv")
                      list(list("Hdm" h) list("Hdm_cl5" cl5) list("G_P" pw) list("G_N" nw) list("CM" cw)))
        ;; ---- C: stb ----
        ece203Setup(cell strcat("_" tag "stb"))
        analysis('stb ?start "1m" ?stop "100M" ?dec "10" ?probe "/IPRB")
        ssVars(sOver)
        run()
        s = otaStb()
        r->ugf = car(s) r->pm = cadr(s) r->LG_10 = and(cadddr(s) ldMag(cadddr(s) 10.0))
        ldWriteCurves(strcat(ssDir "/" tag "_stb.csv") list(list("LG" cadddr(s))))
        ;; ---- D: 10 Hz transient, vd peak = 2 vtp ----
        foreach(k '(1 2)
          ece203Setup(cell strcat("_" tag "tr" sprintf(nil "%d" k)))
          analysis('tran ?stop "0.5" ?maxstep "0.25m")
          ssVars(append(sOver list(list("vtp" if( k == 1 0.5e-3 2.5e-3)) list("ap" 0.0) list("an" 0.0))))
          run()
          tr = car(errset(v("/o" ?result "tran") nil))
          pp = and(tr car(errset(ymax(clip(tr 0.4 0.5)) - ymin(clip(tr 0.4 0.5)) nil)))
          putprop(r if( k == 1 1e-3 5e-3) stringToSymbol(sprintf(nil "tran%d_vdpk" k)))
          putprop(r pp stringToSymbol(sprintf(nil "tran%d_pp" k)))
          putprop(r and(pp pp / (2.0 * if( k == 1 1e-3 5e-3))) stringToSymbol(sprintf(nil "tran%d_gain" k)))
          spsWriteWaves(strcat(ssDir "/" tag sprintf(nil "_tran%d.csv" k)) "t_s,o_V,vinp_V,vinn_V"
                        list(tr car(errset(v("/vinp" ?result "tran") nil)) car(errset(v("/vinn" ?result "tran") nil)))))
        ece203SaveNetlist(cell strcat("ece203_" tag))
        t)
      t)
    unless( ok r->status = "error" r->reason = sprintf(nil "%L" errset.errset))
    acSay("ss %s: %s %s | |Hdm| 0.1/10/60/100 Hz %s %s %s %s (ideal %s, %s dB short @100) max %s dB fL %s fH %s | P/N %s %s CM60 %s | CL5 %s fH %s | UGF %s PM %s LG10 %s | DC o %s p %s n %s | I %s margin %s %s | noise in(VINP) %s out %s dm %s | tran %s %s\n"
          tag r->status or(r->reason "") acNum(r->gain_0p1 "%.4g") acNum(r->gain_10 "%.4g") acNum(r->gain_60 "%.4g")
          acNum(r->gain_100 "%.4g") acNum(r->ideal_gain "%g") acNum(r->shortfall_dB_100 "%.2f") acNum(r->dB_max "%.2f")
          acNum(r->fL "%.4g") acNum(r->fH "%.4g") acNum(r->G_P_100 "%.4g") acNum(r->G_N_100 "%.4g") acNum(r->CM_60 "%.3g")
          acNum(r->gain_100_cl5 "%.4g") acNum(r->fH_cl5 "%.4g") acNum(r->ugf "%.4g") acNum(r->pm "%.1f") acNum(r->LG_10 "%.4g")
          acNum(r->dc_o "%.5g") acNum(r->dc_p "%.5g") acNum(r->dc_n "%.5g") acNum(r->I_VDD "%.4g") acNum(r->margin "%.3f")
          or(r->worst "") acNum(r->noise_in_vinp_rms "%.4g") acNum(r->noise_out_rms "%.4g") acNum(r->noise_dm_rms "%.4g")
          acNum(r->tran1_gain "%.4g") acNum(r->tran2_gain "%.4g"))
    r
  )
)

procedure( ssRunJob()
  let( (port over)
    ssBuild()
    port = ssOpen("ece203_ss_summary.csv")
    foreach(s ssCfg->S
      over = list(list("cc" cadr(s)) list("cfb" caddr(s)) list("rfb" cadddr(s)))
      ssWriteRow(port ssRun(ssCells->ideal strcat("A_ideal_" car(s)) car(s) over nil))
      ssWriteRow(port ssRun(ssCells->real strcat("B_real_" car(s)) car(s) over t)))
    close(port)
    t
  )
)

;; ---------------- ADE L states (GUI job) ----------------
procedure( ssAdeOne(cell real)
  let( (sess)
    sess = acAdeStart(ece203Lib cell)
    unless( sess error("No ADE session for %s\n" cell) )
    acAdeModels(sess "tt")
    when( real acAdeSaveCurrents(sess))
    acAdeAnalysis(sess 'dc list(list('saveOppoint t)))
    acAdeAnalysis(sess 'ac
      list(list('start ssCfg->fStart) list('stop ssCfg->fStop) list('dec ssCfg->dec))
      list(list('sweep "freq") list('rangeType "start") list('incrType "log") list('stepTypeLog "decade")))
    acAdeAnalysis(sess 'noise
      list(list('start "100m") list('stop "250") list('dec ssCfg->dec)
           list('p "/o") list('n "/gnd!") list('inVsrc "/VINP"))
      list(list('sweep "freq") list('rangeType "start") list('incrType "log") list('stepTypeLog "decade")
           list('outType "voltage") list('inType "voltage")))
    acAdeAnalysis(sess 'tran list(list('stop "0.5")))
    when( real acAdeProbe(sess 'stb))
    acAdeAnalysis(sess 'stb
      list(list('start "1m") list('stop "100M") list('dec "10") list('probe "/IPRB"))
      list(list('sweep "freq") list('rangeType "start") list('incrType "log") list('stepTypeLog "decade")))
    acAdeOutput(acAdeSev "Hdm" "(VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\")))")
    acAdeOutput(acAdeSev "Hdm_dB" "db20((VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\"))))")
    acAdeOutput(acAdeSev "gain_100Hz" "value(mag((VF(\"/o\") / (VF(\"/vinp\") - VF(\"/vinn\")))) 100)")
    acAdeOutput(acAdeSev "vout_tran" "VT(\"/o\")")
    acAdeOutput(acAdeSev "out_noise" "getData(\"out\" ?result \"noise\")")
    acAdeOutput(acAdeSev "loopGain" "getData(\"loopGain\" ?result \"stb\")")
    when( real
      acAdeOutput(acAdeSev "I_VDD" "IDC(\"/VDD/PLUS\")")
      foreach(p '(("M1_gm" "gm") ("M1_id" "id") ("M1_region" "region"))
        acAdeOutput(acAdeSev car(p) sprintf(nil "OP(\"/XA/M1\" \"%s\")" cadr(p)))))
    foreach(s ssCfg->S
      acAdeVars(sess
        list(list("vdd" "1.8") list("vref" "0.9") list("ib3" "50n") list("aol" "1e5")
             list("cc" sprintf(nil "%g" cadr(s))) list("cfb" sprintf(nil "%g" caddr(s)))
             list("rfb" sprintf(nil "%g" cadddr(s))) list("cl" "0")
             list("ap" "0.5") list("an" "-0.5") list("vtp" "0.5m") list("ftr" "10")))
      acAdeSave(sess ece203Lib cell strcat("ss_" car(s))))
    sess
  )
)

procedure( ssAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("ssAde needs the GUI (run.sh ece203_ss_ade)\n") )
  ssAdeOne(ssCells->ideal nil)
  ssAdeOne(ssCells->real t)
  t
)
