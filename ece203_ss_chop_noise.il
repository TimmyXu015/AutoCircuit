;; ece203_ss_chop_noise.il -- ECE203 Round 3E: ideal 1 MHz chopper noise demo with a calibrated noisy ideal OTA.
;; Work order: docs/ECE203_round3e_ideal_chopper_noise_demo.md.
;; Copy of the Round-3D ideal chopper bench (non-overlapping 1 MHz relay commutator, ideal EINV demodulator,
;; feedback from the demodulated node o, S2 network, ideal Rfb) with ONE change: a 0 V vdc noise source VN in
;; series with the VCVS (+) input, i.e. AFTER the input chopper and BEFORE amplification. Its noise table
;; (analogLib vdc F/N pairs -> Spectre noisevec, one-sided V^2/Hz) is the fit of the Round-3C C OTA deembedded
;; input PSD: S_e(f) = K/f^alpha + Sw (fit 1 Hz-100 kHz; values above 100 kHz are an EXTRAPOLATION).
;; The VCVS has unlimited bandwidth (a model, not the real OTA).
;; Cases: U = clock frozen (chen 0), C = chopping (chen 1). Both: PSS (fund 1 MHz) + time-averaged PNoise at /o
;; (0.1-250 Hz; the integration band is the ideal brick-wall 250 Hz LP) + PAC for the baseband differential gain.
;; U also gets ordinary dc/ac/noise to check that the noise table is active.

cnCell = "ece203_ss_chop_noise_tb"
cnDir = strcat(getShellEnvVar("HOME") "/AutoCircuit_results/ece203_ss_chop_noise")
cnK = 3.451141677922061e-11
cnA = 1.0381388091865171
cnSw = 1.1879871469517083e-14
procedure( cnSe(f) cnK / (f ** cnA) + cnSw )

;; 50 log-spaced points 1 mHz .. 100 MHz
procedure( cnNoiseParams()
  let( (ps f)
    ps = list(list("FNpairs" "50"))
    for(i 0 49
      f = 10.0 ** (-3.0 + 11.0 * i / 49.0)
      ps = append(ps list(list(sprintf(nil "F%d" i + 1) sprintf(nil "%.6g" f))
                          list(sprintf(nil "N%d" i + 1) sprintf(nil "%.6g" cnSe(f))))))
    ps
  )
)

procedure( cnPulse(name v1 v2 acm pacm a)
  list("analogLib" "vpulse" name
       list(list("dc" v1) list("v1" v1) list("v2" v2) list("td" "tst") list("tr" "1n") list("tf" "1n")
            list("pw" "1") list("per" "2") list("acm" acm) list("pacm" pacm))
       list(list("PLUS" a) list("MINUS" "gnd!")))
)

procedure( cnSpecs()
  list(ldV("VREF" "vref" "0" "vref" "gnd!")
       cnPulse("VINP" "vref" "vref+vst/2" "0.5" "0.5" "vinp")
       cnPulse("VINN" "vref" "vref-vst/2" "-0.5" "-0.5" "vinn")
       chPulse("VCK1" "1.8" "1.8*(1-chen)" "0.5u" "0.499u" "1u" "ck1")
       chPulse("VCK2" "0" "1.8*chen" "0.51u" "0.479u" "1u" "ck2")
       otaC("CCP" "cc" "vinp" "p")  otaC("CCN" "cc" "vinn" "n")
       otaC("CFP" "cfb" "p" "vref") otaR("RFP" "rfb" "p" "vref")
       otaC("CFN" "cfb" "n" "o")    otaR("RFN" "rfb" "n" "o")
       chSw("S1P" "p" "ia" "ck1") chSw("S1N" "n" "ib_" "ck1")
       chSw("S2P" "n" "ia" "ck2") chSw("S2N" "p" "ib_" "ck2")
       list("analogLib" "vdc" "VN" append(list(list("vdc" "0") list("acm" "0")) cnNoiseParams())
            list(list("PLUS" "ia2") list("MINUS" "ia")))
       ldE("E1" "ia2" "ib_" "oa" "gnd!" "aol")
       ldE("EINV" "oa" "vref" "oinv" "vref" "-1")
       chSw("S3" "oa" "o" "ck1") chSw("S4" "oinv" "o" "ck2")
       otaC("CL" "cl" "o" "gnd!"))
)

