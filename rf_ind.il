;; rf_ind.il -- planar inductor model at high frequency (ECE 203 HW1 optional P5b)
;;
;;                 +---------- Cs ----------+
;;                 |                        |
;;   IIN --> p1 ---+---- L ---- Rs ---------+--- p2 --- gnd   (port 2 grounded)
;;           |                              |
;;        Cp || Rp                       Rp || Cp   (shorted by the grounded port 2)
;;           |                              |
;;          gnd                            gnd
;;
;;   L = 9 nH, Rs = 1 ohm, Cs = 50 fF, Cp = 0.2 pF, Rp = 5000 ohm
;;
;; Cell SelfPractice/planar_ind, driven by a 1 A AC current source into p1 so V(p1) = Zin.
;;
;; Batch (SSH):  ~/AutoCircuit/run.sh indb
;; Outputs in ~/AutoCircuit_results/:
;;   indb_hw.csv    0.5 .. 6 GHz, log, 50 points/decade (the homework sweep)
;;   indb_wide.csv  10 MHz .. 30 GHz, log, 40 points/decade (the bigger picture)
;;   indb.txt       summary; columns f, R, X, |Z|, phase, Q = |X|/R

indbCfg = list(nil
  'lib "SelfPractice"  'cell "planar_ind"
  'l "9n"  'rs "1"  'cs "50f"  'cp "0.2p"  'rp "5k"
)

;; Cp || Rp from node `p` to ground, Cp straight below, Rp offset sideways by dx
procedure( indbShunt(cv p dx suffix cfg)
  let( (j cp rp)
    j = acDown(p 0.35)
    acWire(cv p j)
    cp = acPlace(cv "analogLib" "cap" strcat("CP" suffix) "R0" "PLUS" acDown(p 0.75))
    acSetParam(cp "c" cfg->cp)
    acWire(cv j acPinPt(cp "PLUS"))
    acGnd(cv strcat("GNDC" suffix) acPinPt(cp "MINUS"))
    rp = acPlace(cv "analogLib" "res" strcat("RP" suffix) "R0" "PLUS" acRight(acDown(p 0.75) dx))
    acSetParam(rp "r" cfg->rp)
    acWire(cv j acPinPt(rp "PLUS"))
    acGnd(cv strcat("GNDR" suffix) acPinPt(rp "MINUS"))
  )
)

procedure( indbBuild(@optional (cfg indbCfg))
  let( (cv p1 p2 src l0 rs cs top1 top2 g)
    cv = acOpenSch(cfg->lib cfg->cell)
    p1 = list(0.0 0.0)

    ;; 1 A AC current source into p1 (analogLib drives PLUS -> MINUS through the source)
    src = acPlace(cv "analogLib" "idc" "IIN" "R180" "MINUS" acLeft(p1 2.0))
    acSetParam(src "idc" "0")
    acSetParam(src "acm" "1")
    acWire(cv acPinPt(src "MINUS") p1 "p1")
    acGnd(cv "GNDS" acPinPt(src "PLUS"))

    ;; series branch: L then Rs, horizontal
    l0 = acPlace(cv "analogLib" "ind" "L0" "R90" "PLUS" acRight(p1 1.0))
    acSetParam(l0 "l" cfg->l)
    acWire(cv p1 acPinPt(l0 "PLUS"))
    rs = acPlace(cv "analogLib" "res" "RS" "R90" "PLUS" acRight(acPinPt(l0 "MINUS") 0.5))
    acSetParam(rs "r" cfg->rs)
    acWire(cv acPinPt(l0 "MINUS") acPinPt(rs "PLUS"))
    p2 = acRight(acPinPt(rs "MINUS") 1.0)
    acWire(cv acPinPt(rs "MINUS") p2 "p2")

    ;; Cs across L + Rs, on top
    top1 = acUp(p1 1.0)
    top2 = acUp(p2 1.0)
    acWire(cv p1 top1)
    acWire(cv p2 top2)
    cs = acPlace(cv "analogLib" "cap" "CS" "R90" "PLUS"
                 list((xCoord(top1) + xCoord(top2)) / 2.0 - 0.25 yCoord(top1)))
    acSetParam(cs "c" cfg->cs)
    acWire(cv top1 acPinPt(cs "PLUS"))
    acWire(cv acPinPt(cs "MINUS") top2)

    ;; shunt Cp || Rp at both ports
    indbShunt(cv p1 -0.75 "1" cfg)
    indbShunt(cv p2 0.75 "2" cfg)

    ;; port 2 grounded
    g = acRight(p2 1.75)
    acWire(cv p2 g)
    acGnd(cv "GNDP2" g)

    acFinish(cv cfg->lib cfg->cell)
  )
)

procedure( indbRun(@optional (cfg indbCfg))
  let( (dir zw zh rowsW rowsH txt port k)
    indbBuild(cfg)
    dir = acResultsDir()
    ;; wide sweep first, homework sweep last (its results stay in psf for ADE / plotting)
    zw = acZinAc(cfg->lib cfg->cell "/p1" "10M" "30G" ?dec "40")
    rowsW = when( zw acWriteZ(zw strcat(dir "/indb_wide.csv")) )
    zh = acZinAc(cfg->lib cfg->cell "/p1" "500M" "6G" ?dec "50")
    rowsH = when( zh acWriteZ(zh strcat(dir "/indb_hw.csv")) )
    unless( zh error("No AC results for /p1 -- did the simulation run?\n") )

    txt = strcat(dir "/indb.txt")
    port = outfile(txt "w")
    fprintf(port "Planar inductor, port 2 grounded: L = %s, Rs = %s, Cs = %s, Cp = %s, Rp = %s  (%s/%s)\n\n"
            cfg->l cfg->rs cfg->cs cfg->cp cfg->rp cfg->lib cfg->cell)
    fprintf(port "Homework sweep 0.5 .. 6 GHz, log (every 2nd of %d points):\n" length(rowsH))
    acZHeader(port)
    k = 0
    foreach(row rowsH
      when( zerop(mod(k 2)) acZRow(port row) )
      k++)
    fprintf(port "\nWide view 10 MHz .. 30 GHz (every 4th of %d points):\n" length(rowsW))
    acZHeader(port)
    k = 0
    foreach(row rowsW
      when( zerop(mod(k 4)) acZRow(port row) )
      k++)
    fprintf(port "\nFiles: %s/indb_hw.csv, indb_wide.csv\n" dir)
    close(port)
    acSay("indb: wrote %s\n" txt)
    t
  )
)
