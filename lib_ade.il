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

;; set fields of one analysis, read each back, and enable it LAST (ADE builds the
;; Arguments text in its window when the analysis is enabled).
;; choices = list(list('field "hint") ...) for choice-type fields, applied first
;; fields  = list(list('field value) ...)
procedure( acAdeAnalysis(sess anaType fields @optional (choices nil))
  let( (ana ok back names)
    ana = car(errset(asiGetAnalysis(sess anaType) t))
    acSay("ADE: analysis %L object -> %L\n" anaType ana)
    when( ana
      names = car(errset(asiGetAnalysisParamNameList(ana) nil))
      unless( names
        names = car(errset(mapcar(lambda((f) f->name) asiGetAnalysisFieldList(ana)) nil)) )
      acSay("ADE:   field names: %L\n" names)
      errset(asiDisableAnalysis(ana) nil)
      foreach(c choices acAdeChoice(ana car(c) cadr(c)))
      foreach(f fields
        ok = errset(asiSetAnalysisFieldVal(ana car(f) cadr(f)) nil)
        back = car(errset(asiGetAnalysisFieldVal(ana car(f)) nil))
        acSay("ADE:   field %L = %L  %s, reads back %L%s\n" car(f) cadr(f)
              if( ok "ok" "FAILED") back
              if( names && !memq(car(f) names) && !member(get_pname(car(f)) names)
                  "  (not in field list)" "")))
      ok = errset(asiEnableAnalysis(ana) t)
      acSay("ADE:   enable -> %L, enabled now %L\n" ok car(errset(asiIsAnalysisEnabled(ana) nil)))
    )
    ana
  )
)

;; set a choice-type field to the allowed choice that contains `hint` (case-insensitive)
procedure( acAdeChoice(ana field hint)
  let( (choices pick ok)
    choices = car(errset(asiGetAnalysisFieldChoices(ana field) nil))
    foreach(c choices
      when( !pick && stringp(c) && index(lowerCase(c) lowerCase(hint))
        pick = c))
    unless( pick pick = hint )
    ok = errset(asiSetAnalysisFieldVal(ana field pick) nil)
    acSay("ADE:   field %L choices %L -> %L %s, reads back %L\n" field choices pick
          if( ok "ok" "FAILED") car(errset(asiGetAnalysisFieldVal(ana field) nil)))
    ok
  )
)

;; add an output expression to the ADE L Outputs list (needs the sev session)
procedure( acAdeOutput(sev name expr)
  let( (ok)
    ok = errset(sevAddExpression(sev name expr ?plottingEnabled t) t)
    acSay("ADE: output %s = %s -> %L\n" name expr ok)
    ok
  )
)

;; ask spectre to save all terminal currents (so current outputs can be plotted).
;; The setter's name differs between versions, so try the candidates and report.
procedure( acAdeSaveCurrents(sess)
  let( (done)
    foreach(c '((asiSetKeepOptionVal currents "all")
                (asiSetEnvOptionVal  currents "all")
                (asiSetKeepOptionVal save "all"))
      unless( done
        when( isCallable(car(c))
          done = car(errset(funcall(car(c) sess cadr(c) caddr(c)) nil))
          acSay("ADE: %L(%L %L) -> %L\n" car(c) cadr(c) caddr(c) done))))
    unless( done
      acSay("ADE: could not switch on saving all currents -- in ADE L: Outputs -> Save All -> all terminal currents\n"))
    done
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
    keys = '("Anal" "Output" "Expr" "State" "Temp" "Model" "DesignVar" "Session" "Plot" "EnvOption" "Save" "Keep" "Option")
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
      fprintf(port "properties -> %L\n" car(errset(ana->? nil)))
      fprintf(port "param names -> %L\n" car(errset(asiGetAnalysisParamNameList(ana) nil)))
      foreach(fo car(errset(asiGetAnalysisFieldList(ana) nil))
        fprintf(port "  field %L = %L   prompt %L\n" car(errset(fo->name nil))
                car(errset(asiGetAnalysisFieldVal(ana fo->name) nil))
                car(errset(fo->prompt nil)))))
    fprintf(port "\n== sev functions\n")
    foreach(f sort(setof(f listFunctions("^sev") exists(k keys index(get_pname(f) k))) 'alphalessp)
      fprintf(port "%s %L\n" f car(errset(arglist(f) nil))))
    close(port)
    acSay("ADE: probe written to %s\n" file)
    file
  )
)

;; ---------- unattended GUI runs ----------
;; Modal dialogs (e.g. Cadence's "Next License" question) freeze a run on a virtual
;; display. A timer keeps firing inside the dialog's event loop and presses OK on the
;; dialogs we know about. acAutoOkStart() / acAutoOkStop().
acAutoOkDialogs = '(_icLicLicenseQuestionDBox)
unless( boundp('acAutoOkOn) acAutoOkOn = nil )

unless( boundp('acAutoOkTicks) acAutoOkTicks = 0 )

procedure( acAutoOkTick()
  let( (ok h)
    when( acAutoOkOn
      acAutoOkTicks = acAutoOkTicks + 1
      when( acAutoOkTicks == 1 || zerop(mod(acAutoOkTicks 15))
        acSay("auto-OK timer alive (tick %d)\n" acAutoOkTicks))
      foreach(d acAutoOkDialogs
        ;; the name may be the dialog itself or a variable holding its handle
        h = car(errset(symeval(d) nil))
        ok = or(car(errset(hiDBoxOK(d) acAutoOkTicks < 3))
                and(h car(errset(hiDBoxOK(h) acAutoOkTicks < 3))))
        when( ok acSay("auto-OK: pressed OK on dialog %L\n" d)))
      hiRegTimer("acAutoOkTick()" 20))      ; again in 2 s
  )
)

procedure( acAutoOkStart()
  acAutoOkOn = t
  acAutoOkTicks = 0
  hiRegTimer("acAutoOkTick()" 20)
)

procedure( acAutoOkStop() acAutoOkOn = nil )
