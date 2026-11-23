;; ECE203 R8: real-MOS chopper noise of the frozen R7F candidate Project/ece203_r7f_tb_gain_g0_load10p (read-only, no rebuild).
;; Same hardware, one operational variable: chen = 0 (TG static phase A) vs chen = 1 (2 kHz TG). Task:
;; docs/ECE203_round8_real_mos_chopper_noise_task.md; pre-registration docs/ece203_data/round8/r8_plan.md.
;; Jobs (env AC_R8_STEP selects attempt / sideband where relevant):
;;   ece203_r8_a     Stage A: chen 0, dc + ac (1 mHz-100 kHz) + ordinary noise 0.1-250 Hz on (outp, outn) + noiseSummary
;;   ece203_r8_t0    Stage B pre-check: 20 ms zero-input chopper-ON tran (R7F setting C)
;;   ece203_r8_pss   Stage B: PSS only (AC_R8_STEP = a1 | a2), writepss on success
;;   ece203_r8_pac   Stage B: readpss + zero-sideband PAC 0.1-250 Hz
;;   ece203_r8_pn    Stage C: readpss + PAC + PNoise (AC_R8_STEP = sideband count: 10 | 30 | 60 | 90)
;; Output to ~/AutoCircuit_results/ece203_r8 (small files); PSF of the periodic runs in /tmp/lix015_r8 with tools/r8_watchdog.sh.

