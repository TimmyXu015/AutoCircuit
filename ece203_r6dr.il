;; ECE203 R6D-R: bounded Spectre convergence recovery for the R6D Stage B 2 kHz TG-chopper transient (Stage B only).
;; Task: docs/ECE203_round6d_chopper_tran_recovery_task.md. Reuses the R6D cells unchanged (Project/ece203_r6d_tb_ref,
;; _direct, _buf, ece203_r6d_cd); no circuit, size, bias, load, CMFB, clock or input change. Only ONE numerical setting
;; differs from the R6D Stage B baseline per variant:
;;   A : R6D baseline - default integration (trapezoidal), gmin 1e-18, iabstol 1e-17, reltol 1e-5, cmin 0
;;   B : as A but iabstol 1e-15 (simulator option; also applies to the tran's initial DC point)
;;   C : as A but tran cmin 1e-17 F (only if B fails)
;; All psf / CSV go to /tmp/lix015_r6dr (not the home quota). A watchdog (tools/r6dr_watchdog.sh) kills only this run's
;; Spectre when the reported tran time stops advancing for r6drStall seconds.
;; Jobs: ece203_r6dr_probe (BUF 1 pF, 1 ms: A, B, then C if B fails), ece203_r6dr_short (REF/DIRECT 1p/BUF 1p, 1 ms,
;;       setting from env AC_R6DR_SETTING), ece203_r6dr_full (the 5 R6D Stage B cases, 60 ms, same setting).

r6drTmp = "/tmp/lix015_r6dr"
r6drOut = strcat(r6drTmp "/out")
r6drStall = 180
r6drSettings = list(nil
  'A list(nil 'opts '(gmin "1e-18" iabstol "1e-17" reltol "1e-5") 'cmin nil 'label "A: R6D baseline (default trap, iabstol 1e-17, cmin 0)")
  'B list(nil 'opts '(gmin "1e-18" iabstol "1e-15" reltol "1e-5") 'cmin nil 'label "B: iabstol 1e-15 only")
  'C list(nil 'opts '(gmin "1e-18" iabstol "1e-17" reltol "1e-5") 'cmin "1e-17" 'label "C: tran cmin 1e-17 F only"))
procedure( r6drSetting() or(getShellEnvVar("AC_R6DR_SETTING") "B") )
procedure( r6drMkdir(d) unless( isDir(d) sh(sprintf(nil "mkdir -p %s" d))) )
r6drCols = '(tag setting bench cl stop status reason t_end stalled_at fp_cm_avg buf_cm_avg vg_min vg_max I_VDD I_VDDD rows csv)
procedure( r6drOpen(name)
  let( (port)
    r6drMkdir(r6drOut)
    port = outfile(strcat(r6drOut "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString r6drCols) ","))
    port
  )
)
;; one transient run
procedure( r6drTran(port tag skey bench cell cl stop)
  let( (st r ok sim psf vid fp fn op on vg dr bp bn iv id names waves file wlog stall isbuf t1 t0)
    st = get(r6drSettings skey) isbuf = (cell == r6dCells->buf)
    r = list(nil 'tag tag 'setting st->label 'bench bench 'cl cl 'stop stop 'status "ok")
    sim = sprintf(nil "%s/sim_%s" r6drTmp tag) psf = strcat(sim "/psf")
    sh(sprintf(nil "rm -rf %s" sim)) r6drMkdir(r6drOut)
    wlog = strcat(r6drOut "/watchdog.log")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        resultsDir(sim)
        r6bOpt(st->opts)
        if( st->cmin
          analysis('tran ?stop sprintf(nil "%g" stop) ?maxstep "0.5u" ?cmin st->cmin)
          analysis('tran ?stop sprintf(nil "%g" stop) ?maxstep "0.5u"))
        car(errset(saveOption('save "selected") nil))
        if( isbuf
          car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr" "/bufp" "/bufn") nil))
          car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/vg" "/drlr") nil)))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars append(r6dBase list(list("cld" cl) list("clb" cl) list("chen" 1.0) list("tch" 500e-6) list("vd" 1e-3))))
        ;; watchdog for THIS run only (background), then the blocking run
        sh(sprintf(nil "nohup bash %s/tools/r6dr_watchdog.sh %s %s %d %s > /dev/null 2>&1 &" acRoot tag psf r6drStall wlog))
        run()
        stall = isFile(strcat(sim "/WATCHDOG_STALL"))
        when( stall
          r->stalled_at = car(errset(let( (p l) p = infile(strcat(sim "/WATCHDOG_STALL")) gets(l p) close(p) car(parseString(l "\n"))) nil))
          error("stalled (watchdog)"))
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        r->t_end = r6bTend(vid)
        when( r->t_end < 0.99 * stop error("tran stopped at %g s" r->t_end))
        fp = v("/fp" ?result "tran") fn = v("/fn" ?result "tran") op = v("/op" ?result "tran") on = v("/on" ?result "tran")
        vg = v("/vg" ?result "tran") dr = v("/drlr" ?result "tran")
        bp = and(isbuf v("/bufp" ?result "tran")) bn = and(isbuf v("/bufn" ?result "tran"))
        iv = car(errset(i("/VDD/PLUS" ?result "tran") nil)) id = car(errset(i("/VDDD/PLUS" ?result "tran") nil))
        t1 = r->t_end t0 = if( t1 > 0.03 0.04 0.5 * t1)
        r->fp_cm_avg = chAvg((fp + fn) / 2.0 t0 t1)
        r->vg_min = ymin(vg) r->vg_max = ymax(vg)
        when( and(bp bn) r->buf_cm_avg = chAvg((bp + bn) / 2.0 t0 t1))
        r->I_VDD = and(iv chAvg(iv t0 t1)) r->I_VDDD = and(id chAvg(id t0 t1))
        file = sprintf(nil "%s/%s_tran.csv" r6drOut tag)
        names = "t_s,vid_V,fp_V,fn_V,op_V,on_V,vg_V,drlr_V" waves = list(vid fp fn op on vg dr)
        when( and(bp bn) names = strcat(names ",bufp_V,bufn_V") waves = append(waves list(bp bn)))
        when( and(iv id) names = strcat(names ",i_vdd_A,i_vddd_A") waves = append(waves list(iv id)))
        r->rows = r6bWrite(file names waves)
        sh(sprintf(nil "cd %s && sha256sum %s_tran.csv > %s_tran.csv.sha256 && gzip -f %s_tran.csv" r6drOut tag tag tag))
        r->csv = strcat(file ".gz")
        t)
      t)
    unless( ok r->status = if( isFile(strcat(sim "/WATCHDOG_STALL")) "stalled" "failed") r->reason = sprintf(nil "%L" errset.errset))
    ;; keep the full spectre.out (gzip) + the netlist of this run; drop the rebuildable psf data
    sh(sprintf(nil "gzip -c %s/spectre.out > %s/%s_spectre.out.gz 2>/dev/null; cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s/%s_netlist.scs 2>/dev/null; rm -rf %s"
               psf r6drOut tag getShellEnvVar("HOME") cell r6drOut tag psf))
    acSay("r6dr %s [%s | %s cl %g stop %g]: %s %s | t_end %s stalled %s | fp/fn cm %s buf cm %s | vg %s..%s | I %s %s | rows %s\n"
          tag st->label bench cl stop r->status or(r->reason "") r4Num(r->t_end "%.6g") or(r->stalled_at "-")
          r4Num(r->fp_cm_avg "%.6g") r4Num(r->buf_cm_avg "%.5g") r4Num(r->vg_min "%.5g") r4Num(r->vg_max "%.5g")
          r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->rows "%.0f"))
    r4Row(port r6drCols r)
    r
  )
)
;; Stage 2 minimal diagnosis: BUFFERED 1 pF, 1 ms (covers TG edges at 0.25, 0.5, 0.75 ms)
procedure( r6drProbe()
  let( (port rb)
    port = r6drOpen("r6dr_probe.csv")
    r6drTran(port "P_A_buf_1p" 'A "BUFFERED" r6dCells->buf 1e-12 1e-3)
    rb = r6drTran(port "P_B_buf_1p" 'B "BUFFERED" r6dCells->buf 1e-12 1e-3)
    unless( rb->status == "ok" r6drTran(port "P_C_buf_1p" 'C "BUFFERED" r6dCells->buf 1e-12 1e-3))
    close(port)
    t
  )
)
;; Stage 3a: short consistency, same validated setting for REF / DIRECT 1 pF / BUFFERED 1 pF
procedure( r6drShort()
  let( (port s)
    s = stringToSymbol(r6drSetting())
    port = r6drOpen("r6dr_short.csv")
    r6drTran(port sprintf(nil "S_%s_ref" r6drSetting()) s "REF" r6dCells->ref 0.0 1e-3)
    r6drTran(port sprintf(nil "S_%s_direct_1p" r6drSetting()) s "DIRECT" r6dCells->direct 1e-12 1e-3)
    r6drTran(port sprintf(nil "S_%s_buf_1p" r6drSetting()) s "BUFFERED" r6dCells->buf 1e-12 1e-3)
    close(port)
    t
  )
)
;; Stage 3b: full R6D Stage B, 60 ms, same validated setting
procedure( r6drFull()
  let( (port s k)
    s = stringToSymbol(r6drSetting()) k = r6drSetting()
    port = r6drOpen("r6dr_full.csv")
    r6drTran(port sprintf(nil "F_%s_ref" k) s "REF" r6dCells->ref 0.0 60e-3)
    r6drTran(port sprintf(nil "F_%s_direct_1p" k) s "DIRECT" r6dCells->direct 1e-12 60e-3)
    r6drTran(port sprintf(nil "F_%s_buf_1p" k) s "BUFFERED" r6dCells->buf 1e-12 60e-3)
    r6drTran(port sprintf(nil "F_%s_direct_10p" k) s "DIRECT" r6dCells->direct 10e-12 60e-3)
    r6drTran(port sprintf(nil "F_%s_buf_10p" k) s "BUFFERED" r6dCells->buf 10e-12 60e-3)
    close(port)
    t
  )
)
