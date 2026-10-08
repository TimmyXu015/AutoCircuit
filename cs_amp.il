;; cs_amp.il  (v3: textbook layout with real wires)
;; Builds the common-source amplifier test schematic, laid out like the
;; homework figure:
;;
;;            RD (100k) -- VDD (2 V)
;;             |
;;   vin --C0--+-- gate  M0 (drain -> RD, source -> gnd)
;;    |        |
;;   V0     RLARGE
;;  (2MHz)     |
;;           VBIAS
;;
;; Usage (in the CIW):
;;   sh("cd ~/AutoCircuit && git pull")  load("~/AutoCircuit/cs_amp.il")
;;   csBuild("SelfPractice" "cs_amp" "cmrf7sf" "nfet")
;;   csBuild("SelfPractice" "cs_amp" "cmrf7sf" "nfet" ?vbias "0.55" ?rlarge "10M")
;;
;;   Arg 1-2 : your own library and the cell name to create (overwritten if it exists)
;;   Arg 3-4 : NMOS library and cell from your PDK
;;   ?vbias  : VBIAS value               (default "0.6", placeholder)
;;   ?rlarge : RLARGE value              (default "1G")
;;   ?vamp   : input sine amplitude      (default "10m")
;;   ?nParams: NMOS CDF params, e.g. list(list("nf" "2"))
;;
;; Every device is placed so that one chosen pin lands on a chosen point,
;; measured from the real pin positions of each symbol, then pins are joined
;; with straight or L-shaped wires. This keeps it independent of symbol sizes.

csLabelH = 0.1

;; ---------- geometry helpers ----------
procedure( csLeft(p d)  list(xCoord(p) - d  yCoord(p)) )
procedure( csRight(p d) list(xCoord(p) + d  yCoord(p)) )
procedure( csUp(p d)    list(xCoord(p)  yCoord(p) + d) )
procedure( csDown(p d)  list(xCoord(p)  yCoord(p) - d) )

;; absolute position of a terminal's pin on a placed instance
procedure( csPinPt(inst termName)
  let( (term)
    term = car(setof(x inst~>master~>terminals
                     upperCase(x~>name) == upperCase(termName)))
    when( term
      dbTransformPoint(centerBox(car(term~>pins)~>fig~>bBox) inst~>transform) )
  )
)

;; place lib/cell so that pin termName sits exactly on target
procedure( csPlace(cv lib cellName name orient termName target)
  let( (master inst p origin)
    master = dbOpenCellViewByType(lib cellName "symbol")
    unless( master
      error("Cannot open symbol %s/%s -- check the library/cell name\n" lib cellName) )
    inst = schCreateInst(cv master name list(0.0 0.0) orient)
    p = csPinPt(inst termName)
    unless( p
      error("%s (%s/%s): no terminal named %s\n" name lib cellName termName) )
    origin = list(xCoord(target) - xCoord(p)  yCoord(target) - yCoord(p))
    dbDeleteObject(inst)
    schCreateInst(cv master name origin orient)
  )
)

;; wire from a to b: straight if aligned, otherwise horizontal then vertical
procedure( csWire(cv a b @optional (label nil))
  let( (pts wires mx my)
    if( xCoord(a) == xCoord(b) || yCoord(a) == yCoord(b) then
      pts = list(a b)
    else
      pts = list(a list(xCoord(b) yCoord(a)) b)
    )
    wires = schCreateWire(cv "draw" "full" pts 0.0625 0.0625 0.0)
    when( label && wires
      mx = (xCoord(car(pts)) + xCoord(cadr(pts))) / 2.0 + 0.0625
      my = (yCoord(car(pts)) + yCoord(cadr(pts))) / 2.0 + 0.0625
      schCreateWireLabel(cv car(wires) list(mx my) label "lowerLeft" "R0" "stick" csLabelH nil)
    )
    wires
  )
)

;; ground symbol half a unit below pt, wired to pt
procedure( csGnd(cv name pt)
  let( (g)
    g = csPlace(cv "analogLib" "gnd" name "R0" "gnd!" csDown(pt 0.5))
    csWire(cv pt csPinPt(g "gnd!"))
    g
  )
)

