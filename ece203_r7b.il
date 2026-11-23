;; ECE203 R7B: CMFB input-gate capacitance causality test (diagnostic only, no MOS redesign).
;; Task: docs/ECE203_round7b_cmfb_gatecap_causality_task.md. All R6D / R7A cells are read-only.
;;
;; Step 1 (job ece203_r7b_cap): independent estimate of the extra load of the R7A a2 detector input devices on op / on
;;   (a) DC op of the unchanged R7A system bench ece203_r7a_tb_buf_a2 (TG static phase A, vd 0): BSIM3 cgg/cgs/cgd/cgb
;;       of XC.MA1 (gate = op) and XC.MB1 (gate = on);
;;   (b) small-signal gate-input admittance of the unchanged detector cell ece203_r7a_cmfb_a2 in a new standalone bench
;;       ece203_r7b_cin_tb (copy of the R7A standalone bench with an AC magnitude on VOP or VON only):
;;       C_eff(f) = Im(Y_in)/(2 pi f), Y_in = current delivered by the source into the gate node / V_ac;
;;       bias vcm 0.899918 V (R7A a2 system op/on DC), vd in {-0.094, 0, +0.094} V (the chopped DM swing peaks).
;; Step 2 (jobs ece203_r7b_build x3, ece203_r7b_smoke, ece203_r7b_tran x3): new benches ece203_r7b_tb_c0/_c1/_c2 =
;;   the R6D BUFFERED spec list (ideal R6C CMFB, XCD, CLBP/CLBN) + only CCOP (op gnd!) / CCON (on gnd!) = Cextra
;;   (none in c0). 60 ms 2 kHz TG tran with the R6D-R setting C (gmin 1e-18, iabstol 1e-17, reltol 1e-5, cmin 1e-17 F),
;;   psf in /tmp/lix015_r7b, per-run watchdog.

