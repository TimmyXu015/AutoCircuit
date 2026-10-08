;; cs_amp.il -- common-source amplifier (ECE 203 HW1 figure)
;;
;;            RD (100k) -- VDD (2 V)
;;             |
;;   vin --C0--+-- gate  M0 (drain -> RD, source -> gnd)
;;    |        |
;;   V0     RLARGE
;;  (2MHz)     |
;;           VBIAS  (= design variable "vbias")
;;
;; Usage (in the CIW, after load("~/AutoCircuit/ac.il")):
;;   csBuild("SelfPractice" "cs_amp")                  ; draw the schematic
;;   csSim()                                           ; DC + AC + tran, print results, plot
;;   csSim(?vbias 0.55)                                ; another bias point
;;   csSim(?vbias 0.55 ?plots nil)                     ; numbers only
;;   csBuild("SelfPractice" "cs_amp" ?nParams list(list("nf" "2")))   ; NMOS parameters
;;
;; VBIAS is the design variable "vbias". If you open this cell in ADE L by hand,
;; add vbias under Variables (Variables -> Copy From Cellview).

procedure( csBuild(lib cell @key (rlarge "1G") (vamp "10m") (nParams nil)
                                 (nLib acPdk->lib) (nCell acPdk->nmos))
  let( (cv m0 pG pD pS rd pRDt vdd n c0 pCp rl pRb vb v0)
    cv = acOpenSch(lib cell)

    ;; transistor, gate pin at the origin
    m0 = acPlace(cv nLib nCell "M0" "R0" "G" list(0.0 0.0))
    foreach(pv nParams acSetParam(m0 car(pv) cadr(pv)))
    pG = acPinPt(m0 "G")
    pD = acPinPt(m0 "D")
    pS = acPinPt(m0 "S")

    ;; load resistor above the drain, 2 V supply to its right
    rd = acPlace(cv "analogLib" "res" "RD" "R0" "MINUS" acUp(pD 0.5))
    acSetParam(rd "r" "100K")
    acWire(cv pD acPinPt(rd "MINUS") "vout")
    pRDt = acPinPt(rd "PLUS")
    vdd = acPlace(cv "analogLib" "vdc" "VDD" "R0" "PLUS" acRight(pRDt 2.0))
    acSetParam(vdd "vdc" "2")
    acWire(cv pRDt acPinPt(vdd "PLUS") "vdd")
    acGnd(cv "GND1" acPinPt(vdd "MINUS"))

    ;; source to ground
    acGnd(cv "GND2" pS)

    ;; gate node: coupling cap from the left, bias resistor below
    n = acLeft(pG 1.0)
    acWire(cv pG n "vg")
    c0 = acPlace(cv "analogLib" "cap" "C0" "R90" "MINUS" acLeft(n 0.5))
    acSetParam(c0 "c" "100f")
    acWire(cv acPinPt(c0 "MINUS") n)
    rl = acPlace(cv "analogLib" "res" "RLARGE" "R0" "PLUS" acDown(n 0.75))
    acSetParam(rl "r" rlarge)
    acWire(cv n acPinPt(rl "PLUS"))
    pRb = acPinPt(rl "MINUS")
    vb = acPlace(cv "analogLib" "vdc" "VBIAS" "R0" "PLUS" acDown(pRb 0.5))
    acSetParam(vb "vdc" "vbias")
    acWire(cv pRb acPinPt(vb "PLUS") "vb")
    acGnd(cv "GND3" acPinPt(vb "MINUS"))

    ;; 2 MHz input source, lower left
    pCp = acPinPt(c0 "PLUS")
    v0 = acPlace(cv "analogLib" "vsin" "V0" "R0" "PLUS" acDown(acLeft(pCp 1.0) 1.0))
    foreach(pv list(list("vo" "0") list("va" vamp) list("freq" "2M") list("acm" "1"))
      acSetParam(v0 car(pv) cadr(pv)))
    acWire(cv pCp acPinPt(v0 "PLUS") "vin")
    acGnd(cv "GND4" acPinPt(v0 "MINUS"))

    ;; substrate tie, far right
    acSubTie(cv acRight(acPinPt(vdd "PLUS") 1.5))

    acFinish(cv lib cell)
  )
)

;; DC operating point + AC sweep + transient, then print key numbers.
;; tstop is in seconds (5u = 10 periods of the 2 MHz input).
procedure( csSim(@key (lib "SelfPractice") (cell "cs_amp") (vbias 0.6)
                      (tstop 5e-6) (corner "tt") (plots t))
  let( (vout vg vd gain pp vinpp gm id)
    acSimSetup(lib cell corner)
    desVar("vbias" vbias)
    analysis('dc ?saveOppoint t)
    analysis('ac ?start "1k" ?stop "10G" ?dec "20")
    analysis('tran ?stop sprintf(nil "%g" tstop))
    run()

    ;; each measurement is guarded so one failure does not hide the rest
    vg    = car(errset(v("/vg"   ?result "dcOp") nil))
    vout  = car(errset(v("/vout" ?result "dcOp") nil))
    gain  = car(errset(value(mag(v("/vout" ?result "ac")) 2e6) nil))
    pp    = car(errset(peakToPeak(clip(v("/vout" ?result "tran") tstop/2 tstop)) nil))
    vinpp = car(errset(peakToPeak(clip(v("/vin"  ?result "tran") tstop/2 tstop)) nil))
    gm    = car(errset(pv("M0" "gm" ?result "dcOpInfo") nil))
    id    = car(errset(pv("M0" "id" ?result "dcOpInfo") nil))

    printf("\n========== cs_amp  (vbias = %g V, corner %s) ==========\n" vbias corner)
    printf("DC   V(vg)   = %s V\n" acNum(vg))
    printf("DC   V(vout) = %s V\n" acNum(vout))
    printf("DC   M0 gm   = %s S     Id = %s A\n" acNum(gm) acNum(id))
    printf("AC   |vout/vin| @ 2 MHz = %s V/V  (%s dB)\n"
           acNum(gain)
           if( numberp(gain) && gain > 0 then acNum(20.0 * log10(gain) "%.2f") else "n/a" ))
    printf("TRAN vout p-p = %s V   (vin p-p = %s V, 2nd half of the run)\n" acNum(pp) acNum(vinpp))
    printf("=======================================================\n")

    when( plots
      errset(
        progn(
          newWindow()
          plot(v("/vin" ?result "tran") v("/vout" ?result "tran"))
          newWindow()
          plot(db20(v("/vout" ?result "ac")))
        )
        t)
    )
    list(vout gain pp)
  )
)
