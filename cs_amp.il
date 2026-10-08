;; cs_amp.il
;; Builds the common-source amplifier test schematic:
;;   vsin (2 MHz) -> 100 fF -> gate ; gate biased through RLARGE from VBIAS
;;   NMOS drain -> 100 kOhm -> 2 V supply ; source and bulk -> gnd
;;
;; Usage (in the CIW):
;;   load("~/cs_amp.il")
;;   csBuild("myLib" "cs_amp" "gpdk045" "nmos1v")
;;   csBuild("myLib" "cs_amp" "gpdk045" "nmos1v" ?vbias "0.55" ?rlarge "10M")
;;
;;   Arg 1-2 : your own library and the cell name to create (overwritten if it exists)
;;   Arg 3-4 : NMOS library and cell from your PDK
;;   ?vbias  : VBIAS value               (default "0.6", placeholder)
;;   ?rlarge : RLARGE value              (default "1G")
;;   ?vamp   : input sine amplitude      (default "10m")
;;   ?nParams: NMOS CDF params, e.g. list(list("fingers" "2") list("l" "45n"))
;;
;; Connectivity is made with short wire stubs plus net labels, so it does not
;; depend on the exact geometry of each PDK symbol.

procedure( csStub(cv inst termName netName)
  let( (term pin ctr pt ic dx dy len s end wires)
    len = 0.25
    term = car(setof(x inst~>master~>terminals
                     upperCase(x~>name) == upperCase(termName)))
    if( term then
      pin = car(term~>pins)
      ctr = centerBox(pin~>fig~>bBox)
      pt  = dbTransformPoint(ctr inst~>transform)
      ic  = centerBox(inst~>bBox)
      dx  = xCoord(pt) - xCoord(ic)
      dy  = yCoord(pt) - yCoord(ic)
      ;; stub points away from the symbol body
      if( abs(dx) >= abs(dy) then
        s = len
        when( (dx < 0) s = -s )
        end = list( xCoord(pt)+s  yCoord(pt) )
      else
        s = len
        when( (dy < 0) s = -s )
        end = list( xCoord(pt)  yCoord(pt)+s )
      )
      wires = schCreateWire(cv "draw" "full" list(pt end) 0.0625 0.0625 0.0)
      schCreateWireLabel(cv car(wires) end netName "lowerLeft" "R0" "stick" 0.0625 nil)
      t
    else
      warn("%s: no terminal named %s\n" inst~>name termName)
      nil
    )
  )
)

procedure( csSetParam(inst name val)
  let( (cdf p)
    cdf = cdfGetInstCDF(inst)
    p = and(cdf cdfFindParamByName(cdf name))
    if( p then
      p~>value = val
    else
      warn("%s: CDF parameter %s not found, skipped\n" inst~>name name)
    )
  )
)

procedure( csBuild(lib cell nLib nCell @key (vbias "0.6") (rlarge "1G") (vamp "10m") (nParams nil))
  let( (cv specs master inst mapped chk)
    unless( ddGetObj(lib)
      error("Library %s does not exist. Create it in Library Manager first.\n" lib) )
    cv = dbOpenCellViewByType(lib cell "schematic" "schematic" "w")
    unless( cv
      error("Cannot open %s/%s/schematic for writing.\n" lib cell) )

    ;;        name      lib          cell    x    y    terminal -> net                                  CDF params
    specs = list(
      list("V0"     "analogLib" "vsin" 0.0  2.0  '(("PLUS" "vin") ("MINUS" "gnd!"))
           list(list("vo" "0") list("va" vamp) list("freq" "2M") list("acm" "1")))
      list("C0"     "analogLib" "cap"  1.5  3.0  '(("PLUS" "vin") ("MINUS" "vg"))      '(("c" "100f")))
      list("RLARGE" "analogLib" "res"  3.0  2.0  '(("PLUS" "vg") ("MINUS" "vb"))       list(list("r" rlarge)))
      list("VBIAS"  "analogLib" "vdc"  3.0  0.0  '(("PLUS" "vb") ("MINUS" "gnd!"))     list(list("vdc" vbias)))
      list("M0"     nLib        nCell  4.5  3.0  '(("D" "vout") ("G" "vg") ("S" "gnd!") ("B" "gnd!"))  nParams)
      list("RD"     "analogLib" "res"  4.5  5.0  '(("PLUS" "vdd") ("MINUS" "vout"))    '(("r" "100K")))
      list("VDD"    "analogLib" "vdc"  7.0  3.0  '(("PLUS" "vdd") ("MINUS" "gnd!"))    '(("vdc" "2")))
      list("GND0"   "analogLib" "gnd"  7.0  0.0  '(("gnd!" "gnd!"))                    nil)
    )

    foreach(s specs
      master = dbOpenCellViewByType(nth(1 s) nth(2 s) "symbol")
      if( master then
        inst = schCreateInst(cv master nth(0 s) list(nth(3 s) nth(4 s)) "R0")
        foreach(tn nth(5 s) csStub(cv inst car(tn) cadr(tn)))
        foreach(pv nth(6 s) csSetParam(inst car(pv) cadr(pv)))
        ;; report any symbol terminal we did not connect
        mapped = mapcar(lambda((x) upperCase(car(x))) nth(5 s))
        foreach(tm master~>terminals
          unless( member(upperCase(tm~>name) mapped)
            warn("%s: terminal %s left unconnected\n" nth(0 s) tm~>name) ))
      else
        warn("Cannot open symbol %s/%s -- check the library/cell name\n" nth(1 s) nth(2 s))
      )
    )

    chk = schCheck(cv)
    printf("schCheck (errors warnings): %L\n" chk)
    dbSave(cv)
    geOpen(?lib lib ?cell cell ?view "schematic" ?mode "a")
    printf("Built %s/%s/schematic\n" lib cell)
    t
  )
)

printf("cs_amp.il loaded. Run: csBuild(\"yourLib\" \"cs_amp\" \"pdkLib\" \"nmosCell\")\n")
