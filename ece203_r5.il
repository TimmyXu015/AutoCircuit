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
    port = r4Open("r5_stageA.csv" r5Cols)
    r5Run(port "none" "d2" "A_noLP" list(list("rlp" 1e15)) nil t)
    r5Run(port "none" "d2" "A_LP" nil t t)
    r5Run(port "ibuf" "d2" "A_LP_idealBUF" nil t t)
    r5Zout(port "none" "d2" "A_zout_none" nil)
    r5Zout(port "ibuf" "d2" "A_zout_idealBUF" nil)
    close(port)
    t
  )
)
