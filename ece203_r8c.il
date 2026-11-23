;; ECE203 R8C: root cause of the periodic (chopper ON) sideband-0 high-pass corner, fL ~0.34 Hz vs ~0.095 Hz static.
;; Task: docs/ECE203_round8c_periodic_highpass_rootcause_task.md; pre-registration docs/ece203_data/round8c/r8c_plan.md.
;; Stage A (no device change): the R8B cell Project/ece203_r8b_tb_noeoc_chp is used READ-ONLY (netlisted, never edited).
;;   A1 OFF  : chen 0, dc + ac 1 mHz-100 kHz with node transfers (outp-outn, bufp-bufn, fp-fn, p-n, ia-ibx, op-on)
;;   A1 PAC  : readpss of the archived converged R8B PSS (/tmp/lix015_r8b/pss_converged.pss, SHA-256 checked first),
;;             PAC 0.01-250 Hz at 40/dec, maxsideband AC_R8C_MSB = 1 | 3 (numerical consistency only)
;; Stage B (diagnostic only): new cell(s) = r8bSpecs() with XPRP / XPRN replaced by analogLib resistors RPRP (p fn) / RPRN (n fp).
;;   case l0 = 3.128 TOhm (pre-set); case l1 = the one allowed OFF-fL-scaled correction (value registered in r8c_plan.md first).
;;   B0 OFF dc + ac (same as A1 OFF); B1 PSS (AC_R8C_STEP = b1 | b2, writepss) then PAC (readpss, maxsideband 1).
;; Jobs: ece203_r8c_a1off, ece203_r8c_a1pac, ece203_r8c_build, ece203_r8c_b0, ece203_r8c_bpss, ece203_r8c_bpac
;;       (env AC_R8C_CASE = l0 | l1 for build / b0 / bpss / bpac; AC_R8C_MSB for a1pac; AC_R8C_STEP for bpss).
;; No ordinary noise, no PNoise, no long tran. Old cells read-only.

r8cDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r8c")
r8cTmp = "/tmp/lix015_r8c"
r8cExtraOps = nil           ;; extra op-info instances for r8cOff (R8D rebinds; default nil = R8C behaviour)
r8cWd = "r8c_watchdog.sh"     ;; watchdog script name (R8D rebinds r8cDir / r8cTmp / r8cWd; default unchanged)
r8cMosPss = "/tmp/lix015_r8b/pss_converged.pss"
r8cMosPssSha = "7d6ab501b25f818a508fd56c8b3678a1e37f99e4b56c589d9f423b98c131aad2"   ;; docs/ece203_data/round8b/raw/gateB/pss_converged.pss.sha256
;; linear surrogate cases. l1 is filled in ONLY after an r8c_plan.md update registers its value (B0 correction rule).
r8cCases = list(nil
  'l0 list(nil 'cell "ece203_r8c_tb_linear_pr" 'r "3.128T")
  'l1 list(nil 'cell "ece203_r8c_tb_linear_pr_b" 'r nil))
;; PSS attempts on the linear surrogate: b1 = R8 a1 settings (= R8B); b2 = the one numerical retry (R8 a2 settings), circuit unchanged
r8cPssCfg = list(nil
  'b1 list(nil 'tstab "5m" 'maxperiods "40" 'errpreset "moderate" 'cmin "1e-17" 'itres "1e-4")
  'b2 list(nil 'tstab "5m" 'maxperiods "60" 'errpreset "moderate" 'cmin "1e-17" 'itres "1e-7"))
r8cNodes = '("ep" "en" "ia" "ibx" "p" "n" "op" "on" "fp" "fn" "bufp" "bufn" "outp" "outn" "vg" "pref" "ib" "cka" "ckb" "ckab" "ckbb")
;; differential transfers (name plus minus)
r8cPairs = '(("out" "outp" "outn") ("buf" "bufp" "bufn") ("f" "fp" "fn") ("pn" "p" "n") ("in" "ia" "ibx") ("o" "op" "on"))

procedure( r8cCaseKey() or(getShellEnvVar("AC_R8C_CASE") "l0") )
procedure( r8cC(key) let( (p) p = get(r8cCases stringToSymbol(key)) unless( p error("unknown R8C case %s" key)) p ) )
procedure( r8cTag(base key) sprintf(nil "%s_%s" base key) )
procedure( r8cNum(x) r8Num(x) )
;; property-name form of a frequency: 0.1 -> "0p1"
procedure( r8cF(f) buildString(parseString(sprintf(nil "%g" float(f)) ".") "p") )
procedure( r8cWriteKv(file r)
  let( (port)
    port = outfile(file "w")
    fprintf(port "key,value\n")
    foreach(k cdr(r) when( symbolp(k) fprintf(port "%s,%s\n" k r8cNum(get(r k)))))
    close(port)
  )
)
;; curves with nil entries dropped
procedure( r8cCurves(file named)
  let( (ok)
    ok = setof(nw named cadr(nw))
    when( ok ldWriteCurves(file ok))
  )
)