r8Dir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r8")
r8Tmp = "/tmp/lix015_r8"
r8Cell = "ece203_r7f_tb_gain_g0_load10p"
r8Opts = '(gmin "1e-18" iabstol "1e-17" reltol "1e-5")          ;; R7F system options (setting C)
r8Bands = '(0.1 1.0 10.0 100.0 250.0)
;; PSS attempts: a1 = pre-registered; a2 = the one numerically motivated retry, registered in r8_plan.md before it runs
r8PssCfg = list(nil
  'a1 list(nil 'tstab "5m" 'maxperiods "40" 'errpreset "moderate" 'method nil 'cmin "1e-17" 'itres "1e-4")
  ;; a2 = the one retry after the a1 failure (r8_plan.md update 1): shooting linear-solver residual itres 1e-4 -> 1e-7, maxperiods 60
  'a2 list(nil 'tstab "5m" 'maxperiods "60" 'errpreset "moderate" 'method nil 'cmin "1e-17" 'itres "1e-7"))
;; the PSS settings of the converged attempt (env AC_R8_PSS, default a1) are reused, with readpss, by the PAC / PNoise jobs
procedure( r8PssUsedCfg() get(r8PssCfg stringToSymbol(or(getShellEnvVar("AC_R8_PSS") "a1"))) )
procedure( r8Step(def) or(getShellEnvVar("AC_R8_STEP") def) )
procedure( r8Mk(d) unless( isDir(d) sh(sprintf(nil "mkdir -p %s" d))) )
procedure( r8Num(x) cond( (stringp(x) x) (numberp(x) sprintf(nil "%.7g" float(x))) (t "n/a")) )
;; R7F G0 loaded variables (R7D/R7E set + cc 60p) with the noise-run overrides: no 100 Hz stimulus, no Cc mismatch
procedure( r8Vars(chen over) append(append(r7eVars() '(("cc" 60e-12))) append(list(list("chen" chen) list("tch" 500e-6) list("vd" 0.0) list("dcc" 0.0) list("vcmin" 0.0)) over)) )
procedure( r8Say(file fmt @rest args) let( (p) p = outfile(file "a") apply('fprintf cons(p cons(fmt args))) close(p) ) )
procedure( r8KeepNetlist(tag) sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs" getShellEnvVar("HOME") r8Cell r8Dir tag)) )
;; one noiseSummary dump (raw text, parsed/grouped later by r8_noise_groups.py)
procedure( r8NoiseSummary(file res type a b)
  let( (port ok)
    port = outfile(file "w")
    ok = if( type == 'spot
           then errset(noiseSummary('spot ?result res ?frequency a ?output port) t)
           else errset(noiseSummary('integrated ?result res ?from a ?to b ?output port) t))
    close(port)
    unless( ok acSay("r8: noiseSummary %L %L %g-%g failed: %L\n" res type float(a) float(b) errset.errset))
    and(ok t)
  )
)
procedure( r8Summaries(tag res)
  let( (ok)
    ok = r8NoiseSummary(sprintf(nil "%s/%s_ns_int_0p1_250.txt" r8Dir tag) res 'integrated 0.1 250.0)
    for(j 0 length(r8Bands) - 2
      r8NoiseSummary(sprintf(nil "%s/%s_ns_int_b%d.txt" r8Dir tag j) res 'integrated nth(j r8Bands) nth(j + 1 r8Bands)))
    foreach(f '(0.1 1.0 10.0 100.0 250.0)
      r8NoiseSummary(sprintf(nil "%s/%s_ns_spot_%gHz.txt" r8Dir tag f) res 'spot f nil))
    ok
  )
)

;; ---------- Stage A: chen 0 (static phase A), ordinary dc / ac / noise ----------
procedure( r8StageA()
  let( (tag r ok vd h nout nin port)
    ece203LibInfo() r8Mk(r8Dir)
    tag = "A_off"
    r = list(nil 'tag tag 'status "ok")
    ok = errset(
      progn(
        ece203Setup(r8Cell strcat("_r8_" tag))
        r6bOpt(r8Opts)
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1m" ?stop "100k" ?dec "50")
        analysis('noise ?start "0.1" ?stop "250" ?dec "20" ?p "/outp" ?n "/outn")
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars r8Vars(0.0 '(("adm" 1.0) ("pacd" 0.0))))
        run()
        vd = ldAc("ep") - ldAc("en")
        h = ldDiv(ldAc("outp") - ldAc("outn") vd)
        r->Hoff1 = ldMag(h 1.0) r->Hoff10 = ldMag(h 10.0) r->Hoff100 = ldMag(h 100.0) r->Hoff100_ph = ldPh(h 100.0) r->Hoff250 = ldMag(h 250.0)
        r->Hoff0p1 = ldMag(h 0.1) r->Hoff60 = ldMag(h 60.0)
        nout = car(errset(getData("out" ?result "noise") nil))
        unless( nout error("no noise output"))
        nin = car(errset(nout / mag(h) nil))
        r->out_rms = nsRms(nout 0.1 250.0)
        r->app_in = and(r->out_rms r->Hoff100 r->out_rms / r->Hoff100)
        r->deemb_in = nsRms(nin 0.1 250.0)
        foreach(q '((0.1 out_0p1 in_0p1) (1.0 out_1 in_1) (10.0 out_10 in_10) (100.0 out_100 in_100) (250.0 out_250 in_250))
          putprop(r ece203V(nout car(q)) cadr(q)) putprop(r and(nin ece203V(nin car(q))) caddr(q)))
        foreach(n '("op" "on" "fp" "fn" "p" "n" "bufp" "bufn" "outp" "outn" "vg" "ib" "pref") putprop(r ldDc(n) stringToSymbol(strcat("dc_" n))))
        r->I_VDD = ldIdc("/VDD/PLUS") r->I_VDDD = ldIdc("/VDDD/PLUS")
        ldWriteCurves(strcat(r8Dir "/A_off_ac.csv") list(list("Hoff" h)))
        spsWriteWaves(strcat(r8Dir "/A_off_noise.csv") "f_Hz,Sout_V_rtHz,deemb_in_V_rtHz" list(nout nin))
        r->summary = if( r8Summaries(tag 'noise) "ok" "noiseSummary failed")
        ece203OpDump(strcat(r8Dir "/A_off_dcop.csv") append('("XA.M1" "XA.M2" "XA.M3" "XA.M4" "XA.MC1" "XA.MC2" "XA.MT" "XCD.MSP" "XCD.MKP" "MP0" "MP1" "MP2") r7aCmfbInsts))
        r8KeepNetlist(tag)
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "f=%s/simulation/%s/spectre/schematic_r8_%s/psf; cp $f/spectre.out %s/%s_spectre.out 2>/dev/null; rm -rf $f" getShellEnvVar("HOME") r8Cell tag r8Dir tag))
    acSay("r8A %s: %s %s | Hoff 0.1/1/10/60/100/250 %s %s %s %s %s %s ph100 %s | out rms %s V | app %s deemb %s V | in 0.1/1/10/100/250 %s %s %s %s %s | DC out %s %s op %s %s p %s n %s | I %s %s | summary %s\n"
          tag r->status or(r->reason "") r8Num(r->Hoff0p1) r8Num(r->Hoff1) r8Num(r->Hoff10) r8Num(r->Hoff60) r8Num(r->Hoff100) r8Num(r->Hoff250) r8Num(r->Hoff100_ph)
          r8Num(r->out_rms) r8Num(r->app_in) r8Num(r->deemb_in) r8Num(r->in_0p1) r8Num(r->in_1) r8Num(r->in_10) r8Num(r->in_100) r8Num(r->in_250)
          r8Num(r->dc_outp) r8Num(r->dc_outn) r8Num(r->dc_op) r8Num(r->dc_on) r8Num(r->dc_p) r8Num(r->dc_n) r8Num(r->I_VDD) r8Num(r->I_VDDD) or(r->summary ""))
    port = outfile(strcat(r8Dir "/A_off.csv") "w")
    fprintf(port "key,value\n")
    foreach(k cdr(r) when( symbolp(k) fprintf(port "%s,%s\n" k r8Num(get(r k)))))
    close(port)
    t
  )
)

;; ---------- Stage B pre-check: zero-input chopper-ON tran, 20 ms ----------
procedure( r8Tran0()
  let( (tag sim psf out wlog vid ws names file ok)
    ece203LibInfo() r8Mk(r8Dir) out = strcat(r8Tmp "/out") r8Mk(out)
    tag = "T0_on_zero" sim = sprintf(nil "%s/sim_%s" r8Tmp tag) psf = strcat(sim "/psf") wlog = strcat(out "/watchdog.log")
    sh(sprintf(nil "rm -rf %s" sim))
    ok = errset(
      progn(
        ece203Setup(r8Cell strcat("_r8_" tag))
        resultsDir(sim)
        r6bOpt(r8Opts)
        analysis('tran ?stop "20m" ?maxstep "0.5u" ?cmin "1e-17")
        car(errset(saveOption('save "selected") nil))
        car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/bufp" "/bufn" "/outp" "/outn" "/p" "/n" "/pref" "/ib" "/cka" "/ckb") nil))
        r6bSet(r6Vars r8Vars(1.0 '(("adm" 0.0) ("pacd" 0.0))))
        sh(sprintf(nil "nohup bash %s/tools/r8_watchdog.sh %s %s 240 3600 %s > /dev/null 2>&1 &" acRoot tag psf wlog))
        run()
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        ws = list(vid) names = "t_s,vid_V"
        foreach(n '("fp" "fn" "op" "on" "vg" "bufp" "bufn" "outp" "outn" "p" "n" "pref" "ib" "cka" "ckb")
          ws = append(ws list(v(strcat("/" n) ?result "tran"))) names = strcat(names "," n "_V"))
        file = sprintf(nil "%s/%s_tran.csv" out tag)
        r6bWrite(file names ws)
        sh(sprintf(nil "cd %s && sha256sum %s_tran.csv > %s_tran.csv.sha256 && gzip -f %s_tran.csv" out tag tag tag))
        t)
      t)
    sh(sprintf(nil "gzip -c %s/spectre.out > %s/%s_spectre.out.gz 2>/dev/null; cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs; rm -rf %s"
               psf out tag getShellEnvVar("HOME") r8Cell out tag psf))
    acSay("r8T0: %s\n" if( ok "ok" sprintf(nil "failed %L" errset.errset)))
    t
  )
)

;; ---------- periodic analyses: one Spectre run per job in /tmp, watchdog, logs kept ----------
;; kind: 'pss (attempt a1/a2, writepss) | 'pac (readpss) | 'pn (readpss + pac + pnoise maxsideband msb)
procedure( r8Periodic(kind step)
  let( (cfg tag sim psf out wlog pssfile ok r w vd h nout nin port stall hard r8PssUsed)
    ece203LibInfo() r8Mk(r8Dir) out = strcat(r8Tmp "/out") r8Mk(out)
    r8PssUsed = r8PssUsedCfg()
    tag = case( kind (pss sprintf(nil "B_pss_%s" step)) (pac "B_pac") (pn sprintf(nil "C_pnoise_s%s" step)))
    pssfile = strcat(r8Tmp "/pss_converged.pss")
    sim = sprintf(nil "%s/sim_%s" r8Tmp tag) psf = strcat(sim "/psf") wlog = strcat(out "/watchdog.log")
    sh(sprintf(nil "rm -rf %s" sim))
    r = list(nil 'tag tag 'status "ok")
    when( kind == 'pss
      cfg = get(r8PssCfg stringToSymbol(step))
      unless( cfg error("PSS attempt %s is not registered in r8PssCfg" step))
      sh(sprintf(nil "rm -f %s" pssfile)))
    stall = if( kind == 'pn 1800 900) hard = if( kind == 'pn 21600 5400)
    ok = errset(
      progn(
        when( and(kind != 'pss !isFile(pssfile)) error("no converged PSS file %s" pssfile))
        ece203Setup(r8Cell strcat("_r8_" tag))
        resultsDir(sim)
        r6bOpt(r8Opts)
        car(errset(saveOption('save "selected") nil))
        car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/bufp" "/bufn" "/outp" "/outn" "/p" "/n" "/pref" "/ib" "/cka" "/ckb" "/ckab" "/ckbb") nil))
        if( kind == 'pss
          then analysis('pss ?fund "2k" ?harms "40" ?maxacfreq "200k" ?errpreset cfg->errpreset ?tstab cfg->tstab
                        ?maxperiods cfg->maxperiods ?cmin cfg->cmin ?itres cfg->itres ?writepss pssfile)
          else analysis('pss ?fund "2k" ?harms "40" ?maxacfreq "200k" ?errpreset r8PssUsed->errpreset ?tstab r8PssUsed->tstab
                        ?maxperiods r8PssUsed->maxperiods ?cmin r8PssUsed->cmin ?itres r8PssUsed->itres ?readpss pssfile))
        when( member(kind '(pac pn))
          analysis('pac ?sweeptype "relative" ?relharmnum "0" ?start "0.1" ?stop "250" ?dec "20" ?maxsideband "1"))
        when( kind == 'pn
          analysis('pnoise ?sweeptype "relative" ?relharmnum "0" ?start "0.1" ?stop "250" ?dec "20"
                   ?maxsideband step ?p "/outp" ?n "/outn" ?noisetype "timeaverage"))
        r6bSet(r6Vars r8Vars(1.0 if( kind == 'pss '(("adm" 0.0) ("pacd" 0.0)) '(("adm" 0.0) ("pacd" 1.0)))))
        sh(sprintf(nil "nohup bash %s/tools/r8_watchdog.sh %s %s %d %d %s > /dev/null 2>&1 &" acRoot tag psf stall hard wlog))
        run()
        sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs" getShellEnvVar("HOME") r8Cell r8Dir tag))
        sh(sprintf(nil "grep -n -i 'converge\\|steady\\|conv norm\\|did not\\|error\\|warning\\|maxacfreq\\|time step\\|pss:\\|period' %s/spectre.out | head -400 > %s/%s_convergence_lines.txt" psf r8Dir tag))
        when( isFile(strcat(sim "/WATCHDOG_STALL")) error("stopped by the watchdog"))
        when( sh(sprintf(nil "grep -q -i 'did not converge\\|no convergence' %s/spectre.out" psf)) error("Spectre reports PSS non-convergence (see spectre.out)"))
        ;; periodic steady state waveforms of one period
        openResults(psf) selectResult('pss_td)
        w = mapcar(lambda((n) car(errset(v(strcat("/" n)) nil))) '("op" "on" "fp" "fn" "bufp" "bufn" "outp" "outn" "p" "n" "vg" "pref" "ib" "cka" "ckb"))
        when( car(w)
          spsWriteWaves(sprintf(nil "%s/%s_pss_td.csv" r8Dir tag) "t_s,op_V,on_V,fp_V,fn_V,bufp_V,bufn_V,outp_V,outn_V,p_V,n_V,vg_V,pref_V,ib_V,cka_V,ckb_V" w))
        when( member(kind '(pac pn))
          vd = car(errset(harmonic(v("/ep" ?result "pac") - v("/en" ?result "pac") 0) nil))
          h = car(errset(harmonic(v("/outp" ?result "pac") - v("/outn" ?result "pac") 0) / vd nil))
          unless( h error("no PAC sideband-0 transfer"))
          r->vd_pac_100 = ldMag(vd 100.0)
          r->Hon0p1 = ldMag(h 0.1) r->Hon1 = ldMag(h 1.0) r->Hon10 = ldMag(h 10.0) r->Hon100 = ldMag(h 100.0) r->Hon100_ph = ldPh(h 100.0) r->Hon250 = ldMag(h 250.0)
          ldWriteCurves(sprintf(nil "%s/%s_pac.csv" r8Dir tag) list(list("Hon" h) list("vd_pac" vd))))
        when( kind == 'pn
          nout = or(car(errset(getData("out" ?result "pnoise") nil)) car(errset(getData("out" ?result "pnoise_pnoise") nil)))
          unless( nout error("no pnoise output"))
          nin = car(errset(nout / mag(h) nil))
          r->out_rms = nsRms(nout 0.1 250.0)
          r->app_in = and(r->out_rms r->Hon100 r->out_rms / r->Hon100)
          r->deemb_in = nsRms(nin 0.1 250.0)
          foreach(q '((0.1 out_0p1 in_0p1) (1.0 out_1 in_1) (10.0 out_10 in_10) (100.0 out_100 in_100) (250.0 out_250 in_250))
            putprop(r ece203V(nout car(q)) cadr(q)) putprop(r and(nin ece203V(nin car(q))) caddr(q)))
          spsWriteWaves(sprintf(nil "%s/%s_pnoise.csv" r8Dir tag) "f_Hz,Sout_V_rtHz,deemb_in_V_rtHz" list(nout nin))
          r->summary = if( r8Summaries(tag 'pnoise) "ok" "noiseSummary for pnoise not available"))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    sh(sprintf(nil "cp %s/spectre.out %s/%s_spectre.out 2>/dev/null; gzip -f %s/%s_spectre.out" psf r8Dir tag r8Dir tag))
    sh(sprintf(nil "du -sh %s > %s/%s_psf_size.txt 2>/dev/null; rm -rf %s" psf r8Dir tag psf))
    acSay("r8P %s: %s %s | PAC vd %s Hon 0.1/1/10/100/250 %s %s %s %s %s ph100 %s | out rms %s app %s deemb %s | in 0.1/1/10/100/250 %s %s %s %s %s | %s\n"
          tag r->status or(r->reason "") r8Num(r->vd_pac_100) r8Num(r->Hon0p1) r8Num(r->Hon1) r8Num(r->Hon10) r8Num(r->Hon100) r8Num(r->Hon250) r8Num(r->Hon100_ph)
          r8Num(r->out_rms) r8Num(r->app_in) r8Num(r->deemb_in) r8Num(r->in_0p1) r8Num(r->in_1) r8Num(r->in_10) r8Num(r->in_100) r8Num(r->in_250) or(r->summary ""))
    port = outfile(sprintf(nil "%s/%s.csv" r8Dir tag) "w")
    fprintf(port "key,value\n")
    foreach(k cdr(r) when( symbolp(k) fprintf(port "%s,%s\n" k r8Num(get(r k)))))
    close(port)
    t
  )
)
procedure( r8Pss() r8Periodic('pss r8Step("a1")) )
procedure( r8Pac() r8Periodic('pac nil) )
procedure( r8Pn() r8Periodic('pn r8Step("10")) )
