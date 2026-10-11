;; wsub.il -- at fixed Ids, does gm change with W? (expectation: not in weak inversion)
;;
;; Weak inversion: Id ~ W * exp(VGS / n phi_t)  ->  gm = Id / (n phi_t), independent of W.
;; Shrink W far enough at the same Id and VGS must rise into moderate / strong inversion,
;; where gm/Id falls -- so gm drops.
;;
;; Circuit: the P1a nfetx test bench (drain at VDS, gate at VGS, source and bulk to ground)
;; in its own cell, W = design variable wn. For every W the gate is swept finely; then for
;; every target current the VGS and gm at exactly that current are interpolated from the
;; sweep -- i.e. the bias is re-adjusted per W so that Ids stays locked.
;;
;; Batch (SSH):  ~/AutoCircuit/run.sh wsub
;; Outputs in ~/AutoCircuit_results/:
;;   wsub.csv   W_um, Id_target_A, VGS_V, gm_S, gm_over_Id, n_estimate
;;   wsub.txt   gm vs W for every target current

wsubCfg = list(nil
  'lib "SelfPractice"  'cell "wsweep_sub"
  'devLib "cmrf7sf"  'dev "nfetx"
  'w "wn"  'l "1u"
  'vds 1.8
  'vgsStart -0.2  'vgsStop 1.8  'vgsStep 0.002
  'widths  '(0.5 1 2 5 10 20 50 100)        ; um
  'targets '(1e-8 1e-7 1e-6 1e-5)           ; A
)

;; one DC sweep at width wu (um); returns list(vgVector idVector n)
procedure( wsubSweep(cfg wu)
  let( (pts n vg id)
    acSimSetup(cfg->lib cfg->cell)
    desVar("vds" cfg->vds)
    desVar("vgs" 0)
    desVar("wn" wu * 1e-6)
    save('i "/VDS/PLUS")
    analysis('dc ?param "vgs"
                 ?start sprintf(nil "%g" cfg->vgsStart)
                 ?stop  sprintf(nil "%g" cfg->vgsStop)
                 ?step  sprintf(nil "%g" cfg->vgsStep))
    run()
    pts = acWavePoints(p1aIds())
    n = length(pts)
    vg = makeVector(n)  id = makeVector(n)
    for(k 0 n - 1  vg[k] = car(nth(k pts))  id[k] = cadr(nth(k pts)))
    list(vg id n)
  )
)

;; gm at point k by central difference
procedure( wsubGm(vg id n k)
  let( (a b)
    a = max(k - 1 0)  b = min(k + 1 n - 1)
    (id[b] - id[a]) / (vg[b] - vg[a])
  )
)

procedure( wsubRun(@optional (cfg wsubCfg))
  let( (sw vg id n rows best g dir csv txt port k f v gm nEst phit)
    phit = 0.02585
    p1aBuild(cfg)
    foreach(wu cfg->widths
      sw = wsubSweep(cfg wu)
      vg = car(sw)  id = cadr(sw)  n = caddr(sw)
      unless( n > 2 error("No DC results at W = %g um\n" wu) )
      ;; plateau of gm/Id at this width -> n
      best = 0.0
      for(i 1 n - 2
        when( id[i] > 0
          g = wsubGm(vg id n i) / id[i]
          when( g > best best = g )))
      nEst = if( best > 0 then 1.0 / (best * phit) else nil )
      foreach(it cfg->targets
        ;; first crossing of the target on the rising part of the curve (log interpolation)
        k = nil
        for(i 0 n - 2
          when( !k && id[i] > 0 && id[i] < it && id[i + 1] >= it  k = i ))
        if( k then
          f  = (log(it) - log(id[k])) / (log(id[k + 1]) - log(id[k]))
          v  = vg[k] + f * (vg[k + 1] - vg[k])
          gm = wsubGm(vg id n k) + f * (wsubGm(vg id n k + 1) - wsubGm(vg id n k))
          rows = cons(list(wu it v gm gm / it nEst) rows)
        else
          acSay("wsub: W = %g um never reaches %g A in the sweep\n" wu it)
        ))
      acSay("wsub: W = %g um done (n = %s)\n" wu acNum(nEst "%.3f"))
    )
    rows = reverse(rows)

    dir = acResultsDir()
    csv = strcat(dir "/wsub.csv")
    port = outfile(csv "w")
    fprintf(port "W_um,Id_target_A,VGS_V,gm_S,gm_over_Id_per_V,n_estimate\n")
    foreach(r rows
      fprintf(port "%g,%g,%g,%g,%g,%s\n" nth(0 r) nth(1 r) nth(2 r) nth(3 r) nth(4 r) acNum(nth(5 r) "%g")))
    close(port)

    txt = strcat(dir "/wsub.txt")
    port = outfile(txt "w")
    fprintf(port "gm at locked Ids vs W  (%s, L = %s, VDS = %g V, %s/%s)\n" cfg->dev cfg->l cfg->vds cfg->lib cfg->cell)
    foreach(it cfg->targets
      fprintf(port "\nIds = %g A   (weak-inversion limit Id/(n phi_t) uses n of each width)\n" it)
      fprintf(port "%8s %9s %12s %10s %14s\n" "W(um)" "VGS(V)" "gm(S)" "gm/Id" "gm/(Id/nphit)")
      foreach(r setof(x rows nth(1 x) == it)
        fprintf(port "%8g %9.3f %12.4e %10.2f %14s\n" nth(0 r) nth(2 r) nth(3 r) nth(4 r)
                if( numberp(nth(5 r)) acNum(nth(4 r) * nth(5 r) * phit "%.3f") "n/a"))))
    close(port)
    acSay("wsub: wrote %s\n" txt)
    t
  )
)
