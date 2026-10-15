;; ac.il -- AutoCircuit entry point. Loads the PDK config, the helper libraries
;; and every circuit script.
;;
;; In the CIW, one line does everything for a job (pull, reload, run, report):
;;   load("~/AutoCircuit/ac.il") acGo("p1a")
;; Just reload the latest scripts:
;;   acReload()
;; Over SSH (no GUI):
;;   ~/AutoCircuit/run.sh p1a

acRoot = or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit"))

;; order matters: PDK config, then libraries, then circuits
acFiles = '("pdk_cmrf7sf.il" "lib_draw.il" "lib_sim.il" "lib_ade.il"
            "cs_amp.il" "cs_wsweep.il"
            "hw1_p1a.il" "rf_cap.il" "rf_ind.il" "gmid.il" "wsub.il" "hw1_setup.il" "sps.il" "spsg.il")

;; steps per job for acGo, run in order; each step is a function of no arguments
acJobs = list(nil
  'p1a  '(p1aRun p1aAde)
  'capc '(capcRun)
  'indb '(indbRun)
  'gmid '(gmidRun)
  'wsub '(wsubRun)
  'hw1 '(hw1Setup)
  'hw1check '(hw1Check)
  'p1c '(hw1P1cTest)
  'p1cp '(hw1P1cTestP)
  'spsscan '(spsScan)
  'sps '(spsRun)
  'spsade '(spsAde)
  'spsg '(spsgRun)
  'spsgade '(spsgAde)
)

;; ---------- reporting ----------
;; acSay prints to the CIW and, during acGo, also to ~/AutoCircuit_results/ciw_<job>.txt
;; so the report can be read (and copied) over SSH.
unless( boundp('acLogPort) acLogPort = nil )

procedure( acSay(fmt @rest args)
  let( (msg)
    ;; lsprintf is the lambda form of sprintf: apply() must not re-evaluate the args
    msg = if( isCallable('lsprintf)
            then apply('lsprintf cons(fmt args))
            else apply('sprintf append(list(nil fmt) mapcar(lambda((a) list('quote a)) args))))
    printf("AC> %s" msg)
    when( acLogPort
      fprintf(acLogPort "%s" msg)
      drain(acLogPort))
    msg
  )
)

;; ---------- loading ----------
procedure( acLoadAll()
  foreach(f acFiles
    load(strcat(acRoot "/" f)))
  printf("AutoCircuit loaded (%d files) from %s\n" length(acFiles) acRoot)
  t
)

procedure( acReload()
  if( sh(strcat("cd " acRoot " && git pull -q")) then
    printf("git pull ok\n")
  else
    warn("git pull failed -- loading the local copy\n")
  )
  load(strcat(acRoot "/ac.il"))
)

;; ---------- batch (run.sh) ----------
;; run a job function: errors are reported, never left hanging
procedure( acBatch(fn)
  let( (ok)
    ok = errset(funcall(fn) t)
    if( ok then
      printf("AC_BATCH_DONE\n")
    else
      printf("AC_BATCH_FAILED: %L\n" errset.errset)
    )
    ok
  )
)

;; ---------- one-shot runner for the CIW ----------
;; pulls from GitHub, reloads, runs every step of the job and writes the report to
;; ~/AutoCircuit_results/ciw_<job>.txt   (over SSH: cat ~/AutoCircuit_results/ciw_p1a.txt)
procedure( acGo(job)
  let( (steps dir file ok)
    when( stringp(job) job = stringToSymbol(job) )
    sh(strcat("cd " acRoot " && git pull -q"))
    load(strcat(acRoot "/ac.il"))
    steps = get(acJobs job)
    dir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results")
    unless( isDir(dir) createDir(dir) )
    file = strcat(dir "/ciw_" get_pname(job) ".txt")
    when( acLogPort errset(close(acLogPort) nil) )   ; left open by an interrupted run
    acLogPort = outfile(file "w")
    acSay("acGo %L  steps %L\n" job steps)
    unless( steps acSay("unknown job %L -- known jobs: %L\n" job acJobs) )
    foreach(st steps
      acSay("---- %L ----\n" st)
      ok = errset(funcall(st) t)
      acSay("---- %L %s\n" st if( ok "done" sprintf(nil "FAILED: %L" errset.errset))))
    acSay("acGo finished\n")
    close(acLogPort)
    acLogPort = nil
    printf("Report: %s\n" file)
    t
  )
)

acLoadAll()
