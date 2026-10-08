;; lib_draw.il -- generic schematic-drawing helpers (PDK independent).
;;
;; Pattern used by every circuit script:
;;   cv = acOpenSch(lib cell)
;;   m  = acPlace(cv lib cell "M0" "R0" "G" list(0.0 0.0))   ; put pin G at (0,0)
;;   acWire(cv acPinPt(m "D") someOtherPoint "vout")          ; wire + net label
;;   acGnd(cv "GND1" acPinPt(m "S"))
;;   acFinish(cv lib cell)

acLabelH = 0.1

;; ---------- geometry ----------
procedure( acLeft(p d)  list(xCoord(p) - d  yCoord(p)) )
procedure( acRight(p d) list(xCoord(p) + d  yCoord(p)) )
procedure( acUp(p d)    list(xCoord(p)  yCoord(p) + d) )
procedure( acDown(p d)  list(xCoord(p)  yCoord(p) - d) )

;; absolute position of a terminal's pin on a placed instance (case-insensitive name)
procedure( acPinPt(inst termName)
  let( (term)
    term = car(setof(x inst~>master~>terminals
                     upperCase(x~>name) == upperCase(termName)))
    when( term
      dbTransformPoint(centerBox(car(term~>pins)~>fig~>bBox) inst~>transform) )
  )
)

;; place lib/cell so that pin termName lands exactly on target
procedure( acPlace(cv lib cellName name orient termName target)
  let( (master inst p origin)
    master = dbOpenCellViewByType(lib cellName "symbol")
    unless( master
      error("Cannot open symbol %s/%s -- check the library/cell name\n" lib cellName) )
    inst = schCreateInst(cv master name list(0.0 0.0) orient)
    p = acPinPt(inst termName)
    unless( p
      error("%s (%s/%s): no terminal named %s\n" name lib cellName termName) )
    origin = list(xCoord(target) - xCoord(p)  yCoord(target) - yCoord(p))
    dbDeleteObject(inst)
    schCreateInst(cv master name origin orient)
  )
)

;; wire a -> b: straight if aligned, otherwise horizontal then vertical
procedure( acWire(cv a b @optional (label nil))
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
      schCreateWireLabel(cv car(wires) list(mx my) label "lowerLeft" "R0" "stick" acLabelH nil)
    )
    wires
  )
)

;; ground symbol half a unit below pt, wired to pt
procedure( acGnd(cv name pt)
  let( (g)
    g = acPlace(cv "analogLib" "gnd" name "R0" "gnd!" acDown(pt 0.5))
    acWire(cv pt acPinPt(g "gnd!"))
    g
  )
)

;; short labelled stub pointing up from a pin (for global nets such as sub!)
procedure( acStub(cv inst termName netName)
  let( (pt end wires)
    pt = acPinPt(inst termName)
    when( pt
      end = acUp(pt 0.25)
      wires = schCreateWire(cv "draw" "full" list(pt end) 0.0625 0.0625 0.0)
      schCreateWireLabel(cv car(wires) end netName "lowerLeft" "R0" "stick" acLabelH nil)
    )
  )
)

;; set a CDF parameter on an instance, warn if the PDK calls it something else
procedure( acSetParam(inst name val)
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

;; print every CDF parameter of an instance (name, prompt, value) -- for learning a PDK
;;   acDumpParams("SelfPractice" "cs_amp" "M0")
procedure( acDumpParams(lib cell instName)
  let( (cv inst cdf)
    cv = dbOpenCellViewByType(lib cell "schematic")
    inst = and(cv car(setof(i cv~>instances i~>name == instName)))
    if( inst then
      cdf = cdfGetInstCDF(inst)
      printf("CDF parameters of %s (%s/%s):\n" instName inst~>libName inst~>cellName)
      foreach(p cdf~>parameters
        printf("  %-16s %L  = %L\n" p~>name p~>prompt p~>value))
    else
      warn("No instance %s in %s/%s/schematic\n" instName lib cell)
    )
  )
)

;; 0 V source tying the PDK substrate net to ground, placed at pt (its + pin)
procedure( acSubTie(cv pt)
  let( (vs)
    when( acPdk->subNet
      vs = acPlace(cv "analogLib" "vdc" "VSUB" "R0" "PLUS" pt)
      acSetParam(vs "vdc" "0")
      acStub(cv vs "PLUS" acPdk->subNet)
      acGnd(cv "GNDSUB" acPinPt(vs "MINUS"))
      vs
    )
  )
)

;; open (overwrite) a schematic for writing
procedure( acOpenSch(lib cell)
  let( (cv)
    unless( ddGetObj(lib)
      error("Library %s does not exist. Create it in Library Manager first.\n" lib) )
    cv = dbOpenCellViewByType(lib cell "schematic" "schematic" "w")
    unless( cv
      error("Cannot open %s/%s/schematic for writing.\n" lib cell) )
    cv
  )
)

;; check, save and show the schematic
procedure( acFinish(cv lib cell)
  let( (chk)
    chk = schCheck(cv)
    printf("schCheck (errors warnings): %L\n" chk)
    dbSave(cv)
    geOpen(?lib lib ?cell cell ?view "schematic" ?mode "a")
    printf("Built %s/%s/schematic\n" lib cell)
    t
  )
)
