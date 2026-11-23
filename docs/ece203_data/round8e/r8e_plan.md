# R8E pre-run plan — proportional Cc / Cfb scaling (Cc/Cfb = 120) on the frozen R8B real-MOS chopper

Task: `docs/ECE203_round8e_proportional_capacitance_highpass_recovery_task.md`. Committed **before any R8E Spectre run**.

## Code

- **New files:**
  - `ece203_r8e.il`, `tools/r8e_watchdog.sh`, `tools/r8e_tran_watchdog.sh`;
  - `batch/ece203_r8e_{build,static,pss,pac,pnoise,tran}.il`;
  - in this folder: `r8e_netlist_audit.py`, `r8e_budget.py`, `r8e_analysis.py`.
- **Backward-compatible hooks in older code.** Each default reproduces the old behaviour exactly.
  - `ece203_r8_noise.il`:
    - `r8VarsExtra` — design-variable overrides appended last by `r8Vars`;
    - `r8SaveI` — extra current saves in `r8Periodic`.
  - `ece203_r8c.il`:
    - `r8cCurSave` — `'auto` = the R8C current saves;
    - `r8cPacStop` — `"250"`;
    - a sideband-0 Zin curve is written only when `/VSP/PLUS` is in `r8cCurSave`.

## Cases (cells built from `r8bSpecs()` unchanged; only cc / cfb change, set per run)

| Case | Cell | k | Cc/side | Cfb/side | Budget (predicted from the 439 pF G0 netlist) | Model fL_ON = 0.338/k |
|---|---|---|---|---|---|---|
| G0 | `Project/ece203_r8b_tb_noeoc_chp` (read-only reference) | 1 | 60p | 0.5p | 439.0 pF | 0.338 (measured R8C) |
| A2 (`c2`) | `Project/ece203_r8e_tb_c2` | 2 | 120p | 1.0p | 560.0 pF | 0.169 |
| B35 (`c35`) | `Project/ece203_r8e_tb_c35` | 3.5 | 210p | 1.75p | 741.5 pF | 0.097 |

- The model is a prediction to be falsified, not a result.
- The predicted OFF fL is about 0.047 Hz for A2 and 0.027 Hz for B35. OFF is reported but not gated.
- No other k, no separate Cc or Cfb change, and no MOS / bias / RLP / CLP / COUT / pseudo-R / TG / clock change.

## Netlist audit (`r8e_netlist_audit.py`, before any result is used)

- **Static (B_ and L_ netlists, c2 and c35):** compared with the same-type G0 netlist from the same R8E code. Zero instances removed, added or changed; subckts identical; parameter block differs **only** in `cc` and `cfb`, with the case values.
- **PSS / PAC / PNoise netlists:** compared with the R8B gate B PSS, the R8C A1 PAC and the R8B gate D PNoise netlists respectively. Same rule; `pacd` is allowed only where the reference itself differs.
- Any other difference → STOP that case.

**Budget** (`r8e_budget.py`, from the real L_ netlist; reproduces 439.0 pF on the R7F G0 netlist):
- counted: CCP, CCN, CFP, CFN, CLBP, CLBN, CLP_P, CLP_N, CCMP, CCMN, CVG;
- excluded: COUT (stress load), CEP/CEN/CER (electrodes), CBODY, and CCX = cc·dcc (mismatch fixture; dcc = 0 in the design).

## Stage A — static TG phase A (job `ece203_r8e_static`, cases g0, c2, c35)

- The R7F measurement unchanged: `r7cStageB1` (dc op, DM AC with dcc 0.01, CM AC → CMRR60, Zin(10 Hz) = vd / I(VSP), CMFB and DRL STB, op info) plus `r7eLp` (output transfer, CMRR60 at the output).
- Load is COUT 10 pF/side (in the cell). Options gmin 1e-18, iabstol 1e-17, reltol 1e-5.

**Hard gates** (all of):

| # | Gate |
|---|---|
| 1 | Audit PASS and netlisted cc/cfb equal the case values |
| 2 | Zin(10 Hz) ≥ 100 MΩ |
| 3 | CMFB PM ≥ 60° and DRL PM ≥ 60° |
| 4 | CMRR60 (fp/fn) ≥ 85 dB |
| 5 | P < 4 µW |
| 6 | Design C < 1000 pF |
| 7 | op/on CM within 1 mV of 0.9 V, and min XA saturation margin ≥ 50 mV |

- Any hard FAIL → that case STOPS (no ON). If both cases fail → R8E STOP.
- **Reported, not hard:**
  - fL_OFF (expected to drop);
  - fH_OFF against 225–275 Hz;
  - H100_OFF against 38–42 dB. Outside 38–42 dB with everything else healthy, the case is marked "static gain caution" and still goes to ON PAC.

