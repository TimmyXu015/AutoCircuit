;; ac.il -- AutoCircuit entry point. Loads the PDK config, the helper libraries
;; and every circuit script.
;;
;; First time in a Virtuoso session (in the CIW):
;;   sh("cd ~/AutoCircuit && git pull")  load("~/AutoCircuit/ac.il")
;; After that, to pick up new changes from GitHub:
;;   acReload()

acRoot = or(getShellEnvVar("AC_ROOT") strcat(getShellEnvVar("HOME") "/AutoCircuit"))

;; order matters: PDK config, then libraries, then circuits
acFiles = '("pdk_cmrf7sf.il" "lib_draw.il" "lib_sim.il"
            "cs_amp.il" "cs_wsweep.il"
            "hw1_p1a.il")

procedure( ;; run a job function in batch mode (run.sh): errors are reported, never left hanging
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

acLoadAll()
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

;; run a job function in batch mode (run.sh): errors are reported, never left hanging
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

acLoadAll()
