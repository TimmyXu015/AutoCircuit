;; ece203_lib.il -- helpers shared by the ECE203 ECG project cells (library Project).
;;
;; Cells are drawn "netlist style": every instance sits on a grid and each terminal gets a
;; short labelled stub, so every connection is made by net NAME (no long wires that could
;; touch other pins by accident). Global ground is the label "gnd!" (one gnd symbol is
;; added per testbench as well). Sub-cells get pins + an auto-generated symbol.

ece203Lib = "Project"

;; short labelled wire from a pin, pointing away from the instance centre; returns the far end
procedure( ece203Stub(cv inst term net @optional (len 0.375))
  let( (p c dx dy end)
    p = acPinPt(inst term)
    unless( p error("%s: no terminal %s\n" inst~>name term) )
    c = centerBox(inst~>bBox)
    dx = xCoord(p) - xCoord(c)
    dy = yCoord(p) - yCoord(c)
    end = if( abs(dx) >= abs(dy)
            then if( dx < 0 acLeft(p len) acRight(p len))
            else if( dy < 0 acDown(p len) acUp(p len)))
    acWire(cv p end net)
    end
  )
)

;; report the technology library of the project library
procedure( ece203LibInfo()
  let( (lib)
    lib = ddGetObj(ece203Lib)
    unless( lib error("Library %s not found in cds.lib\n" ece203Lib) )
    acSay("ece203: library %s at %s, tech library = %L\n" ece203Lib lib~>readPath
          car(errset(techGetTechLibName(lib) nil)))
    lib
  )
)

;; grid position number k (6 per row)
procedure( ece203Grid(k @optional (cols 6) (dx 3.0) (dy 3.5))
  list(dx * float(mod(k cols)) -dy * float(quotient(k cols)))
)

;; place lib/cell at xy, set CDF params ((name value) ...), connect ((term net) ...) by stubs
procedure( ece203Elem(cv lib cell name xy params conns @optional (orient "R0"))
  let( (master inst tn)
    master = dbOpenCellViewByType(lib cell "symbol")
    unless( master error("ece203Elem: cannot open symbol %s/%s\n" lib cell) )
    inst = schCreateInst(cv master name xy orient)
    foreach(p params acSetParam(inst car(p) cadr(p)))
    foreach(c conns
      tn = acTerm(inst list(car(c)))
      unless( tn
        error("ece203Elem: %s (%s) has no terminal %s; terminals %L\n"
              name cell car(c) inst~>master~>terminals~>name))
      ece203Stub(cv inst tn cadr(c)))
    inst
  )
)

;; specs: list of (lib cell name params conns), placed on the grid from position start
procedure( ece203Place(cv specs @optional (start 0))
  let( (k insts)
    k = start
    foreach(s specs
      insts = cons(ece203Elem(cv nth(0 s) nth(1 s) nth(2 s) ece203Grid(k) nth(3 s) nth(4 s)) insts)
      k = k + 1)
    reverse(insts)
  )
)

;; spec of a cmrf7sf FET: w, l in metres; d g s b net names
procedure( ece203FetSpec(dev name w l d g s b)
  list("cmrf7sf" dev name
       append(list(list("w" sprintf(nil "%gu" w * 1e6)) list("l" sprintf(nil "%gu" l * 1e6)))
              hw2DiffParams(w))
       list(list("D" d) list("G" g) list("S" s) list("B" b)))
)

;; a gnd symbol tied to the label gnd! (so the global ground is drawn once)
procedure( ece203GndRef(cv xy)
  let( (q)
    q = acDown(xy 0.5)
    acWire(cv xy q "gnd!")
    acGnd(cv "GND0" q)
  )
)

;; schematic pin (dir "input" | "output" | "inputOutput") with a labelled stub of the same name
procedure( ece203Pin(cv name dir xy)
  let( (mname master)
    mname = cond( (dir == "input" "ipin") (dir == "output" "opin") (t "iopin") )
    master = dbOpenCellViewByType("basic" mname "symbol")
    unless( master error("no basic/%s symbol\n" mname) )
    schCreatePin(cv master name dir nil xy "R0")
    acWire(cv xy acRight(xy 0.5) name)
  )
)

;; pins ((name dir) ...) in a column at x = -3
procedure( ece203Pins(cv pins)
  let( (k)
    k = 0
    foreach(p pins
      ece203Pin(cv car(p) cadr(p) list(-3.0 -0.75 * float(k)))
      k = k + 1)
  )
)

