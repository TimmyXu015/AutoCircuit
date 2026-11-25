;; ECE203 F2 interference task: frozen early non-chopped F2 (Project/ece203_r5nf_tb_f2, OTA ece203_r5nf_ota_f2) under
;; 0 / 100 nA / 1 uA 60 Hz body interference, using the professor's ECG_tb scenario.
;; Task: docs/ECE203_F2_1uA_interference_gain_task.md.  Library rule (user, 2026-11-25): nothing is ever written into any 203ECG*
;; library (read + copy-from only); all new cells live in Project.
;; Step 1 (this file so far): read-only probe of the libraries, the instructor ECG_tb and the F2 fixture. No cell is created or edited.

f2iDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_f2i")
procedure( f2iMk() unless( isDir(f2iDir) sh(sprintf(nil "mkdir -p %s" f2iDir))) )
procedure( f2iP(port fmt @rest a) apply('fprintf cons(port cons(fmt a))) )

;; read-only dump of one schematic (instances, master, terminals -> nets, user/CDF properties, pins)
procedure( f2iDumpSch(port lib cell)
  let( (cv)
    cv = dbOpenCellViewByType(lib cell "schematic" nil "r")
    if( !cv then f2iP(port "  (no schematic view)\n")
    else
      f2iP(port "  views: %L\n" ddGetObj(lib cell)~>views~>name)
      f2iP(port "  terminals (pins): %L\n" mapcar(lambda((t) list(t~>name t~>direction)) cv~>terminals))
      f2iP(port "  nets: %L\n" sort(cv~>nets~>name 'alphalessp))
      foreach(inst cv~>instances
        f2iP(port "  INST %s  %s/%s/%s\n" inst~>name inst~>libName inst~>cellName inst~>viewName)
        foreach(it inst~>instTerms f2iP(port "     term %s -> %s\n" it~>name it~>net~>name))
        foreach(p inst~>prop f2iP(port "     prop %s = %L\n" p~>name p~>value)))
      dbClose(cv))
    t
  )
)
procedure( f2iProbe()
  let( (port hits libs)
    f2iMk()
    port = outfile(strcat(f2iDir "/probe_libraries.txt") "w")
    libs = sort(ddGetLibList()~>name 'alphalessp)
    f2iP(port "libraries (%d): %L\n\n" length(libs) libs)
    ;; every cell whose name looks like an ECG testbench, in every library
    foreach(lib ddGetLibList()
      foreach(c lib~>cells
        when( rexMatchp("[Ee][Cc][Gg].*[Tt][Bb]\\|[Tt][Bb].*[Ee][Cc][Gg]" c~>name)
          hits = cons(list(lib~>name c~>name c~>views~>name) hits))))
    f2iP(port "ECG testbench-like cells: \n")
    foreach(h reverse(hits) f2iP(port "  %s / %s  views %L\n" car(h) cadr(h) caddr(h)))
    ;; cells of non-Project, non-PDK libraries (to see where course material lives)
    foreach(lib ddGetLibList()
      unless( member(lib~>name '("Project" "analogLib" "basic" "cdsDefTechLib" "functional" "sbaLib" "ahdlLib" "rfLib" "US_8ths" "cmrf7sf" "rfExamples" "bicmos7wl"))
        f2iP(port "\nLIB %s (%s): %d cells: %L\n" lib~>name lib~>readPath length(lib~>cells) sort(lib~>cells~>name 'alphalessp))))
    close(port)
    ;; read-only schematic dumps of every hit + the frozen F2 fixture
    port = outfile(strcat(f2iDir "/probe_schematics.txt") "w")
    foreach(h reverse(hits)
      f2iP(port "\n==== %s / %s (read-only)\n" car(h) cadr(h))
      car(errset(f2iDumpSch(port car(h) cadr(h)) t)))
    f2iP(port "\n==== Project / ece203_r5nf_tb_f2 (frozen F2 fixture, read-only)\n")
    car(errset(f2iDumpSch(port "Project" "ece203_r5nf_tb_f2") t))
    close(port)
    acSay("f2i probe: %d ECG-tb-like cells: %L\n" length(hits) reverse(hits))
    t
  )
)
