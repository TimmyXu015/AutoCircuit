;; ece203_load.il -- ECE203 Round 2B: real A1/A2 -> A3 loading diagnosis.
;; Work order: docs/ECE203_round2b_loading_diagnosis.md. All Round-1 / Round-2A cells are READ-ONLY here:
;; ece203_a12_ota, ece203_a12n_ota, ece203_a3_ota, ece203_hp_fb, ece203_lp_out are only instantiated,
;; never rebuilt by this file.
;;
;; New cells (library Project), all "netlist style" (labelled stubs):
;;   ece203_load_chain_tb      REAL A1 + REAL A2 (ece203_a12_ota + ece203_hp_fb each) -> R1/R2 network ->
;;                             REAL A3 (ece203_a3_ota) -> ece203_lp_out. Direct electrical inputs (no
;;                             electrodes / body / DRL). Probes IPRB1/2/3 in each loop (0 V unless stb).
;;   ece203_load_chain_n_tb    same with ece203_a12n_ota (Round-2A variable geometry) as A1/A2
;;   ece203_load_ideal_tb      same nets, A1/A2/A3 = VCVS (golden reference, same R network and RC)
;;   ece203_load_chain_a3v_tb  REAL A1/A2, VCVS A3, same R network and RC (isolates finite real A3)
;;   ece203_load_chain_buf_tb  REAL A1/A2/A3 with ideal unity VCVS buffers between A1/A2 outputs and the
;;                             R network (diagnostic only -- NOT an approved buffer)
;;   ece203_load_a1_tb         one REAL A1 + hp_fb + IPRB1, CL = cl12, RLD (rld) to vref, AC current
;;                             injection IZ1 (iz) at o1 -> isolated transfer / closed-loop Zout
;;   ece203_load_a1ol_tb       A1 open loop (1 TOhm / 1 F follower DC) + IZ1 at out -> open-loop Zout
;;   ece203_load_a3_tb         REAL A3 + R network + RC driven by ideal sources VA (o1 side) / VB (o2 side)
;;                             + IZ3 at o3 -> ideal-drive transfer, per-port Zin, closed-loop Zout
;;   ece203_load_a3ol_tb       A3 open loop (follower DC) + IZ3 at out, no RC -> open-loop Zout
;;
;; Net names (chain): inputs inp / inn; A1: s1 (sum), oa1 -> IPRB1 -> o1; A2: s2, oa2 -> IPRB2 -> o2;
;; A3 network: o2 -R1A- p3 -R2A- vref ;  o1 -R1B- n3 -R2B- o3 ; A3 INP = p3, INN = n3, oa3 -> IPRB3 -> o3;
;; RC: o3 -> RLP -> out (CLP to ground). out = +100 (inp - inn) ideally.
;; A3 port facing A1 (o1): R1 into the inverting summing node n3. Port facing A2 (o2): R1 + R2 divider to vref.

ldDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_load")
ldCells = list(nil 'chain "ece203_load_chain_tb" 'chainN "ece203_load_chain_n_tb" 'ideal "ece203_load_ideal_tb"
                   'a3v "ece203_load_chain_a3v_tb" 'buf "ece203_load_chain_buf_tb"
                   'a1 "ece203_load_a1_tb" 'a1ol "ece203_load_a1ol_tb" 'a3 "ece203_load_a3_tb" 'a3ol "ece203_load_a3ol_tb")
ldCfg = list(nil
  'vars list(list("vdd" 1.8) list("vref" 0.9) list("vcm" 0.9) list("vcp" 0.70) list("vcn" 0.75)
             list("ib12" 100e-9) list("ib3" 50e-9)
             list("cc" 100e-12) list("cf" 4e-12) list("rp" 398e9)
             list("r1" 1e6) list("r2" 4e6) list("rlp" 3.18e6) list("clp" 200e-12)
             list("ap" 0.5) list("an" -0.5) list("vtp" 0.0) list("ftr" 10.0)
             list("aol" 1e5) list("aol3" 1e5)
             list("iz" 0.0) list("iz3" 0.0) list("za" 0.0) list("zb" 0.0) list("avin" 1.0)
             list("cl12" 5e-12) list("rld" 1e15) list("rbig" 1e12) list("cbig" 1.0)
             list("w12in" 20e-6) list("l12in" 1e-6) list("w78in" 1e-6) list("l78in" 10e-6))
  ;; Round-2A best frozen geometry (headroom risk, ~23 mV margin)
  'nVars list(list("w12in" 160e-6) list("l12in" 1e-6) list("w78in" 2e-6) list("l78in" 20e-6)
              list("vcp" 0.65) list("vcn" 0.75))
  'cases list(list("C0" 1e6 4e6) list("C1" 10e6 40e6) list("C2" 100e6 400e6))
  'spot '(1.0 10.0 60.0 100.0 250.0)
  'fStart "10m" 'fStop "100k" 'dec "20")

