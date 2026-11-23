;; ECE203 R7F: two orthogonal, bounded changes on the accepted R7E lp_a0 system (R7D a0 + differential output RC LP).
;;  Stage A: LP impedance scaling only, same time constant: RLP_P/N 31.8 MOhm -> 4.77 MOhm, CLP_P/N 20 pF -> 133 pF
;;           (bufp->outp / bufn->outn, outp/outn -> gnd!), unloaded and with COUTP/COUTN 10 pF per side (stress load).
;;  Stage B: same LP, input coupling capacitors CCP/CCN design variable cc 50 pF -> 60 pF only (G0), loaded and unloaded.
;;  Stage C: one 60 ms 2 kHz TG transient of the final loaded gain candidate (R7E settings).
;; Everything else (MOS, CMFB, DRL, bias, pseudo-R, Cfb, CLB 10 pF on bufp/bufn, clocks) frozen. Task:
;; docs/ECE203_round7f_gain_and_loaded_lp_task.md. Measurement code = R7C r7cStageB1 + R7E r7eLp / r7eStageC (rebound to r7fDir).
;; Jobs: ece203_r7f_build / ece203_r7f_a (static, per case) / ece203_r7f_c (tran) / ece203_r7f_ade, case via env AC_R7F_CASE.

r7fDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r7f")
r7fTmp = "/tmp/lix015_r7f"
;; cases: lp (R, C), load (COUT 10 pF per side), extra (design-variable overrides on top of the R7D/R7E set)
r7fCases = list(nil
  'lp_l0            list(nil 'cell "ece203_r7f_tb_lp_l0"            'r "4.77M" 'c "133p" 'load nil 'extra nil)
  'lp_l0_load10p    list(nil 'cell "ece203_r7f_tb_lp_l0_load10p"    'r "4.77M" 'c "133p" 'load t   'extra nil)
  'gain_g0_load10p  list(nil 'cell "ece203_r7f_tb_gain_g0_load10p"  'r "4.77M" 'c "133p" 'load t   'extra '(("cc" 60e-12)))
  'gain_g0_unloaded list(nil 'cell "ece203_r7f_tb_gain_g0_unloaded" 'r "4.77M" 'c "133p" 'load nil 'extra '(("cc" 60e-12))))
procedure( r7fCase() or(getShellEnvVar("AC_R7F_CASE") "lp_l0") )
procedure( r7fC(c) let( (p) p = get(r7fCases stringToSymbol(c)) unless( p error("unknown case %s" c)) p ) )

procedure( r7fSpecs(c)
  let( (p)
    p = r7fC(c)
    append(r7dSpecs("a0")
           append(list(otaR("RLP_P" p->r "bufp" "outp") otaC("CLP_P" p->c "outp" "gnd!")
                       otaR("RLP_N" p->r "bufn" "outn") otaC("CLP_N" p->c "outn" "gnd!"))
                  if( p->load list(otaC("COUTP" "10p" "outp" "gnd!") otaC("COUTN" "10p" "outn" "gnd!")) nil)))
  )
)
procedure( r7fBuild()
  let( (c cell)
    ece203LibInfo()
    c = r7fCase() cell = r7fC(c)->cell
    foreach(x list("ece203_r7e_tb_lp_a0" "ece203_r7d_tb_bias_a0" "ece203_ss_pr_cell" r7aCmfbCell("a2") r6dCells->cd) unless( ddGetObj(ece203Lib x) error("missing %s" x)))
    when( ddGetObj(ece203Lib cell) error("%s already exists" cell))
    otaTb(cell r7fSpecs(c))
    t
  )
)
;; register a case in the R7C / R7E case tables so r7cStageB1, r7eLp and r7eStageC measure it unchanged
procedure( r7fRegister(c)
  let( (p key)
    p = r7fC(c) key = stringToSymbol(c)
    putprop(r7cCases list(nil 'cell p->cell 'prw 4e-6 'extra p->extra) key)
    putprop(r7eCases list(nil 'cell p->cell 'load p->load 'extra p->extra) key)
  )
)
;; Stage A / B (static, TG phase A): full system measurement (DC op, margins, DM/CM AC, Zin, CMRR, CMFB + DRL STB) + LP transfer
procedure( r7fStatic()
  let( (c od oe res)
    ece203LibInfo()
    c = r7fCase() r7fRegister(c)
    od = r7cDir oe = r7eDir r7cDir = r7fDir r7eDir = r7fDir
    res = errset(progn(r7cStageB1(c r6bSysOpts "") r7eLp(c)) t)
    r7cDir = od r7eDir = oe
    unless( res error("%L" errset.errset))
    t
  )
)
;; Stage C: r7eStageC on an R7F case, results in r7fDir / r7fTmp, R7F watchdog
procedure( r7fTran()
  let( (c od ot ow res)
    ece203LibInfo()
    c = r7fCase() r7fRegister(c)
    od = r7eDir ot = r7eTmp ow = r7eWd
    r7eDir = r7fDir r7eTmp = r7fTmp r7eWd = "r7f_watchdog.sh"
    res = errset(r7eStageC() t)
    r7eDir = od r7eTmp = ot r7eWd = ow
    unless( res error("%L" errset.errset))
    t
  )
)
procedure( r7fAde()
  let( (c vars outs)
    hw1NoLicensePrompts()
    when( hiGraphicMode() acAutoOkStart() )
    unless( hiGraphicMode() error("r7fAde needs the GUI (run.sh ece203_r7f_ade)\n") )
    c = r7fCase()
    vars = r6bMerge(r6Vars append(append(r7eVars() r7fC(c)->extra) list(list("adm" 1.0) list("dcc" 0.01))))
    outs = list(list("Hout_dB" "db20((VF(\"/outp\") - VF(\"/outn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("Hbuf_dB" "db20((VF(\"/bufp\") - VF(\"/bufn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("Hpre_dB" "db20((VF(\"/fp\") - VF(\"/fn\")) / (VF(\"/ep\") - VF(\"/en\")))")
                list("op_cm" "(VDC(\"/op\") + VDC(\"/on\")) / 2")
                list("cmfbLoopGain" "getData(\"loopGain\" ?result \"stb\")"))
    r6bAdeOne(r7fC(c)->cell sprintf(nil "r7f_%s_phaseA" c) vars outs "/IPRC")
    t
  )
)