## Stage B — ON PSS + PAC (order A2, then B35; only hard-gate-passing cases)

- **PSS** (`ece203_r8e_pss`, AC_R8E_STEP = b1):
  - settings = R8B a1: fund 2k, harms 40, maxacfreq 200k, errpreset moderate, tstab 5 ms, maxperiods 40, cmin 1e-17, itres 1e-4;
  - chen 1, vd 0, adm 0, dcc 0, pacd 0;
  - writepss `/tmp/lix015_r8e_<case>/pss_converged.pss`.
- **PAC** (`ece203_r8e_pac`):
  - readpss; relative, relharmnum 0, 0.01–1000 Hz at 40/dec, maxsideband 1, pacd 1;
  - clocks pacmag 0; the measured V(ep)−V(en) must be 2 V at 0°.
- **Save list:** identical in PSS, PAC and PNoise — node voltages plus the VSP current, which is needed for Zin. The analysis checks that the PAC run reports "achieved in 1 shooting-Newton iteration" (no R8C-type equation-size mismatch).
- **Retry:** at most one per case, b2 = R8 a2 (maxperiods 60, itres 1e-7), PSS only, circuit unchanged. It is run only after a PSS without the explicit "steady-state solution was achieved" message; the failed log is kept. If it fails too → that case is BLOCKED.

**Measured:** fL_flat, fH_flat (same 5–10 Hz plateau, −3 dB below and above), H100 and phase, H at 0.1/1/10/250 Hz, node corners (p−n, fp−fn, bufp−bufn), sideband-0 Zin(10 Hz) = (ep−en)₀ / I(VSP)₀ (same definition as the static Zin), Q = fL_ON/fL_OFF, and PSS node ranges.

**ON gates** (all of): PSS converged; fL_ON 0.09–0.11 Hz; fH_ON 225–275 Hz; H100_ON 38–42 dB; PAC Zin(10 Hz) ≥ 100 MΩ.
- A case failing an ON gate gets no PNoise and no tran.
- The expected A2 fL ≈ 0.17 Hz is a scout non-PASS. B35 always runs if its static hard gates pass.
- No extra k.

## Stage C — PNoise (one case only)

- **Eligibility:** only a case with all ON gates PASS. If B35 passes, B35 is used (task priority). Otherwise A2, if it passes. If neither passes → no PNoise ("compensation hypothesis failed / partly holds").
- **Definition:** identical to R8B Stage D (`r8Periodic` 'pn): readpss of the same file, PAC 0.1–250 Hz at 20/dec, maxsideband 1 (normalisation), PNoise timeaverage, relative relharmnum 0, 0.1–250 Hz at 20/dec, (outp, outn), with noiseSummary.
- **Ladder:** S30 → S60 → S90.
  - Converged if S60→S90 changes ≤ 5 % in both RMS metrics and ≤ 10 % in the input density at 1, 10 and 100 Hz.
  - Otherwise one S120, with the same test on S90→S120. If that fails → NOT CONVERGED and no spec claim.
- **Metrics:** application = out RMS / |Hon(100)|; de-embedded = √∫(Sout/|Hon(f)|)² df, both over 0.1–250 Hz, each judged against < 3 µVrms independently. R8B reference: 3.141 / 3.994 µV.

## Stage D — 60 ms tran (at most one case)

- **Run** only if Stage C converged **and** the application metric < 3 µV.
- If application < 3 but de-embedded ≥ 3, it still runs once, labelled "Noise definition-dependent / not full signoff".
- **Definition:** the R7F `r7eStageC` unchanged — 2 kHz, 1 mV 100 Hz DM, 60 ms, maxstep 0.5 µs, cmin 1e-17. Analysis is `round7e/r7e_analysis.py` on the 20–40 and 40–60 ms windows.
- **Compared with R7F G0:** Hout100, H3 (R7F −85.8 dBc), output residual and spurs, CM, power, ranges.

## Budget, stops, safety

- **Runs:**
  - static: 3 (g0 reference + 2);
  - PSS: ≤ 2 first attempts + ≤ 1 retry per case;
  - PAC: ≤ 2;
  - PNoise: ≤ 4 runs on one case;
  - tran: ≤ 1.
- **Not run:** PVT/MC, any optimisation, MATLAB, R8F.
- **Watchdogs** kill only `/tmp/lix015_r8e_<case>/sim_<tag>` and `/tmp/lix015_r8e_tran/sim_<tag>`. The user's Virtuoso/Spectre is never touched.
- **Read-only:** R8B/R8C/R8D cells and data.
- **No PDK model content in the repo.**
