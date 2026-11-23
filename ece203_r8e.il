;; ECE203 R8E: proportional Cc / Cfb scaling (Cc/Cfb = 120 kept) on the frozen R8B real-MOS chopper system, to pull the chopped
;; (PAC sideband-0) high-pass corner from 0.338 Hz back towards 0.1 Hz. Task: docs/ECE203_round8e_proportional_capacitance_highpass_recovery_task.md;
;; pre-registration docs/ece203_data/round8e/r8e_plan.md.
;; New cells = r8bSpecs() unchanged (Project/ece203_r8e_tb_c2, ece203_r8e_tb_c35); the ONLY difference is the design-variable values
;; cc / cfb (CCP/CCN use cc, CFP/CFN use cfb, CCX = cc*dcc with dcc 0 in every periodic / noise run). G0 = the read-only R8B cell.
;; Measurement code reused unchanged in definition:
;;   static  : R7F path (r7cStageB1 + r7eLp: dc op, DM/CM AC, Zin, CMRR, CMFB + DRL STB, LP transfer)  -> job ece203_r8e_static
;;   PSS/PAC : R8C r8cPeriodic (PSS writepss, PAC readpss sb0 0.01-1000 Hz 40/dec, node transfers, sb0 Zin)  -> ece203_r8e_pss / _pac
;;   PNoise  : R8 r8Periodic (same definition as R8B Stage D: PAC 0.1-250 Hz + timeaverage PNoise outp/outn)  -> ece203_r8e_pnoise
;;   tran    : R7E r7eStageC (60 ms, 2 kHz TG, 1 mV 100 Hz DM, maxstep 0.5 us, cmin 1e-17)  -> ece203_r8e_tran
;; Env: AC_R8E_CASE = g0 | c2 | c35 ; AC_R8E_STEP = b1 | b2 (PSS attempt) ; AC_R8_STEP = 30 | 60 | 90 | 120 (PNoise sidebands).

r8eDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_r8e")
r8eCases = list(nil
  'g0  list(nil 'cell "ece203_r8b_tb_noeoc_chp" 'cc 60e-12  'cfb 0.5e-12  'k 1.0 'readonly t)
  'c2  list(nil 'cell "ece203_r8e_tb_c2"        'cc 120e-12 'cfb 1.0e-12  'k 2.0 'readonly nil)
  'c35 list(nil 'cell "ece203_r8e_tb_c35"       'cc 210e-12 'cfb 1.75e-12 'k 3.5 'readonly nil))
procedure( r8eKey() or(getShellEnvVar("AC_R8E_CASE") "c2") )
procedure( r8eC(key) let( (p) p = get(r8eCases stringToSymbol(key)) unless( p error("unknown R8E case %s" key)) p ) )
procedure( r8eExtra(key) let( (p) p = r8eC(key) list(list("cc" p->cc) list("cfb" p->cfb)) ) )
procedure( r8eTmp(key) sprintf(nil "/tmp/lix015_r8e_%s" key) )
procedure( r8eCaseDir(key) sprintf(nil "%s/%s" r8eDir key) )
;; PSS attempts: b1 = R8B a1; b2 = the one registered setting-only retry (R8 a2: maxperiods 60, itres 1e-7)
r8ePssCfg = list(nil
  'b1 list(nil 'tstab "5m" 'maxperiods "40" 'errpreset "moderate" 'cmin "1e-17" 'itres "1e-4")
  'b2 list(nil 'tstab "5m" 'maxperiods "60" 'errpreset "moderate" 'cmin "1e-17" 'itres "1e-7"))
procedure( r8eStep() or(getShellEnvVar("AC_R8E_STEP") "b1") )
procedure( r8eCfg() let( (c) c = get(r8ePssCfg stringToSymbol(r8eStep())) unless( c error("PSS attempt %s not registered" r8eStep())) c ) )

;; ---------- build: the R8B spec list, unchanged ----------
procedure( r8eBuild()
  let( (key p)
    ece203LibInfo()
    key = r8eKey() p = r8eC(key)
    when( p->readonly error("case %s is the read-only R8B cell" key))
    foreach(x list(r8bCell "ece203_ss_pr_cell" r6bCells->tg r7aCmfbCell("a2") r6dCells->cd) unless( ddGetObj(ece203Lib x) error("missing %s" x)))
    when( ddGetObj(ece203Lib p->cell) error("%s already exists" p->cell))
    otaTb(p->cell r8bSpecs())
    acSay("r8e: built %s = r8bSpecs() (cc %g, cfb %g set per run)\n" p->cell p->cc p->cfb)
    t
  )
)

