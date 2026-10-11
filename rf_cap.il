;; rf_cap.il -- "real" capacitor at high frequency (ECE 203 HW1 optional P5c)
;;
;;   in o----+
;;           C   0.4 uF
;;           Rs  0.1 ohm
;;           Ls  0.1 nH
;;          gnd
;;
;; Two cells in SelfPractice:
;;   real_cap     driven by a 1 A AC current source into "in", so V(in) = Zin directly
;;   real_cap_sp  the same capacitor behind a 50 ohm port, for S-parameters / Smith chart
;;
;; Batch (SSH):  ~/AutoCircuit/run.sh capc
;; In the CIW:   capcRun()      same as batch
;;
;; Outputs in ~/AutoCircuit_results/:
;;   capc_lin.csv   1 MHz .. 300 MHz, 5 MHz steps (the homework sweep)
;;   capc_log.csv   100 kHz .. 3 GHz, 20 points/decade (the bigger picture)
;;   capc.txt       summary; columns f, R, X, |Z|, phase, Q = |X|/R
;; In ADE / Results Browser: real_cap_sp sp results -> Smith chart of S11 or Z11.

capcCfg = list(nil
  'lib "SelfPractice"
  'cell "real_cap"
  'cellSp "real_cap_sp"
  'c "0.4u"  'rs "0.1"  'ls "0.1n"
)

;; ---------- schematics ----------
;; draws C, Rs, Ls in series from node `top` down to ground; returns nothing useful
procedure( capcDut(cv top cfg)
  let( (c0 rs ls p)
    c0 = acPlace(cv "analogLib" "cap" "C0" "R0" "PLUS" acDown(top 0.5))
    acSetParam(c0 "c" cfg->c)
    acWire(cv top acPinPt(c0 "PLUS"))
    p = acPinPt(c0 "MINUS")
    rs = acPlace(cv "analogLib" "res" "RS" "R0" "PLUS" acDown(p 0.5))
    acSetParam(rs "r" cfg->rs)
    acWire(cv p acPinPt(rs "PLUS"))
    p = acPinPt(rs "MINUS")
    ls = acPlace(cv "analogLib" "ind" "LS" "R0" "PLUS" acDown(p 0.5))
    acSetParam(ls "l" cfg->ls)
    acWire(cv p acPinPt(ls "PLUS"))
    acGnd(cv "GND0" acPinPt(ls "MINUS"))
  )
)

;; AC testbench: 1 A current source pushing into "in"
procedure( capcBuild(@optional (cfg capcCfg))
  let( (cv top src)
    cv = acOpenSch(cfg->lib cfg->cell)
    top = list(0.0 0.0)
    ;; analogLib current sources drive current from PLUS through the source to MINUS,
    ;; so MINUS goes to "in" (flipped symbol) and PLUS to ground
    src = acPlace(cv "analogLib" "idc" "IIN" "R180" "MINUS" acLeft(top 1.5))
    acSetParam(src "idc" "0")
    acSetParam(src "acm" "1")
    acWire(cv acPinPt(src "MINUS") top "in")
    acGnd(cv "GNDS" acPinPt(src "PLUS"))
    capcDut(cv top cfg)
    acFinish(cv cfg->lib cfg->cell)
  )
)

;; S-parameter testbench: 50 ohm port 1 at "in"
procedure( capcBuildSp(@optional (cfg capcCfg))
  let( (cv top prt)
    cv = acOpenSch(cfg->lib cfg->cellSp)
    top = list(0.0 0.0)
    prt = acPlace(cv "analogLib" "port" "PORT1" "R0" "PLUS" acLeft(top 1.5))
    ;; analogLib port defaults: 50 ohm, port number 1
    acWire(cv acPinPt(prt "PLUS") top "in")
    acGnd(cv "GNDP" acPinPt(prt "MINUS"))
    capcDut(cv top cfg)
    acFinish(cv cfg->lib cfg->cellSp)
  )
)

