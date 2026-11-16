;; ece203_r4.il -- ECE203 Round 4: integrated ECG system (electrodes/body + single-stage C OTA + LP + DRL).
;; Work order: docs/ECE203_round4_ecg_integrated_bigrun.md. New cells ece203_r4_*; old cells untouched.
;;
;; Cells (library Project):
;;   ece203_r4_ota       copy of Round-3C C OTA (NMOS 10u/8u input, PMOS mirror 2u/4u, NMOS cascode MC 10u/4u on
;;                       M2, NMOS tail 8u/4u + ref 2u/4u), pins GND IBIAS INN INP OUT VCAS VDD
;;   ece203_r4_drl_ota   copy of Round-3C B 5T (NMOS 10u/8u input) for the real DRL driver
;;   ece203_r4_ecg_tb    whole system, ideal Rfb            ece203_r4_ecg_pr_tb   same, two Round-3B pseudo-R
;; Testbench (both):
;;   body: CBODY (cbody) to gnd; IINT 60 Hz interferer (ac current icm, gnd -> body)
;;   ECG/CM test sources: VSP body->ep (ac adm/2 + vcmin), VSN body->en (ac -adm/2 + vcmin)
;;   electrodes (each): rs in series with (re || ce); VPP/VPN 0 V probes electrode -> amp input (inp/inn)
;;   amp: inp -CCP(cc)- p, CCX (cc*dcc, Cc mismatch) inp-p; inn -CCN(cc)- n;
;;        p -(CFP cfb || RFP rfb / pseudo-R)- vref; n -(CFN cfb || RFN rfb / pseudo-R)- o
;;        XA ece203_r4_ota: INP p, INN n, OUT oa; IPRB oa->o (main loop probe); CL (cl) o-gnd
;;   output LP (outside the OTA feedback, after the sampling node o): RLP (rlp) o->out, CLP (clp) out-gnd
;;   CM sense BEFORE the coupling caps: RCMP/RCMN (rcm) inp,inn -> cm
;;   DRL ideal (diagnostic): EDRL drli - vref = adrl (vref - cm); RDRI (rdi) drli -> rl0
;;   DRL real: XD ece203_r4_drl_ota INP vref, INN cm, OUT drlr (open-loop inverting gain A0); RDRR (rdr) drlr -> rl0
;;   IPRD rl0 -> rl0b (DRL loop probe); right-leg electrode rl0b -RSR(rs)- rl1 -(RER re || CER ce)- body
;;   DRL OFF: rdi = rdr = 1e15 (path kept, disconnected)
;;   supplies: VDD (main OTA + IB), VDDD (DRL OTA + IBD) separately metered; VREF, VCAS ideal (diagnostic)
;; Tolerances: gmin = iabstol = 1e-18, reltol 1e-6 for every run (Round 3B).

r4Dir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r4")
r4Cells = list(nil 'ota "ece203_r4_ota" 'drl "ece203_r4_drl_ota" 'tb "ece203_r4_ecg_tb" 'pr "ece203_r4_ecg_pr_tb")
r4Vars = list(list("vdd" 1.8) list("vref" 0.9) list("ib3" 50e-9) list("ibd" 50e-9) list("vcas" 1.05)
  list("cc" 50e-12) list("cfb" 0.5e-12) list("rfb" 3.1831e12) list("prw" 3e-6) list("prl" 2e-6) list("cl" 0.0)
  list("rlp" 3.18e6) list("clp" 200e-12) list("rcm" 10e9) list("rs" 2e3) list("re" 1e6) list("ce" 50e-9)
  list("cbody" 200e-12) list("icm" 0.0) list("adm" 1.0) list("vcmin" 0.0) list("dcc" 0.0)
  list("adrl" 100.0) list("rdi" 1e15) list("rdr" 1e15) list("rdrl0" 1e6) list("itr" 0.0) list("ccm" 0.0)
  list("rv1" 90e6) list("rv2" 90e6) list("cvref" 20e-12) list("rc1" 75e6) list("rc2" 105e6) list("iref" 100e-9))
r4Off = list(list("rdi" 1e15) list("rdr" 1e15))
r4IdealOn = list(list("rdi" 1e6) list("rdr" 1e15))
r4RealOn = list(list("rdi" 1e15) list("rdr" 1e6))

