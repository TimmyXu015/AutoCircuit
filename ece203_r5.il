;; ece203_r5.il -- ECE203 Round 5: OTA output architectures (ideal BUF / CD / CS two-stage) x stage noise x
;; chopper demodulation placement. Work order: docs/ECE203_round5_ota_stage_noise_chopper_placement_bigrun.md.
;; New cells only (Project/ece203_r5_*); Round 3/4 cells are instantiated, never rebuilt.
;;
;; Isolated S2 bench ece203_r5_s2_<stage>_<slot> (one wiring for every case):
;;   VINP/VINN (vpulse: DC vref, step vst at tst, ac +-adm/2, pac 0.5 / 180 deg) -CCP/CCN(cc)- p / n
;;   p -(CFP cfb || RFP rfb)- vref ;  n -(CFN cfb || RFN rfb)- fb            (fb = feedback pickoff, BEFORE LP)
;;   input commutator S1P p->ia, S1N n->ib_ (ck1); S2P n->ia, S2N p->ib_ (ck2)
;;   OTA1 = XA Project/ece203_r4_ota (frozen Round-4 C OTA, VCAS 1.10): INP ia / INN ib_ (swapped for the
;;          inverting CS stage so the loop stays negative), OUT oa1
;;   slot 1 (d1): demod  oa1 -> d1 (ck1), EIN1 = 2*vr1 - oa1 -> d1 (ck2)   | or 0 V pass oa1 -> d1
;;   stage:  none (0 V pass d1 -> oa2) | ibuf (ideal VCVS x1, diagnostic) | cd (X2 ece203_r5_cd, NMOS source
;;           follower) | cs (X2 ece203_r5_cs, PMOS common source + CM2 Miller cap d1 <-> oa2)
;;   slot 2 (d2): demod  oa2 -> d2 (ck1), EIN2 = 2*vref - oa2 -> d2 (ck2)  | or 0 V pass oa2 -> d2
;;   IPRB d2 -> fb (main-loop stb probe);  LP: RLP (rlp) fb -> out, CLP (clp) out -> gnd;  IZ ac current into fb (Zout)
;;   supplies: VDD (OTA1 + IB), VDD2 (OTA2 only), ideal VREF, VCAS, IB 50 nA (diagnostic, as Round-4 A/B),
;;   VR1 ideal reference for the slot-1 inverter (set to the measured OTA1 output DC). OTA2 bias = OTA1 IBIAS node.
;;   chen = 0 freezes the clock in phase 1 -> both slots are plain wires (static / unchopped bench).
;; All runs: gmin = iabstol = 1e-18, reltol 1e-6.

r5Dir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r5")
r5Vars = list(list("vdd" 1.8) list("vref" 0.9) list("vcas" 1.10) list("ib3" 50e-9) list("cc" 50e-12)
  list("cfb" 0.5e-12) list("rfb" 3.1831e12) list("rlp" 31.8e6) list("clp" 20e-12) list("adm" 1.0) list("pacd" 0.5)
  list("vst" 0.0) list("tst" 1.0) list("tch" 250e-6) list("chen" 0.0) list("vr1" 0.9) list("cm2" 0.5e-12) list("izac" 0.0))

procedure( r5Cell(stage slot) sprintf(nil "ece203_r5_s2_%s_%s" stage slot) )

;; ---------- OTA2 cells ----------
r5Ota2 = list(nil
  'cd list("ece203_r5_cd" list(list("nfetx" "MSF" 4e-6 1e-6 "VDD" "IN" "OUT" "GND")
                               list("nfetx" "MSB" 2e-6 4e-6 "OUT" "BIAS" "GND" "GND")))
  'cs list("ece203_r5_cs" list(list("pfetx" "MCS" 4e-6 2e-6 "OUT" "IN" "VDD" "VDD")
                               list("nfetx" "MCL" 2e-6 4e-6 "OUT" "BIAS" "GND" "GND"))))