r7bDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r7b")
r7bTmp = "/tmp/lix015_r7b"
r7bStall = 240
;; Cextra per branch (F): filled from the pre-registered estimate in docs/ece203_data/round7b/r7b_cap_plan.md
r7bCases = list(nil 'c0 nil 'c1 nil 'c2 nil)
procedure( r7bCase() or(getShellEnvVar("AC_R7B_CASE") "c0") )
procedure( r7bCell(c) strcat("ece203_r7b_tb_" c) )
procedure( r7bMkdir(d) unless( isDir(d) sh(sprintf(nil "mkdir -p %s" d))) )
procedure( r7bOpen(name cols)
  let( (port)
    r7bMkdir(r7bDir)
    port = outfile(strcat(r7bDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)

;; ---------- Step 1a: BSIM op capacitances in the unchanged R7A system ----------
r7bCapParams = '("ids" "vgs" "vds" "vth" "gm" "region" "cgg" "cgs" "cgd" "cgb" "cgsovl" "cgdovl" "cgbovl")
procedure( r7bCapOp()
  let( (port names n)
    r7bMkdir(r7bDir)
    ece203Setup("ece203_r7a_tb_buf_a2" "_r7b_capop")
    r6bOpt(r6bSysOpts)
    r6bSet(r6Vars append(r7aSysBase list(list("chen" 0.0) list("vd" 0.0))))
    analysis('dc ?saveOppoint t)
    run()
    names = ece203OpNames()
    port = outfile(strcat(r7bDir "/r7b_capop_system.csv") "w")
    fprintf(port "inst,opname,%s,op_V,on_V\n" buildString(r7bCapParams ","))
    foreach(inst '("XC.MA1" "XC.MB1" "XC.MA2" "XC.MB2")
      n = ece203OpFind(names inst)
      fprintf(port "%s,%s" inst or(n "n/a"))
      foreach(p r7bCapParams fprintf(port ",%s" spsNum(and(n car(errset(pv(n p ?result "dcOpInfo") nil))) "%.6g")))
      fprintf(port ",%s,%s\n" spsNum(ldDc("op") "%.7g") spsNum(ldDc("on") "%.7g"))
      acSay("r7b capop %s (%s): cgg %s cgs %s cgd %s cgb %s ids %s\n" inst or(n "n/a")
            spsNum(and(n car(errset(pv(n "cgg" ?result "dcOpInfo") nil))) "%.4g")
            spsNum(and(n car(errset(pv(n "cgs" ?result "dcOpInfo") nil))) "%.4g")
            spsNum(and(n car(errset(pv(n "cgd" ?result "dcOpInfo") nil))) "%.4g")
            spsNum(and(n car(errset(pv(n "cgb" ?result "dcOpInfo") nil))) "%.4g")
            spsNum(and(n car(errset(pv(n "ids" ?result "dcOpInfo") nil))) "%.4g")))
    close(port)
    ;; every dcOpInfo name under XC.MA1 (PDK parasitic sub-elements, e.g. wiring capacitors)
    port = outfile(strcat(r7bDir "/r7b_capop_names.txt") "w")
    foreach(x names when( stringp(x) && (rexMatchp("XC.MA1" x) || rexMatchp("XC/MA1" x)) fprintf(port "%s\n" x)))
    close(port)
    sh(sprintf(nil "f=$(find %s/simulation/ece203_r7a_tb_buf_a2 -path '*_r7b_capop*' -name input.scs | head -1); cp \"$f\" %s/r7b_capop_netlist.scs; rm -rf %s/simulation/ece203_r7a_tb_buf_a2/spectre/schematic_r7b_capop/psf"
               getShellEnvVar("HOME") r7bDir getShellEnvVar("HOME")))
    t
  )
)

;; ---------- Step 1b: standalone gate-input admittance of the unchanged R7A a2 detector ----------
r7bCinCell = "ece203_r7b_cin_tb"
procedure( r7bCinSpecs()
  list(
    otaV("VDD" "vdd" "0" "vdd" "gnd!")
    otaV("VDDC" "vdd" "0" "vddc" "gnd!")
    otaV("VREF" "vref" "0" "vref" "gnd!")
    otaV("VLD" "vref" "0" "vld" "gnd!")
    otaI("IB" "ib3" "vdd" "ib")
    ece203FetSpec("nfetx" "MREF" 2e-6 4e-6 "ib" "ib" "gnd!" "gnd!")
    otaV("VOP" "vcm+vd/2" "aop" "op" "gnd!")
    otaV("VON" "vcm-vd/2" "aon" "on" "gnd!")
    ece203FetSpec("pfetx" "M3R" 2e-6 4e-6 "vld" "vg" "vdd" "vdd")
    ece203FetSpec("pfetx" "M4R" 2e-6 4e-6 "vld" "vg" "vdd" "vdd")
    list(ece203Lib "ece203_r7a_cmfb_a2" "XC" nil '(("OP" "op") ("ON" "on") ("VREF" "vref") ("VCMFB" "vg") ("VDD" "vddc")
                                                     ("GND" "gnd!") ("IBIAS" "ib"))))
)
procedure( r7bCin()
  let( (tag iw y w)
    r7bMkdir(r7bDir)
    unless( ddGetObj(ece203Lib "ece203_r7a_cmfb_a2") error("missing ece203_r7a_cmfb_a2"))
    unless( ddGetObj(ece203Lib r7bCinCell) otaTb(r7bCinCell r7bCinSpecs()))
    foreach(br '(("op" "VOP" 1.0 0.0) ("on" "VON" 0.0 1.0))
      foreach(vdx '(-0.094 0.0 0.094)
        tag = sprintf(nil "cin_%s_vd%+.0fmV" car(br) vdx * 1000.0)
        ece203Setup(r7bCinCell strcat("_" tag))
        r6bOpt(r6bSysOpts)
        ece203Vars(list(list("vdd" 1.8) list("vref" 0.9) list("ib3" 50e-9) list("vcm" 0.899918) list("vd" vdx)
                        list("aop" nth(2 br)) list("aon" nth(3 br))))
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "10" ?stop "100M" ?dec "10")
        run()
        ;; current into the source's PLUS terminal flows out of the circuit node; the current the source delivers into the
        ;; gate node is -i(PLUS). Y = -i / 1 V.
        iw = i(strcat("/" cadr(br) "/PLUS") ?result "ac")
        y = -1.0 * iw
        w = 2.0 * 3.141592653589793 * xval(y)
        ldWriteCurves(strcat(r7bDir "/" tag "_y.csv") list(list("Y" y)))
        spsWriteWaves(strcat(r7bDir "/" tag "_ceff.csv") "f_Hz,Ceff_F,Geff_S" list(imag(y) / w real(y)))
        acSay("r7b cin %s: Ceff 1k %s 100k %s 1M %s 10M %s F | Re Y 1k %s S | vg %s\n" tag
              r4Num(ece203V(imag(y) / w 1e3) "%.4g") r4Num(ece203V(imag(y) / w 1e5) "%.4g") r4Num(ece203V(imag(y) / w 1e6) "%.4g")
              r4Num(ece203V(imag(y) / w 1e7) "%.4g") r4Num(ece203V(real(y) 1e3) "%.4g") r4Num(ldDc("vg") "%.6g"))))
    sh(sprintf(nil "f=$(find %s/simulation/%s -name input.scs | head -1); cp \"$f\" %s/r7b_cin_netlist.scs; rm -rf %s/simulation/%s/spectre/schematic_*/psf"
               getShellEnvVar("HOME") r7bCinCell r7bDir getShellEnvVar("HOME") r7bCinCell))
    t
  )
)
procedure( r7bCap() r7bCapOp() r7bCin() t )

;; ---------- Step 2: benches (each built in its own Virtuoso session) ----------
procedure( r7bSpecs(c)
  let( (cx base)
    cx = get(r7bCases stringToSymbol(c))
    base = append(r6dBaseSpecs()
                  list(list(ece203Lib r6dCells->cd "XCD" nil '(("FP" "fp") ("FN" "fn") ("BUFP" "bufp") ("BUFN" "bufn") ("VDD" "vdd")
                                                                ("GND" "gnd!") ("IBIAS" "ib")))
                       otaC("CLBP" "clb" "bufp" "gnd!") otaC("CLBN" "clb" "bufn" "gnd!")))
    if( c == "c0" base
        progn( unless( cx error("no Cextra for %s" c))
               append(base list(otaC("CCOP" sprintf(nil "%g" cx) "op" "gnd!") otaC("CCON" sprintf(nil "%g" cx) "on" "gnd!")))))
  )
)
procedure( r7bBuild()
  let( (c)
    ece203LibInfo()
    c = r7bCase()
    unless( ddGetObj(ece203Lib r6dCells->cd) error("missing %s" r6dCells->cd))
    when( ddGetObj(ece203Lib r7bCell(c)) error("%s already exists" r7bCell(c)))
    otaTb(r7bCell(c) r7bSpecs(c))
    t
  )
)
;; ---------- Step 2: transient (smoke 1 ms or full 60 ms), R6D-R setting C ----------
r7bTCols = '(tag case stop status reason t_end stalled_at fp_cm_avg op_cm_avg buf_cm_avg vg_min vg_max I_VDD I_VDDD rows csv)
procedure( r7bTranRun(c stop)
  let( (cell tag r ok sim psf vid fp fn op on vg dr bp bn iv id names waves file wlog port t1 t0 out)
    cell = r7bCell(c) tag = sprintf(nil "%s_%s" if( stop < 10e-3 "P" "T") c)
    out = strcat(r7bTmp "/out") r7bMkdir(out)
    port = r7bOpen(sprintf(nil "%s.csv" tag) r7bTCols)
    r = list(nil 'tag tag 'case c 'stop stop 'status "ok")
    sim = sprintf(nil "%s/sim_%s" r7bTmp tag) psf = strcat(sim "/psf")
    sh(sprintf(nil "rm -rf %s" sim))
    wlog = strcat(out "/watchdog.log")
    ok = errset(
      progn(
        unless( ddGetObj(ece203Lib cell) error("missing %s" cell))
        ece203Setup(cell strcat("_" tag))
        resultsDir(sim)
        r6bOpt('(gmin "1e-18" iabstol "1e-17" reltol "1e-5"))
        analysis('tran ?stop sprintf(nil "%g" stop) ?maxstep "0.5u" ?cmin "1e-17")
        car(errset(saveOption('save "selected") nil))
        car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr" "/bufp" "/bufn") nil))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars append(r7aSysBase list(list("chen" 1.0) list("tch" 500e-6) list("vd" 1e-3))))
        sh(sprintf(nil "nohup bash %s/tools/r7b_watchdog.sh %s %s %d %s > /dev/null 2>&1 &" acRoot tag psf r7bStall wlog))
        run()
        when( isFile(strcat(sim "/WATCHDOG_STALL"))
          r->stalled_at = car(errset(let( (p l) p = infile(strcat(sim "/WATCHDOG_STALL")) gets(l p) close(p) car(parseString(l "\n"))) nil))
          error("stalled (watchdog)"))
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        r->t_end = r6bTend(vid)
        when( r->t_end < 0.99 * stop error("tran stopped at %g s" r->t_end))
        fp = v("/fp" ?result "tran") fn = v("/fn" ?result "tran") op = v("/op" ?result "tran") on = v("/on" ?result "tran")
        vg = v("/vg" ?result "tran") dr = v("/drlr" ?result "tran") bp = v("/bufp" ?result "tran") bn = v("/bufn" ?result "tran")
        iv = car(errset(i("/VDD/PLUS" ?result "tran") nil)) id = car(errset(i("/VDDD/PLUS" ?result "tran") nil))
        t1 = r->t_end t0 = if( t1 > 0.03 0.04 0.5 * t1)
        r->fp_cm_avg = chAvg((fp + fn) / 2.0 t0 t1) r->op_cm_avg = chAvg((op + on) / 2.0 t0 t1)
        r->buf_cm_avg = chAvg((bp + bn) / 2.0 t0 t1)
        r->vg_min = ymin(vg) r->vg_max = ymax(vg)
        r->I_VDD = and(iv chAvg(iv t0 t1)) r->I_VDDD = and(id chAvg(id t0 t1))
        file = sprintf(nil "%s/%s_tran.csv" out tag)
        names = "t_s,vid_V,fp_V,fn_V,op_V,on_V,vg_V,drlr_V,bufp_V,bufn_V" waves = list(vid fp fn op on vg dr bp bn)
        when( and(iv id) names = strcat(names ",i_vdd_A,i_vddd_A") waves = append(waves list(iv id)))
        r->rows = r6bWrite(file names waves)
        sh(sprintf(nil "cd %s && sha256sum %s_tran.csv > %s_tran.csv.sha256 && gzip -f %s_tran.csv" out tag tag tag))
        r->csv = strcat(file ".gz")
        t)
      t)
    unless( ok r->status = if( isFile(strcat(sim "/WATCHDOG_STALL")) "stalled" "failed") r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "gzip -c %s/spectre.out > %s/%s_spectre.out.gz 2>/dev/null; cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs 2>/dev/null; rm -rf %s"
               psf out tag getShellEnvVar("HOME") cell out tag psf))
    acSay("r7bT %s: %s %s | t_end %s stalled %s | fp/fn cm %s op/on cm %s buf cm %s | vg %s..%s | I %s %s | rows %s\n"
          tag r->status or(r->reason "") r4Num(r->t_end "%.6g") or(r->stalled_at "-") r4Num(r->fp_cm_avg "%.6g")
          r4Num(r->op_cm_avg "%.6g") r4Num(r->buf_cm_avg "%.5g") r4Num(r->vg_min "%.5g") r4Num(r->vg_max "%.5g")
          r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->rows "%.0f"))
    r4Row(port r7bTCols r)
    close(port)
    t
  )
)
procedure( r7bSmoke() r7bTranRun(r7bCase() 1e-3) )
procedure( r7bTran() r7bTranRun(r7bCase() 60e-3) )