;; ---------- simulation + export ----------
;; run one AC sweep on real_cap and return Zin as a complex waveform (sign checked)
procedure( capcAc(cfg start stop @key step dec)
  let( (z r0)
    acSimSetup(cfg->lib cfg->cell)
    if( dec
      then analysis('ac ?start start ?stop stop ?dec dec)
      else analysis('ac ?start start ?stop stop ?step step))
    run()
    z = car(errset(v("/in" ?result "ac") nil))
    ;; Re(Zin) must be positive (Rs > 0); a negative value means the source pushes the
    ;; other way, so flip the sign rather than report a negative resistance
    when( z
      r0 = car(errset(value(real(z) xmin(z)) nil))
      when( numberp(r0) && r0 < 0
        acSay("capc: source direction reversed in this analogLib, Zin sign flipped\n")
        z = z * -1))
    z
  )
)

;; write f, R, X, |Z|, phase(deg), Q for a Zin waveform; returns list of rows
procedure( capcWrite(z file)
  let( (fr fx fm fp rows port r x q)
    fr = acWavePoints(real(z))
    fx = acWavePoints(imag(z))
    fm = acWavePoints(mag(z))
    fp = acWavePoints(phase(z))
    port = outfile(file "w")
    fprintf(port "f_Hz,R_ohm,X_ohm,absZ_ohm,phase_deg,Q\n")
    for(k 0 length(fr) - 1
      r = cadr(nth(k fr))
      x = cadr(nth(k fx))
      q = if( r != 0 then abs(x) / r else nil )
      rows = cons(list(car(nth(k fr)) r x cadr(nth(k fm)) cadr(nth(k fp)) q) rows)
      fprintf(port "%g,%g,%g,%g,%g,%s\n" car(nth(k fr)) r x cadr(nth(k fm)) cadr(nth(k fp))
              acNum(q "%g")))
    close(port)
    reverse(rows)
  )
)

procedure( capcRow(port row)
  fprintf(port "%10.4g %11.4g %11.4g %11.4g %9.2f %10s\n"
          nth(0 row) nth(1 row) nth(2 row) nth(3 row) nth(4 row) acNum(nth(5 row) "%.4g"))
)

procedure( capcRun(@optional (cfg capcCfg))
  let( (dir zlog zlin rowsLog rowsLin txt port s11 zsp zchk k)
    capcBuild(cfg)
    capcBuildSp(cfg)
    dir = acResultsDir()

    ;; wide log sweep first, the homework sweep last (its results stay in psf)
    zlog = capcAc(cfg "100k" "3G" ?dec "20")
    rowsLog = when( zlog capcWrite(zlog strcat(dir "/capc_log.csv")) )
    zlin = capcAc(cfg "1M" "300M" ?step "5M")
    rowsLin = when( zlin capcWrite(zlin strcat(dir "/capc_lin.csv")) )
    unless( zlin error("No AC results for /in -- did the simulation run?\n") )

    ;; S-parameters on the port testbench, Zin = 50 (1 + S11) / (1 - S11) as a cross-check
    acSimSetup(cfg->lib cfg->cellSp)
    analysis('sp ?ports list("/PORT1") ?start "1M" ?stop "300M" ?step "5M")
    run()
    s11 = car(errset(sp(1 1 ?result "sp") nil))
    when( s11
      zsp = 50 * (1 + s11) / (1 - s11)
      zchk = car(errset(value(mag(zsp) 101e6) nil)))

    txt = strcat(dir "/capc.txt")
    port = outfile(txt "w")
    fprintf(port "Real capacitor: C = %s, Rs = %s, Ls = %s   (SelfPractice/%s, /%s)\n\n"
            cfg->c cfg->rs cfg->ls cfg->cell cfg->cellSp)
    fprintf(port "Homework sweep 1 MHz .. 300 MHz, 5 MHz steps (every point):\n")
    fprintf(port "%10s %11s %11s %11s %9s %10s\n" "f(Hz)" "R(ohm)" "X(ohm)" "|Z|(ohm)" "ph(deg)" "Q=|X|/R")
    foreach(row rowsLin capcRow(port row))
    fprintf(port "\nWide view 100 kHz .. 3 GHz (every 5th point of %d):\n" length(rowsLog))
    fprintf(port "%10s %11s %11s %11s %9s %10s\n" "f(Hz)" "R(ohm)" "X(ohm)" "|Z|(ohm)" "ph(deg)" "Q=|X|/R")
    k = 0
    foreach(row rowsLog
      when( zerop(mod(k 5)) capcRow(port row) )
      k++)
    fprintf(port "\nS-parameter cross-check at 101 MHz: |Zin| from S11 = %s ohm, from AC = %s ohm\n"
            acNum(zchk) acNum(car(errset(value(mag(zlin) 101e6) nil))))
    fprintf(port "Files: %s/capc_lin.csv, capc_log.csv\n" dir)
    close(port)
    acSay("capc: wrote %s\n" txt)
    t
  )
)
