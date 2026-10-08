;; cs_wsweep.il -- width sweep at constant drain current (HW1 Problem 2, parts c/d/e)
;;
;; For every width W:
;;   1. DC-sweep the design variable vbias and find the value where
;;      vout = 2 V - Id*100k  (i.e. Id = idTarget, 10 uA -> vout = 1 V).
;;      This is the "VBIAS automatically adjusted" from the problem statement.
;;   2. At that bias, run an AC analysis and read at 2 MHz:
;;        |vg/vin|    attenuation from the source to the gate      (part c)
;;        |vout/vg|   gain from the gate to the output             (part d)
;;        |vout/vin|  overall gain                                 (part e)
;;
;; Usage (in the CIW):
;;   csWSweep()                                        ; default widths 1.5 ... 96 um
;;   csWSweep(?widths '(2 4 8 16 32 64 128))
;;   csWSweep(?build nil)                              ; reuse the existing cs_amp_w schematic
;;
;; The schematic is built into its own cell (cs_amp_w) with W = design variable wn
;; and L = 1.5 um, so cs_amp is left untouched.
;; A table is printed in the CIW, written to ~/AutoCircuit_results/cs_wsweep.csv,
;; and plotted against W.
;;
;; Note: the simulator uses the real cmrf7sf models, not the simplified numbers
;; in the problem statement (Cox, n, Vt0 ...), so values will differ from a hand
;; calculation; compare trends.

procedure( csWSweep(@key (lib "SelfPractice") (cell "cs_amp_w")
                         (widths '(1.5 3 6 12 24 48 96))   ; um
                         (lUm 1.5) (idTarget 10e-6) (rd 100e3) (vdd 2.0)
                         (freq 2e6) (corner "tt") (build t) (plots t))
  let( (voutTarget rows w vbx vdcw atten gain agate dir csv port ok wave1 wave2 wave3 xs)
    voutTarget = vdd - idTarget * rd

    when( build
      csBuild(lib cell ?nW "wn" ?nL sprintf(nil "%gu" lUm)) )

    printf("\nW sweep: Id = %g A (vout = %g V), L = %g um, %d widths\n"
           idTarget voutTarget lUm length(widths))

    foreach(wu widths
      w = wu * 1e-6
      vbx   = nil
      vdcw  = nil
      atten = nil
      gain  = nil
      agate = nil

      ;; step 1: find the bias that sets the drain current
      acSimSetup(lib cell corner)
      desVar("wn" w)
      desVar("vbias" 0.5)
      analysis('dc ?param "vbias" ?start "0" ?stop "1.5" ?step "1m")
      run()
      vbx = car(errset(cross(v("/vout" ?result "dc") voutTarget 1 "falling") nil))

      ;; step 2: small-signal response at that bias
      when( numberp(vbx)
        acSimSetup(lib cell corner)
        desVar("wn" w)
        desVar("vbias" vbx)
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "1k" ?stop "10G" ?dec "20")
        run()
        vdcw  = car(errset(v("/vout" ?result "dcOp") nil))
        atten = car(errset(value(mag(v("/vg"   ?result "ac")) freq) nil))
        gain  = car(errset(value(mag(v("/vout" ?result "ac")) freq) nil))
        when( numberp(atten) && numberp(gain) && atten > 0
          agate = gain / atten )
      )
      unless( numberp(vbx)
        warn("W = %g um: vout never crossed %g V in the vbias sweep\n" wu voutTarget) )

      rows = cons(list(wu vbx vdcw atten agate gain) rows)
      printf("  done W = %g um\n" wu)
    )
    rows = reverse(rows)

    ;; ---- table ----
    printf("\n==================== cs_amp W sweep @ %g Hz ====================\n" freq)
    printf("%8s %10s %9s %10s %10s %11s\n" "W(um)" "VBIAS(V)" "Vout(V)" "|vg/vin|" "|vout/vg|" "|vout/vin|")
    foreach(r rows
      printf("%8s %10s %9s %10s %10s %11s\n"
             acNum(nth(0 r)) acNum(nth(1 r) "%.4f") acNum(nth(2 r) "%.4f")
             acNum(nth(3 r)) acNum(nth(4 r)) acNum(nth(5 r))))
    printf("================================================================\n")

    ;; ---- CSV ----
    dir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results")
    unless( isDir(dir) createDir(dir) )
    csv = strcat(dir "/cs_wsweep.csv")
    port = outfile(csv "w")
    when( port
      fprintf(port "W_um,VBIAS_V,Vout_V,atten_vg_over_vin,gain_vout_over_vg,gain_vout_over_vin\n")
      foreach(r rows
        fprintf(port "%s,%s,%s,%s,%s,%s\n"
                acNum(nth(0 r) "%g") acNum(nth(1 r) "%g") acNum(nth(2 r) "%g")
                acNum(nth(3 r) "%g") acNum(nth(4 r) "%g") acNum(nth(5 r) "%g")))
      close(port)
      printf("Saved %s\n" csv)
    )

    ;; ---- plot vs W ----
    ok = setof(r rows numberp(nth(5 r)) && numberp(nth(4 r)) && numberp(nth(3 r)))
    when( plots && ok
      errset(
        progn(
          xs    = drCreateVec('double mapcar('car ok))
          wave1 = drCreateWaveform(xs drCreateVec('double mapcar(lambda((r) nth(3 r)) ok)))
          wave2 = drCreateWaveform(xs drCreateVec('double mapcar(lambda((r) nth(4 r)) ok)))
          wave3 = drCreateWaveform(xs drCreateVec('double mapcar(lambda((r) nth(5 r)) ok)))
          newWindow()
          plot(wave1 ?expr list("|vg/vin| vs W(um)"))
          newWindow()
          plot(wave2 wave3 ?expr list("|vout/vg| vs W(um)" "|vout/vin| vs W(um)"))
        )
        t)
    )
    rows
  )
)
