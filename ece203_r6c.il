;; ECE203 Round 6C-I: ideal linear CMFB controller in the R6B real-MOS system (A/B against the real DD-pair CMFB).
;; Task: docs/ECE203_round6c_ideal_cmfb_task.md. New cells only (ece203_r6c_*); R6A/R6B/R5/R4 cells are read-only.
;; Jobs: ece203_r6c_a (Stage A: TG static phase A - DC/AC/STB/CM disturbance), ece203_r6c_b (Stage B: chopper off,
;;       100 Hz 1 mV DM tran), ece203_r6c_c (Stage C: 2 kHz TG chopper, 60 ms tran), ece203_r6c_ade (GUI: ADE states).
;;
;; Two testbench cells built from the SAME spec list (the R6B system ece203_r6b_fd_tg_tb: R6A FD OTA1, two real TG
;; choppers, ideal 2-phase clock, real R4 DRL OTA, body/electrodes, Cc/Cfb, ideal Rfb, ideal VREF/VCAS/IB/IBD):
;;   ece203_r6c_tb_old   : unchanged R6B system (real MOS DD-pair CMFB XC -> vcf -> IPRC -> RCF -> vg)
;;   ece203_r6c_tb_ideal : XC removed, replaced by the ideal linear controller below driving the SAME node vcf
;; The CMFB is the only difference. Probe node (sense) and actuation node (vg = PMOS M3/M4 gates) are distinct.
;;
;; Ideal controller (Spectre analogLib primitives only):
;;   sense   : ESA, ESB  vcvs 0.5 each       csen = (op + on)/2        (infinite input impedance, no load on op/on)
;;   error   : EEA       vcvs a0             cea1 = a0 * (csen - vrc)  (vrc = the same VREF node the old CMFB uses)
;;   pole    : RPC/CPC   rcp, ccp            cea2 = cea1 / (1 + s*rcp*ccp)   (fp = 1/(2*pi*rcp*ccp))
;;   bias    : VBC + EAD vb                  csum = vb + cea2          (vb is a fixed controller bias, not a servo)
;;   limiter : ELM       vcvs 1, maxm/minm   vcf  = clip(csum, vclmin, vclmax) = 0 .. 1.8 V rails
;;   polarity: Vout,cm up -> csen up -> vcf/vg up -> PMOS loads source less -> Vout,cm down (negative feedback).

