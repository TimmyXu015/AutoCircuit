;; ECE203 R8D: isolate the input (XCI) / output (XCO) TG choppers as the source of the chopped periodic fL rise (0.094 -> 0.338 Hz).
;; Task: docs/ECE203_round8d_tg_isolation_task.md; pre-registration docs/ece203_data/round8d/r8d_plan.md.
;; Only diagnostic variable: the master of XCI / XCO, real MOS TG (Project/ece203_r6b_tgchop) -> ideal 4-relay TG
;; (new master Project/ece203_r8d_ideal_tg, same 10 pins). Everything else = r8bSpecs() (real MOS pseudo-R, OTA, CMFB,
;; DRL, CD, bias, Cc 60p, Cfb 0.5p, LP 4M/148p, COUT 10p, electrodes, clocks). R8B / R8C cells and data are read-only.
;; Jobs:
;;   ece203_r8d_unit   Stage A: analogLib switch CDF/terminal probe, build ece203_r8d_ideal_tg + unit bench
;;                     ece203_r8d_tg_tb, static DC (Ron / polarity / off), 2 ms 2 kHz chopped smoke tran
;;   ece203_r8d_build  build system cell for AC_R8D_CASE = ii | im | mi
;;   ece203_r8d_off    chen 0 dc + ac 1 mHz-100 kHz node transfers (= r8cOff)
;;   ece203_r8d_pss    chen 1 zero-input PSS (AC_R8D_STEP = b1 | b2), writepss
;;   ece203_r8d_pac    readpss + PAC sb0 0.01-250 Hz 40/dec (same save list as the PSS run)
;; Measurement code = R8C (ece203_r8c.il: r8cOff, r8cPeriodic) with r8cDir / r8cTmp / r8cWd / r8cExtraOps rebound.

r8dDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r8d")
r8dTmp = "/tmp/lix015_r8d"
r8dTg = "ece203_r8d_ideal_tg"
r8dUtb = "ece203_r8d_tg_tb"
r8dRon = "1.68k"           ;; pre-set: R6B real TG Ron at Vcm 0.9 V (1681 Ohm)
;; case -> (cell, XCI master ideal?, XCO master ideal?)
r8dCases = list(nil
  'ii list(nil 'cell "ece203_r8d_tb_ii" 'xci t   'xco t)
  'im list(nil 'cell "ece203_r8d_tb_im" 'xci t   'xco nil)
  'mi list(nil 'cell "ece203_r8d_tb_mi" 'xci nil 'xco t))
