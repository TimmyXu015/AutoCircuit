;; lib_sim.il -- generic OCEAN simulation helpers (reads PDK details from acPdk).
;;
;; Pattern used by every circuit script:
;;   acSimSetup("SelfPractice" "cs_amp")        ; spectre, design, models, PDK variables
;;   desVar("vbias" 0.6)                        ; circuit variables
;;   analysis('tran ?stop "5u")                 ; analyses
;;   run()
;;   acNum( value(v("/vout" ?result "dcOp")) )  ; numbers, "n/a" if anything fails

;; start a spectre session on lib/cell/schematic with the PDK models
procedure( acSimSetup(lib cell @optional (corner "tt") (dirSuffix ""))
  let( (mf)
    simulator('spectre)
    design(lib cell "schematic")
    ;; dirSuffix keeps a run out of the folder ADE L uses for this cell (an open ADE
    ;; session reloads that folder and can swap the results under an OCEAN plot)
    resultsDir(strcat(acSimDir(cell) dirSuffix))
    path(acPdk->modelPath)
    mf = mapcar(lambda((m) if( cadr(m) == "" then m else list(car(m) corner) ))
                acPdk->modelFiles)
    apply('modelFile mf)
    foreach(d acPdk->desVars desVar(car(d) cadr(d)))
    temp(acPdk->temp)
    printf("Simulation set up: %s/%s, corner %s\n" lib cell corner)
    t
  )
)

;; format a number for printing, "n/a" for anything that is not a number
procedure( acNum(x @optional (fmt "%.4g"))
  if( numberp(x) then sprintf(nil fmt x) else "n/a" )
)

;; base-10 log that returns nil for non-positive input
procedure( acLog10(x)
  if( numberp(x) && x > 0 then log(x) / log(10.0) else nil )
)

;; ~/AutoCircuit_results, created if needed
procedure( acResultsDir()
  let( (dir)
    dir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results")
    unless( isDir(dir) createDir(dir) )
    dir
  )
)

;; waveform -> list of (x y) pairs
procedure( acWavePoints(w)
  let( (xv yv pts)
    when( w
      xv = drGetWaveformXVec(w)
      yv = drGetWaveformYVec(w)
      for(k 0 drVectorLength(xv) - 1
        pts = cons(list(drGetElem(xv k) drGetElem(yv k)) pts))
    )
    reverse(pts)
  )
)

;; results directory acSimSetup uses for a cell (psf lives inside it)
procedure( acSimDir(cell)
  strcat(getShellEnvVar("HOME") "/simulation/" cell "/spectre/schematic")
)

;; ---------- impedance measurements (passive one-ports) ----------
;; AC sweep of lib/cell; returns V(node) as a complex waveform. With a 1 A AC current
;; source driving the node this IS Zin. If Re(Zin) comes out negative at the first
;; frequency the source pushes the other way, so the sign is flipped.
procedure( acZinAc(lib cell node start stop @key step dec)
  let( (z r0)
    acSimSetup(lib cell)
    if( dec
      then analysis('ac ?start start ?stop stop ?dec dec)
      else analysis('ac ?start start ?stop stop ?step step))
    run()
    z = car(errset(v(node ?result "ac") nil))
    when( z
      r0 = car(errset(value(real(z) xmin(z)) nil))
      when( numberp(r0) && r0 < 0
        acSay("%s: source pushes the other way, Zin sign flipped\n" cell)
        z = z * -1))
    z
  )
)

;; write f, R, X, |Z|, phase(deg), Q = |X|/R of a Zin waveform to a CSV; returns the rows
procedure( acWriteZ(z file)
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

;; one table row of acWriteZ output; acZHeader prints the matching header
procedure( acZHeader(port)
  fprintf(port "%10s %11s %11s %11s %9s %10s\n" "f(Hz)" "R(ohm)" "X(ohm)" "|Z|(ohm)" "ph(deg)" "Q=|X|/R")
)
procedure( acZRow(port row)
  fprintf(port "%10.4g %11.4g %11.4g %11.4g %9.2f %10s\n"
          nth(0 row) nth(1 row) nth(2 row) nth(3 row) nth(4 row) acNum(nth(5 row) "%.4g"))
)