;; ---------- Stage B cell: R8B spec list, XPRP / XPRN -> RPRP / RPRN ----------
procedure( r8cSpecs(rval)
  let( (all keep gone)
    all = r8bSpecs()
    keep = setof(e all !member(caddr(e) '("XPRP" "XPRN")))
    gone = setof(e all member(caddr(e) '("XPRP" "XPRN")))
    unless( length(gone) == 2 error("expected exactly XPRP and XPRN, found %L" mapcar('caddr gone)))
    append(keep list(otaR("RPRP" rval "p" "fn") otaR("RPRN" rval "n" "fp")))
  )
)
procedure( r8cBuild()
  let( (key p)
    ece203LibInfo()
    key = r8cCaseKey() p = r8cC(key)
    unless( p->r error("case %s has no registered resistance (register it in r8c_plan.md first)" key))
    foreach(x list(r8bCell "ece203_ss_pr_cell" r7aCmfbCell("a2") r6dCells->cd) unless( ddGetObj(ece203Lib x) error("missing %s" x)))
    when( ddGetObj(ece203Lib p->cell) error("%s already exists" p->cell))
    otaTb(p->cell r8cSpecs(p->r))
    acSay("r8c: built %s with RPRP/RPRN = %s\n" p->cell p->r)
    t
  )
)

;; ---------- OFF (chen 0) dc + ac with node transfers; used for A1 (MOS, R8B cell) and B0 (linear cells) ----------
procedure( r8cOff(cell tag isPr)
  let( (r ok vd port w named)
    ece203LibInfo() r8Mk(r8cDir)
    r = list(nil 'tag tag 'cell cell 'status "ok")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_r8c_" tag))
        r6bOpt(r8Opts)
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1m" ?stop "100k" ?dec "50")
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars r8Vars(0.0 '(("adm" 1.0) ("pacd" 0.0))))
        run()
        vd = ldAc("ep") - ldAc("en")
        foreach(pr r8cPairs
          w = ldDiv(ldAc(cadr(pr)) - ldAc(caddr(pr)) vd)
          named = append(named list(list(car(pr) w)))
          foreach(f '(0.1 1.0 10.0 100.0)
            putprop(r ldMag(w f) stringToSymbol(sprintf(nil "H_%s_%s" car(pr) r8cF(f))))))
        foreach(n r8cNodes putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDDD = ldIdc("/VDDD/PLUS")
        r8cCurves(sprintf(nil "%s/%s_ac.csv" r8cDir tag) named)
        ece203OpDump(sprintf(nil "%s/%s_dcop.csv" r8cDir tag)
                     append(append('("XA.M1" "XA.M2" "XA.M3" "XA.M4" "MP0" "MP1" "MP2") if( isPr '("XPRP.MP" "XPRN.MP") nil)) r8cExtraOps))
        sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs" getShellEnvVar("HOME") cell r8cDir tag))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "f=%s/simulation/%s/spectre/schematic_r8c_%s/psf; cp $f/spectre.out %s/%s_spectre.out 2>/dev/null; rm -rf $f" getShellEnvVar("HOME") cell tag r8cDir tag))
    r8cWriteKv(sprintf(nil "%s/%s.csv" r8cDir tag) r)
    acSay("r8c OFF %s (%s): %s %s | H_out 0.1/1/10/100 %s %s %s %s | DC p %s n %s fp %s fn %s op %s on %s outp %s outn %s | I %s %s\n"
          tag cell r->status or(r->reason "") r8cNum(r->H_out_0p1) r8cNum(r->H_out_1) r8cNum(r->H_out_10) r8cNum(r->H_out_100)
          r8cNum(r->dc_p) r8cNum(r->dc_n) r8cNum(r->dc_fp) r8cNum(r->dc_fn) r8cNum(r->dc_op) r8cNum(r->dc_on) r8cNum(r->dc_outp) r8cNum(r->dc_outn)
          r8cNum(r->I_VDD) r8cNum(r->I_VDDD))
    t
  )
)

;; ---------- periodic run: kind 'pss (writepss) or 'pac (readpss + PAC 0.01-250 Hz 40/dec, maxsideband msb) ----------
procedure( r8cPeriodic(cell tag kind cfg pssfile msb isPr)
  let( (sim psf out wlog ok r w vd h hp hm named pairs names)
    ece203LibInfo() r8Mk(r8cDir) r8Mk(r8cTmp) out = strcat(r8cTmp "/out") r8Mk(out)
    sim = sprintf(nil "%s/sim_%s" r8cTmp tag) psf = strcat(sim "/psf") wlog = strcat(out "/watchdog.log")
    sh(sprintf(nil "rm -rf %s" sim))
    when( kind == 'pss sh(sprintf(nil "rm -f %s" pssfile)))
    r = list(nil 'tag tag 'cell cell 'kind kind 'status "ok" 'pssfile pssfile 'msb msb)
    ok = errset(
      progn(
        when( and(kind == 'pac !isFile(pssfile)) error("no converged PSS file %s" pssfile))
        ece203Setup(cell strcat("_r8c_" tag))
        resultsDir(sim)
        r6bOpt(r8Opts)
        car(errset(saveOption('save "selected") nil))
        car(errset(apply('save cons('v mapcar(lambda((n) strcat("/" n)) r8cNodes))) nil))
        car(errset(if( isPr save('i "/XPRP/A" "/XPRN/A") save('i "/RPRP/PLUS" "/RPRN/PLUS")) nil))
        if( kind == 'pss
          then analysis('pss ?fund "2k" ?harms "40" ?maxacfreq "200k" ?errpreset cfg->errpreset ?tstab cfg->tstab
                        ?maxperiods cfg->maxperiods ?cmin cfg->cmin ?itres cfg->itres ?writepss pssfile)
          else analysis('pss ?fund "2k" ?harms "40" ?maxacfreq "200k" ?errpreset cfg->errpreset ?tstab cfg->tstab
                        ?maxperiods cfg->maxperiods ?cmin cfg->cmin ?itres cfg->itres ?readpss pssfile)
               analysis('pac ?sweeptype "relative" ?relharmnum "0" ?start "0.01" ?stop "250" ?dec "40" ?maxsideband msb))
        r6bSet(r6Vars r8Vars(1.0 if( kind == 'pss '(("adm" 0.0) ("pacd" 0.0)) '(("adm" 0.0) ("pacd" 1.0)))))
        sh(sprintf(nil "nohup bash %s/tools/%s %s %s 900 5400 %s > /dev/null 2>&1 &" acRoot r8cWd tag psf wlog))
        run()
        sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs" getShellEnvVar("HOME") cell r8cDir tag))
        sh(sprintf(nil "grep -n -i 'converge\\|steady\\|conv norm\\|did not\\|error\\|warning\\|maxacfreq\\|time step\\|pss:\\|period\\|Total time' %s/spectre.out | head -400 > %s/%s_convergence_lines.txt" psf r8cDir tag))
        when( isFile(strcat(sim "/WATCHDOG_STALL")) error("stopped by the watchdog"))
        when( sh(sprintf(nil "grep -q -i 'did not converge\\|no convergence' %s/spectre.out" psf)) error("Spectre reports PSS non-convergence (see spectre.out)"))
        unless( sh(sprintf(nil "grep -q 'steady-state solution was achieved' %s/spectre.out" psf)) error("no explicit PSS convergence message"))
        r->pss_converged = "yes"
        openResults(psf) selectResult('pss_td)
        names = "t_s" w = nil
        foreach(n r8cNodes when( setq(h car(errset(v(strcat("/" n)) nil))) w = append(w list(h)) names = strcat(names "," n "_V")))
        foreach(t2 if( isPr '("/XPRP/A" "/XPRN/A") '("/RPRP/PLUS" "/RPRN/PLUS"))
          when( setq(h car(errset(i(t2) nil))) w = append(w list(h)) names = strcat(names "," "I" t2 "_A")))
        when( w spsWriteWaves(sprintf(nil "%s/%s_pss_td.csv" r8cDir tag) names w))
        when( kind == 'pac
          vd = car(errset(harmonic(v("/ep" ?result "pac") - v("/en" ?result "pac") 0) nil))
          unless( vd error("no PAC input"))
          named = list(list("vd_pac" vd))
          foreach(pr r8cPairs
            h = car(errset(harmonic(v(strcat("/" cadr(pr)) ?result "pac") - v(strcat("/" caddr(pr)) ?result "pac") 0) / vd nil))
            named = append(named list(list(strcat("H0_" car(pr)) h)))
            foreach(f '(0.1 0.3 1.0 10.0 100.0) putprop(r ldMag(h f) stringToSymbol(sprintf(nil "H0_%s_%s" car(pr) r8cF(f))))))
          ;; carrier-band (sideband +-1) content of the modulated nodes, normalised by the sideband-0 input
          foreach(pr '(("in" "ia" "ibx") ("o" "op" "on") ("pn" "p" "n"))
            hp = car(errset(harmonic(v(strcat("/" cadr(pr)) ?result "pac") - v(strcat("/" caddr(pr)) ?result "pac") 1) / vd nil))
            hm = car(errset(harmonic(v(strcat("/" cadr(pr)) ?result "pac") - v(strcat("/" caddr(pr)) ?result "pac") -1) / vd nil))
            named = append(named list(list(strcat("Hp1_" car(pr)) hp) list(strcat("Hm1_" car(pr)) hm)))
            putprop(r ldMag(hp 1.0) stringToSymbol(sprintf(nil "Hp1_%s_1" car(pr))))
            putprop(r ldMag(hm 1.0) stringToSymbol(sprintf(nil "Hm1_%s_1" car(pr)))))
          r->vd_pac_100 = ldMag(vd 100.0)
          r->H0_out_100_ph = ldPh(cadr(assoc("H0_out" named)) 100.0)
          r8cCurves(sprintf(nil "%s/%s_pac.csv" r8cDir tag) named))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "cp %s/spectre.out %s/%s_spectre.out 2>/dev/null; gzip -f %s/%s_spectre.out" psf r8cDir tag r8cDir tag))
    when( and(ok kind == 'pss) sh(sprintf(nil "sha256sum %s > %s/%s_pss.sha256" pssfile r8cDir tag)))
    sh(sprintf(nil "du -sh %s > %s/%s_psf_size.txt 2>/dev/null; rm -rf %s" psf r8cDir tag psf))
    r8cWriteKv(sprintf(nil "%s/%s.csv" r8cDir tag) r)
    acSay("r8c P %s (%s): %s %s | vd %s | H0 out 0.1/0.3/1/10/100 %s %s %s %s %s ph100 %s | pn %s %s %s | f %s %s %s\n"
          tag cell r->status or(r->reason "") r8cNum(r->vd_pac_100)
          r8cNum(r->H0_out_0p1) r8cNum(r->H0_out_0p3) r8cNum(r->H0_out_1) r8cNum(r->H0_out_10) r8cNum(r->H0_out_100) r8cNum(r->H0_out_100_ph)
          r8cNum(r->H0_pn_0p1) r8cNum(r->H0_pn_1) r8cNum(r->H0_pn_10) r8cNum(r->H0_f_0p1) r8cNum(r->H0_f_1) r8cNum(r->H0_f_10))
    t
  )
)

;; ---------- jobs ----------
procedure( r8cA1off() r8cOff(r8bCell "A1_off_mos" t) )
procedure( r8cA1pac()
  let( (msb tag)
    msb = or(getShellEnvVar("AC_R8C_MSB") "1")
    unless( member(msb '("1" "3")) error("AC_R8C_MSB must be 1 or 3"))
    tag = sprintf(nil "A1_pac_mos_m%s" msb)
    ;; the archived R8B PSS is reused only if its SHA-256 is unchanged
    unless( sh(sprintf(nil "echo '%s  %s' | sha256sum -c --status" r8cMosPssSha r8cMosPss))
      error("archived R8B PSS %s missing or changed: rebuild it (one allowed) with the a1 settings first" r8cMosPss))
    r8cPeriodic(r8bCell tag 'pac get(r8cPssCfg 'b1) r8cMosPss msb t)
  )
)
procedure( r8cB0() let( (key) key = r8cCaseKey() r8cOff(r8cC(key)->cell r8cTag("B0_off" key) nil) ) )
procedure( r8cBpss()
  let( (key step cfg)
    key = r8cCaseKey() step = or(getShellEnvVar("AC_R8C_STEP") "b1")
    cfg = get(r8cPssCfg stringToSymbol(step))
    unless( cfg error("PSS attempt %s is not registered" step))
    r8cPeriodic(r8cC(key)->cell r8cTag(strcat("B1_pss_" step) key) 'pss cfg sprintf(nil "%s/pss_%s.pss" r8cTmp key) "1" nil)
  )
)
procedure( r8cBpac()
  let( (key step)
    key = r8cCaseKey() step = or(getShellEnvVar("AC_R8C_STEP") "b1")
    r8cPeriodic(r8cC(key)->cell r8cTag("B1_pac" key) 'pac get(r8cPssCfg stringToSymbol(step)) sprintf(nil "%s/pss_%s.pss" r8cTmp key) "1" nil)
  )
)