procedure( r4OtaDevs(c)
  if( c
    list(list("pfetx" "M3" 2e-6 4e-6 "n1" "n1" "VDD" "VDD")
         list("pfetx" "M4" 2e-6 4e-6 "OUT" "n1" "VDD" "VDD")
         list("nfetx" "M1" 10e-6 8e-6 "n1" "INP" "tail" "GND")
         list("nfetx" "M2" 10e-6 8e-6 "x" "INN" "tail" "GND")
         list("nfetx" "MC" 10e-6 4e-6 "OUT" "VCAS" "x" "GND")
         list("nfetx" "MT" 8e-6 4e-6 "tail" "IBIAS" "GND" "GND")
         list("nfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "GND" "GND"))
    list(list("pfetx" "M3" 2e-6 4e-6 "n1" "n1" "VDD" "VDD")
         list("pfetx" "M4" 2e-6 4e-6 "OUT" "n1" "VDD" "VDD")
         list("nfetx" "M1" 10e-6 8e-6 "n1" "INP" "tail" "GND")
         list("nfetx" "M2" 10e-6 8e-6 "OUT" "INN" "tail" "GND")
         list("nfetx" "MT" 8e-6 4e-6 "tail" "IBIAS" "GND" "GND")
         list("nfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "GND" "GND")))
)

procedure( r4BuildOta(cell c)
  let( (cv)
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv append(a3Cfg->pins if( c '(("VCAS" "input")) nil)))
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) r4OtaDevs(c)))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
  )
)

procedure( r4Specs(pr)
  append(append(
    list(
      otaV("VREF" "vref" "0" "vref" "gnd!")
      otaV("VCAS" "vcas" "0" "vcas" "gnd!")
      otaV("VDD" "vdd" "0" "vdd" "gnd!")
      otaV("VDDD" "vdd" "0" "vddd" "gnd!")
      otaI("IB" "ib3" "vdd" "ib")
      otaI("IBD" "ibd" "vddd" "ibd")
      ;; body + sources
      otaC("CBODY" "cbody" "body" "gnd!")
      list("analogLib" "idc" "IINT" '(("idc" "0") ("acm" "icm")) '(("PLUS" "gnd!") ("MINUS" "body")))
      list("analogLib" "isin" "IINTT" '(("io" "0") ("ia" "itr") ("freq" "60") ("acm" "0")) '(("PLUS" "gnd!") ("MINUS" "body")))
      otaV("VSP" "0" "adm/2+vcmin" "ep" "body")
      otaV("VSN" "0" "-adm/2+vcmin" "en" "body")
      ;; electrodes
      otaR("RSP" "rs" "ep" "ep1") otaR("REP" "re" "ep1" "inpr") otaC("CEP" "ce" "ep1" "inpr")
      otaR("RSN" "rs" "en" "en1") otaR("REN" "re" "en1" "innr") otaC("CEN" "ce" "en1" "innr")
      otaV("VPP" "0" "0" "inpr" "inp")
      otaV("VPN" "0" "0" "innr" "inn")
      ;; amplifier network
      otaC("CCP" "cc" "inp" "p") otaC("CCX" "cc*dcc" "inp" "p") otaC("CCN" "cc" "inn" "n")
      otaC("CFP" "cfb" "p" "vref") otaC("CFN" "cfb" "n" "o"))
    if( pr
      list(list(ece203Lib "ece203_ss_pr_cell" "XPP" nil '(("A" "p") ("B" "vref")))
           list(ece203Lib "ece203_ss_pr_cell" "XPN" nil '(("A" "n") ("B" "o"))))
      list(otaR("RFP" "rfb" "p" "vref") otaR("RFN" "rfb" "n" "o"))))
    list(
      list(ece203Lib r4Cells->ota "XA" nil
           '(("INP" "p") ("INN" "n") ("OUT" "oa") ("VDD" "vdd") ("GND" "gnd!") ("IBIAS" "ib") ("VCAS" "vcas")))
      ldProbe("IPRB" "oa" "o")
      otaC("CL" "cl" "o" "gnd!")
      otaR("RLP" "rlp" "o" "out") otaC("CLP" "clp" "out" "gnd!")
      ;; CM sense + DRL
      otaR("RCMP" "rcm" "inp" "cm") otaR("RCMN" "rcm" "inn" "cm")
      otaC("CCMP" "ccm" "inp" "cm") otaC("CCMN" "ccm" "inn" "cm")
      ldE("EDRL" "vref" "cm" "drli" "vref" "adrl")
      otaR("RDRI" "rdi" "drli" "rl0")
      list(ece203Lib r4Cells->drl "XD" nil
           '(("INP" "vref") ("INN" "cm") ("OUT" "drlr") ("VDD" "vddd") ("GND" "gnd!") ("IBIAS" "ibd")))
      otaR("RDRR" "rdr" "drlr" "rl0")
      list("analogLib" "iprobe" "IPRD" nil '(("PLUS" "rl0") ("MINUS" "rl0b")))
      otaR("RSR" "rs" "rl0b" "rl1") otaR("RER" "re" "rl1" "body") otaC("CER" "ce" "rl1" "body")))
)

procedure( r4Build()
  ece203LibInfo()
  r4BuildOta(r4Cells->ota t)
  r4BuildOta(r4Cells->drl nil)
  otaTb(r4Cells->tb r4Specs(nil))
  otaTb(r4Cells->pr r4Specs(t))
  t
)

;; ---------------- measurement helpers ----------------
procedure( r4Tight() car(errset(option('gmin "1e-18" 'iabstol "1e-18" 'reltol "1e-6") t)) )
procedure( r4Set(over) ece203Vars(r4Vars) ece203Vars(over) )
procedure( r4Num(x fmt) acNum(and(numberp(x) float(x)) fmt) )

;; generic row writer: cols list of symbols
procedure( r4Open(name cols)
  let( (port)
    unless( isDir(r4Dir) createDir(r4Dir) )
    port = outfile(strcat(r4Dir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
procedure( r4Row(port cols r)
  let( (x first)
    first = t
    foreach(c cols
      x = get(r c)
      fprintf(port "%s%s" if( first "" ",")
              cond( (stringp(x) if( rexMatchp("," x) strcat("\"" x "\"") x))
                    (numberp(x) sprintf(nil "%.6g" float(x))) (t "n/a")))
      first = nil)
    fprintf(port "\n") drain(port)
  )
)

;; corners of |w| relative to its maximum
procedure( r4Corners(w)
  let( (m)
    m = and(w car(errset(ymax(mag(w)) nil)))
    list(m and(m car(errset(cross(db20(w) ece203Db(m) - 3.0 1 "rising") nil)))
           and(m car(errset(cross(db20(w) ece203Db(m) - 3.0 1 "falling") nil))))
  )
)

r4OpInsts = '("XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.MC" "XA.MT" "XA.MREF")
r4DrlInsts = '("XD.M1" "XD.M2" "XD.M3" "XD.M4" "XD.MT" "XD.MREF")

;; one DM/CM/interference AC (+ optional noise) run. Returns DPL with numbers + waves.
;; kind: 'dm (adm 1), 'cm (vcmin 1), 'int (icm 0.1u)
procedure( r4Ac(cell tag kind over noise)
  let( (r h ho hamp vin dO vp vn zin zinS c co nout nin rows m drl)
    r = list(nil 'tag tag 'cell cell 'kind kind 'status "ok")
    ece203Setup(cell strcat("_" tag))
    r4Tight()
    analysis('dc ?saveOppoint t)
    analysis('ac ?start "1m" ?stop "100k" ?dec "20")
    when( noise
      analysis('noise ?start "1m" ?stop "100k" ?dec "20" ?p "/out" ?n "/gnd!" ?iprobe "/VSP"))
    car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS" "/VPP/PLUS" "/VPN/PLUS" "/VSP/PLUS" "/IPRD/PLUS") nil))
    r4Set(append(cond( (kind == 'dm list(list("adm" 1.0) list("vcmin" 0.0) list("icm" 0.0)))
                       (kind == 'cm list(list("adm" 0.0) list("vcmin" 1.0) list("icm" 0.0)))
                       (t list(list("adm" 0.0) list("vcmin" 0.0) list("icm" 0.1e-6))))
                 over))
    run()
    vp = ldAc("inp") vn = ldAc("inn")
    unless( vp error("no ac result (%s)" tag))
    r->out = ldAc("out") r->o = ldAc("o") r->body = ldAc("body") r->vcm = (vp + vn) / 2.0
    vin = car(errset(ldAc("ep") - ldAc("en") nil))
    r->vin = vin
    when( kind == 'dm
      h = ldDiv(r->out vin) ho = ldDiv(r->o vin) hamp = ldDiv(r->out vp - vn)
      r->h = h r->ho = ho
      foreach(f '(10.0 60.0 100.0) putprop(r ldMag(h f) stringToSymbol(sprintf(nil "Hout_%d" fix(f)))))
      foreach(f '(10.0 60.0 100.0) putprop(r ldMag(ho f) stringToSymbol(sprintf(nil "Ho_%d" fix(f)))))
      r->Hout_100_dB = ece203Db(r->Hout_100) r->Hamp_100 = ldMag(hamp 100.0)
      c = r4Corners(h) r->Hout_max = car(c) r->Hout_max_dB = ece203Db(car(c)) r->fL_out = cadr(c) r->fH_out = caddr(c)
      co = r4Corners(ho) r->Ho_max = car(co) r->fL_o = cadr(co) r->fH_o = caddr(co)
      ;; Zin at the amplifier input (after the electrode model): v(inp) / i(VPP); through the electrode: v(VSP) / i(VSP)
      zin = car(errset(vp / i("/VPP/PLUS" ?result "ac") nil))
      zinS = car(errset((ldAc("ep") - ldAc("body")) / i("/VSP/PLUS" ?result "ac") nil))
      r->Zin_amp_P_10 = ldMag(zin 10.0)
      r->Zin_amp_N_10 = ldMag(car(errset(vn / i("/VPN/PLUS" ?result "ac") nil)) 10.0)
      r->Zin_src_P_10 = ldMag(zinS 10.0))
    ;; DC operating point
    foreach(n '("o" "out" "p" "n" "inp" "inn" "cm" "body" "drli" "drlr" "rl0" "vref")
      putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
    r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDDD = ldIdc("/VDDD/PLUS")
    rows = ece203OpDump(strcat(r4Dir "/" tag "_dcop.csv") append(r4OpInsts r4DrlInsts))
    m = ldMinMargin(rows "XA.") r->margin_A = car(m) r->worst_A = cadr(m)
    m = ldMinMargin(rows "XD.") r->margin_D = car(m) r->worst_D = cadr(m)
    r->vds_M2 = car(errset(pv("/XA/M2" "vds" ?result "dcOpInfo") nil))
    when( noise
      nout = car(errset(getData("out" ?result "noise") nil))
      nin = and(nout r->h car(errset(nout / mag(r->h) nil)))
      r->noise_out_rms = nsRms(nout 0.1 250.0)
      r->noise_app_in = and(r->noise_out_rms r->Hout_100 r->noise_out_rms / r->Hout_100)
      r->noise_deemb_in = nsRms(nin 0.1 250.0)
      r->noise_vsp_in = nsRms(car(errset(getData("in" ?result "noise") nil)) 0.1 250.0)
      nsSummary(strcat(r4Dir "/" tag "_noisesummary_0p1_250.txt") 'integrated 0.1 250.0)
      spsWriteWaves(strcat(r4Dir "/" tag "_noise.csv") "f_Hz,out_V_rtHz,deemb_in_V_rtHz" list(nout nin)))
    when( kind == 'dm
      ldWriteCurves(strcat(r4Dir "/" tag "_ac.csv") list(list("Hout" r->h) list("Ho" r->ho))))
    ece203SaveNetlist(cell strcat("ece203_r4_" tag))
    r
  )
)

;; ---------------- Stage A ----------------
r4ACols = '(tag cell kind variant status reason Hout_10 Hout_60 Hout_100 Hout_100_dB Hout_max_dB fL_out fH_out
  Ho_10 Ho_100 fL_o fH_o Hamp_100 Zin_amp_P_10 Zin_amp_N_10 Zin_src_P_10
  dc_o dc_out dc_p dc_n dc_inp dc_inn dc_cm dc_body I_VDD I_VDDD margin_A worst_A vds_M2 margin_D worst_D
  noise_out_rms noise_app_in noise_deemb_in noise_vsp_in)

procedure( r4ACase(port cell tag variant over noise)
  let( (r ok)
    ok = errset(r = r4Ac(cell tag 'dm over noise) t)
    unless( ok r = list(nil 'tag tag 'cell cell 'status "failed" 'reason sprintf(nil "%L" errset.errset)))
    r->variant = variant
    acSay("r4A %s: %s %s | Hout 10/60/100 %s %s %s (%s dB) max %s dB fL %s fH %s | Ho 100 %s fH_o %s | Hamp100 %s | Zin amp P/N %s %s src %s | DC o %s out %s n %s cm %s body %s | I %s %s | margin A %s %s (M2 vds %s) | noise out %s app %s deemb %s\n"
          tag r->status or(r->reason "") r4Num(r->Hout_10 "%.4g") r4Num(r->Hout_60 "%.4g") r4Num(r->Hout_100 "%.4g")
          r4Num(r->Hout_100_dB "%.2f") r4Num(r->Hout_max_dB "%.2f") r4Num(r->fL_out "%.4g") r4Num(r->fH_out "%.4g")
          r4Num(r->Ho_100 "%.4g") r4Num(r->fH_o "%.4g") r4Num(r->Hamp_100 "%.4g")
          r4Num(r->Zin_amp_P_10 "%.4g") r4Num(r->Zin_amp_N_10 "%.4g") r4Num(r->Zin_src_P_10 "%.4g")
          r4Num(r->dc_o "%.5g") r4Num(r->dc_out "%.5g") r4Num(r->dc_n "%.5g") r4Num(r->dc_cm "%.5g") r4Num(r->dc_body "%.5g")
          r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->margin_A "%.3f") or(r->worst_A "") r4Num(r->vds_M2 "%.4g")
          r4Num(r->noise_out_rms "%.4g") r4Num(r->noise_app_in "%.4g") r4Num(r->noise_deemb_in "%.4g"))
    r4Row(port r4ACols r)
    r
  )
)

procedure( r4StageA()
  let( (port)
    r4Build()
    port = r4Open("r4_stageA.csv" r4ACols)
    ;; DRL OFF (forward chain only), baseline LP 3.18M/200p
    r4ACase(port r4Cells->tb "A1_idealRfb_LP" "ideal Rfb, LP 3.18M/200p, DRL off" r4Off t)
    r4ACase(port r4Cells->tb "A2_idealRfb_noLP" "ideal Rfb, LP removed (rlp 1e15) - loading reference" append(r4Off list(list("rlp" 1e15))) nil)
    r4ACase(port r4Cells->tb "A3_idealRfb_LP31M8" "ideal Rfb, LP alternative 31.8M/20p (same tau)" append(r4Off list(list("rlp" 31.8e6) list("clp" 20e-12))) nil)
    r4ACase(port r4Cells->pr "A4_pseudoR_LP" "pseudo-R W3u/L2u, LP 3.18M/200p, DRL off" r4Off t)
    close(port)
    t
  )
)


;; ---------------- Stage B: DRL ----------------
;; System LP = Stage-A alternative 31.8 MOhm / 20 pF (the one RC change). Cc mismatch dcc 1 % for CMRR.
r4LP = list(list("rlp" 31.8e6) list("clp" 20e-12))
r4BCols = '(tag drl dcc status reason Adm60 Acm60 CMRR60_dB body60 vcm60 out60 o60 drl60 body60_per_uA
  Zin_amp_P_10 Zin_amp_N_10 ugf pm lg60 lg_dc ph0 dc_o dc_cm dc_body dc_drlr dc_drli I_VDD I_VDDD margin_A worst_A margin_D worst_D
  tr_body_pp tr_o_min tr_o_max tr_out_pp tr_vcm_pp tr_drl_min tr_drl_max)

procedure( r4DrlOver(mode)
  cond( (mode == "off" r4Off) (mode == "ideal" r4IdealOn) (t r4RealOn))
)

procedure( r4Stb(cell tag over)
  let( (s)
    ece203Setup(cell strcat("_" tag))
    r4Tight()
    analysis('stb ?start "1m" ?stop "10M" ?dec "20" ?probe "/IPRD")
    r4Set(over)
    run()
    s = otaStb()
    list(car(s) cadr(s) and(cadddr(s) ldMag(cadddr(s) 60.0)) and(cadddr(s) ldMag(cadddr(s) 1e-3)) nth(4 s) cadddr(s))
  )
)

procedure( r4Tran(cell tag over)
  let( (b o out vcm drl res)
    ece203Setup(cell strcat("_" tag))
    r4Tight()
    analysis('tran ?stop "50m" ?maxstep "20u")
    r4Set(append(over list(list("itr" 0.1e-6) list("adm" 0.0))))
    run()
    b = car(errset(v("/body" ?result "tran") nil))
    o = car(errset(v("/o" ?result "tran") nil))
    out = car(errset(v("/out" ?result "tran") nil))
    vcm = car(errset((v("/inp" ?result "tran") + v("/inn" ?result "tran")) / 2.0 nil))
    drl = car(errset(v("/drlr" ?result "tran") nil))
    res = list(nil 'b b 'o o 'out out 'vcm vcm 'drl drl)
    spsWriteWaves(strcat(r4Dir "/" tag "_tran.csv") "t_s,body_V,o_V,out_V,vcm_V,drlr_V" list(b o out vcm drl))
    res
  )
)
procedure( r4Pp(w a b) car(errset(ymax(clip(w a b)) - ymin(clip(w a b)) nil)) )

procedure( r4BCase(port mode dcc @optional (extra nil) (pre "B") (cell nil))
  let( (r over dm cm it st tr ok tag)
    unless( cell cell = r4Cells->tb )
    tag = sprintf(nil "%s_%s_dcc%g" pre mode dcc * 100.0)
    over = append(append(append(r4LP r4DrlOver(mode)) list(list("dcc" dcc))) extra)
    r = list(nil 'tag tag 'drl mode 'dcc dcc 'status "ok")
    ok = errset(
      progn(
        dm = r4Ac(cell strcat(tag "_dm") 'dm over nil)
        cm = r4Ac(cell strcat(tag "_cm") 'cm over nil)
        it = r4Ac(cell strcat(tag "_int") 'int over nil)
        r->Adm60 = dm->Hout_60
        r->Acm60 = ldMag(cm->out 60.0)
        r->CMRR60_dB = and(numberp(r->Adm60) numberp(r->Acm60) r->Acm60 > 0 ece203Db(r->Adm60 / r->Acm60))
        r->Zin_amp_P_10 = dm->Zin_amp_P_10 r->Zin_amp_N_10 = dm->Zin_amp_N_10
        r->body60 = ldMag(it->body 60.0) r->vcm60 = ldMag(it->vcm 60.0) r->out60 = ldMag(it->out 60.0)
        r->o60 = ldMag(it->o 60.0)
        r->drl60 = ldMag(car(errset(v(if( mode == "ideal" "/drli" "/drlr") ?result "ac") nil)) 60.0)
        r->body60_per_uA = and(r->body60 r->body60 / 0.1)
        foreach(k '(dc_o dc_cm dc_body dc_drlr dc_drli I_VDD I_VDDD margin_A worst_A margin_D worst_D)
          putprop(r get(dm k) k))
        when( mode != "off"
          st = car(errset(r4Stb(cell strcat(tag "_stb") over) t))
          when( st
            r->ugf = nth(0 st) r->pm = nth(1 st) r->lg60 = nth(2 st) r->lg_dc = nth(3 st) r->ph0 = nth(4 st)
            ldWriteCurves(strcat(r4Dir "/" tag "_stb.csv") list(list("LG" nth(5 st))))))
        when( dcc > 0.0
          tr = car(errset(r4Tran(cell strcat(tag "_tran") over) t))
          when( tr
            r->tr_body_pp = r4Pp(tr->b 0.0333 0.05)
            r->tr_o_min = car(errset(ymin(clip(tr->o 0.0333 0.05)) nil)) r->tr_o_max = car(errset(ymax(clip(tr->o 0.0333 0.05)) nil))
            r->tr_out_pp = r4Pp(tr->out 0.0333 0.05) r->tr_vcm_pp = r4Pp(tr->vcm 0.0333 0.05)
            r->tr_drl_min = car(errset(ymin(clip(tr->drl 0.0333 0.05)) nil)) r->tr_drl_max = car(errset(ymax(clip(tr->drl 0.0333 0.05)) nil))))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r4B %s: %s %s | Adm60 %s Acm60 %s CMRR %s dB | int: body %s vcm %s out %s o %s drl %s V | Zin P/N %s %s | stb UGF %s PM %s LG60 %s LGdc %s ph0 %s | DC o %s cm %s body %s drlr %s | I %s %s | margin A %s %s D %s %s | tran body pp %s o %s..%s out pp %s vcm pp %s drl %s..%s\n"
          tag r->status or(r->reason "") r4Num(r->Adm60 "%.4g") r4Num(r->Acm60 "%.4g") r4Num(r->CMRR60_dB "%.2f")
          r4Num(r->body60 "%.4g") r4Num(r->vcm60 "%.4g") r4Num(r->out60 "%.4g") r4Num(r->o60 "%.4g") r4Num(r->drl60 "%.4g")
          r4Num(r->Zin_amp_P_10 "%.4g") r4Num(r->Zin_amp_N_10 "%.4g")
          r4Num(r->ugf "%.4g") r4Num(r->pm "%.1f") r4Num(r->lg60 "%.4g") r4Num(r->lg_dc "%.4g") r4Num(r->ph0 "%.1f")
          r4Num(r->dc_o "%.5g") r4Num(r->dc_cm "%.5g") r4Num(r->dc_body "%.5g") r4Num(r->dc_drlr "%.5g")
          r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->margin_A "%.3f") or(r->worst_A "")
          r4Num(r->margin_D "%.3f") or(r->worst_D "")
          r4Num(r->tr_body_pp "%.4g") r4Num(r->tr_o_min "%.4g") r4Num(r->tr_o_max "%.4g") r4Num(r->tr_out_pp "%.4g")
          r4Num(r->tr_vcm_pp "%.4g") r4Num(r->tr_drl_min "%.4g") r4Num(r->tr_drl_max "%.4g"))
    r4Row(port r4BCols r)
    r
  )
)

procedure( r4StageB()
  let( (port)
    r4Build()
    port = r4Open("r4_drl_60hz.csv" r4BCols)
    foreach(mode '("off" "ideal" "real")
      r4BCase(port mode 0.01)
      r4BCase(port mode 0.0))
    close(port)
    t
  )
)


;; ---------------- Stage C ----------------
;; C1: VCAS points (baseline 1.05 from Stage A3) 1.10 / 1.15, ideal Rfb, LP 31.8M/20p, DRL off: gain, fH, margins.
r4CCols = '(tag vcas status reason Hout_10 Hout_100 Hout_100_dB fL_out fH_out Ho_100 fH_o dc_o margin_A worst_A vds_M2 vds_MC margin_MC)

procedure( r4C1()
  let( (port r ok)
    r4Build()
    port = r4Open("r4_C1_vcas.csv" r4CCols)
    foreach(vc '(1.05 1.10 1.15)
      ok = errset(r = r4Ac(r4Cells->tb sprintf(nil "C1_vcas%g" vc) 'dm append(append(r4LP r4Off) list(list("vcas" vc))) nil) t)
      unless( ok r = list(nil 'status "failed" 'reason sprintf(nil "%L" errset.errset)))
      r->tag = sprintf(nil "C1_vcas%g" vc) r->vcas = vc
      r->vds_MC = car(errset(pv("/XA/MC" "vds" ?result "dcOpInfo") nil))
      r->margin_MC = and(numberp(r->vds_MC) abs(r->vds_MC) - max(abs(car(errset(pv("/XA/MC" "vdsat" ?result "dcOpInfo") nil))) 0.1))
      acSay("r4C1 vcas %g: %s | Hout 10/100 %s %s (%s dB) fL %s fH %s | Ho100 %s fH_o %s | DC o %s | margin %s %s, M2 vds %s, MC vds %s margin %s\n"
            vc or(r->status "ok") r4Num(r->Hout_10 "%.4g") r4Num(r->Hout_100 "%.4g") r4Num(r->Hout_100_dB "%.2f")
            r4Num(r->fL_out "%.4g") r4Num(r->fH_out "%.4g") r4Num(r->Ho_100 "%.4g") r4Num(r->fH_o "%.4g") r4Num(r->dc_o "%.5g")
            r4Num(r->margin_A "%.3f") or(r->worst_A "") r4Num(r->vds_M2 "%.4g") r4Num(r->vds_MC "%.4g") r4Num(r->margin_MC "%.3f"))
      r4Row(port r4CCols r))
    close(port)
    t
  )
)

;; C2: the one DRL change -- CM-sense compensation ccm = 1 pF across each 10 GOhm sense resistor (zero ~16 Hz
;; against the ~5 GOhm x DRL-OTA input-cap pole). Real DRL OTA, VCAS 1.10 (C1 choice), LP 31.8M/20p, ideal Rfb.
r4Vcas = 1.10
procedure( r4C2()
  let( (port)
    r4Build()
    port = r4Open("r4_C2_drlcomp.csv" r4BCols)
    r4BCase(port "real" 0.01 list(list("vcas" r4Vcas) list("ccm" 0.0)) "C2before")
    r4BCase(port "real" 0.01 list(list("vcas" r4Vcas) list("ccm" 1e-12)) "C2after")
    close(port)
    t
  )
)

;; ---------------- C3: real-bias final system ----------------
;; Only VDD 1.8 V + ONE ideal 100 nA reference (IREF, pref -> gnd). PMOS diode MP0 4u/4u carries it;
;; MP1 / MP2 2u/4u mirror ~50 nA into the main OTA IBIAS (ib) and the DRL OTA IBIAS (ibd).
;; VREF = VDD divider RV1/RV2 90M/90M (10 nA) + CVR 20 pF decoupling; VCAS = RC1/RC2 70M/110M (1.10 V, 10 nA).
;; VDDD is now a 0 V ammeter (vddd <- vdd) for the DRL OTA current. Ideal resistors in the dividers are a
;; simplification (on-chip ~100 MOhm high-res poly would be large).
r4Cells->rb = "ece203_r4_ecg_rb_tb"
r4Cells->rbpr = "ece203_r4_ecg_rbpr_tb"
r4RbVars = list(list("vcas" 1.10) list("rc1" 70e6) list("rc2" 110e6) list("ccm" 1e-12))

procedure( r4SpecsRB(pr)
  append(
    setof(e r4Specs(pr) !member(caddr(e) '("VREF" "VCAS" "IB" "IBD" "VDDD")))
    list(otaV("VDDD" "0" "0" "vddd" "vdd")
         otaI("IREF" "iref" "pref" "gnd!")
         ece203FetSpec("pfetx" "MP0" 4e-6 4e-6 "pref" "pref" "vdd" "vdd")
         ece203FetSpec("pfetx" "MP1" 2e-6 4e-6 "ib" "pref" "vdd" "vdd")
         ece203FetSpec("pfetx" "MP2" 2e-6 4e-6 "ibd" "pref" "vdd" "vdd")
         otaR("RV1" "rv1" "vdd" "vref") otaR("RV2" "rv2" "vref" "gnd!") otaC("CVR" "cvref" "vref" "gnd!")
         otaR("RC1" "rc1" "vdd" "vcas") otaR("RC2" "rc2" "vcas" "gnd!")))
)

procedure( r4C3()
  let( (port portA r)
    r4Build()
    otaTb(r4Cells->rb r4SpecsRB(nil))
    otaTb(r4Cells->rbpr r4SpecsRB(t))
    portA = r4Open("r4_C3_final_dm.csv" r4ACols)
    r = r4ACase(portA r4Cells->rbpr "C3_rbpr_dm" "FINAL: real bias + pseudo-R + real DRL (ccm 1p) + LP 31.8M/20p, VCAS div 1.10"
                append(append(r4LP r4RealOn) r4RbVars) t)
    acSay("r4C3 bias: vref %s vcas %s ib-node %s\n" r4Num(ldDc("vref") "%.5g") r4Num(ldDc("vcas") "%.5g") r4Num(ldDc("ib") "%.5g"))
    r4ACase(portA r4Cells->rb "C3_rb_dm" "real bias + ideal Rfb + real DRL (ccm 1p) + LP 31.8M/20p"
            append(append(r4LP r4RealOn) r4RbVars) t)
    close(portA)
    port = r4Open("r4_C3_final_drl.csv" r4BCols)
    r4BCase(port "real" 0.01 r4RbVars "C3rbpr" r4Cells->rbpr)
    r4BCase(port "real" 0.0 r4RbVars "C3rbpr" r4Cells->rbpr)
    close(port)
    t
  )
)

;; ---------------- C4: mismatch Monte Carlo (N = 12) on the frozen final config ----------------
;; PDK process.scs has a statistics { ... mismatch { } } block. OCEAN monteCarlo with analysisVariation
;; 'mismatch, same seed for the DM and the CM run so sample k is the same circuit in both.
procedure( r4Mc(tag kind exprs)
  let( (ok over file)
    over = append(append(append(r4LP r4RealOn) r4RbVars)
                  if( kind == 'dm list(list("adm" 1.0) list("vcmin" 0.0) list("icm" 0.0) list("dcc" 0.0))
                                 list(list("adm" 0.0) list("vcmin" 1.0) list("icm" 0.0) list("dcc" 0.0))))
    ece203Setup(r4Cells->rbpr strcat("_" tag))
    r4Tight()
    analysis('ac ?start "1m" ?stop "100k" ?dec "20")
    r4Set(over)
    file = strcat(r4Dir "/" tag "_mc.txt")
    ok = errset(
      progn(
        acSay("r4C4: monteCarlo arglist %L\n" car(errset(arglist('monteCarlo) nil)))
        if( member('seed car(errset(arglist('monteCarlo) nil))) || member("seed" car(errset(arglist('monteCarlo) nil)))
          then monteCarlo(?numIters "12" ?startIter "1" ?analysisVariation 'mismatch ?saveData t ?seed "12345")
          else monteCarlo(?numIters "12" ?startIter "1" ?analysisVariation 'mismatch ?saveData t))
        acSay("r4C4: monte functions %L\n" listFunctions("^monte"))
        acSay("r4C4: iter functions %L\n" listFunctions("^iter"))
        foreach(e exprs monteExpr(car(e) cadr(e)))
        monteRun()
        ;; per-iteration values: iterVsValue(name) -> waveform value vs iteration
        let( (port w xs)
          port = outfile(file "w")
          fprintf(port "expr,iter,value\n")
          foreach(e exprs
            w = car(errset(iterVsValue(car(e)) t))
            acSay("r4C4 %s: iterVsValue(%s) -> %L\n" tag car(e) w)
            when( w && drIsWaveform(w)
              xs = drGetWaveformXVec(w)
              for(k 0 drVectorLength(xs) - 1
                fprintf(port "%s,%g,%.6g\n" car(e) drGetElem(xs k) drGetElem(drGetWaveformYVec(w) k)))))
          close(port))
        t)
      t)
    acSay("r4C4 %s: monteCarlo -> %L, output file %s exists %L\n" tag ok file isFile(file))
    when( isFile(file) sh(sprintf(nil "sed 's/^/AC> mc %s: /' %s | head -40" tag file)))
    ok
  )
)

procedure( r4C4()
  let( (h)
    h = "(VF(\"/out\") / (VF(\"/ep\") - VF(\"/en\")))"
    r4Mc("C4_dm" 'dm
      list(list("g100" sprintf(nil "value(mag(%s) 100)" h))
           list("g60" sprintf(nil "value(mag(%s) 60)" h))
           list("fL" sprintf(nil "cross(db20(mag(%s)) (ymax(db20(mag(%s))) - 3) 1 \"rising\")" h h))
           list("fH" sprintf(nil "cross(db20(mag(%s)) (ymax(db20(mag(%s))) - 3) 1 \"falling\")" h h))
           list("dc_o" "VDC(\"/o\")")))
    r4Mc("C4_cm" 'cm
      list(list("acm60" "value(mag(VF(\"/out\")) 60)")))
    t
  )
)

;; read the finished MC families (mc1_ac) directly from the psf dirs; per-sample g100, g60, fL, fH, acm60
procedure( r4WaveRows(w)
  let( (xs ys rows)
    when( w && drIsWaveform(w)
      xs = drGetWaveformXVec(w) ys = drGetWaveformYVec(w)
      for(k 0 drVectorLength(xs) - 1 rows = cons(list(drGetElem(xs k) drGetElem(ys k)) rows)))
    reverse(rows)
  )
)
procedure( r4McName()
  let( (n)
    foreach(x results()
      when( !n && symbolp(x) && x == 'ac n = x))
    acSay("r4C4read: selected %L\n" n)
    if( stringp(n) stringToSymbol(n) n)
  )
)
procedure( r4C4Read()
  let( (base dm cm h g100 g60 fl fh acm port rows)
    base = strcat(getShellEnvVar("HOME") "/simulation/ece203_r4_ecg_rbpr_tb/spectre/")
    dm = openResults(strcat(base "schematic_C4_dm/psf"))
    foreach(x results() acSay("r4C4read: result %L\n" x))
    selectResult(r4McName())
    h = car(errset(v("/out") / (v("/ep") - v("/en")) t))
    acSay("r4C4read: h %L sweepNames %L\n" h car(errset(sweepNames(h) nil)))
    g100 = car(errset(value(mag(h) 100) t))
    g60 = car(errset(value(mag(h) 60) t))
    fl = car(errset(cross(db20(h) ymax(db20(h)) - 3 1 "rising") t))
    fh = car(errset(cross(db20(h) ymax(db20(h)) - 3 1 "falling") t))
    acSay("r4C4read: g100 %L g60 %L fL %L fH %L\n" g100 g60 fl fh)
    cm = openResults(strcat(base "schematic_C4_cm/psf"))
    selectResult(r4McName())
    acm = car(errset(value(mag(v("/out")) 60) t))
    port = outfile(strcat(r4Dir "/r4_mc12.csv") "w")
    fprintf(port "quantity,sample,value\n")
    foreach(q list(list("g100" g100) list("g60" g60) list("fL" fl) list("fH" fh) list("acm60" acm))
      rows = r4WaveRows(cadr(q))
      unless( rows when( numberp(cadr(q)) rows = list(list(0 cadr(q)))))
      foreach(r rows
        fprintf(port "%s,%g,%.6g\n" car(q) car(r) cadr(r))
        acSay("mc %s sample %g = %g\n" car(q) car(r) cadr(r))))
    close(port)
    t
  )
)