;; ---------- Stage A: static TG phase A, the R7F measurement (r7cStageB1 + r7eLp), 10 pF/side load is in the cell ----------
procedure( r8eStatic()
  let( (key p od oe res)
    ece203LibInfo()
    key = r8eKey() p = r8eC(key)
    putprop(r7cCases list(nil 'cell p->cell 'prw 4e-6 'extra r8eExtra(key)) stringToSymbol(key))
    putprop(r7eCases list(nil 'cell p->cell 'load t 'extra r8eExtra(key)) stringToSymbol(key))
    r8Mk(r8eDir)
    od = r7cDir oe = r7eDir r7cDir = r8eDir r7eDir = r8eDir
    res = errset(progn(r7cStageB1(key r6bSysOpts "") r7eLp(key)) t)
    r7cDir = od r7eDir = oe
    unless( res error("%L" errset.errset))
    t
  )
)

;; ---------- Stage B: PSS / PAC through r8cPeriodic, PSS file where the PNoise job (r8Periodic) reads it ----------
procedure( r8eOnC(key fn @rest args)
  let( (od ot ow oc os ox res)
    od = r8cDir ot = r8cTmp ow = r8cWd oc = r8cCurSave os = r8cPacStop ox = r8VarsExtra
    r8cDir = r8eCaseDir(key) r8cTmp = r8eTmp(key) r8cWd = "r8e_watchdog.sh" r8cCurSave = list("/VSP/PLUS") r8cPacStop = "1000" r8VarsExtra = r8eExtra(key)
    res = errset(apply(fn args) t)
    r8cDir = od r8cTmp = ot r8cWd = ow r8cCurSave = oc r8cPacStop = os r8VarsExtra = ox
    unless( res error("%L" errset.errset))
    t
  )
)
procedure( r8ePss()
  let( (key)
    key = r8eKey()
    r8eOnC(key 'r8cPeriodic r8eC(key)->cell sprintf(nil "B_pss_%s_%s" r8eStep() key) 'pss r8eCfg() strcat(r8eTmp(key) "/pss_converged.pss") "1" t)
  )
)
procedure( r8ePac()
  let( (key)
    key = r8eKey()
    r8eOnC(key 'r8cPeriodic r8eC(key)->cell sprintf(nil "B_pac_%s" key) 'pac r8eCfg() strcat(r8eTmp(key) "/pss_converged.pss") "1" t)
  )
)

;; ---------- Stage C: PNoise, R8B Stage D definition (r8Periodic 'pn, readpss of the same PSS file) ----------
;; r8Periodic reads the PSS settings from r8PssCfg via env AC_R8_PSS (default a1 = b1 here); b2 maps to R8 a2 (identical values).
procedure( r8ePn()
  let( (key oc od ot ow ox oi res)
    key = r8eKey()
    oc = r8Cell od = r8Dir ot = r8Tmp ow = r8Wd ox = r8VarsExtra oi = r8SaveI
    r8Cell = r8eC(key)->cell r8Dir = r8eCaseDir(key) r8Tmp = r8eTmp(key) r8Wd = "r8e_watchdog.sh" r8VarsExtra = r8eExtra(key) r8SaveI = list("/VSP/PLUS")
    res = errset(r8Pn() t)
    r8Cell = oc r8Dir = od r8Tmp = ot r8Wd = ow r8VarsExtra = ox r8SaveI = oi
    unless( res error("%L" errset.errset))
    t
  )
)

;; ---------- Stage D: the R7F 60 ms transient (r7eStageC) on one case ----------
procedure( r8eTran()
  let( (key p od ot ow res)
    ece203LibInfo()
    key = r8eKey() p = r8eC(key)
    putprop(r7eCases list(nil 'cell p->cell 'load t 'extra r8eExtra(key)) stringToSymbol(key))
    unless( getShellEnvVar("AC_R7E_CASE") == key error("set AC_R7E_CASE=%s (r7eStageC reads it), got %L" key getShellEnvVar("AC_R7E_CASE")))
    od = r7eDir ot = r7eTmp ow = r7eWd
    r7eDir = r8eCaseDir(key) r7eTmp = "/tmp/lix015_r8e_tran" r7eWd = "r8e_tran_watchdog.sh"
    r8Mk(r7eDir)
    res = errset(r7eStageC() t)
    r7eDir = od r7eTmp = ot r7eWd = ow
    unless( res error("%L" errset.errset))
    t
  )
)