;; ---------------- spec helpers ----------------
procedure( ldV(name dc acm a b)
  list("analogLib" "vdc" name list(list("vdc" dc) list("acm" acm)) list(list("PLUS" a) list("MINUS" b)))
)
procedure( ldSin(name dc acm amp a b)
  list("analogLib" "vsin" name
       list(list("vdc" dc) list("acm" acm) list("vo" dc) list("va" amp) list("freq" "ftr"))
       list(list("PLUS" a) list("MINUS" b)))
)
;; AC current injection into node (current flows gnd -> node)
procedure( ldIz(name acm node)
  list("analogLib" "idc" name list(list("idc" "0") list("acm" acm)) list(list("PLUS" "gnd!") list("MINUS" node)))
)
procedure( ldE(name ncp ncm p m g)
  list("analogLib" "vcvs" name list(list("egain" g)) list(list("NC+" ncp) list("NC-" ncm) list("PLUS" p) list("MINUS" m)))
)
procedure( ldA12(inst cell inp inn out vdd ib)
  list(ece203Lib cell inst nil
       list(list("INP" inp) list("INN" inn) list("OUT" out) list("VDD" vdd) list("GND" "gnd!")
            list("IBIAS" ib) list("VCP" "vcp") list("VCN" "vcn")))
)
procedure( ldA3(inst inp inn out vdd ib)
  list(ece203Lib "ece203_a3_ota" inst nil
       list(list("INP" inp) list("INN" inn) list("OUT" out) list("VDD" vdd) list("GND" "gnd!") list("IBIAS" ib)))
)
procedure( ldProbe(name a b) list("analogLib" "iprobe" name nil list(list("PLUS" a) list("MINUS" b))) )
procedure( ldFb(inst vin sum vout) list(ece203Lib "ece203_hp_fb" inst nil list(list("VIN" vin) list("SUM" sum) list("VOUT" vout))) )

;; one first-stage path k ("1" or "2"): real OTA or VCVS
procedure( ldStage1(k a12cell real vin)
  let( (s o oa)
    s = strcat("s" k) o = strcat("o" k) oa = strcat("oa" k)
    if( real then
      list(ldFb(strcat("XFB" k) vin s o)
           ldA12(strcat("XA" k) a12cell "vref" s oa strcat("vdd" k) strcat("ib" k))
           otaI(strcat("IB" k) "ib12" strcat("ib" k) "gnd!")
           ldV(strcat("VDD" k) "vdd" "0" strcat("vdd" k) "gnd!")
           ldProbe(strcat("IPRB" k) oa o))
    else
      list(ldFb(strcat("XFB" k) vin s o)
           ldE(strcat("E" k) "vref" s o "gnd!" "aol")))
  )
)

