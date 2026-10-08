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
    resultsDir(strcat(getShellEnvVar("HOME") "/simulation/" cell "/spectre/schematic"))
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