procedure( r5BuildOta2(key)
  let( (d cv cell)
    d = get(r5Ota2 key) cell = car(d)
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv '(("IN" "input") ("OUT" "output") ("VDD" "inputOutput") ("GND" "inputOutput") ("BIAS" "input")))
    ece203Place(cv mapcar(lambda((x) apply('ece203FetSpec x)) cadr(d)))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
    cell
  )
)

procedure( r5Pulse(name v1 v2 acm pacp net)
  list("analogLib" "vpulse" name
       list(list("dc" v1) list("v1" v1) list("v2" v2) list("td" "tst") list("tr" "1n") list("tf" "1n")
            list("pw" "1") list("per" "2") list("acm" acm) list("pacm" "pacd") list("pacp" pacp))
       list(list("PLUS" net) list("MINUS" "gnd!")))
)

procedure( r5Specs(stage slot)
  append(append(append(
    list(otaV("VREF" "vref" "0" "vref" "gnd!")
         otaV("VCAS" "vcas" "0" "vcas" "gnd!")
         otaV("VDD" "vdd" "0" "vdd" "gnd!")
         otaV("VDD2" "vdd" "0" "vdd2" "gnd!")
         otaV("VR1" "vr1" "0" "vr1" "gnd!")
         otaI("IB" "ib3" "vdd" "ib")
         r5Pulse("VINP" "vref" "vref+vst/2" "adm/2" "0" "vinp")
         r5Pulse("VINN" "vref" "vref-vst/2" "-adm/2" "180" "vinn")
         r4Clk("VCK1" "1.8" "1.8*(1-chen)" "tch/2" "tch/2-1n" "ck1")
         r4Clk("VCK2" "0" "1.8*chen" "tch/2+10n" "tch/2-21n" "ck2")
         otaC("CCP" "cc" "vinp" "p") otaC("CCN" "cc" "vinn" "n")
         otaC("CFP" "cfb" "p" "vref") otaR("RFP" "rfb" "p" "vref")
         otaC("CFN" "cfb" "n" "fb") otaR("RFN" "rfb" "n" "fb")
         chSw("S1P" "p" "ia" "ck1") chSw("S1N" "n" "ib_" "ck1")
         chSw("S2P" "n" "ia" "ck2") chSw("S2N" "p" "ib_" "ck2")
         list(ece203Lib r4Cells->ota "XA" nil
              list(list("INP" if( stage == "cs" "ib_" "ia")) list("INN" if( stage == "cs" "ia" "ib_"))
                   list("OUT" "oa1") list("VDD" "vdd") list("GND" "gnd!") list("IBIAS" "ib") list("VCAS" "vcas"))))
    if( slot == "d1"
      list(ldE("EIN1" "oa1" "vr1" "oi1" "vr1" "-1") chSw("S31" "oa1" "d1" "ck1") chSw("S41" "oi1" "d1" "ck2"))
      list(otaV("VP1" "0" "0" "oa1" "d1"))))
    cond(
      (stage == "none" list(otaV("VP2" "0" "0" "d1" "oa2")))
      (stage == "ibuf" list(ldE("EBUF" "d1" "gnd!" "oa2" "gnd!" "1")))
      (stage == "cd" list(list(ece203Lib "ece203_r5_cd" "X2" nil
                               '(("IN" "d1") ("OUT" "oa2") ("VDD" "vdd2") ("GND" "gnd!") ("BIAS" "ib")))))
      (t list(list(ece203Lib "ece203_r5_cs" "X2" nil
                   '(("IN" "d1") ("OUT" "oa2") ("VDD" "vdd2") ("GND" "gnd!") ("BIAS" "ib")))
              otaC("CM2" "cm2" "d1" "oa2")))))
    append(
      if( slot == "d2"
        list(ldE("EIN2" "oa2" "vref" "oi2" "vref" "-1") chSw("S32" "oa2" "d2" "ck1") chSw("S42" "oi2" "d2" "ck2"))
        list(otaV("VP3" "0" "0" "oa2" "d2")))
      list(ldProbe("IPRB" "d2" "fb")
           otaR("RLP" "rlp" "fb" "out") otaC("CLP" "clp" "out" "gnd!")
           list("analogLib" "idc" "IZ" '(("idc" "0") ("acm" "izac")) '(("PLUS" "gnd!") ("MINUS" "fb"))))))
)

procedure( r5BuildTb(stage slot)
  ece203LibInfo()
  when( member(stage '("cd" "cs")) r5BuildOta2(stringToSymbol(stage)))
  otaTb(r5Cell(stage slot) r5Specs(stage slot))
  r5Cell(stage slot)
)

;; ---------- measurement ----------
procedure( r5Set(over) ece203Vars(r5Vars) ece203Vars(over) )
procedure( r5Open(name cols)
  let( (port)
    unless( isDir(r5Dir) createDir(r5Dir) )
    port = outfile(strcat(r5Dir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
r5Insts = '("XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.MC" "XA.MT" "XA.MREF" "X2.MSF" "X2.MSB" "X2.MCS" "X2.MCL")

;; noise sub-bands (log) for pointwise de-embedding per source
r5Bins = '(0.1 0.168 0.282 0.473 0.794 1.33 2.24 3.76 6.31 10.6 17.8 29.9 50.2 84.3 141.6 250.0)

r5Cols = '(tag cell stage slot kind status reason H10 H60 H100 H100_dB ph100 Hmax_dB fL fH Hfb100 fH_fb Ho1_100
  dc_oa1 dc_oa2 dc_fb dc_out dc_n dc_p I_VDD I_VDD2 margin_A worst_A margin_2 worst_2
  Zcl_10 Zcl_100 Zcl_250 ugf pm lg10 lg100 lg_dc ph0
  noise_out_rms noise_app_in noise_deemb_in)

procedure( r5Run(port stage slot tag over noise stb)
  let( (cell r ok vp vn h hf ho1 c cf rows m nout nin s)
    cell = r5Cell(stage slot)
    r = list(nil 'tag tag 'cell cell 'stage stage 'slot slot 'kind "dm" 'status "ok")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        r4Tight()
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1m" ?stop "100k" ?dec "20")
        when( noise
          analysis('noise ?start "1m" ?stop "100k" ?dec "20" ?p "/out" ?n "/gnd!" ?iprobe "/VINP"))
        car(errset(save('i "/VDD/PLUS" "/VDD2/PLUS") nil))
        r5Set(over)
        run()
        vp = ldAc("vinp") vn = ldAc("vinn")
        unless( vp error("no ac result"))
        h = ldDiv(ldAc("out") vp - vn) hf = ldDiv(ldAc("fb") vp - vn) ho1 = ldDiv(ldAc("oa1") vp - vn)
        foreach(f '(10.0 60.0 100.0) putprop(r ldMag(h f) stringToSymbol(sprintf(nil "H%d" fix(f)))))
        r->H100_dB = ece203Db(r->H100) r->ph100 = ldPh(h 100.0)
        c = r4Corners(h) r->Hmax_dB = ece203Db(car(c)) r->fL = cadr(c) r->fH = caddr(c)
        cf = r4Corners(hf) r->Hfb100 = ldMag(hf 100.0) r->fH_fb = caddr(cf)
        r->Ho1_100 = ldMag(ho1 100.0)
        foreach(n '("oa1" "oa2" "fb" "out" "n" "p") putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDD2 = ldIdc("/VDD2/PLUS")
        rows = ece203OpDump(strcat(r5Dir "/" tag "_dcop.csv") r5Insts)
        m = ldMinMargin(rows "XA.") r->margin_A = car(m) r->worst_A = cadr(m)
        m = ldMinMargin(rows "X2.") r->margin_2 = car(m) r->worst_2 = cadr(m)
        ldWriteCurves(strcat(r5Dir "/" tag "_ac.csv") list(list("Hout" h) list("Hfb" hf) list("Hoa1" ho1)))
        when( noise
          nout = car(errset(getData("out" ?result "noise") nil))
          nin = and(nout car(errset(nout / mag(h) nil)))
          r->noise_out_rms = nsRms(nout 0.1 250.0)
          r->noise_app_in = and(r->noise_out_rms r->noise_out_rms / r->H100)
          r->noise_deemb_in = nsRms(nin 0.1 250.0)
          spsWriteWaves(strcat(r5Dir "/" tag "_noise.csv") "f_Hz,out_V_rtHz,deemb_in_V_rtHz" list(nout nin))
          nsSummary(strcat(r5Dir "/" tag "_ns_full.txt") 'integrated 0.1 250.0)
          for(k 0 length(r5Bins) - 2
            nsSummary(strcat(r5Dir "/" tag sprintf(nil "_ns_b%02d.txt" k)) 'integrated nth(k r5Bins) nth(k + 1 r5Bins))))
        ece203SaveNetlist(cell strcat("ece203_r5_" tag))
        ;; main-loop stb (probe IPRB between the last stage / demod and the feedback pickoff)
        when( stb
          ece203Setup(cell strcat("_" tag "_stb"))
          r4Tight()
          analysis('stb ?start "1m" ?stop "100M" ?dec "20" ?probe "/IPRB")
          r5Set(over)
          run()
          s = otaStb()
          r->ugf = nth(0 s) r->pm = nth(1 s) r->ph0 = nth(4 s)
          r->lg10 = and(nth(3 s) ldMag(nth(3 s) 10.0)) r->lg100 = and(nth(3 s) ldMag(nth(3 s) 100.0))
          r->lg_dc = and(nth(3 s) ldMag(nth(3 s) 1e-3))
          ldWriteCurves(strcat(r5Dir "/" tag "_stb.csv") list(list("LG" nth(3 s)))))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r5 %s: %s %s | H out 10/60/100 %s %s %s (%s dB, ph %s) max %s dB fL %s fH %s | fb H100 %s fH %s | oa1/vd %s | DC oa1 %s oa2 %s fb %s n %s | I %s %s | margin A %s %s, 2 %s %s | stb UGF %s PM %s LG10 %s LGdc %s ph0 %s | noise out %s app %s deemb %s\n"
          tag r->status or(r->reason "") r4Num(r->H10 "%.4g") r4Num(r->H60 "%.4g") r4Num(r->H100 "%.4g")
          r4Num(r->H100_dB "%.2f") r4Num(r->ph100 "%.1f") r4Num(r->Hmax_dB "%.2f") r4Num(r->fL "%.4g") r4Num(r->fH "%.4g")
          r4Num(r->Hfb100 "%.4g") r4Num(r->fH_fb "%.4g") r4Num(r->Ho1_100 "%.4g")
          r4Num(r->dc_oa1 "%.5g") r4Num(r->dc_oa2 "%.5g") r4Num(r->dc_fb "%.5g") r4Num(r->dc_n "%.5g")
          r4Num(r->I_VDD "%.4g") r4Num(r->I_VDD2 "%.4g") r4Num(r->margin_A "%.3f") or(r->worst_A "")
          r4Num(r->margin_2 "%.3f") or(r->worst_2 "") r4Num(r->ugf "%.4g") r4Num(r->pm "%.1f") r4Num(r->lg10 "%.4g")
          r4Num(r->lg_dc "%.4g") r4Num(r->ph0 "%.1f")
          r4Num(r->noise_out_rms "%.4g") r4Num(r->noise_app_in "%.4g") r4Num(r->noise_deemb_in "%.4g"))
    r4Row(port r5Cols r)
    r
  )
)

;; closed-loop output impedance at the feedback pickoff fb: 1 A ac into fb, inputs ac 0
procedure( r5Zout(port stage slot tag over)
  let( (cell r ok z)
    cell = r5Cell(stage slot)
    r = list(nil 'tag tag 'cell cell 'stage stage 'slot slot 'kind "zout" 'status "ok")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        r4Tight()
        analysis('ac ?start "1m" ?stop "100k" ?dec "20")
        r5Set(append(over list(list("adm" 0.0) list("izac" 1.0))))
        run()
        z = ldAc("fb")
        unless( z error("no ac result"))
        r->Zcl_10 = ldMag(z 10.0) r->Zcl_100 = ldMag(z 100.0) r->Zcl_250 = ldMag(z 250.0)
        ldWriteCurves(strcat(r5Dir "/" tag "_zout.csv") list(list("Zfb" z)))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r5 %s: %s | Zout_cl at fb 10/100/250 Hz %s %s %s Ohm\n" tag r->status
          r4Num(r->Zcl_10 "%.4g") r4Num(r->Zcl_100 "%.4g") r4Num(r->Zcl_250 "%.4g"))
    r4Row(port r5Cols r)
    r
  )
)

;; ---------- Stage A: ideal unity buffer ----------
procedure( r5StageA()
  let( (port)
    r5BuildTb("none" "d2")
    r5BuildTb("ibuf" "d2")
    port = r5Open("r5_stageA.csv" r5Cols)
    r5Run(port "none" "d2" "A_noLP" list(list("rlp" 1e15)) nil t)
    r5Run(port "none" "d2" "A_LP" nil t t)
    r5Run(port "ibuf" "d2" "A_LP_idealBUF" nil t t)
    r5Zout(port "none" "d2" "A_zout_none" nil)
    r5Zout(port "ibuf" "d2" "A_zout_idealBUF" nil)
    close(port)
    t
  )
)

;; ---------- Stage B: real output stages ----------
;; B1 CD: NMOS source follower MSF 4u/1u (D VDD2, G oa1, S oa2, bulk gnd) + NMOS sink MSB 2u/4u gated by the
;;        OTA1 IBIAS node (mirror of the 50 nA reference). OTA1 must sit ~one Vgs above 0.9 V (expected ~1.3-1.4 V).
;; B2 CS: PMOS common source MCS 4u/2u (S VDD2, G oa1, D oa2) + NMOS sink MCL 2u/4u (mirror), Miller CM2 oa1<->oa2.
;;        Inverting -> OTA1 inputs swapped in the bench. Compensation: cm2 = 0.5 pF, ONE change to 2 pF if PM < 55 deg.
;; B3 (CS -> CD) only if B2 still shows output-loading loss; otherwise NOT RUN.
procedure( r5StageB()
  let( (port cs cs2)
    r5BuildTb("cd" "d2")
    r5BuildTb("cs" "d2")
    port = r5Open("r5_stageB.csv" r5Cols)
    r5Run(port "cd" "d2" "B1_CD_LP" nil t t)
    r5Zout(port "cd" "d2" "B1_zout_CD" nil)
    cs = r5Run(port "cs" "d2" "B2_CS_cm0p5_LP" list(list("cm2" 0.5e-12)) t t)
    r5Zout(port "cs" "d2" "B2_zout_CS_cm0p5" list(list("cm2" 0.5e-12)))
    when( !numberp(cs->pm) || cs->pm < 55.0
      acSay("r5B: CS PM %L < 55 deg -> the one Miller change to 2 pF\n" cs->pm)
      cs2 = r5Run(port "cs" "d2" "B2_CS_cm2p_LP" list(list("cm2" 2e-12)) t t)
      r5Zout(port "cs" "d2" "B2_zout_CS_cm2p" list(list("cm2" 2e-12))))
    close(port)
    t
  )
)

;; ---------- Stage D: demodulator placement D1 (after OTA1) vs D2 (after OTA2), 4 kHz, ideal relays + ideal EINV ----------
;; candidate: CD (non-inverting; OTA2 own 1/f ~4.5 uV at its own input = the largest OTA2 term from stage C;
;;            main-loop UGF 181 kHz >> 4 kHz). Same cell family, same bias/LP/feedback; static = chen 0.
;; D1 cell ece203_r5_s2_cd_d1: demod around vr1 = static OTA1 output DC (1.31308 V, from B1 dcop) -> CD gate.
;; D2 cell ece203_r5_s2_cd_d2 (= the B1 cell): demod around VREF after the CD.
r5DCols = '("tag" "cell" "slot" "chen" "status" "reason" "pre" "post" "slope" "step_gain" "step_ratio" "ripple_out_pp"
            "ripple_fb_pp" "oa1_min" "oa1_max" "oa1_avg" "d1_min" "d1_max" "oa2_min" "oa2_max" "oa2_avg" "d2_min" "d2_max"
            "fb_avg" "out_avg" "I_VDD2" "pss_out_avg" "pss_out_pp" "pss_fb_avg" "pss_fb_pp" "pss_oa1_min" "pss_oa1_max"
            "pss_oa1_avg" "pss_d1_min" "pss_d1_max" "pss_oa2_min" "pss_oa2_max" "pss_oa2_avg" "pss_d2_min" "pss_d2_max"
            "pac10" "pac100" "pac100_dB" "pacfb100" "pac_ratio" "out_rms" "app_in" "deemb_in"
            "in_0p1" "in_1" "in_10" "in_100" "in_250" "out_1" "out_10" "out_100" "noisetype")
r5DVr1 = 1.31308
procedure( r5Mm(w a b) car(errset(list(ymin(clip(w a b)) ymax(clip(w a b)) average(clip(w a b))) nil)) )
procedure( r5DTran(port slot tag chen)
  let( (cell r ok o fb a1 d1 a2 d2 i2 m pre0 s)
    cell = r5Cell("cd" slot)
    r = list(nil 'tag tag 'cell cell 'slot slot 'chen chen 'status "ok")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        r4Tight()
        analysis('tran ?stop "20m" ?maxstep "0.5u")
        car(errset(save('i "/VDD2/PLUS") nil))
        r5Set(list(list("chen" chen) list("vr1" r5DVr1) list("vst" 1e-3) list("tst" 5e-3) list("adm" 0.0)))
        run()
        o = car(errset(v("/out" ?result "tran") nil))
        unless( o error("no tran"))
        fb = v("/fb" ?result "tran") a1 = v("/oa1" ?result "tran") d1 = v("/d1" ?result "tran")
        a2 = v("/oa2" ?result "tran") d2 = v("/d2" ?result "tran")
        i2 = car(errset(i("/VDD2/PLUS" ?result "tran") nil))
        ;; step gain with drift removal: pre slope from 2-3 ms vs 4-5 ms, post window 9-10 ms (8 LP tau after the step)
        pre0 = chAvg(o 2e-3 3e-3) r->pre = chAvg(o 4e-3 5e-3) r->post = chAvg(o 9e-3 10e-3)
        r->slope = (r->pre - pre0) / 2e-3
        r->step_gain = (r->post - (r->pre + r->slope * 5e-3)) / 1e-3
        r->ripple_out_pp = chPp(o 19e-3 20e-3) r->ripple_fb_pp = chPp(fb 19e-3 20e-3)
        m = r5Mm(a1 19e-3 20e-3) r->oa1_min = nth(0 m) r->oa1_max = nth(1 m) r->oa1_avg = nth(2 m)
        m = r5Mm(d1 19e-3 20e-3) r->d1_min = nth(0 m) r->d1_max = nth(1 m)
        m = r5Mm(a2 19e-3 20e-3) r->oa2_min = nth(0 m) r->oa2_max = nth(1 m) r->oa2_avg = nth(2 m)
        m = r5Mm(d2 19e-3 20e-3) r->d2_min = nth(0 m) r->d2_max = nth(1 m)
        r->fb_avg = chAvg(fb 19e-3 20e-3) r->out_avg = chAvg(o 19e-3 20e-3)
        r->I_VDD2 = and(i2 chAvg(i2 19e-3 20e-3))
        spsWriteWaves(strcat(r5Dir "/" tag "_tran.csv") "t_s,out_V,fb_V,oa1_V,d1_V,oa2_V,d2_V" list(o fb a1 d1 a2 d2))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r5D %s: %s %s | step gain %s (pre %s slope %s post %s) | ripple out %s fb %s | oa1 %s..%s avg %s | d1 %s..%s | oa2 %s..%s | d2 %s..%s | fb %s out %s | I2 %s\n"
          tag r->status or(r->reason "") r4Num(r->step_gain "%.4g") r4Num(r->pre "%.6g") r4Num(r->slope "%.4g")
          r4Num(r->post "%.6g") r4Num(r->ripple_out_pp "%.4g") r4Num(r->ripple_fb_pp "%.4g")
          r4Num(r->oa1_min "%.4g") r4Num(r->oa1_max "%.4g") r4Num(r->oa1_avg "%.5g") r4Num(r->d1_min "%.4g") r4Num(r->d1_max "%.4g")
          r4Num(r->oa2_min "%.4g") r4Num(r->oa2_max "%.4g") r4Num(r->d2_min "%.4g") r4Num(r->d2_max "%.4g")
          r4Num(r->fb_avg "%.5g") r4Num(r->out_avg "%.5g") r4Num(r->I_VDD2 "%.4g"))
    r
  )
)
procedure( r5DPss(slot tag r @optional (msb "30"))
  let( (cell ok w vd h hf nout nin m nl k res)
    cell = r5Cell("cd" slot)
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        r4Tight()
        analysis('pss ?fund "4k" ?harms "30" ?errpreset "moderate")
        analysis('pac ?sweeptype "relative" ?relharmnum "0" ?start "0.1" ?stop "250" ?dec "20" ?maxsideband "3")
        analysis('pnoise ?sweeptype "relative" ?relharmnum "0" ?start "0.1" ?stop "250" ?dec "20"
                 ?maxsideband msb ?p "/out" ?n "/gnd!" ?noisetype "timeaverage")
        r5Set(list(list("chen" 1.0) list("vr1" r5DVr1) list("vst" 0.0) list("tst" 1.0)))
        run()
        res = strcat(getShellEnvVar("HOME") "/simulation/" cell "/spectre/schematic_" tag)
        ;; periodic steady state
        openResults(strcat(res "/psf")) selectResult('pss_td)
        foreach(n '("out" "fb" "oa1" "d1" "oa2" "d2")
          w = car(errset(v(strcat("/" n)) nil))
          m = car(errset(list(ymin(w) ymax(w) average(w)) nil))
          when( m
            putprop(r nth(0 m) stringToSymbol(strcat("pss_" n "_min"))) putprop(r nth(1 m) stringToSymbol(strcat("pss_" n "_max")))
            putprop(r nth(2 m) stringToSymbol(strcat("pss_" n "_avg")))))
        r->pss_out_pp = and(numberp(r->pss_out_max) r->pss_out_max - r->pss_out_min)
        r->pss_fb_pp = and(numberp(r->pss_fb_max) r->pss_fb_max - r->pss_fb_min)
        spsWriteWaves(strcat(r5Dir "/" tag "_pss_td.csv") "t_s,out_V,fb_V,oa1_V,d1_V,oa2_V,d2_V"
                      mapcar(lambda((n) car(errset(v(strcat("/" n)) nil))) '("out" "fb" "oa1" "d1" "oa2" "d2")))
        ;; PAC sideband 0, normalised to the actual differential PAC drive
        w = car(errset(v("/out" ?result "pac") nil))
        vd = car(errset(harmonic(v("/vinp" ?result "pac") - v("/vinn" ?result "pac") 0) nil))
        h = car(errset(harmonic(w 0) nil))
        when( vd h = h / vd)
        hf = car(errset(harmonic(v("/fb" ?result "pac") 0) nil))
        when( and(hf vd) hf = hf / vd)
        r->pac10 = ldMag(h 10.0) r->pac100 = ldMag(h 100.0) r->pac100_dB = ece203Db(r->pac100) r->pacfb100 = ldMag(hf 100.0)
        nout = car(errset(getData("out" ?result "pnoise") nil))
        nin = and(nout h car(errset(nout / mag(h) nil)))
        r->out_rms = nsRms(nout 0.1 250.0)
        r->app_in = and(r->out_rms r->pac100 r->out_rms / r->pac100)
        r->deemb_in = nsRms(nin 0.1 250.0)
        r->in_0p1 = ece203V(nin 0.1) r->in_1 = ece203V(nin 1.0) r->in_10 = ece203V(nin 10.0)
        r->in_100 = ece203V(nin 100.0) r->in_250 = ece203V(nin 249.0)
        r->out_1 = ece203V(nout 1.0) r->out_10 = ece203V(nout 10.0) r->out_100 = ece203V(nout 100.0)
        spsWriteWaves(strcat(r5Dir "/" tag "_pnoise.csv") "f_Hz,out_V_rtHz,absH_pac,deemb_in_V_rtHz" list(nout ece203Mag(h) nin))
        ldWriteCurves(strcat(r5Dir "/" tag "_ac.csv") list(list("Hout" h) list("Hfb" hf)))
        ;; per-source pnoise contributions (if this Spectre/OCEAN version exposes them for pnoise)
        nl = outfile(strcat(r5Dir "/" tag "_ns_full.txt") "w")
        k = errset(noiseSummary('integrated ?result 'pnoise ?from 0.1 ?to 250.0 ?output nl) t)
        close(nl)
        acSay("r5D %s: pnoise noiseSummary %L\n" tag if( k "ok" errset.errset))
        when( k
          for(j 0 length(r5Bins) - 2
            nl = outfile(strcat(r5Dir "/" tag sprintf(nil "_ns_b%02d.txt" j)) "w")
            errset(noiseSummary('integrated ?result 'pnoise ?from nth(j r5Bins) ?to nth(j + 1 r5Bins) ?output nl) t)
            close(nl)))
        ;; netlist of this exact run: confirm the pnoise noisetype
        nl = strcat(r5Dir "/" tag "_netlist.scs")
        sh(sprintf(nil "cp %s/netlist/input.scs %s" res nl))
        r->noisetype = if( sh(sprintf(nil "grep -q noisetype=timeaverage %s" nl)) "timeaverage(netlist)" "check")
        acSay("r5D %s netlist pnoise line:\n" tag)
        sh(sprintf(nil "grep -n 'pnoise\\|pss \\|pac ' %s | sed 's/^/AC>   /'" nl))
        t)
      t)
    unless( ok r->status = "pss failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r5D %s: %s %s | PSS out avg %s pp %s fb avg %s pp %s | oa1 %s..%s | d1 %s..%s | oa2 %s..%s | d2 %s..%s | PAC 10/100 %s %s (%s dB) fb %s | noise out %s app %s deemb %s | in @0.1/1/10/100/250 %s %s %s %s %s | %s\n"
          tag r->status or(r->reason "") r4Num(r->pss_out_avg "%.5g") r4Num(r->pss_out_pp "%.4g")
          r4Num(r->pss_fb_avg "%.5g") r4Num(r->pss_fb_pp "%.4g") r4Num(r->pss_oa1_min "%.4g") r4Num(r->pss_oa1_max "%.4g")
          r4Num(r->pss_d1_min "%.4g") r4Num(r->pss_d1_max "%.4g") r4Num(r->pss_oa2_min "%.4g") r4Num(r->pss_oa2_max "%.4g")
          r4Num(r->pss_d2_min "%.4g") r4Num(r->pss_d2_max "%.4g")
          r4Num(r->pac10 "%.4g") r4Num(r->pac100 "%.4g") r4Num(r->pac100_dB "%.2f") r4Num(r->pacfb100 "%.4g")
          r4Num(r->out_rms "%.4g") r4Num(r->app_in "%.4g") r4Num(r->deemb_in "%.4g")
          r4Num(r->in_0p1 "%.4g") r4Num(r->in_1 "%.4g") r4Num(r->in_10 "%.4g") r4Num(r->in_100 "%.4g") r4Num(r->in_250 "%.4g")
          or(r->noisetype ""))
    r
  )
)
;; gate: |step_gain/static - 1| < 10% and no node within 0.1 V of a rail -> PSS+PAC+PNoise; else BLOCKED (data kept)
procedure( r5DGate(r st)
  and(numberp(r->step_gain) numberp(st->step_gain) st->step_gain > 0
      abs(r->step_gain / st->step_gain - 1.0) < 0.1
      numberp(r->oa1_min) r->oa1_min > 0.1 r->oa1_max < 1.7 numberp(r->oa2_min) r->oa2_min > 0.1 r->oa2_max < 1.7)
)
procedure( r5StageD()
  let( (port st d1 d2)
    r5BuildTb("cd" "d1")
    port = r5Open("r5_stageD.csv" r5DCols)
    st = r5DTran(port "d2" "D0_static_tran" 0.0)
    d1 = r5DTran(port "d1" "D1_chop4k_tran" 1.0)
    d2 = r5DTran(port "d2" "D2_chop4k_tran" 1.0)
    foreach(r list(st d1 d2) r->step_ratio = and(numberp(r->step_gain) numberp(st->step_gain) r->step_gain / st->step_gain))
    r4Row(port r5DCols st)
    foreach(r list(d1 d2)
      if( r5DGate(r st)
        r5DPss(r->slot strcat(substring(r->tag 1 2) "_pss_pnoise") r)
        r->status = "BLOCKED(gate)")
      r4Row(port r5DCols r))
    close(port)
    t
  )
)
;; optional single sideband-convergence check (maxsideband 50) on one case
procedure( r5StageDsb()
  let( (port r)
    port = r5Open("r5_stageD_sb50.csv" r5DCols)
    r = list(nil 'tag "D1_pss_pnoise_sb50" 'cell r5Cell("cd" "d1") 'slot "d1" 'chen 1.0 'status "ok")
    r5DPss("d1" "D1_pss_pnoise_sb50" r "50")
    r4Row(port r5DCols r)
    close(port)
    t
  )
)
