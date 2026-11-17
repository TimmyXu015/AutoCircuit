;; ECE203 Round 5N: single-ended no-chopper submission baseline (fL fix) + OTA1 flicker-noise floor sprint.
;; Task: docs/ECE203_round5n_no_chopper_submission_noise_sprint.md
;; System = Round 5 Stage E real architecture (r5SpecsE("cs"): 3 electrodes + body, pseudo-R, real DRL OTA + 2x1p ccm,
;; one 100 nA reference + PMOS mirrors, VREF/VCAS dividers (VCAS 1.10), C OTA1 + PMOS CS OTA2 (Miller 0.5p), LP 31.8M/20p).
;; Only NEW cells are created: ece203_r5n_ota_<n><p> (OTA1 copies with scaled M1/M2 and M3/M4) and ece203_r5n_tb_<n><p>.
;; Old cells (ece203_r4_ota, ece203_r5_cs, ece203_ss_pr_cell, ...) are instantiated read-only; no r4Build/r5BuildOta2/r6Build.
;; Jobs: ece203_r5n_a (baseline replica + prw scan), ece203_r5n_b (OTA1 area cases), ece203_r5n_c (signoff), ece203_r5n_ade.

r5nDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r5n")
;; area factors per device pair: 1, 4 (W x2, L x2), 16 (W x4, L x4); W/L ratio kept
r5nTail = 1   ;; OTA1 tail-current multiplier (MT width), used only for the bias pilot; 100 nA reference unchanged
procedure( r5nTag(n p) if( r5nTail == 1 sprintf(nil "n%dp%d" n p) sprintf(nil "n%dp%d_t%d" n p r5nTail)) )
procedure( r5nOtaCell(n p) strcat("ece203_r5n_ota_" r5nTag(n p)) )
procedure( r5nTbCell(n p) strcat("ece203_r5n_tb_" r5nTag(n p)) )
procedure( r5nK(a) sqrt(float(a)) )
;; C OTA (R4 local-cascode, = r4OtaDevs(t)) with M1/M2 x kn and M3/M4 x kp in both W and L
procedure( r5nOtaDevs(n p)
  let( (kn kp)
    kn = r5nK(n) kp = r5nK(p)
    list(list("pfetx" "M3" 2e-6 * kp 4e-6 * kp "n1" "n1" "VDD" "VDD")
         list("pfetx" "M4" 2e-6 * kp 4e-6 * kp "OUT" "n1" "VDD" "VDD")
         list("nfetx" "M1" 10e-6 * kn 8e-6 * kn "n1" "INP" "tail" "GND")
         list("nfetx" "M2" 10e-6 * kn 8e-6 * kn "x" "INN" "tail" "GND")
         list("nfetx" "MC" 10e-6 4e-6 "OUT" "VCAS" "x" "GND")
         list("nfetx" "MT" 8e-6 * r5nTail 4e-6 "tail" "IBIAS" "GND" "GND")
         list("nfetx" "MREF" 2e-6 4e-6 "IBIAS" "IBIAS" "GND" "GND"))
  )
)
;; OTA1 transistor gate area sum (um^2), estimate only (not layout area)
procedure( r5nOtaArea(n p)
  let( (a) a = 0.0 foreach(d r5nOtaDevs(n p) a = a + caddr(d) * cadddr(d) * 1e12) a )
)
procedure( r5nBuildOta(n p)
  let( (cv cell)
    cell = r5nOtaCell(n p)
    cv = acOpenSch(ece203Lib cell)
    ece203Pins(cv append(a3Cfg->pins '(("VCAS" "input"))))
    ece203Place(cv mapcar(lambda((d) apply('ece203FetSpec d)) r5nOtaDevs(n p)))
    ece203Finish(cv ece203Lib cell)
    ece203Symbol(ece203Lib cell)
    cell
  )
)
;; R5 Stage E spec list with XA pointed at the new OTA1 cell
procedure( r5nSpecs(n p)
  mapcar(lambda((e) if( caddr(e) == "XA" cons(car(e) cons(r5nOtaCell(n p) cddr(e))) e)) r5SpecsE("cs"))
)
procedure( r5nBuildTb(n p)
  ece203LibInfo()
  r5nBuildOta(n p)
  otaTb(r5nTbCell(n p) r5nSpecs(n p))
  r5nTbCell(n p)
)
procedure( r5nOver(prw) append(r5EOver("cs") list(list("prw" prw) list("prl" 2e-6))) )
procedure( r5nOpen(name cols)
  let( (port)
    unless( isDir(r5nDir) createDir(r5nDir) )
    port = outfile(strcat(r5nDir "/" name) "w")
    fprintf(port "%s\n" buildString(mapcar('symbolToString cols) ","))
    port
  )
)
r5nCols = append(r4ACols '(case n_area p_area prw ota1_area_um2 cgg_M1 cgg_M3 m1_vgs m1_vds m3_vsg m3_vsd margin_X2
                            pr_w_netlist pr_par valid))
r5nNsBins = '(0.1 0.168 0.282 0.473 0.794 1.33 2.24 3.76 6.31 10.6 17.8 29.9 50.2 84.3 141.6 250.0)

;; one configuration: DM AC + DC (+ noise and per-bin NoiseSummary), with r4Ac (same definitions as Round 4/5)
procedure( r5nCase(port caseName n p prw noise)
  let( (cell tag r ok oldDir oldInsts nl m)
    cell = r5nTbCell(n p) tag = strcat(caseName "_" r5nTag(n p))
    oldDir = r4Dir oldInsts = r4OpInsts
    r4Dir = r5nDir r4OpInsts = append(r4OpInsts '("X2.MCS" "X2.MCL"))
    ok = errset(r = r4Ac(cell tag 'dm r5nOver(prw) noise) t)
    unless( ok r = list(nil 'tag tag 'cell cell 'status "failed" 'reason sprintf(nil "%L" errset.errset)))
    when( ok
      r->cgg_M1 = car(errset(pv("/XA/M1" "cgg" ?result "dcOpInfo") nil))
      r->cgg_M3 = car(errset(pv("/XA/M3" "cgg" ?result "dcOpInfo") nil))
      r->m1_vgs = car(errset(pv("/XA/M1" "vgs" ?result "dcOpInfo") nil)) r->m1_vds = car(errset(pv("/XA/M1" "vds" ?result "dcOpInfo") nil))
      r->m3_vsg = car(errset(-pv("/XA/M3" "vgs" ?result "dcOpInfo") nil)) r->m3_vsd = car(errset(-pv("/XA/M3" "vds" ?result "dcOpInfo") nil))
      m = ldMinMargin(ece203OpDump(strcat(r5nDir "/" tag "_x2_dcop.csv") '("X2.MCS" "X2.MCL")) "X2.") r->margin_X2 = car(m)
      ;; pseudo-R really sized by prw? netlist of this exact run
      nl = strcat(r5nDir "/" tag "_netlist.scs")
      sh(sprintf(nil "cp %s/simulation/%s/spectre/schematic/netlist/input.scs %s" getShellEnvVar("HOME") cell nl))
      r->pr_w_netlist = if( sh(sprintf(nil "grep -q 'pfet33x.*w=prw\\|w=prw.*pfet33x\\|MP.*w=prw' %s" nl)) "w=prw" "check")
      r->pr_par = if( sh(sprintf(nil "grep -q 'prw=%g' %s" prw nl)) sprintf(nil "prw=%g" prw) "check")
      sh(sprintf(nil "grep -n 'pfet33x\\|^parameters' %s | sed 's/^/AC>   pr: /' | cut -c1-200" nl))
      when( noise
        for(k 0 length(r5nNsBins) - 2
          nsSummary(strcat(r5nDir "/" tag sprintf(nil "_ns_b%02d.txt" k)) 'integrated nth(k r5nNsBins) nth(k + 1 r5nNsBins)))))
    r4Dir = oldDir r4OpInsts = oldInsts
    r->case = caseName r->n_area = n r->p_area = p r->prw = prw r->ota1_area_um2 = r5nOtaArea(n p)
    r->valid = if( and(numberp(r->margin_A) r->margin_A > 0.03 numberp(r->Hout_100_dB) r->Hout_100_dB > 37.0
                       r->Hout_100_dB < 43.0 numberp(r->fH_out) r->fH_out > 150.0) "valid" "INVALID")
    acSay("r5n %s: %s %s | H10/60/100 %s %s %s (%s dB) fL %s fH %s | Zin P/N %s %s | I %s %s | margin A %s %s X2 %s | M1 vgs %s vds %s cgg %s | M3 vsg %s vsd %s cgg %s | noise app %s deemb %s | OTA1 area %s um2 | pr %s %s | %s\n"
          tag r->status or(r->reason "") r4Num(r->Hout_10 "%.4g") r4Num(r->Hout_60 "%.4g") r4Num(r->Hout_100 "%.4g")
          r4Num(r->Hout_100_dB "%.2f") r4Num(r->fL_out "%.4g") r4Num(r->fH_out "%.4g") r4Num(r->Zin_amp_P_10 "%.3g")
          r4Num(r->Zin_amp_N_10 "%.3g") r4Num(r->I_VDD "%.4g") r4Num(r->I_VDDD "%.4g") r4Num(r->margin_A "%.3f") or(r->worst_A "")
          r4Num(r->margin_X2 "%.3f") r4Num(r->m1_vgs "%.4g") r4Num(r->m1_vds "%.4g") r4Num(r->cgg_M1 "%.3g")
          r4Num(r->m3_vsg "%.4g") r4Num(r->m3_vsd "%.4g") r4Num(r->cgg_M3 "%.3g")
          r4Num(r->noise_app_in "%.4g") r4Num(r->noise_deemb_in "%.4g") r4Num(r->ota1_area_um2 "%.0f")
          or(r->pr_w_netlist "") or(r->pr_par "") r->valid)
    r4Row(port r5nCols r)
    r
  )
)

;; ---------- A: replica of R5 Stage E (prw 3u) + pseudo-R width scan ----------
procedure( r5nStageA()
  let( (port)
    r5nBuildTb(1 1)
    port = r5nOpen("r5n_prw_scan.csv" r5nCols)
    r5nCase(port "A0_replica_prw3u" 1 1 3e-6 t)
    foreach(w '(3.5e-6 4.0e-6 4.5e-6)
      r5nCase(port sprintf(nil "A_prw%gu" w * 1e6) 1 1 w t))
    close(port)
    t
  )
)
;; ---------- B: OTA1 area cases at the chosen pseudo-R width ----------
r5nPrw = 4.0e-6   ;; set after stage A (submission baseline width)
r5nBCases = '((4 1) (1 4) (4 4) (16 4) (4 16) (16 16))
procedure( r5nStageB()
  let( (port)
    port = r5nOpen("r5n_area_cases.csv" r5nCols)
    foreach(c r5nBCases
      r5nBuildTb(car(c) cadr(c))
      r5nCase(port "B" car(c) cadr(c) r5nPrw t))
    close(port)
    t
  )
)

;; ---------- B bias pilot (1 of max 2): B6 sizes with the OTA1 tail current x2 (MT 16u/4u) ----------
;; In weak inversion the input-referred flicker is ~bias independent; only the thermal part (~1.7 uV of 4.6 uV in B6)
;; should move. M2 headroom (0.083 V in B6) is expected to shrink because MC and M1 Vgs both rise.
procedure( r5nStagePilot()
  let( (port)
    port = r5nOpen("r5n_bias_pilot.csv" r5nCols)
    r5nTail = 2
    r5nBuildTb(16 16)
    r5nCase(port "P1_tail2" 16 16 r5nPrw t)
    r5nTail = 1
    close(port)
    t
  )
)

;; bias pilot 2 of 2: tail x4 (pilot 1 kept M2 margin 0.085 V and cut noise 4.60 -> 4.23 uV at +312 nA)
procedure( r5nStagePilot2()
  let( (port)
    port = r5nOpen("r5n_bias_pilot2.csv" r5nCols)
    r5nTail = 4
    r5nBuildTb(16 16)
    r5nCase(port "P2_tail4" 16 16 r5nPrw t)
    r5nTail = 1
    close(port)
    t
  )
)

;; ---------- C: signoff of the frozen submission baseline and the best low-noise candidate ----------
;; r5nBest is set after stage B (n p) - only these two configurations are signed off.
r5nBest = '(16 16)
procedure( r5nSignoff(n p label)
  let( (cell extra pre oldDir oldR5 oldInsts portA portB portS ok)
    cell = r5nTbCell(n p) pre = strcat("C_" label)
    extra = append(r4RbVars list(list("cm2" 0.5e-12) list("prw" r5nPrw) list("prl" 2e-6)))
    portA = r5nOpen(sprintf(nil "r5n_signoff_%s_dm.csv" label) r5nCols)
    r5nCase(portA strcat(pre "_dm_noise") n p r5nPrw t)
    close(portA)
    oldDir = r4Dir oldR5 = r5Dir oldInsts = r4OpInsts
    r4Dir = r5nDir r5Dir = r5nDir r4OpInsts = append(r4OpInsts '("X2.MCS" "X2.MCL"))
    ok = errset(
      progn(
        portS = r5nOpen(sprintf(nil "r5n_signoff_%s_mainstb.csv" label) r5ECols)
        r5EMainStb(portS cell strcat(pre "_mainstb") r5nOver(r5nPrw))
        close(portS)
        portB = r5nOpen(sprintf(nil "r5n_signoff_%s_drl.csv" label) r4BCols)
        r4BCase(portB "off" 0.01 extra pre cell)
        r4BCase(portB "real" 0.01 extra pre cell)
        close(portB)
        t)
      t)
    unless( ok acSay("r5n signoff %s failed: %L\n" label errset.errset))
    r4Dir = oldDir r5Dir = oldR5 r4OpInsts = oldInsts
    t
  )
)
r5nBestTail = 1   ;; tail multiplier of the best candidate (set after the pilots)
procedure( r5nStageC()
  r5nTail = 1
  r5nSignoff(1 1 "baseline")
  r5nTail = r5nBestTail
  r5nSignoff(car(r5nBest) cadr(r5nBest) "best")
  r5nTail = 1
  t
)
;; ---------- ADE L states (GUI) ----------
procedure( r5nAde()
  hw1NoLicensePrompts()
  when( hiGraphicMode() acAutoOkStart() )
  unless( hiGraphicMode() error("r5nAde needs the GUI (run.sh ece203_r5n_ade)\n") )
  r4AdeTb(r5nTbCell(1 1) "r5n_submission_baseline" append(r5nOver(r5nPrw) list(list("dcc" 0.01) list("itr" 1e-7))) t t t)
  r5nTail = r5nBestTail
  r4AdeTb(r5nTbCell(car(r5nBest) cadr(r5nBest)) "r5n_low_noise_best" append(r5nOver(r5nPrw) list(list("dcc" 0.01) list("itr" 1e-7))) t t t)
  r5nTail = 1
  t
)
