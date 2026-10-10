;; hw1_p1a.il -- ECE 203 HW1 Problem 1a: nfetx, W/L = 5/1 um, Ids vs VGS at VDS = 1.8 V
;;
;;        vd ---+------- VDS (= design variable vds, 1.8 V)
;;              |
;;   vg --+--  M0 nfetx 5u/1u
;;        |     |
;;       VGS   gnd          bulk / extra terminals -> gnd
;;   (= vgs, swept)
;;
;; Batch (SSH):   ~/AutoCircuit/run.sh p1a
;; In the CIW:    acGo("p1a")       everything: pull, build, simulate, export, plot, ADE L state
;;                p1aRun()          build + simulate + export (same as batch)
;;                p1aPlot()         plot the saved results again, no re-simulation
;;                p1aAde()          open ADE L on the cell, fill it in, save state "p1a_auto"
;;
;; Outputs:
;;   schematic   HW1_203 / p1_nfetx / schematic
;;   raw results ~/simulation/p1_nfetx/spectre/schematic/psf   (the folder ADE L uses)
;;   table       ~/AutoCircuit_results/p1a.csv    VGS, Ids, log10(Ids), local S (mV/dec)
;;   summary     ~/AutoCircuit_results/p1a.txt

p1aCfg = list(nil
  'lib    "HW1_203"
  'cell   "p1_nfetx"
  'devLib "cmrf7sf"
  'dev    "nfetx"
  'w      "5u"
  'l      "1u"
  'vds    1.8
  'vgsStart 0.0
  'vgsStop  1.8
  'vgsStep  0.005
)

