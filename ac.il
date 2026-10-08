;; ac.il -- AutoCircuit entry point. Loads the PDK config, the helper libraries
;; and every circuit script.
;;
;; First time in a Virtuoso session (in the CIW):
;;   sh("cd ~/AutoCircuit && git pull")  load("~/AutoCircuit/ac.il")
;; After that, to pick up new changes from GitHub:
;;   acReload()

acRoot = strcat(getShellEnvVar("HOME") "/AutoCircuit")

;; order matters: PDK config, then libraries, then circuits
acFiles = '("pdk_cmrf7sf.il" "lib_draw.il" "lib_sim.il"
            "cs_amp.il" "cs_wsweep.il")

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

acLoadAll()
