;; ECE203 F2 final validation scout -- OCEAN read-back of the standalone Spectre runs (tools/f2v_run.sh).
;; f2vOcean(): openResults on /tmp/lix015_f2v/<AC_F2V_RUN or nom2>/psf (psfascii), then the ADE/OCEAN-native numbers the user will see:
;; noiseSummary('integrated) totals ("Total Summarized Noise" = output V^2, "Total Input Referred Noise" = referred to the noise
;; analysis' iprobe = V0) and the Calculator form sqrt(integ(out^2)) / sqrt(integ(in^2)) for 1 mHz..100 kHz and 0.1..250 Hz.
;; Writes ~/AutoCircuit_results/ece203_f2v/ocean_<run>.txt (+ the noiseSummary tables). Reads results only; no simulation.
procedure( f2vOcean()
  let( (run dir od port o i ok sumf)
    run = or(getShellEnvVar("AC_F2V_RUN") "nom2")
    dir = strcat("/tmp/lix015_f2v/" run "/psf")
    od = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_f2v")
    sh(strcat("mkdir -p " od))
    acSay("f2v: openResults %s -> %L\n" dir openResults(dir))
    acSay("f2v: results %L\n" results())
    port = outfile(strcat(od "/ocean_" run ".txt") "w")
    ;; OCEAN names the first noise analysis 'noise and the second "nz100-noise" (psfascii dir)
    foreach(nz results()
      when( nz == 'noise || nz == "nz100-noise"
        selectResult(nz)
        o = getData("out") i = getData("in")
        foreach(b '((0.001 100000.0 "1mHz_100kHz") (0.1 250.0 "0p1_250Hz"))
          ok = errset(
            fprintf(port "%L %s calculator: sqrt(integ(out^2)) = %.6g V ; sqrt(integ(in^2)) = %.6g V\n" nz caddr(b)
                    sqrt(integ(o * o car(b) cadr(b))) sqrt(integ(i * i car(b) cadr(b)))) t)
          unless( ok fprintf(port "%L %s calculator failed %L\n" nz caddr(b) errset.errset))
          sumf = sprintf(nil "%s/ocean_%s_%s_summary_%s.txt" od run if( symbolp(nz) "nz50" "nz100") caddr(b))
          ok = errset(let( (p2) p2 = outfile(sumf "w")
                        noiseSummary('integrated ?result nz ?from car(b) ?to cadr(b) ?output p2) close(p2)) t)
          fprintf(port "%L %s noiseSummary -> %L (%s)\n" nz caddr(b) ok sumf)
          sh(sprintf(nil "grep -E 'Total' %s | sed 's/^/    /' >> %s/ocean_%s.txt.tmp" sumf od run)))))
    close(port)
    sh(sprintf(nil "cat %s/ocean_%s.txt.tmp >> %s/ocean_%s.txt; rm -f %s/ocean_%s.txt.tmp; sed 's/^/AC> /' %s/ocean_%s.txt" od run od run od run od run))
    t
  )
)
