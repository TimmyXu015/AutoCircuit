;; gmid.il -- gm/Id of an NMOS vs VGS (does gm/Id peak below threshold?)
;;
;; Same test circuit as HW1 P1a (nfetx, drain at VDS, gate at VGS, source and bulk
;; grounded), built in its own cell so the homework cell is left alone.
;; gm is taken as dIds/dVGS of the DC sweep (central difference), so
;; gm/Id = d(ln Ids)/dVGS -- straight from the definition, no PDK operating-point names.
;;
;; Batch (SSH):  ~/AutoCircuit/run.sh gmid
;; Outputs in ~/AutoCircuit_results/:
;;   gmid.csv   VGS, Ids, gm, gm/Id for every point
;;   gmid.txt   summary table every 50 mV and the peak of gm/Id

gmidCfg = list(nil
  'lib "SelfPractice"  'cell "gmid_nfet"
  'devLib "cmrf7sf"  'dev "nfetx"
  'w "5u"  'l "1u"
  'vds 1.8
  'vgsStart 0.0  'vgsStop 1.8  'vgsStep 0.005
)

procedure( gmidRun(@optional (cfg gmidCfg))
  let( (pts n vg id gm gmid dir csv txt port best bestK)
    p1aBuild(cfg)                     ; draws the nfetx test circuit into cfg->cell
    p1aSim(cfg)                       ; DC sweep of vgs at vds
    pts = acWavePoints(p1aIds())
    unless( pts error("No DC results for /VDS/PLUS -- did the simulation run?\n") )
    n  = length(pts)
    vg = makeVector(n)  id = makeVector(n)  gm = makeVector(n)  gmid = makeVector(n)
    for(k 0 n - 1
      vg[k] = car(nth(k pts))
      id[k] = cadr(nth(k pts)))
    ;; central difference (one-sided at the ends)
    for(k 0 n - 1
      let( (a b)
        a = max(k - 1 0)
        b = min(k + 1 n - 1)
        gm[k] = (id[b] - id[a]) / (vg[b] - vg[a])
        gmid[k] = if( id[k] > 0 then gm[k] / id[k] else nil )))

    best = 0.0  bestK = 0
    for(k 0 n - 1
      when( numberp(gmid[k]) && gmid[k] > best  best = gmid[k]  bestK = k ))

    dir = acResultsDir()
    csv = strcat(dir "/gmid.csv")
    port = outfile(csv "w")
    fprintf(port "VGS_V,Ids_A,gm_S,gm_over_Id_per_V\n")
    for(k 0 n - 1
      fprintf(port "%g,%g,%g,%s\n" vg[k] id[k] gm[k] acNum(gmid[k] "%g")))
    close(port)

    txt = strcat(dir "/gmid.txt")
    port = outfile(txt "w")
    fprintf(port "gm/Id of %s %s/%s at VDS = %g V  (%s/%s)\n\n" cfg->dev cfg->w cfg->l cfg->vds cfg->lib cfg->cell)
    fprintf(port "%8s %12s %12s %12s\n" "VGS(V)" "Ids(A)" "gm(S)" "gm/Id(1/V)")
    for(k 0 n - 1
      when( abs(vg[k] / 0.05 - round(vg[k] / 0.05)) < 1e-6
        fprintf(port "%8.3f %12.4e %12.4e %12s\n" vg[k] id[k] gm[k] acNum(gmid[k] "%.2f"))))
    fprintf(port "\nPeak gm/Id = %.2f 1/V at VGS = %.3f V (Ids = %.3e A)\n" best vg[bestK] id[bestK])
    fprintf(port "Full table (%d points): %s\n" n csv)
    close(port)
    acSay("gmid: wrote %s\n" txt)
    t
  )
)