;; make the symbol from the schematic pins; regenerate if the pin set changed
procedure( ece203Symbol(lib cell)
  let( (sch sym schTerms symTerms symObj ok)
    sch = dbOpenCellViewByType(lib cell "schematic")
    schTerms = sort(copy(sch~>terminals~>name) 'alphalessp)
    symObj = ddGetObj(lib cell "symbol")
    when( symObj
      sym = dbOpenCellViewByType(lib cell "symbol")
      symTerms = sort(copy(and(sym sym~>terminals~>name)) 'alphalessp)
      when( sym dbClose(sym) )
      if( equal(symTerms schTerms) then
        acSay("%s: symbol up to date, pins %L\n" cell symTerms)
      else
        acSay("%s: symbol pins %L differ from schematic %L -> regenerate\n" cell symTerms schTerms)
        ddDeleteObj(symObj)
        symObj = nil))
    unless( symObj
      ok = errset(schViewToView(lib cell lib cell "schematic" "symbol"
                                "schSchemToPinList" "schPinListToSymbol") t)
      acSay("%s: symbol generated -> %L, pins %L\n" cell ok schTerms))
    t
  )
)

;; ---------- simulation helpers ----------
procedure( ece203V(w x) car(errset(value(w x) nil)) )
procedure( ece203Db(x) and(numberp(x) x > 0 20.0 * acLog10(x)) )

procedure( ece203OpNames()
  car(errset(progn(selectResult('dcOpInfo) outputs()) nil))
)

;; dcOpInfo name for a (hierarchical) instance, e.g. "XA.M1": exact or the shortest
;; "XA.M1.<...>" that has a numeric gm
procedure( ece203OpFind(names inst)
  let( (pref cands)
    pref = strcat(inst ".")
    cands = setof(n names stringp(n) && (n == inst || strncmp(n pref strlen(pref)) == 0))
    cands = sort(cands lambda((a b) strlen(a) < strlen(b)))
    car(setof(n cands numberp(car(errset(pv(n "gm" ?result "dcOpInfo") nil)))))
  )
)

ece203OpParams = '("id" "gm" "gds" "vgs" "vds" "vth" "vdsat" "region")

;; one row per instance: values of ece203OpParams, gm/Id, saturation margin |vds|-|vdsat|
procedure( ece203OpRows(insts)
  let( (names n vals rows)
    names = ece203OpNames()
    foreach(inst insts
      n = ece203OpFind(names inst)
      vals = mapcar(lambda((p) and(n car(errset(pv(n p ?result "dcOpInfo") nil)))) ece203OpParams)
      rows = cons(list(inst n vals) rows))
    reverse(rows)
  )
)

procedure( ece203Margin(vals)
  let( (vds vdsat)
    vds = nth(4 vals) vdsat = nth(6 vals)
    and(numberp(vds) numberp(vdsat) abs(vds) - max(abs(vdsat) 0.1))
  )
)

procedure( ece203OpDump(file insts)
  let( (port id gm rows)
    rows = ece203OpRows(insts)
    port = outfile(file "w")
    fprintf(port "inst,opname,id_A,gm_S,gds_S,vgs_V,vds_V,vth_V,vdsat_V,region,gm_over_id,sat_margin_V\n")
    foreach(r rows
      id = nth(0 caddr(r)) gm = nth(1 caddr(r))
      fprintf(port "%s,%s" car(r) or(cadr(r) "n/a"))
      foreach(x caddr(r) fprintf(port ",%s" spsNum(x "%.6g")))
      fprintf(port ",%s,%s\n"
              spsNum(and(numberp(id) numberp(gm) id != 0 abs(gm / id)) "%.4g")
              spsNum(ece203Margin(caddr(r)) "%.4g"))
      acSay("op %-6s %-12s id %s gm %s vgs %s vds %s vdsat %s region %s\n" car(r) or(cadr(r) "n/a")
            spsNum(id "%.4g") spsNum(gm "%.4g") spsNum(nth(3 caddr(r)) "%.4g")
            spsNum(nth(4 caddr(r)) "%.4g") spsNum(nth(6 caddr(r)) "%.4g") spsNum(nth(7 caddr(r)) "%g")))
    close(port)
    rows
  )
)

;; smallest saturation margin (|vds| - max(|vdsat|, 0.1 V)) over instances; returns (margin inst)
procedure( ece203MinMargin(insts)
  let( (best m)
    foreach(r ece203OpRows(insts)
      m = ece203Margin(caddr(r))
      when( !numberp(m) m = -9.0 )
      when( !best || m < car(best) best = list(m car(r))))
    best
  )
)

;; set design variables ((name value) ...)
procedure( ece203Vars(vars)
  foreach(p vars desVar(car(p) cadr(p)))
)

;; copy the netlist of the last run of cell into ~/AutoCircuit_results/<tag>_netlist.scs
procedure( ece203SaveNetlist(cell tag)
  let( (nl)
    nl = strcat(acResultsDir() "/" tag "_netlist.scs")
    sh(sprintf(nil "f=$(find %s -name input.scs | head -1); [ -n \"$f\" ] && cp \"$f\" %s"
               acSimDir(cell) nl))
    acSay("%s: netlist copied %L; lines with mag=:\n" tag isFile(nl))
    when( isFile(nl) sh(sprintf(nil "grep -n 'mag=' %s | sed 's/^/AC>   /'" nl)))
    nl
  )
)

;; analyses set for one testbench must not leak into the next one (e.g. a noise analysis
;; that names a source the next testbench does not have)
procedure( ece203Setup(cell suffix)
  acSimSetup(ece203Lib cell "tt" suffix)
  car(errset(delete('analysis 'dc 'ac 'noise 'stb 'tran) nil))
  t
)

;; nil-safe wave transforms for CSV writing
procedure( ece203Mag(w) and(w car(errset(mag(w) nil))) )
procedure( ece203Ph(w) and(w car(errset(phase(w) nil))) )

;; print pin centres (relative to the instance origin, R0) and bBox of symbols -- for stub rules
procedure( ece203ProbeSymbols()
  foreach(lc '(("cmrf7sf" "nfetx") ("cmrf7sf" "pfetx") ("analogLib" "vcvs") ("analogLib" "iprobe")
               ("analogLib" "idc") ("analogLib" "vdc") ("analogLib" "res") ("analogLib" "cap"))
    let( (m)
      m = dbOpenCellViewByType(car(lc) cadr(lc) "symbol")
      if( m then
        acSay("sym %s/%s bBox %L\n" car(lc) cadr(lc) m~>bBox)
        foreach(tm m~>terminals
          acSay("sym %s/%s pin %s at %L\n" car(lc) cadr(lc) tm~>name
                mapcar(lambda((p) centerBox(p~>fig~>bBox)) tm~>pins)))
      else
        acSay("sym %s/%s: cannot open\n" car(lc) cadr(lc)))))
  t
)
