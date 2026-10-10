;; lib_sim.il -- generic OCEAN simulation helpers (reads PDK details from acPdk).
;;
;; Pattern used by every circuit script:
;;   acSimSetup("SelfPractice" "cs_amp")        ; spectre, design, models, PDK variables
;;   desVar("vbias" 0.6)                        ; circuit variables
;;   analysis('tran ?stop "5u")                 ; analyses
;;   run()
;;   acNum( value(v("/vout" ?result "dcOp")) )  ; numbers, "n/a" if anything fails

;; start a spectre session on lib/cell/schematic with the PDK models
procedure( acSimSetup(lib cell @optional (corner "tt"))
  let( (mf)
    simulator('spectre)
    design(lib cell "schematic")
    resultsDir(acSimDir(cell))
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