;; short labelled stub on a pin (used for the global sub! net)
procedure( csStub(cv inst termName netName)
  let( (pt end wires)
    pt = csPinPt(inst termName)
    when( pt
      end = csUp(pt 0.25)
      wires = schCreateWire(cv "draw" "full" list(pt end) 0.0625 0.0625 0.0)
      schCreateWireLabel(cv car(wires) end netName "lowerLeft" "R0" "stick" csLabelH nil)
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

;; ---------- main ----------
procedure( csBuild(lib cell nLib nCell @key (vbias "0.6") (rlarge "1G") (vamp "10m") (nParams nil))
  let( (cv m0 pG pD pS rd pRDt vdd n c0 pCp rl pRb vb v0 vsub chk)
    unless( ddGetObj(lib)
      error("Library %s does not exist. Create it in Library Manager first.\n" lib) )
    cv = dbOpenCellViewByType(lib cell "schematic" "schematic" "w")
    unless( cv
      error("Cannot open %s/%s/schematic for writing.\n" lib cell) )

    ;; transistor, gate pin at the origin
    m0 = csPlace(cv nLib nCell "M0" "R0" "G" list(0.0 0.0))
    foreach(pv nParams csSetParam(m0 car(pv) cadr(pv)))
    pG = csPinPt(m0 "G")
    pD = csPinPt(m0 "D")
    pS = csPinPt(m0 "S")

    ;; load resistor above the drain, 2 V supply to its right
    rd = csPlace(cv "analogLib" "res" "RD" "R0" "MINUS" csUp(pD 0.5))
    csSetParam(rd "r" "100K")
    csWire(cv pD csPinPt(rd "MINUS") "vout")
    pRDt = csPinPt(rd "PLUS")
    vdd = csPlace(cv "analogLib" "vdc" "VDD" "R0" "PLUS" csRight(pRDt 2.0))
    csSetParam(vdd "vdc" "2")
    csWire(cv pRDt csPinPt(vdd "PLUS") "vdd")
    csGnd(cv "GND1" csPinPt(vdd "MINUS"))

    ;; source to ground
    csGnd(cv "GND2" pS)

    ;; gate node: coupling cap from the left, bias resistor below
    n = csLeft(pG 1.0)
    csWire(cv pG n "vg")
    c0 = csPlace(cv "analogLib" "cap" "C0" "R90" "MINUS" csLeft(n 0.5))
    csSetParam(c0 "c" "100f")
    csWire(cv csPinPt(c0 "MINUS") n)
    rl = csPlace(cv "analogLib" "res" "RLARGE" "R0" "PLUS" csDown(n 0.75))
    csSetParam(rl "r" rlarge)
    csWire(cv n csPinPt(rl "PLUS"))
    pRb = csPinPt(rl "MINUS")
    vb = csPlace(cv "analogLib" "vdc" "VBIAS" "R0" "PLUS" csDown(pRb 0.5))
    csSetParam(vb "vdc" vbias)
    csWire(cv pRb csPinPt(vb "PLUS") "vb")
    csGnd(cv "GND3" csPinPt(vb "MINUS"))

    ;; 2 MHz input source, lower left
    pCp = csPinPt(c0 "PLUS")
    v0 = csPlace(cv "analogLib" "vsin" "V0" "R0" "PLUS" csDown(csLeft(pCp 1.0) 1.0))
    foreach(pv list(list("vo" "0") list("va" vamp) list("freq" "2M") list("acm" "1"))
      csSetParam(v0 car(pv) cadr(pv)))
    csWire(cv pCp csPinPt(v0 "PLUS") "vin")
    csGnd(cv "GND4" csPinPt(v0 "MINUS"))

    ;; IBM PDKs tie the device substrate to global net sub!; short it to ground
    vsub = csPlace(cv "analogLib" "vdc" "VSUB" "R0" "PLUS" csRight(csPinPt(vdd "PLUS") 1.5))
    csSetParam(vsub "vdc" "0")
    csStub(cv vsub "PLUS" "sub!")
    csGnd(cv "GND5" csPinPt(vsub "MINUS"))

    chk = schCheck(cv)
    printf("schCheck (errors warnings): %L\n" chk)
    dbSave(cv)
    geOpen(?lib lib ?cell cell ?view "schematic" ?mode "a")
    printf("Built %s/%s/schematic\n" lib cell)
    t
  )
)

printf("cs_amp.il v3 loaded. Run: csBuild(\"SelfPractice\" \"cs_amp\" \"cmrf7sf\" \"nfet\")\n")