;; ---------- schematic ----------
procedure( p1aBuild(@optional (cfg p1aCfg))
  let( (lib cell cv m0 tD tG tS pG pD pS n d vgs vds others k usedW usedL)
    lib  = cfg->lib
    cell = cfg->cell
    cv = acOpenSch(lib cell)

    m0 = acPlace(cv cfg->devLib cfg->dev "M0" "R0" "G" list(0.0 0.0))
    usedW = acSetFirstParam(m0 '("w" "W" "wr" "width" "Width") cfg->w)
    usedL = acSetFirstParam(m0 '("l" "L" "lr" "length" "Length") cfg->l)
    ;; the PDK callback that keeps "wt" (total width) in step fails outside the form;
    ;; with one finger the total width equals the finger width
    acSetParam(m0 "wt" cfg->w t)
    printf("M0 size: width param %L = %s, length param %L = %s\n" usedW cfg->w usedL cfg->l)

    tD = acTerm(m0 '("D" "drain"))
    tG = acTerm(m0 '("G" "gate"))
    tS = acTerm(m0 '("S" "source"))
    unless( tD && tG && tS
      error("%s/%s: could not find D/G/S terminals, has %L\n"
            cfg->devLib cfg->dev m0~>master~>terminals~>name) )
    pG = acPinPt(m0 tG)
    pD = acPinPt(m0 tD)
    pS = acPinPt(m0 tS)

    ;; gate drive: node to the left, VGS below it
    n = acLeft(pG 1.0)
    acWire(cv pG n "vg")
    vgs = acPlace(cv "analogLib" "vdc" "VGS" "R0" "PLUS" acDown(n 0.5))
    acSetParam(vgs "vdc" "vgs")
    acWire(cv n acPinPt(vgs "PLUS"))
    acGnd(cv "GND1" acPinPt(vgs "MINUS"))

    ;; drain supply: node above the drain, VDS to the right
    d = acUp(pD 0.5)
    acWire(cv pD d "vd")
    vds = acPlace(cv "analogLib" "vdc" "VDS" "R0" "PLUS" acRight(d 1.5))
    acSetParam(vds "vdc" "vds")
    acWire(cv d acPinPt(vds "PLUS"))
    acGnd(cv "GND2" acPinPt(vds "MINUS"))

    ;; source to ground
    acGnd(cv "GND3" pS)

    ;; any other terminal (bulk, substrate ...) to ground
    others = setof(tn m0~>master~>terminals~>name !member(tn list(tD tG tS)))
    k = 0
    foreach(tn others
      k++
      acGnd(cv sprintf(nil "GNDB%d" k) acPinPt(m0 tn))
      printf("INFO: M0 terminal %s tied to gnd\n" tn))

    ;; PDK substrate net
    acSubTie(cv acRight(acPinPt(vds "PLUS") 1.5))

    acFinish(cv lib cell)
    m0
  )
)

;; ---------- simulation ----------
procedure( p1aSim(@optional (cfg p1aCfg))
  acSimSetup(cfg->lib cfg->cell)
  desVar("vds" cfg->vds)
  desVar("vgs" 0)
  save('i "/VDS/PLUS")
  analysis('dc ?param "vgs"
               ?start sprintf(nil "%g" cfg->vgsStart)
               ?stop  sprintf(nil "%g" cfg->vgsStop)
               ?step  sprintf(nil "%g" cfg->vgsStep))
  run()
)

;; Ids waveform from the current results (current into VDS + terminal, sign flipped)
procedure( p1aIds()
  let( (w)
    w = car(errset(i("/VDS/PLUS" ?result "dc") nil))
    when( w abs(w) )
  )
)

;; ---------- export ----------
;; local inverse slope S = dVGS / dlog10(Ids) at point k (central difference), mV/decade
procedure( p1aLocalS(arr n k)
  let( (a b la lb)
    a = arr[max(k - 1 0)]
    b = arr[min(k + 1 n - 1)]
    la = acLog10(cadr(a))
    lb = acLog10(cadr(b))
    when( la && lb && lb != la
      1000.0 * (car(b) - car(a)) / (lb - la) )
  )
)

procedure( p1aExport(@optional (cfg p1aCfg))
  let( (pts n arr dir csv txt port vgsK id m0 cv)
    pts = acWavePoints(p1aIds())
    unless( pts error("No DC results for /VDS/PLUS -- did the simulation run?\n") )
    n = length(pts)
    arr = makeVector(n)
    for(k 0 n - 1 arr[k] = nth(k pts))

    dir = acResultsDir()
    csv = strcat(dir "/p1a.csv")
    port = outfile(csv "w")
    fprintf(port "VGS_V,Ids_A,log10_Ids,S_mV_per_dec\n")
    for(k 0 n - 1
      vgsK = car(arr[k])
      id   = cadr(arr[k])
      fprintf(port "%g,%g,%s,%s\n" vgsK id acNum(acLog10(id) "%g") acNum(p1aLocalS(arr n k) "%g")))
    close(port)

    txt = strcat(dir "/p1a.txt")
    port = outfile(txt "w")
    fprintf(port "ECE 203 HW1 P1a -- %s %s/%s, VDS = %g V, VGS %g..%g V step %g V\n"
            cfg->dev cfg->w cfg->l cfg->vds cfg->vgsStart cfg->vgsStop cfg->vgsStep)
    fprintf(port "schematic %s/%s/schematic   results %s/psf\n\n" cfg->lib cfg->cell acSimDir(cfg->cell))

    ;; confirm the device size really is what we asked for
    cv = dbOpenCellViewByType(cfg->lib cfg->cell "schematic")
    m0 = and(cv car(setof(x cv~>instances x~>name == "M0")))
    when( m0
      fprintf(port "M0 size parameters as stored in the schematic:\n")
      acReportParams(m0 port)
      fprintf(port "\n"))

    fprintf(port "%8s %12s %10s %12s\n" "VGS(V)" "Ids(A)" "log10Ids" "S(mV/dec)")
    for(k 0 n - 1
      vgsK = car(arr[k])
      ;; one row every 50 mV
      when( abs(vgsK / 0.05 - round(vgsK / 0.05)) < 1e-6
        fprintf(port "%8.3f %12.4e %10s %12s\n" vgsK cadr(arr[k])
                acNum(acLog10(cadr(arr[k])) "%.3f") acNum(p1aLocalS(arr n k) "%.1f"))))
    fprintf(port "\nFull table (%d points): %s\n" n csv)
    close(port)
    printf("Wrote %s and %s\n" csv txt)
    t
  )
)

;; ---------- entry points ----------
procedure( p1aRun(@optional (cfg p1aCfg))
  p1aBuild(cfg)
  p1aSim(cfg)
  p1aExport(cfg)
  when( hiGraphicMode() p1aPlot(cfg) )
  t
)

;; plot the stored results (works after a batch run, no re-simulation)
procedure( p1aPlot(@optional (cfg p1aCfg))
  let( (ids)
    openResults(strcat(acSimDir(cfg->cell) "/psf"))
    selectResult('dc)
    ids = p1aIds()
    if( ids then
      newWindow()
      plot(log10(ids) ?expr list("log10(Ids)  [A]"))
      newWindow()
      plot(ids ?expr list("Ids  [A]"))
    else
      warn("No stored DC results for %s -- run p1aRun() or run.sh p1a first\n" cfg->cell)
    )
  )
)

;; open ADE L on the cell, fill in models / variables / DC sweep, save as state "p1a_auto"
procedure( p1aAde(@optional (cfg p1aCfg))
  let( (sess)
    sess = acAdeStart(cfg->lib cfg->cell)
    unless( sess error("Could not get an ADE L session\n") )
    acAdeModels(sess "tt")
    acAdeVars(sess list(list("vgs" "0") list("vds" sprintf(nil "%g" cfg->vds))))
    ;; DC sweep of design variable vgs (field names from this installation's dc form)
    acAdeAnalysis(sess 'dc
      list(list('saveOppoint t)
           list('designVar "vgs")
           list('start sprintf(nil "%g" cfg->vgsStart))
           list('stop  sprintf(nil "%g" cfg->vgsStop))
           list('step  sprintf(nil "%g" cfg->vgsStep)))
      list(list('sweep "design")
           list('rangeType "start")
           list('incrType "linear")
           list('stepTypeLin "step")))
    acAdeSaveCurrents(sess)
    acAdeOutput(acAdeSev "Ids" "abs(getData(\"/VDS/PLUS\" ?result \"dc\"))")
    acAdeOutput(acAdeSev "log10_Ids" "log10(abs(getData(\"/VDS/PLUS\" ?result \"dc\")))")
    acAdeProbe(sess 'dc)
    acAdeSave(sess cfg->lib cfg->cell "p1a_auto")
    sess
  )
)