r6cDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r6c")
r6cCells = list(nil 'old "ece203_r6c_tb_old" 'ideal "ece203_r6c_tb_ideal")
;; a0 = 1 (DC controller gain), fp = 30 MHz: the plant (vg -> Vout,cm) already has ~1.4e3 mid-band gain, so the loop
;; gain at DC is ~a0 * 1.4e3. a0 sets the loop UGF (~0.7 MHz, ~2x the old CMFB's 0.35 MHz); fp is placed well above it.
;; Pre-run estimate from the R6B old-CMFB loop-gain curve (old K ~0.5, its MD pole 1.5-5 MHz): PM 63-83 deg.
r6cCtrl = list(list("a0" 1.0) list("rcp" 1e3) list("ccp" 5.3052e-12) list("vb" 1.325) list("vclmax" 1.8) list("vclmin" 0.0))

procedure( r6cE(name ncp ncm p m g @optional mx mn)
  list("analogLib" "vcvs" name
       append(list(list("egain" g)) if( mx list(list("maxm" mx) list("minm" mn)) nil))
       list(list("NC+" ncp) list("NC-" ncm) list("PLUS" p) list("MINUS" m)))
)
procedure( r6cCtrlSpecs()
  list(
    r6cE("ESA" "op" "gnd!" "csh" "gnd!" "0.5")
    r6cE("ESB" "on" "gnd!" "csen" "csh" "0.5")
    r6cE("EEA" "csen" "vrc" "cea1" "gnd!" "a0")
    otaR("RPC" "rcp" "cea1" "cea2") otaC("CPC" "ccp" "cea2" "gnd!")
    otaV("VBC" "vb" "0" "cvb" "gnd!")
    r6cE("EAD" "cea2" "gnd!" "csum" "cvb" "1")
    r6cE("ELM" "csum" "gnd!" "vcf" "gnd!" "1" "vclmax" "vclmin"))
)
;; VSPS gets an explicit sinephase 0: an omitted analogLib vsin parameter is filled with the value last used in the
;; Virtuoso session (VSNS 180 of the previously built bench), which made VSPS == VSNS in the first ideal-bench build.
procedure( r6cFixSpec(e)
  if( caddr(e) == "VSPS" list(nth(0 e) nth(1 e) nth(2 e) append(nth(3 e) '(("sinephase" "0"))) nth(4 e)) e)
)
procedure( r6cBuild()
  let( (base)
    ece203LibInfo()
    r6bBuildTg()
    r6Build()
    base = mapcar('r6cFixSpec r6bSSpecs())
    otaTb(r6cCells->old base)
    otaTb(r6cCells->ideal append(setof(e base caddr(e) != "XC") r6cCtrlSpecs()))
    t
  )
)
r6cBase = append(r6bSysBase r6cCtrl)
procedure( r6cOpen(name cols)
  let( (port)
    unless( isDir(r6cDir) createDir(r6cDir) )
    port = outfile(strcat(r6cDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
;; run an R6A measurement function on an R6C cell (temporarily rebinding the R6A cell name and output dir)
procedure( r6cOn(cell fn @rest args)
  let( (oldTb oldDir res)
    oldTb = r6Cells->tb oldDir = r6Dir
    r6Cells->tb = cell r6Dir = r6cDir r4TightOpts = r6bSysOpts
    res = errset(apply(fn args) t)
    r6Cells->tb = oldTb r6Dir = oldDir r4TightOpts = nil
    unless( res error("%L" errset.errset))
    car(res)
  )
)

;; ---------- Stage A: TG static phase A ----------
r6cACols = '(tag cmfb status reason Hdm10 Hdm100 ph100 Acm60 CMRR60_dB I_VDD I_VDDD op on ocm vg vcf body drlr csen cea2
             m3_vsd m3_vdsat m3_margin m4_vsd m4_vdsat m4_margin minA worstA cmfb_ugf cmfb_pm cmfb_lgdc cmfb_ph0
             drl_ugf drl_pm drl_lg60 drl_lgdc drl_ph0 dz_eo_1 dz_eo_1k dz_eo_100k dz_vod_1 dz_vod_1k
             st_eo_step st_vg_step st_vod_pk st_eo_pk st_t90 st_eo_pp_end st_vg_min st_vg_max)
procedure( r6cOp(r tag)
  let( (rows m)
    rows = ece203OpRows('("XA.M1" "XA.M2" "XA.MC1" "XA.MC2" "XA.M3" "XA.M4" "XA.MT" "XA.MREF"))
    foreach(x rows
      m = ece203Margin(caddr(x))
      cond( (car(x) == "XA.M3" r->m3_vsd = and(numberp(nth(4 caddr(x))) -nth(4 caddr(x)))
                               r->m3_vdsat = and(numberp(nth(6 caddr(x))) -nth(6 caddr(x))) r->m3_margin = m)
            (car(x) == "XA.M4" r->m4_vsd = and(numberp(nth(4 caddr(x))) -nth(4 caddr(x)))
                               r->m4_vdsat = and(numberp(nth(6 caddr(x))) -nth(6 caddr(x))) r->m4_margin = m))
      when( numberp(m) && (!r->minA || m < r->minA) r->minA = m r->worstA = car(x)))
  )
)
;; 1 nA/side output-CM current step at 1 ms, 6 ms tran: CM step, recovery, DM crosstalk, polarity (vg follows eo)
procedure( r6cStep(r cell tag over)
  let( (eo vg vod a b fin t90)
    ece203Setup(cell strcat("_" tag "_step"))
    r6bOpt(r6bSysOpts)
    analysis('tran ?stop "6m" ?maxstep "0.2u")
    car(errset(saveOption('save "selected") nil))
    car(errset(save('v "/op" "/on" "/fp" "/fn" "/vg") nil))
    r6bSet(r6Vars append(over list(list("izst" 1e-9) list("tzo" 1e-3))))
    run()
    eo = (v("/op" ?result "tran") + v("/on" ?result "tran")) / 2.0 - 0.9
    vg = v("/vg" ?result "tran") vod = v("/fp" ?result "tran") - v("/fn" ?result "tran")
    when( r6bTend(eo) < 5.9e-3 error("step tran stopped at %g s" r6bTend(eo)))
    a = chAvg(eo 0.5e-3 1e-3) b = chAvg(eo 5e-3 6e-3)
    r->st_eo_step = b - a
    r->st_vg_step = chAvg(vg 5e-3 6e-3) - chAvg(vg 0.5e-3 1e-3)
    r->st_vod_pk = ymax(abs(clip(vod 1e-3 6e-3) - chAvg(vod 0.5e-3 1e-3)))
    r->st_eo_pk = ymax(abs(clip(eo 1e-3 6e-3) - a))
    fin = a + 0.9 * (b - a)
    t90 = car(errset(cross(clip(eo 1e-3 6e-3) fin 1 if( b > a "rising" "falling")) nil))
    r->st_t90 = and(numberp(t90) t90 - 1e-3)
    r->st_eo_pp_end = chPp(eo 5e-3 6e-3)
    r->st_vg_min = ymin(clip(vg 1e-3 6e-3)) r->st_vg_max = ymax(clip(vg 1e-3 6e-3))
    r6bWrite(strcat(r6cDir "/" tag "_step_tran.csv") "t_s,e_out_V,vg_V,vod_V" list(eo vg vod))
  )
)
procedure( r6cCaseA(port tag kind cell)
  let( (r ok over w)
    over = append(r6cBase list(list("dcc" 0.01)))
    r = list(nil 'tag tag 'cmfb kind 'status "ok")
    ok = errset(
      progn(
        r6cOn(cell 'r6Gains r tag over)
        ;; DC (dm run, dcc 0.01): ocm, controller nodes, OTA device margins (r6Gains already wrote <tag>_dm_dcop.csv)
        r->ocm = and(numberp(r->op) numberp(r->on) (r->op + r->on) / 2.0)
        r->csen = ldDc("csen") r->cea2 = ldDc("cea2")
        r6cOp(r tag)
        r6cOn(cell 'r6Stb r tag over)
        ;; AC output-CM disturbance 1 nA/side (dcc 0): closed-loop e_out and DM crosstalk
        w = r6cOn(cell 'r6AcRun strcat(tag "_dz") append(r6cBase list(list("izo" 1e-9))))
        r->dz_eo_1 = ldMag(w->eo 1.0) r->dz_eo_1k = ldMag(w->eo 1000.0) r->dz_eo_100k = ldMag(w->eo 1e5)
        r->dz_vod_1 = ldMag(w->vod 1.0) r->dz_vod_1k = ldMag(w->vod 1000.0)
        ldWriteCurves(strcat(r6cDir "/" tag "_dz_ac.csv") list(list("eo_per_nA" w->eo) list("vod_per_nA" w->vod) list("ei_per_nA" w->ei)))
        ;; transient 1 nA/side step
        r6cStep(r cell tag r6cBase)
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r6cA %s [%s]: %s %s | Hdm 10/100 %s %s ph %s | CMRR60 %s dB | op %s on %s ocm %s vg %s csen %s | I %s %s | M3 vsd %s vdsat %s margin %s | M4 %s %s %s | minA %s %s\n"
          tag kind r->status or(r->reason "") r4Num(r->Hdm10 "%.5g") r4Num(r->Hdm100 "%.5g") r4Num(r->ph100 "%.2f")
          r4Num(r->CMRR60_dB "%.2f") r4Num(r->op "%.6g") r4Num(r->on "%.6g") r4Num(r->ocm "%.6g") r4Num(r->vg "%.6g")
          r4Num(r->csen "%.6g") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->m3_vsd "%.4g") r4Num(r->m3_vdsat "%.4g")
          r4Num(r->m3_margin "%.3f") r4Num(r->m4_vsd "%.4g") r4Num(r->m4_vdsat "%.4g") r4Num(r->m4_margin "%.3f")
          r4Num(r->minA "%.3f") or(r->worstA ""))
    acSay("r6cA %s: CMFB stb UGF %s PM %s LGdc %s ph0 %s | DRL UGF %s PM %s LG60 %s | dz e_out/nA 1/1k/100k %s %s %s vod/nA 1/1k %s %s | step eo %s vg %s t90 %s pk %s vod pk %s end pp %s vg %s..%s\n"
          tag r4Num(r->cmfb_ugf "%.4g") r4Num(r->cmfb_pm "%.1f") r4Num(r->cmfb_lgdc "%.4g") r4Num(r->cmfb_ph0 "%.1f")
          r4Num(r->drl_ugf "%.4g") r4Num(r->drl_pm "%.1f") r4Num(r->drl_lg60 "%.4g")
          r4Num(r->dz_eo_1 "%.4g") r4Num(r->dz_eo_1k "%.4g") r4Num(r->dz_eo_100k "%.4g") r4Num(r->dz_vod_1 "%.3g") r4Num(r->dz_vod_1k "%.3g")
          r4Num(r->st_eo_step "%.4g") r4Num(r->st_vg_step "%.4g") r4Num(r->st_t90 "%.4g") r4Num(r->st_eo_pk "%.4g")
          r4Num(r->st_vod_pk "%.3g") r4Num(r->st_eo_pp_end "%.3g") r4Num(r->st_vg_min "%.6g") r4Num(r->st_vg_max "%.6g"))
    r4Row(port r6cACols r)
    r
  )
)
procedure( r6cStageA()
  let( (port)
    r6cBuild()
    port = r6cOpen("r6c_stageA.csv" r6cACols)
    r6cCaseA(port "A_old" "real DD-pair CMFB" r6cCells->old)
    r6cCaseA(port "A_ideal" "ideal linear CMFB a0 1 fp 30 MHz vb 1.325" r6cCells->ideal)
    close(port)
    t
  )
)

;; ---------- Stage B / C: 60 ms tran, 100 Hz 1 mV differential ECG input ----------
r6cTCols = '(tag cmfb chen status reason ocm_avg ocm_pp vod_pp op_min op_max on_min on_max vg_min vg_max p_avg n_avg I_VDD I_VDDD rows)
procedure( r6cTran(port tag kind cell chen maxstep)
  let( (r ok vid vod op on ocm icm pp nn vg)
    r = list(nil 'tag tag 'cmfb kind 'chen chen 'status "ok")
    ok = errset(
      progn(
        ece203Setup(cell strcat("_" tag))
        r6bOpt(r6bSysOpts)
        analysis('tran ?stop "60m" ?maxstep maxstep)
        car(errset(saveOption('save "selected") nil))
        car(errset(save('v "/ep" "/en" "/fp" "/fn" "/op" "/on" "/inp" "/inn" "/p" "/n" "/vg") nil))
        car(errset(save('i "/VDD/PLUS" "/VDDD/PLUS") nil))
        r6bSet(r6Vars append(r6cBase list(list("chen" chen) list("tch" 500e-6) list("vd" 1e-3))))
        run()
        vid = v("/ep" ?result "tran") - v("/en" ?result "tran")
        when( r6bTend(vid) < 59e-3 error("tran stopped at %g s" r6bTend(vid)))
        vod = v("/fp" ?result "tran") - v("/fn" ?result "tran")
        op = v("/op" ?result "tran") on = v("/on" ?result "tran") ocm = (op + on) / 2.0
        icm = (v("/inp" ?result "tran") + v("/inn" ?result "tran")) / 2.0
        pp = v("/p" ?result "tran") nn = v("/n" ?result "tran") vg = v("/vg" ?result "tran")
        r->vod_pp = chPp(vod 40e-3 60e-3) r->ocm_avg = chAvg(ocm 40e-3 60e-3) r->ocm_pp = chPp(ocm 40e-3 60e-3)
        r->op_min = ymin(clip(op 20e-3 60e-3)) r->op_max = ymax(clip(op 20e-3 60e-3))
        r->on_min = ymin(clip(on 20e-3 60e-3)) r->on_max = ymax(clip(on 20e-3 60e-3))
        r->p_avg = chAvg(pp 40e-3 60e-3) r->n_avg = chAvg(nn 40e-3 60e-3)
        r->vg_min = ymin(clip(vg 20e-3 60e-3)) r->vg_max = ymax(clip(vg 20e-3 60e-3))
        r->I_VDD = car(errset(chAvg(i("/VDD/PLUS" ?result "tran") 40e-3 60e-3) nil))
        r->I_VDDD = car(errset(chAvg(i("/VDDD/PLUS" ?result "tran") 40e-3 60e-3) nil))
        r->rows = r6bWrite(strcat(r6cDir "/" tag "_tran.csv") "t_s,vid_V,vod_V,op_V,on_V,ocm_V,icm_V,p_V,n_V,vg_V"
                           list(vid vod op on ocm icm pp nn vg))
        t)
      t)
    unless( ok r->status = "failed" r->reason = sprintf(nil "%L" errset.errset))
    acSay("r6cT %s [%s, chen %g]: %s %s | 40-60 ms: vod pp %s | ocm avg %s pp %s | 20-60 ms op %s..%s on %s..%s vg %s..%s | p %s n %s | I %s %s | rows %s\n"
          tag kind chen r->status or(r->reason "") r4Num(r->vod_pp "%.4g") r4Num(r->ocm_avg "%.6g") r4Num(r->ocm_pp "%.4g")
          r4Num(r->op_min "%.4g") r4Num(r->op_max "%.4g") r4Num(r->on_min "%.4g") r4Num(r->on_max "%.4g")
          r4Num(r->vg_min "%.5g") r4Num(r->vg_max "%.5g") r4Num(r->p_avg "%.6g") r4Num(r->n_avg "%.6g")
          r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->rows "%.0f"))
    r4Row(port r6cTCols r)
    r
  )
)
procedure( r6cNetDiff(name)
  let( (h)
    h = getShellEnvVar("HOME")
    sh(sprintf(nil "diff %s/simulation/%s/spectre/schematic/netlist/input.scs %s/simulation/%s/spectre/schematic/netlist/input.scs > %s/%s; true"
               h r6cCells->old h r6cCells->ideal r6cDir name))
    sh(sprintf(nil "sed 's/^/AC>   netdiff: /' %s/%s | cut -c1-200" r6cDir name))
  )
)
procedure( r6cStageB()
  let( (port)
    r6cBuild()
    port = r6cOpen("r6c_stageB.csv" r6cTCols)
    r6cTran(port "B_old" "real DD-pair CMFB" r6cCells->old 0.0 "2u")
    r6cTran(port "B_ideal" "ideal linear CMFB" r6cCells->ideal 0.0 "2u")
    close(port)
    r6cNetDiff("r6c_netlist_diff_B.txt")
    t
  )
)
procedure( r6cStageC()
  let( (port)
    port = r6cOpen("r6c_stageC.csv" r6cTCols)
    r6cTran(port "C_old" "real DD-pair CMFB" r6cCells->old 1.0 "0.5u")
    r6cTran(port "C_ideal" "ideal linear CMFB" r6cCells->ideal 1.0 "0.5u")
    close(port)
    r6cNetDiff("r6c_netlist_diff_C.txt")
    t
  )
)

;; ---------- ADE L states (GUI job ece203_r6c_ade): both benches, TG static phase A, dc / ac / CMFB stb ----------
procedure( r6cAde()
  let( (vars outs)
    hw1NoLicensePrompts()
    when( hiGraphicMode() acAutoOkStart() )
    unless( hiGraphicMode() error("r6cAde needs the GUI (run.sh ece203_r6c_ade)\n") )
    vars = r6bMerge(r6Vars append(r6cBase list(list("adm" 1.0) list("dcc" 0.01))))
    outs = list(list("Hdm_dB" "db20((VF(\"/fp\") - VF(\"/fn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("Vout_cm" "(VDC(\"/op\") + VDC(\"/on\")) / 2")
                list("cmfbLoopGain" "getData(\"loopGain\" ?result \"stb\")"))
    r6bAdeOne(r6cCells->old "r6c_old_cmfb_phaseA" vars outs "/IPRC")
    r6bAdeOne(r6cCells->ideal "r6c_ideal_cmfb_phaseA" vars outs "/IPRC")
    t
  )
)
