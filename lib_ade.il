;; lib_ade.il -- open and fill an ADE L session from SKILL, then save it as a state.
;; GUI only: ADE L states can only be saved from an interactive ADE window.
;;
;;   sess = acAdeStart("HW1_203" "p1_nfetx")           ; opens ADE L on the schematic
;;   acAdeModels(sess "tt")                            ; PDK model files
;;   acAdeVars(sess list(list("vgs" "0") list("vds" "1.8")))
;;   acAdeAnalysis(sess 'dc list(list('param "vgs") ...))
;;   acAdeSave(sess "HW1_203" "p1_nfetx" "p1a_auto")   ; Session -> Load State later
;;
;; Every step reports through acSay, so a run leaves a readable report file.
;; Function names come from the ADE SKILL reference / Cadence forum; the analysis
;; field names are not public, so acAdeProbe dumps what this installation really has.

;; start ADE L on lib/cell/schematic; returns the asi session (or nil)
procedure( acAdeStart(lib cell)
  let( (sev sess)
    unless( hiGraphicMode()
      error("ADE L needs the GUI -- run this in the remote desktop CIW, not over SSH\n") )
    sev = car(errset(sevStartSession(?lib lib ?cell cell ?view "schematic") t))
    acSay("ADE: sevStartSession -> %L\n" sev)
    acAdeSev = sev
    when( sev
      sess = car(errset(sevEnvironment(sev) nil)) )
    unless( sess
      sess = car(errset(asiGetSession(hiGetCurrentWindow()) nil)) )
    unless( sess
      sess = car(errset(asiGetCurrentSession() nil)) )
    acSay("ADE: session -> %L\n" sess)
    sess
  )
)

;; replace the model library list with the PDK model files
procedure( acAdeModels(sess @optional (corner "tt"))
  let( (ok)
    errset(asiRemoveAllModelLibSelection(sess) nil)
    foreach(m acPdk->modelFiles
      ok = errset(asiAddModelLibSelection(sess
                    strcat(acPdk->modelPath "/" car(m))
                    if( cadr(m) == "" then "" else corner )) t)
      acSay("ADE: model %s %s -> %s\n" car(m) cadr(m) if( ok "ok" "FAILED")))
    acSay("ADE: model list now %L\n" car(errset(asiGetModelLibSelectionList(sess) nil)))
  )
)

;; set design variables (values as strings); PDK variables are added automatically
procedure( acAdeVars(sess vars)
  let( (all ok)
    all = append(vars mapcar(lambda((d) list(car(d) sprintf(nil "%L" cadr(d)))) acPdk->desVars))
    ok = errset(asiSetDesignVarList(sess all) t)
    acSay("ADE: design variables %L -> %s\n" all if( ok "ok" "FAILED"))
  )
)

;; set fields of one analysis and enable it; fields = list(list('name value) ...)
procedure( acAdeAnalysis(sess anaType fields)
  let( (ana ok)
    ana = car(errset(asiGetAnalysis(sess anaType) t))
    acSay("ADE: analysis %L object -> %L\n" anaType ana)
    when( ana
      foreach(f fields
        ok = errset(asiSetAnalysisFieldVal(ana car(f) cadr(f)) nil)
        acSay("ADE:   field %L = %L  %s\n" car(f) cadr(f) if( ok "ok" "FAILED")))
      ok = or(car(errset(asiEnableAnalysis(sess anaType) nil))
              car(errset(asiSetAnalysisFieldVal(ana 'enable t) nil)))
      acSay("ADE:   enable -> %L\n" ok)
    )
    ana
  )
)

;; save the session as a cellview state (Session -> Load State -> Cellview)
procedure( acAdeSave(sess lib cell name)
  let( (ok)
    ok = errset(asiSaveState(sess ?name name ?option 'cellview ?lib lib ?cell cell) t)
    acSay("ADE: save state %s in %s/%s -> %L\n" name lib cell ok)
    unless( car(ok)
      acSay("ADE: automatic save failed -- in ADE L use Session -> Save State, name %s, Cellview\n" name))
    ok
  )
)

;; write what this installation offers: asi functions with their arguments, and the
;; fields of an analysis object -- this is how the next version gets the names right
procedure( acAdeProbe(sess @optional (anaType 'dc))
  let( (port file names ana keys)
    file = strcat(acResultsDir() "/ade_probe.txt")
    port = outfile(file "w")
    keys = '("Anal" "Output" "Expr" "State" "Temp" "Model" "DesignVar" "Session" "Plot")
    names = setof(f listFunctions("^asi")
                  exists(k keys index(get_pname(f) k)))
    fprintf(port "== asi functions (%d)\n" length(names))
    foreach(f sort(names 'alphalessp)
      fprintf(port "%s %L\n" f car(errset(arglist(f) nil))))
    ana = car(errset(asiGetAnalysis(sess anaType) nil))
    fprintf(port "\n== %L analysis object: %L\n" anaType ana)
    when( ana
      foreach(fn '(asiGetAnalysisFieldList asiGetAnalysisFieldNames asiGetAnalysisFields)
        when( isCallable(fn)
          fprintf(port "%s -> %L\n" fn car(errset(funcall(fn ana) nil)))))
      fprintf(port "properties -> %L\n" car(errset(ana->? nil))))
    fprintf(port "\n== sev functions\n")
    foreach(f sort(setof(f listFunctions("^sev") exists(k keys index(get_pname(f) k))) 'alphalessp)
      fprintf(port "%s %L\n" f car(errset(arglist(f) nil))))
    close(port)
    acSay("ADE: probe written to %s\n" file)
    file
  )
)