procedure( cnVars(chen)
  ece203Vars(ssCfg->vars) ece203Vars(lsS2)
  ece203Vars(list(list("vst" 0.0) list("tst" 1.0) list("chen" chen) list("aol" 1e5)))
)
procedure( cnTight() car(errset(option('gmin "1e-18" 'iabstol "1e-18" 'reltol "1e-6") t)) )

;; PAC baseband transfer at sideband 0 (try harmonic() first)
procedure( cnPacH()
  let( (w h)
    w = car(errset(v("/o" ?result "pac") nil))
    h = or(car(errset(harmonic(w 0) nil)) w)
    acSay("cn: pac wave %L -> sideband 0 %L\n" w h)
    h
  )
)

procedure( cnRow(port name h nout nin)
  let( (orms)
    orms = nsRms(nout 0.1 250.0)
    fprintf(port "%s,%s,%s,%s,%s,%s,%s,%s\n" name acNum(ldMag(h 10.0) "%.6g") acNum(ldMag(h 100.0) "%.6g")
            acNum(orms "%.6g") acNum(and(orms ldMag(h 100.0) orms / ldMag(h 100.0)) "%.6g")
            acNum(nsRms(nin 0.1 250.0) "%.6g")
            acNum(ece203V(nin 1.0) "%.6g") acNum(ece203V(nin 100.0) "%.6g"))
    acSay("cn %s: |Hdm| 10/100 %s %s | out rms %s | app in rms %s | deemb in rms %s | in-ref @1/10/100 Hz %s %s %s (model OTA-only %s %s %s)\n"
          name acNum(ldMag(h 10.0) "%.5g") acNum(ldMag(h 100.0) "%.5g") acNum(orms "%.4g")
          acNum(and(orms ldMag(h 100.0) orms / ldMag(h 100.0)) "%.4g") acNum(nsRms(nin 0.1 250.0) "%.4g")
          acNum(ece203V(nin 1.0) "%.4g") acNum(ece203V(nin 10.0) "%.4g") acNum(ece203V(nin 100.0) "%.4g")
          acNum(sqrt(cnSe(1.0)) "%.4g") acNum(sqrt(cnSe(10.0)) "%.4g") acNum(sqrt(cnSe(100.0)) "%.4g"))
    drain(port)
  )
)

procedure( cnStaticU(port)
  let( (h nout nin ok)
    ok = errset(
      progn(
        ece203Setup(cnCell "_U_static")
        cnTight()
        analysis('dc ?saveOppoint t)
        analysis('ac ?start "0.1" ?stop "250" ?dec "20")
        analysis('noise ?start "0.1" ?stop "250" ?dec "20" ?p "/o" ?n "/gnd!" ?iprobe "/VINP")
        cnVars(0.0)
        run()
        h = ldDiv(ldAc("o") ldAc("vinp") - ldAc("vinn"))
        nout = car(errset(getData("out" ?result "noise") nil))
        nin = and(nout h car(errset(nout / mag(h) nil)))
        cnRow(port "U_static_noise" h nout nin)
        nsSummary(strcat(cnDir "/U_static_noisesummary.txt") 'integrated 0.1 250.0)
        spsWriteWaves(strcat(cnDir "/U_static_noise.csv") "f_Hz,out_V_rtHz,absHdm,deemb_in_V_rtHz" list(nout ece203Mag(h) nin))
        ece203SaveNetlist(cnCell "ece203_chopnoise_U_static")
        t)
      t)
    unless( ok acSay("cn U static: FAILED %L\n" errset.errset) fprintf(port "U_static_noise,failed\n"))
  )
)

procedure( cnPeriodic(port name chen)
  let( (ok h nout nin)
    ok = errset(
      progn(
        ece203Setup(cnCell strcat("_" name))
        cnTight()
        analysis('pss ?fund "1M" ?harms "50" ?errpreset "moderate")
        analysis('pac ?sweeptype "relative" ?relharmnum "0" ?start "0.1" ?stop "250" ?dec "20" ?maxsideband "3")
        analysis('pnoise ?sweeptype "relative" ?relharmnum "0" ?start "0.1" ?stop "250" ?dec "20"
                 ?maxsideband "49" ?p "/o" ?n "/gnd!" ?noisetype "timeaverage")
        cnVars(chen)
        run()
        acSay("cn %s: results %L\n" name car(errset(results() nil)))
        h = cnPacH()
        nout = or(car(errset(getData("out" ?result "pnoise") nil))
                  car(errset(getData("out" ?result "pnoise_pnoise") nil)))
        acSay("cn %s: pnoise out %L\n" name nout)
        nin = and(nout h car(errset(nout / mag(h) nil)))
        cnRow(port name h nout nin)
        spsWriteWaves(strcat(cnDir "/" name "_pnoise.csv") "f_Hz,out_V_rtHz,absHdm_pac,deemb_in_V_rtHz" list(nout ece203Mag(h) nin))
        ece203SaveNetlist(cnCell strcat("ece203_chopnoise_" name))
        t)
      t)
    unless( ok acSay("cn %s: FAILED %L\n" name errset.errset) fprintf(port "%s,failed\n" name))
  )
)

procedure( cnRunJob()
  let( (port)
    ece203LibInfo()
    otaTb(cnCell cnSpecs())
    unless( isDir(cnDir) createDir(cnDir) )
    port = outfile(strcat(cnDir "/spectre_compare.csv") "w")
    fprintf(port "case,Hdm_10,Hdm_100,out_rms_0p1_250_V,app_in_rms_V,deemb_in_rms_V,in_ref_1Hz_V_rtHz,in_ref_100Hz_V_rtHz\n")
    cnStaticU(port)
    cnPeriodic(port "U_pss_pnoise" 0.0)
    cnPeriodic(port "C_pss_pnoise" 1.0)
    close(port)
    t
  )
)