procedure( r8dKey() or(getShellEnvVar("AC_R8D_CASE") "ii") )
procedure( r8dC(key) let( (p) p = get(r8dCases stringToSymbol(key)) unless( p error("unknown R8D case %s" key)) p ) )
procedure( r8dMk(d) unless( isDir(d) sh(sprintf(nil "mkdir -p %s" d))) )
procedure( r8dSay(file fmt @rest args) let( (p) p = outfile(file "a") apply('fprintf cons(p cons(fmt args))) close(p) ) )

;; ---------- ideal TG master: 4 analogLib switch (Spectre relay), same CDF values as chSw() except rc ----------
;; phase A (CKA high): INP-OUTP, INN-OUTN; phase B (CKB high): INP-OUTN, INN-OUTP. Control NC- = GND pin.
;; CKAB / CKBB / VDD are pins only (no device), so the 10-pin interface equals ece203_r6b_tgchop.
procedure( r8dSw(name a b ck)
  list("analogLib" "switch" name
       list(list("vt1" "0.8") list("vt2" "1.0") list("ro" "1e20") list("rc" r8dRon))
       list(list("N+" a) list("N-" b) list("NC+" ck) list("NC-" "GND")))
)
procedure( r8dTgSpecs()
  list(r8dSw("SA1" "INP" "OUTP" "CKA") r8dSw("SA2" "INN" "OUTN" "CKA")
       r8dSw("SB1" "INP" "OUTN" "CKB") r8dSw("SB2" "INN" "OUTP" "CKB"))
)
procedure( r8dBuildTg()
  let( (cv)
    when( ddGetObj(ece203Lib r8dTg) error("%s already exists" r8dTg))
    cv = acOpenSch(ece203Lib r8dTg)
    ece203Pins(cv '(("INP" "inputOutput") ("INN" "inputOutput") ("OUTP" "inputOutput") ("OUTN" "inputOutput")
                    ("CKA" "input") ("CKAB" "input") ("CKB" "input") ("CKBB" "input") ("VDD" "inputOutput") ("GND" "inputOutput")))
    ece203Place(cv r8dTgSpecs())
    ece203Finish(cv ece203Lib r8dTg)
    ece203Symbol(ece203Lib r8dTg)
    r8dTg
  )
)
;; replace the master of the named instances (spec = (lib cell name params terms)); nothing else changes
procedure( r8dSwapMaster(specs names master)
  mapcar(lambda((e) if( member(caddr(e) names) list(car(e) master caddr(e) nth(3 e) nth(4 e)) e)) specs)
)

;; ---------- Stage A: probe + unit bench ----------
procedure( r8dProbe(file)
  let( (cdf sym ok)
    ok = errset(
      progn(
        cdf = cdfGetBaseCellCDF(ddGetObj("analogLib" "switch"))
        unless( cdf error("no analogLib/switch CDF"))
        foreach(p cdf~>parameters r8dSay(file "param %s default=%L prompt=%L\n" p~>name p~>defValue p~>prompt))
        r8dSay(file "simInfo spectre: %L\n" car(errset(get(cdf~>simInfo (quote spectre)) nil)))
        sym = dbOpenCellViewByType("analogLib" "switch" "symbol")
        r8dSay(file "symbol terminals: %L\n" and(sym sym~>terminals~>name))
        when( sym dbClose(sym))
        t)
      t)
    unless( ok r8dSay(file "probe failed: %L\n" errset.errset))
    sh(sprintf(nil "(CDS_AUTO_64BIT=ALL spectre -h relay) > %s/spectre_help_relay.txt 2>&1" r8dDir))
    and(ok t)
  )
)
;; unit bench = R6B unit bench topology (ideal low-Z sources, 1 pF loads, Ron probe current, leak resistors, R6B clocks)
procedure( r8dUSpecs() r8dSwapMaster(r6bUSpecs() '("XT") r8dTg) )
procedure( r8dUDc(tag over)
  ece203Setup(r8dUtb strcat("_r8d_" tag))
  r6bOpt('(gmin "1e-18"))
  analysis('dc ?saveOppoint t)
  r6bSet(r6bUVars over)
  run()
)
procedure( r8dUnit()
  let( (f r ok ip in op on ca cb vid vod cm port tA tB)
    ece203LibInfo() r8dMk(r8dDir)
    foreach(x list(r6bCells->tg r8bCell) unless( ddGetObj(ece203Lib x) error("missing %s" x)))
    r8dProbe(strcat(r8dDir "/A_switch_probe.txt"))
    r8dBuildTg()
    when( ddGetObj(ece203Lib r8dUtb) error("%s already exists" r8dUtb))
    otaTb(r8dUtb r8dUSpecs())
    f = strcat(r8dDir "/A_unit_static.csv")
    port = outfile(f "w") fprintf(port "key,value\n") close(port)
    ;; static DC at vcm 0.9 V
    r = list(nil 'status "ok")
    ok = errset(
      progn(
        r8dUDc("A_ronA" '(("vcm" 0.9) ("iro" 100e-9) ("pa" 1.0) ("pb" 0.0)))
        r->ron_A = (ldDc("inp") - ldDc("outp")) / 100e-9
        sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/A_unit_netlist.scs" getShellEnvVar("HOME") r8dUtb r8dDir))
        r8dUDc("A_ronB" '(("vcm" 0.9) ("iro" 100e-9) ("pa" 0.0) ("pb" 1.0)))
        r->ron_B = (ldDc("inn") - ldDc("outp")) / 100e-9
        r8dUDc("A_polA" '(("vcm" 0.9) ("vdc" 0.01) ("pa" 1.0) ("pb" 0.0)))
        r->vod_A = ldDc("outp") - ldDc("outn")
        r8dUDc("A_polB" '(("vcm" 0.9) ("vdc" 0.01) ("pa" 0.0) ("pb" 1.0)))
        r->vod_B = ldDc("outp") - ldDc("outn")
        r8dUDc("A_polA_0p1mV" '(("vcm" 0.9) ("vdc" 1e-4) ("pa" 1.0) ("pb" 0.0)))
        r->vod_A_0p1mV = ldDc("outp") - ldDc("outn")
        r8dUDc("A_polB_0p1mV" '(("vcm" 0.9) ("vdc" 1e-4) ("pa" 0.0) ("pb" 1.0)))
        r->vod_B_0p1mV = ldDc("outp") - ldDc("outn")
        ;; both phases off: outputs held only by rl = 1 TOhm to vcmo, inputs +-0.1 V -> any off conduction shows as an offset
        r8dUDc("A_off" '(("vcm" 0.9) ("vdc" 0.2) ("pa" 0.0) ("pb" 0.0) ("rl" 1e12)))
        r->off_outp_minus_vcm = ldDc("outp") - 0.9 r->off_outn_minus_vcm = ldDc("outn") - 0.9
        r->Roff_lower_bound_P = if( abs(r->off_outp_minus_vcm) > 0.0 1e12 * 0.1 / abs(r->off_outp_minus_vcm) 1e30)
        r->i_vdd = ldIdc("/VDD/PLUS")
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    port = outfile(f "a")
    foreach(k cdr(r) when( symbolp(k) fprintf(port "%s,%s\n" k r8Num(get(r k)))))
    close(port)
    acSay("r8dA static: %s %s | Ron A %s B %s | vod(10 mV) A %s B %s | vod(0.1 mV) A %s B %s | off dV P %s N %s | I_VDD %s\n"
          r->status or(r->reason "") r8Num(r->ron_A) r8Num(r->ron_B) r8Num(r->vod_A) r8Num(r->vod_B) r8Num(r->vod_A_0p1mV) r8Num(r->vod_B_0p1mV)
          r8Num(r->off_outp_minus_vcm) r8Num(r->off_outn_minus_vcm) r8Num(r->i_vdd))
    ;; 2 kHz chopped smoke, 2 ms, vd 1 mV at 100 Hz on vcm 0.9 V, 50 ns maxstep (R6B unit setting)
    r = list(nil 'status "ok")
    ok = errset(
      progn(
        ece203Setup(r8dUtb "_r8d_A_tran")
        r6bOpt('(gmin "1e-18"))
        analysis('tran ?stop "2m" ?maxstep "50n")
        r6bSet(r6bUVars '(("vcm" 0.9) ("vd" 1e-3) ("chen" 1.0) ("tch" 500e-6)))
        run()
        ip = v("/inp" ?result "tran") in = v("/inn" ?result "tran") op = v("/outp" ?result "tran") on = v("/outn" ?result "tran")
        ca = v("/cka" ?result "tran") cb = v("/ckb" ?result "tran")
        when( r6bTend(ip) < 1.99e-3 error("tran stopped at %g s" r6bTend(ip)))
        r6bWrite(strcat(r8dDir "/A_unit_tran.csv") "t_s,inp_V,inn_V,outp_V,outn_V,cka_V,ckb_V" list(ip in op on ca cb))
        sh(sprintf(nil "cd %s && sha256sum A_unit_tran.csv > A_unit_tran.csv.sha256 && gzip -f A_unit_tran.csv" r8dDir))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "f=%s/simulation/%s/spectre/schematic_r8d_A_tran/psf; cp $f/spectre.out %s/A_unit_tran_spectre.out 2>/dev/null; gzip -f %s/A_unit_tran_spectre.out; rm -rf $f" getShellEnvVar("HOME") r8dUtb r8dDir r8dDir))
    acSay("r8dA tran: %s %s (per-phase analysis in r8d_unit_analysis.py)\n" r->status or(r->reason ""))
    t
  )
)

;; ---------- Stage B / C system cells ----------
procedure( r8dSpecs(key)
  let( (p names all n)
    p = r8dC(key)
    names = append(if( p->xci '("XCI") nil) if( p->xco '("XCO") nil))
    all = r8bSpecs()
    n = length(setof(e all and(member(caddr(e) names) cadr(e) == r6bCells->tg)))
    unless( n == length(names) error("expected %L with master %s, found %d" names r6bCells->tg n))
    r8dSwapMaster(all names r8dTg)
  )
)
procedure( r8dBuild()
  let( (key p)
    ece203LibInfo()
    key = r8dKey() p = r8dC(key)
    foreach(x list(r8bCell r8dTg r6bCells->tg "ece203_ss_pr_cell" r7aCmfbCell("a2") r6dCells->cd) unless( ddGetObj(ece203Lib x) error("missing %s" x)))
    when( ddGetObj(ece203Lib p->cell) error("%s already exists" p->cell))
    otaTb(p->cell r8dSpecs(key))
    acSay("r8d: built %s (XCI %s, XCO %s)\n" p->cell if( p->xci r8dTg r6bCells->tg) if( p->xco r8dTg r6bCells->tg))
    t
  )
)
;; run an R8C measurement with R8D output / tmp / watchdog; same save list in PSS and PAC runs (isPr t both)
procedure( r8dOn(fn @rest args)
  let( (od ot ow oe res)
    od = r8cDir ot = r8cTmp ow = r8cWd oe = r8cExtraOps
    r8cDir = r8dDir r8cTmp = r8dTmp r8cWd = "r8d_watchdog.sh" r8cExtraOps = r7aCmfbInsts
    res = errset(apply(fn args) t)
    r8cDir = od r8cTmp = ot r8cWd = ow r8cExtraOps = oe
    unless( res error("%L" errset.errset))
    t
  )
)
r8dPssCfg = list(nil
  'b1 list(nil 'tstab "5m" 'maxperiods "40" 'errpreset "moderate" 'cmin "1e-17" 'itres "1e-4")   ;; = R8B a1
  'b2 list(nil 'tstab "5m" 'maxperiods "60" 'errpreset "moderate" 'cmin "1e-17" 'itres "1e-7"))  ;; the registered retry (= R8 a2)
procedure( r8dStep() or(getShellEnvVar("AC_R8D_STEP") "b1") )
procedure( r8dCfg() let( (c) c = get(r8dPssCfg stringToSymbol(r8dStep())) unless( c error("PSS attempt %s not registered" r8dStep())) c ) )
;; AC_R8D_CASE=mm: the read-only R8B cell (MM reference with the same R8D op-info list, incl. CMFB devices)
procedure( r8dOff() let( (key) key = r8dKey() r8dOn('r8cOff if( key == "mm" r8bCell r8dC(key)->cell) sprintf(nil "B_off_%s" key) t) ) )
procedure( r8dPss()
  let( (key)
    key = r8dKey()
    r8dOn('r8cPeriodic r8dC(key)->cell sprintf(nil "B_pss_%s_%s" r8dStep() key) 'pss r8dCfg() sprintf(nil "%s/pss_%s.pss" r8dTmp key) "1" t)
  )
)
procedure( r8dPac()
  let( (key)
    key = r8dKey()
    r8dOn('r8cPeriodic r8dC(key)->cell sprintf(nil "B_pac_%s" key) 'pac r8dCfg() sprintf(nil "%s/pss_%s.pss" r8dTmp key) "1" t)
  )
)