;; A3 network + A3 (real or VCVS) + RC; in1/in2 = nets driving the o1-side / o2-side ports
procedure( ldStage3(real in1 in2)
  append(
    list(otaR("R1A" "r1" in2 "p3") otaR("R2A" "r2" "p3" "vref")
         otaR("R1B" "r1" in1 "n3") otaR("R2B" "r2" "n3" "o3")
         list(ece203Lib "ece203_lp_out" "XLP" nil '(("IN" "o3") ("OUT" "out"))))
    if( real
      list(ldA3("XA3" "p3" "n3" "oa3" "vdd3" "ib3")
           otaI("IB3" "ib3" "vdd3" "ib3")
           ldV("VDD3" "vdd" "0" "vdd3" "gnd!")
           ldProbe("IPRB3" "oa3" "o3"))
      list(ldE("E3" "p3" "n3" "o3" "gnd!" "aol3"))))
)

;; full chain: a12cell = A1/A2 OTA cell; r1real/r3real = real A1/A2 / A3; buf = unity VCVS buffers
procedure( ldChainBuild(cell a12cell r1real r3real buf)
  let( (specs in1 in2)
    in1 = if( buf "o1b" "o1") in2 = if( buf "o2b" "o2")
    specs = append(
      list(ldV("VREF" "vref" "0" "vref" "gnd!")
           ldSin("VSP" "vref" "ap" "vtp" "inp" "gnd!")
           ldSin("VSN" "vref" "an" "-vtp" "inn" "gnd!"))
      append(if( r1real list(ldV("VCP" "vcp" "0" "vcp" "gnd!") ldV("VCN" "vcn" "0" "vcn" "gnd!")) nil)
      append(ldStage1("1" a12cell r1real "inp")
      append(ldStage1("2" a12cell r1real "inn")
      append(if( buf list(ldE("EB1" "o1" "gnd!" "o1b" "gnd!" "1") ldE("EB2" "o2" "gnd!" "o2b" "gnd!" "1")) nil)
             ldStage3(r3real in1 in2))))))
    otaTb(cell specs)
  )
)

procedure( ldBuild()
  ece203LibInfo()
  ldChainBuild(ldCells->chain "ece203_a12_ota" t t nil)
  ldChainBuild(ldCells->chainN "ece203_a12n_ota" t t nil)
  ldChainBuild(ldCells->ideal "ece203_a12_ota" nil nil nil)
  ldChainBuild(ldCells->a3v "ece203_a12_ota" t nil nil)
  ldChainBuild(ldCells->buf "ece203_a12_ota" t t t)
  ;; A1 alone (closed loop) with CL, optional resistive load to vref, current injection
  otaTb(ldCells->a1 list(
    ldV("VREF" "vref" "0" "vref" "gnd!") ldV("VCP" "vcp" "0" "vcp" "gnd!") ldV("VCN" "vcn" "0" "vcn" "gnd!")
    ldV("VIN" "vref" "avin" "inp" "gnd!")
    ldFb("XFB1" "inp" "s1" "o1")
    ldA12("XA1" "ece203_a12_ota" "vref" "s1" "oa1" "vdd1" "ib1")
    otaI("IB1" "ib12" "ib1" "gnd!") ldV("VDD1" "vdd" "0" "vdd1" "gnd!")
    ldProbe("IPRB1" "oa1" "o1")
    otaC("CL" "cl12" "o1" "gnd!") otaR("RLD" "rld" "o1" "vref")
    ldIz("IZ1" "iz" "o1")))
  ;; A1 open loop + current injection
  otaTb(ldCells->a1ol list(
    ldV("VCP" "vcp" "0" "vcp" "gnd!") ldV("VCN" "vcn" "0" "vcn" "gnd!")
    ldV("VINP" "vcm" "avin" "inp" "gnd!")
    ldA12("XA1" "ece203_a12_ota" "inp" "inn" "out" "vdd1" "ib1")
    otaI("IB1" "ib12" "ib1" "gnd!") ldV("VDD1" "vdd" "0" "vdd1" "gnd!")
    otaR("RBIG" "rbig" "out" "inn") otaC("CBIG" "cbig" "inn" "gnd!")
    otaC("CL" "cl12" "out" "gnd!") ldIz("IZ1" "iz" "out")))
  ;; A3 alone with network + RC, ideal drive at both ports, current injection at o3
  otaTb(ldCells->a3 append(
    list(ldV("VREF" "vref" "0" "vref" "gnd!")
         ldV("VA" "vref" "za" "o1" "gnd!")
         ldV("VB" "vref" "zb" "o2" "gnd!")
         ldIz("IZ3" "iz3" "o3"))
    ldStage3(t "o1" "o2")))
  ;; A3 open loop, no RC, current injection
  otaTb(ldCells->a3ol list(
    ldV("VINP" "vcm" "avin" "inp" "gnd!")
    ldA3("XA3" "inp" "inn" "out" "vdd3" "ib3")
    otaI("IB3" "ib3" "vdd3" "ib3") ldV("VDD3" "vdd" "0" "vdd3" "gnd!")
    otaR("RBIG" "rbig" "out" "inn") otaC("CBIG" "cbig" "inn" "gnd!")
    ldIz("IZ3" "iz3" "out")))
  t
)

;; ---------------- simulation helpers ----------------
procedure( ldVars(over)
  ece203Vars(ldCfg->vars)
  ece203Vars(over)
)
procedure( ldAc(n) car(errset(v(strcat("/" n) ?result "ac") nil)) )
procedure( ldDc(n) car(errset(v(strcat("/" n) ?result "dcOp") nil)) )
procedure( ldI(n) car(errset(i(n ?result "ac") nil)) )
procedure( ldIdc(n) car(errset(-1.0 * i(n ?result "dcOp") nil)) )
procedure( ldDiv(a b) and(a b car(errset(a / b nil))) )
procedure( ldMag(w f) and(w ece203V(mag(w) f)) )
procedure( ldPh(w f) and(w ece203V(phase(w) f)) )
;; -3 dB corners of |w| relative to its maximum: (max fL fH)
procedure( ldCorners(w)
  let( (m)
    m = and(w car(errset(ymax(mag(w)) nil)))
    list(m and(m car(errset(cross(db20(w) ece203Db(m) - 3.0 1 "rising") nil)))
           and(m car(errset(cross(db20(w) ece203Db(m) - 3.0 1 "falling") nil))))
  )
)

;; set up a testbench session with ac (+ dc op) and optional noise
procedure( ldSetup(cell tag @optional (noiseSrc nil) (noiseOut "/out"))
  ece203Setup(cell strcat("_" tag))
  analysis('dc ?saveOppoint t)
  analysis('ac ?start ldCfg->fStart ?stop ldCfg->fStop ?dec ldCfg->dec)
  when( noiseSrc
    analysis('noise ?start "1m" ?stop "100k" ?dec "20" ?p noiseOut ?n "/gnd!" ?iprobe noiseSrc))
  foreach(x ldSaves(cell) car(errset(save('i x) nil)))
  t
)

;; currents to save: only sources that exist in that testbench
procedure( ldSaves(cell)
  cond(
    ( member(cell list(ldCells->chain ldCells->chainN ldCells->buf)) '("/VDD1/PLUS" "/VDD2/PLUS" "/VDD3/PLUS"))
    ( cell == ldCells->a3v '("/VDD1/PLUS" "/VDD2/PLUS"))
    ( cell == ldCells->a1 '("/VDD1/PLUS" "/VIN/PLUS"))
    ( cell == ldCells->a1ol '("/VDD1/PLUS"))
    ( cell == ldCells->a3 '("/VDD3/PLUS" "/VA/PLUS" "/VB/PLUS"))
    ( cell == ldCells->a3ol '("/VDD3/PLUS"))
    ( t nil))
)

;; write curves (list of (name wave)) with mag and phase columns
procedure( ldWriteCurves(file named)
  let( (hdr waves)
    hdr = "f_Hz"
    foreach(nw named
      hdr = strcat(hdr "," "abs_" car(nw) ",ph_" car(nw))
      waves = append(waves list(ece203Mag(cadr(nw)) ece203Ph(cadr(nw)))))
    spsWriteWaves(file hdr waves)
  )
)

;; device OP of all OTAs present: rows (inst name vals)
procedure( ldOps(prefixes)
  let( (insts devs)
    foreach(p prefixes
      devs = if( rexMatchp("XA3" p) '("M1" "M2" "M3" "M4" "MT" "MREF")
                 '("M0" "M1" "M2" "M3" "M4" "M5" "M6" "M7" "M8" "MREF"))
      foreach(d devs insts = append(insts list(strcat(p "." d)))))
    insts
  )
)

;; min margin over instances whose names start with prefix (excluding MREF): (margin inst)
procedure( ldMinMargin(rows prefix)
  let( (best m)
    foreach(r rows
      when( strncmp(car(r) prefix strlen(prefix)) == 0 && !rexMatchp("MREF" car(r))
        m = ece203Margin(caddr(r))
        when( !numberp(m) m = -9.0)
        when( !best || m < car(best) best = list(m car(r)))))
    best
  )
)

;; ---------------- result rows ----------------
ldCols = '(tag job cell variant r1 r2 rlp status reason
  I_A1 I_A2 I_A3 I_total P_total_W
  dc_o1 dc_o2 dc_o3 dc_out dc_s1 dc_s2 dc_p3 dc_n3
  Hout_10 Hout_60 Hout_100 Hout_100_dB ph_Hout_100 Hout_max fL_out fH_out
  Ho3_100 fH_o3
  G12_100 ph_G12_100 A1P_100 ph_A1P_100 A2N_100 ph_A2N_100 X21_100
  G3_100 ph_G3_100 G3rc_100 RC_100
  ZloadA_10 ZloadB_10 ZloadA_100 ZloadB_100
  CM_out_60
  ugf1 pm1 ugf2 pm2 ugf3 pm3
  margin_A1 worst_A1 margin_A2 worst_A2 margin_A3 worst_A3
  tran1_vdpk tran1_pp_out tran1_gain tran2_vdpk tran2_pp_out tran2_gain
  noise_in_rms_0p1_250
  Zin_portA_10 Zin_portB_10 Zout_cl_10 Zout_cl_100 Zout_ol_10 Zout_ol_100 A0)

procedure( ldHeader(port)
  fprintf(port "%s\n" buildString(mapcar('symbolToString ldCols) ","))
)
procedure( ldWriteRow(port r)
  let( (x first)
    first = t
    foreach(c ldCols
      x = get(r c)
      fprintf(port "%s%s" if( first "" ",")
              cond( (stringp(x) x) (numberp(x) sprintf(nil "%.6g" float(x))) (t "n/a")))
      first = nil)
    fprintf(port "\n")
    drain(port)
  )
)
procedure( ldRow(tag job cell variant over)
  let( (r v)
    r = list(nil 'tag tag 'job job 'cell cell 'variant variant 'status "ok")
    foreach(k '("r1" "r2" "rlp")
      ;; last setting wins
      foreach(p append(ldCfg->vars over) when( car(p) == k v = p))
      putprop(r cadr(v) stringToSymbol(k)))
    r
  )
)
procedure( ldR1(r) or(r->r1 1e6) )

;; ---------------- chain measurement ----------------
;; flags: DPL 'real (3 real OTAs: stb loops 1-3, per-OTA OP) 'pn (single-ended runs) 'stb 'tran 'noise 'ops
procedure( ldChain(cell tag job variant over flags)
  let( (r ok dm vp vn vd o1 o2 o3 out n3 p3 h12 h3 h3rc hrc hout ho3 c c3 rows pw nw cw s lg lgs tr pp prefixes res)
    res = ldDir
    r = ldRow(tag job cell variant over)
    ok = errset(
      progn(
        ;; ---- differential run ----
        ldSetup(cell tag if( flags->noise "/VSP" nil))
        ldVars(append(over list(list("ap" 0.5) list("an" -0.5))))
        run()
        vp = ldAc("inp") vn = ldAc("inn")
        unless( vp error("no ac result"))
        vd = vp - vn
        o1 = ldAc("o1") o2 = ldAc("o2") o3 = ldAc("o3") out = ldAc("out") n3 = ldAc("n3") p3 = ldAc("p3")
        hout = ldDiv(out vd) ho3 = ldDiv(o3 vd)
        h12 = ldDiv(o1 - o2 vd)
        h3 = ldDiv(o3 o2 - o1) h3rc = ldDiv(out o2 - o1) hrc = ldDiv(out o3)
        dm = list(nil 'hout hout 'ho3 ho3 'h12 h12 'h3 h3 'h3rc h3rc 'hrc hrc
                  'zA ldDiv(o1 (o1 - n3) / ldR1(r)) 'zB ldDiv(o2 (o2 - p3) / ldR1(r)))
        foreach(f '(10.0 60.0 100.0)
          putprop(r ldMag(hout f) stringToSymbol(sprintf(nil "Hout_%d" fix(f)))))
        r->Hout_100_dB = ece203Db(r->Hout_100) r->ph_Hout_100 = ldPh(hout 100.0)
        c = ldCorners(hout) r->Hout_max = car(c) r->fL_out = cadr(c) r->fH_out = caddr(c)
        r->Ho3_100 = ldMag(ho3 100.0) c3 = ldCorners(ho3) r->fH_o3 = caddr(c3)
        r->G12_100 = ldMag(h12 100.0) r->ph_G12_100 = ldPh(h12 100.0)
        r->G3_100 = ldMag(h3 100.0) r->ph_G3_100 = ldPh(h3 100.0)
        r->G3rc_100 = ldMag(h3rc 100.0) r->RC_100 = ldMag(hrc 100.0)
        r->ZloadA_10 = ldMag(dm->zA 10.0) r->ZloadB_10 = ldMag(dm->zB 10.0)
        r->ZloadA_100 = ldMag(dm->zA 100.0) r->ZloadB_100 = ldMag(dm->zB 100.0)
        foreach(n '("o1" "o2" "o3" "out" "s1" "s2" "p3" "n3")
          putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        r->I_A1 = ldIdc("/VDD1/PLUS") r->I_A2 = ldIdc("/VDD2/PLUS") r->I_A3 = ldIdc("/VDD3/PLUS")
        r->I_total = and(r->I_A1 r->I_A2 r->I_A3 r->I_A1 + r->I_A2 + r->I_A3)
        r->P_total_W = and(r->I_total 1.8 * r->I_total)
        when( flags->real
          prefixes = '("XA1" "XA2" "XA3")
          rows = ece203OpDump(strcat(res "/" tag "_dcop.csv") ldOps(prefixes))
          foreach(k '("1" "2" "3")
            s = ldMinMargin(rows strcat("XA" k "."))
            putprop(r car(s) stringToSymbol(strcat("margin_A" k)))
            putprop(r cadr(s) stringToSymbol(strcat("worst_A" k)))))
        when( flags->noise
          r->noise_in_rms_0p1_250 = nsRms(car(errset(getData("in" ?result "noise") nil)) 0.1 250.0)
          nsSummary(strcat(res "/" tag "_noisesummary_0p1_250.txt") 'integrated 0.1 250.0)
          spsWriteWaves(strcat(res "/" tag "_noise.csv") "f_Hz,in_V_rtHz,out_V_rtHz"
                        list(car(errset(getData("in" ?result "noise") nil)) car(errset(getData("out" ?result "noise") nil)))))
        ;; ---- single-ended and common-mode runs ----
        when( flags->pn
          ldVars(append(over list(list("ap" 1.0) list("an" 0.0))))
          run()
          pw = list(nil 'a1 ldDiv(ldAc("o1") ldAc("inp")) 'x21 ldDiv(ldAc("o2") ldAc("inp")) 'out ldDiv(ldAc("out") ldAc("inp")))
          ldVars(append(over list(list("ap" 0.0) list("an" 1.0))))
          run()
          nw = list(nil 'a2 ldDiv(ldAc("o2") ldAc("inn")) 'out ldDiv(ldAc("out") ldAc("inn")))
          ldVars(append(over list(list("ap" 0.5) list("an" 0.5))))
          run()
          cw = list(nil 'cm ldDiv(ldAc("out") (ldAc("inp") + ldAc("inn")) / 2.0))
          r->A1P_100 = ldMag(pw->a1 100.0) r->ph_A1P_100 = ldPh(pw->a1 100.0)
          r->A2N_100 = ldMag(nw->a2 100.0) r->ph_A2N_100 = ldPh(nw->a2 100.0)
          r->X21_100 = ldMag(pw->x21 100.0)
          r->CM_out_60 = ldMag(cw->cm 60.0))
        ldWriteCurves(strcat(res "/" tag "_ac.csv")
          list(list("Hout" hout) list("Ho3" ho3) list("G12" h12) list("G3" h3) list("G3rc" h3rc) list("RC" hrc)
               list("A1P" and(pw pw->a1)) list("A2N" and(nw nw->a2)) list("X21" and(pw pw->x21))
               list("outP" and(pw pw->out)) list("outN" and(nw nw->out)) list("CM" and(cw cw->cm))
               list("ZloadA" dm->zA) list("ZloadB" dm->zB)))
        ;; ---- stb, one loop at a time (other loops intact; probes are 0 V elsewhere) ----
        when( flags->stb
          foreach(k '("1" "2" "3")
            ece203Setup(cell strcat("_" tag "stb" k))
            analysis('stb ?start "1m" ?stop "100M" ?dec "10" ?probe strcat("/IPRB" k))
            ldVars(over)
            run()
            s = otaStb()
            putprop(r car(s) stringToSymbol(strcat("ugf" k)))
            putprop(r cadr(s) stringToSymbol(strcat("pm" k)))
            lgs = append(lgs list(list(strcat("LG" k) cadddr(s)))))
          ldWriteCurves(strcat(res "/" tag "_stb.csv") lgs))
        ;; ---- transient, 10 Hz differential sine (vd peak = 2 vtp) ----
        when( flags->tran
          foreach(k '(1 2)
            ece203Setup(cell strcat("_" tag "tr" sprintf(nil "%d" k)))
            analysis('tran ?stop "0.4" ?maxstep "0.25m")
            ldVars(append(over list(list("vtp" if( k == 1 2.5e-3 5e-3)) list("ap" 0.0) list("an" 0.0))))
            run()
            tr = car(errset(v("/out" ?result "tran") nil))
            pp = and(tr car(errset(ymax(clip(tr 0.3 0.4)) - ymin(clip(tr 0.3 0.4)) nil)))
            putprop(r if( k == 1 5e-3 10e-3) stringToSymbol(sprintf(nil "tran%d_vdpk" k)))
            putprop(r pp stringToSymbol(sprintf(nil "tran%d_pp_out" k)))
            putprop(r and(pp pp / (2.0 * if( k == 1 5e-3 10e-3))) stringToSymbol(sprintf(nil "tran%d_gain" k)))
            spsWriteWaves(strcat(res "/" tag sprintf(nil "_tran%d.csv" k)) "t_s,out_V,o1_V,o2_V,o3_V"
                          list(tr car(errset(v("/o1" ?result "tran") nil)) car(errset(v("/o2" ?result "tran") nil))
                               car(errset(v("/o3" ?result "tran") nil))))))
        ece203SaveNetlist(cell strcat("ece203_" tag))
        t)
      t)
    unless( ok r->status = "error" r->reason = sprintf(nil "%L" car(errset.errset)))
    acSay("ld %s [%s %s]: %s %s | |Hout| 10/60/100 Hz %s %s %s (%s dB, ph %s) fL %s fH %s | A1P %s A2N %s G12 %s | A3 %s (ph %s) after RC %s | Zload A/B @10 %s %s | I %s %s %s | PM %s %s %s | margins %s %s %s | tran gain %s %s | noise %s\n"
          tag cell variant r->status or(r->reason "")
          acNum(r->Hout_10 "%.4g") acNum(r->Hout_60 "%.4g") acNum(r->Hout_100 "%.4g") acNum(r->Hout_100_dB "%.3f")
          acNum(r->ph_Hout_100 "%.1f") acNum(r->fL_out "%.4g") acNum(r->fH_out "%.4g")
          acNum(r->A1P_100 "%.4g") acNum(r->A2N_100 "%.4g") acNum(r->G12_100 "%.4g")
          acNum(r->G3_100 "%.4g") acNum(r->ph_G3_100 "%.1f") acNum(r->G3rc_100 "%.4g")
          acNum(r->ZloadA_10 "%.4g") acNum(r->ZloadB_10 "%.4g")
          acNum(r->I_A1 "%.4g") acNum(r->I_A2 "%.4g") acNum(r->I_A3 "%.4g")
          acNum(r->pm1 "%.1f") acNum(r->pm2 "%.1f") acNum(r->pm3 "%.1f")
          acNum(r->margin_A1 "%.3f") acNum(r->margin_A2 "%.3f") acNum(r->margin_A3 "%.3f")
          acNum(r->tran1_gain "%.4g") acNum(r->tran2_gain "%.4g") acNum(r->noise_in_rms_0p1_250 "%.4g"))
    r
  )
)

;; ---------------- standalone A1 (closed loop) ----------------
procedure( ldA1(tag job variant over @optional (doStb t))
  let( (r ok h c s z)
    r = ldRow(tag job ldCells->a1 variant over)
    ok = errset(
      progn(
        ldSetup(ldCells->a1 tag)
        ldVars(append(over list(list("avin" 1.0) list("iz" 0.0))))
        run()
        h = ldDiv(ldAc("o1") ldAc("inp"))
        unless( h error("no ac result"))
        r->A1P_100 = ldMag(h 100.0) r->ph_A1P_100 = ldPh(h 100.0)
        c = ldCorners(h) r->Hout_max = car(c) r->fL_out = cadr(c) r->fH_out = caddr(c)
        r->I_A1 = ldIdc("/VDD1/PLUS") r->dc_o1 = ldDc("o1") r->dc_s1 = ldDc("s1")
        s = ldMinMargin(ece203OpRows(ldOps('("XA1"))) "XA1.") r->margin_A1 = car(s) r->worst_A1 = cadr(s)
        ldVars(append(over list(list("avin" 0.0) list("iz" 1.0))))
        run()
        z = ldAc("o1")
        r->Zout_cl_10 = ldMag(z 10.0) r->Zout_cl_100 = ldMag(z 100.0)
        ldWriteCurves(strcat(ldDir "/" tag "_ac.csv") list(list("A1" h) list("Zout_cl" z)))
        when( doStb
          ece203Setup(ldCells->a1 strcat("_" tag "stb"))
          analysis('stb ?start "1m" ?stop "100M" ?dec "10" ?probe "/IPRB1")
          ldVars(over)
          run()
          s = otaStb() r->ugf1 = car(s) r->pm1 = cadr(s)
          ldWriteCurves(strcat(ldDir "/" tag "_stb.csv") list(list("LG1" cadddr(s)))))
        t)
      t)
    unless( ok r->status = "error" r->reason = sprintf(nil "%L" car(errset.errset)))
    acSay("ld %s [A1 alone %s]: %s | |o1/vin| 100 Hz %s ph %s, fL %s fH %s, Zout_cl 10/100 Hz %s %s, PM %s, I %s, margin %s %s, dc o1 %s\n"
          tag variant r->status acNum(r->A1P_100 "%.5g") acNum(r->ph_A1P_100 "%.1f") acNum(r->fL_out "%.4g")
          acNum(r->fH_out "%.4g") acNum(r->Zout_cl_10 "%.4g") acNum(r->Zout_cl_100 "%.4g") acNum(r->pm1 "%.1f")
          acNum(r->I_A1 "%.4g") acNum(r->margin_A1 "%.3f") or(r->worst_A1 "") acNum(r->dc_o1 "%.5g"))
    r
  )
)

;; ---------------- open-loop Zout (A1 or A3) ----------------
procedure( ldOl(cell tag job variant over)
  let( (r ok a z)
    r = ldRow(tag job cell variant over)
    ok = errset(
      progn(
        ldSetup(cell tag)
        ldVars(append(over list(list("avin" 1.0) list("iz" 0.0) list("iz3" 0.0))))
        run()
        a = ldAc("out")
        unless( a error("no ac result"))
        r->A0 = ldMag(a 0.01)
        ldVars(append(over list(list("avin" 0.0) list("iz" 1.0) list("iz3" 1.0))))
        run()
        z = ldAc("out")
        r->Zout_ol_10 = ldMag(z 10.0) r->Zout_ol_100 = ldMag(z 100.0)
        ldWriteCurves(strcat(ldDir "/" tag "_ac.csv") list(list("A_ol" a) list("Zout_ol" z)))
        t)
      t)
    unless( ok r->status = "error" r->reason = sprintf(nil "%L" car(errset.errset)))
    acSay("ld %s [open loop %s]: %s | A(10 mHz) %s, Zout_ol 10/100 Hz %s %s\n" tag cell r->status
          acNum(r->A0 "%.5g") acNum(r->Zout_ol_10 "%.4g") acNum(r->Zout_ol_100 "%.4g"))
    r
  )
)

;; ---------------- standalone A3 with ideal drive ----------------
procedure( ldA3(tag job variant over @optional (doStb t))
  let( (r ok h hrc c za zb zo s)
    r = ldRow(tag job ldCells->a3 variant over)
    ok = errset(
      progn(
        ldSetup(ldCells->a3 tag)
        ldVars(append(over list(list("za" -0.5) list("zb" 0.5) list("iz3" 0.0))))
        run()
        h = ldDiv(ldAc("o3") ldAc("o2") - ldAc("o1"))
        unless( h error("no ac result"))
        hrc = ldDiv(ldAc("out") ldAc("o2") - ldAc("o1"))
        r->G3_100 = ldMag(h 100.0) r->ph_G3_100 = ldPh(h 100.0) r->G3rc_100 = ldMag(hrc 100.0)
        c = ldCorners(h) r->fH_o3 = caddr(c)
        c = ldCorners(hrc) r->fH_out = caddr(c)
        r->I_A3 = ldIdc("/VDD3/PLUS") r->dc_o3 = ldDc("o3") r->dc_p3 = ldDc("p3") r->dc_n3 = ldDc("n3")
        s = ldMinMargin(ece203OpRows(ldOps('("XA3"))) "XA3.") r->margin_A3 = car(s) r->worst_A3 = cadr(s)
        ;; port A (o1 side: R1 into the inverting summing node)
        ldVars(append(over list(list("za" 1.0) list("zb" 0.0) list("iz3" 0.0))))
        run()
        za = ldDiv(ldAc("o1") -1.0 * ldI("/VA/PLUS"))
        ;; port B (o2 side: R1 + R2 divider to vref)
        ldVars(append(over list(list("za" 0.0) list("zb" 1.0) list("iz3" 0.0))))
        run()
        zb = ldDiv(ldAc("o2") -1.0 * ldI("/VB/PLUS"))
        ;; closed-loop output impedance at o3 (RC attached)
        ldVars(append(over list(list("za" 0.0) list("zb" 0.0) list("iz3" 1.0))))
        run()
        zo = ldAc("o3")
        r->Zin_portA_10 = ldMag(za 10.0) r->Zin_portB_10 = ldMag(zb 10.0)
        r->Zout_cl_10 = ldMag(zo 10.0) r->Zout_cl_100 = ldMag(zo 100.0)
        ldWriteCurves(strcat(ldDir "/" tag "_ac.csv")
                      list(list("G3" h) list("G3rc" hrc) list("ZinA" za) list("ZinB" zb) list("Zout_cl3" zo)))
        when( doStb
          ece203Setup(ldCells->a3 strcat("_" tag "stb"))
          analysis('stb ?start "1m" ?stop "100M" ?dec "10" ?probe "/IPRB3")
          ldVars(over)
          run()
          s = otaStb() r->ugf3 = car(s) r->pm3 = cadr(s)
          ldWriteCurves(strcat(ldDir "/" tag "_stb.csv") list(list("LG3" cadddr(s)))))
        t)
      t)
    unless( ok r->status = "error" r->reason = sprintf(nil "%L" car(errset.errset)))
    acSay("ld %s [A3 alone, ideal drive, %s]: %s | |o3/(o2-o1)| 100 Hz %s ph %s, after RC %s, fH o3 %s out %s, Zin A/B @10 Hz %s %s, Zout_cl @10/100 %s %s, PM %s, I %s, margin %s %s\n"
          tag variant r->status acNum(r->G3_100 "%.5g") acNum(r->ph_G3_100 "%.1f") acNum(r->G3rc_100 "%.5g")
          acNum(r->fH_o3 "%.4g") acNum(r->fH_out "%.4g") acNum(r->Zin_portA_10 "%.4g") acNum(r->Zin_portB_10 "%.4g")
          acNum(r->Zout_cl_10 "%.4g") acNum(r->Zout_cl_100 "%.4g") acNum(r->pm3 "%.1f") acNum(r->I_A3 "%.4g")
          acNum(r->margin_A3 "%.3f") or(r->worst_A3 ""))
    r
  )
)

;; ---------------- jobs ----------------
procedure( ldOpen(name)
  let( (port)
    unless( isDir(ldDir) createDir(ldDir) )
    port = outfile(strcat(ldDir "/" name) "w")
    ldHeader(port)
    port
  )
)
ldFull = list(nil 'real t 'pn t 'stb t 'tran t 'noise t)
ldBasic = list(nil 'real t 'pn t)

procedure( ldProbeJob()
  let( (port r)
    ldBuild()
    port = ldOpen("ece203_load_probe.csv")
    r = ldChain(ldCells->chain "probe_chain_C0" "probe" "real C0" list(list("r1" 1e6) list("r2" 4e6)) ldBasic)
    ldWriteRow(port r)
    close(port)
    sh(sprintf(nil "f=%s/ece203_probe_chain_C0_netlist.scs; grep -n -e 'mag=' -e 'sine' -e iprobe -e ' vcvs ' $f | sed 's/^/AC>   /'" acResultsDir()))
    t
  )
)

procedure( ldChainJob()
  let( (port c0)
    c0 = list(list("r1" 1e6) list("r2" 4e6))
    port = ldOpen("ece203_load_chain.csv")
    ldWriteRow(port ldChain(ldCells->chain "A_chain_C0" "chain" "real A1/A2/A3, C0" c0 ldFull))
    ldWriteRow(port ldChain(ldCells->ideal "A_ideal_C0" "chain" "all-VCVS golden, C0" c0 list(nil 'pn t)))
    ldWriteRow(port ldA1("A_a1iso_cl5p" "chain" "A1 alone, CL 5 pF (= ece203_hp_real_tb)" list(list("cl12" 5e-12))))
    ldWriteRow(port ldA3("A_a3iso_C0" "chain" "A3 alone, ideal drive, C0" c0))
    close(port)
    t
  )
)

procedure( ldIsolateJob()
  let( (port c0)
    c0 = list(list("r1" 1e6) list("r2" 4e6))
    port = ldOpen("ece203_load_isolate.csv")
    ;; B1: A1 isolated / single-port standalone loads / in the real chain (from Stage A) / buffered chain
    ldWriteRow(port ldA1("B1_a1_cl0" "isolate" "A1 alone, no load" list(list("cl12" 0.0))))
    ldWriteRow(port ldA1("B1_a1_rld1M" "isolate" "A1 alone, 1 MOhm to vref (standalone approx. of port A)"
                         list(list("cl12" 0.0) list("rld" 1e6)) nil))
    ldWriteRow(port ldA1("B1_a1_rld5M" "isolate" "A1 alone, 5 MOhm to vref (standalone approx. of port B)"
                         list(list("cl12" 0.0) list("rld" 5e6)) nil))
    ldWriteRow(port ldOl(ldCells->a1ol "B1_a1ol_zout" "isolate" "A1 open loop, CL 0" list(list("cl12" 0.0))))
    ldWriteRow(port ldChain(ldCells->buf "B1_chain_buf_C0" "isolate" "real chain + ideal unity buffers at A1/A2 outputs (diagnostic)" c0 list(nil 'pn t)))
    ;; B2: A3 with ideal drive (Stage A row A_a3iso_C0) vs real chain; VCVS-A3 with the same network
    ldWriteRow(port ldChain(ldCells->a3v "B2_chain_a3vcvs_C0" "isolate" "real A1/A2 + VCVS A3, same network + RC" c0 list(nil 'pn t)))
    ldWriteRow(port ldOl(ldCells->a3ol "B2_a3ol_zout" "isolate" "A3 open loop, no RC" nil))
    ;; B3: output RC present (Stage A) vs very light load
    ldWriteRow(port ldChain(ldCells->chain "B3_chain_noRC_C0" "isolate" "real chain, RLP = 1e15 (no RC load; out not meaningful)"
                            append(c0 list(list("rlp" 1e15))) list(nil 'real t 'pn t 'stb t)))
    ldWriteRow(port ldA3("B3_a3iso_noRC_C0" "isolate" "A3 alone, ideal drive, RLP = 1e15" append(c0 list(list("rlp" 1e15)))))
    close(port)
    t
  )
)

procedure( ldSweepJob()
  let( (port over)
    port = ldOpen("ece203_load_sweep.csv")
    foreach(c ldCfg->cases
      over = list(list("r1" cadr(c)) list("r2" caddr(c)))
      ldWriteRow(port ldChain(ldCells->chain strcat("C_chain_" car(c)) "sweep" strcat("real chain, " car(c)) over ldFull))
      ldWriteRow(port ldChain(ldCells->ideal strcat("C_ideal_" car(c)) "sweep" strcat("all-VCVS golden, " car(c)) over list(nil 'pn t)))
      ldWriteRow(port ldA3(strcat("C_a3iso_" car(c)) "sweep" strcat("A3 alone, ideal drive, " car(c)) over)))
    ;; Round-2A frozen geometry on the two most informative cases (headroom risk)
    foreach(c list(car(ldCfg->cases) caddr(ldCfg->cases))
      over = append(ldCfg->nVars list(list("r1" cadr(c)) list("r2" caddr(c))))
      ldWriteRow(port ldChain(ldCells->chainN strcat("C_chainN_" car(c)) "sweep"
                              strcat("real chain, A1/A2 = Round-2A best geometry (headroom risk), " car(c)) over
                              list(nil 'real t 'pn t 'stb t 'noise t))))
    close(port)
    t
  )
)
