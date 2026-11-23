# ECE203 R8B — removing the inert EOC + CHP fixture lets the real-MOS 2 kHz chopper PSS converge; chopper ON/OFF noise measured (2026-11-23)

- Task: [ECE203_round8b_pss_fixture_isolation_task.md](ECE203_round8b_pss_fixture_isolation_task.md).
- Pre-registration (`ece203_data/round8b/r8b_plan.md`):
  - plan: commit 72d7e79, before any run;
  - update 1, which registered S90 before it ran: e63d2a0.
- Code:
  - `ece203_r8b.il` builds the new cell and wraps the unchanged R8 measurement code;
  - `ece203_r8_noise.il` gained only a backward-compatible watchdog-name variable;
  - watchdog: `tools/r8b_watchdog.sh`.
- Data: [ece203_data/round8b/](ece203_data/round8b/).
- Setup: cmrf7sf tt, 27 °C, Spectre 15.1.0, options gmin 1e-18, iabstol 1e-17, reltol 1e-5.

## Verdict

| Gate | Result | Evidence |
|---|---|---|
| **A — the cleanup does not change the circuit** | **PASS** | Netlist: exactly EOC and CHP removed. OFF DC / AC / noise identical to R8 (largest difference 6.5e-5 %) |
| **B — PSS with the R8 a1 settings** | **PASS** | Spectre: "steady-state solution was achieved in 3 shooting-Newton iterations, followed by finite-difference refinement". No retry needed |
| **C — PAC sideband 0** | **PASS** | \|Hon(100 Hz)\| = **83.251 V/V** (R7F chopped transient: 83.247) |
| **D — PNoise S10/30/60/90** | **converged** by the registered criterion | S60 → S90: app +0.97 %, de-embedded +1.34 %, density +2.1 / +0.6 / +0.04 % at 1 / 10 / 100 Hz |
| **ON/OFF 1/f suppression** | **QUANTIFIED** | Input RMS 16.87 → **3.14 µV** (application, 5.37×) and 16.32 → **3.99 µV** (de-embedded, 4.09×) |
| **Course spec < 3 µVrms** | **FAIL** (ON 3.14 / 3.99 µV, OFF 16.9 / 16.3 µV) | Not met with either metric |
| New finding | **periodic fL ≈ 0.34 Hz** with the chopper running (static 0.095 Hz) | PAC sideband 0; not cross-checked by a low-frequency transient |

**Causal conclusion.** Removing two inert fixture elements is enough to turn the R8 PSS from non-convergent into converged in 3 iterations. Those elements are EOC (vcvs, gain 1) and CHP (1 MF):
- R8 a1/a2 used identical settings and did not converge in 40 / 60 iterations;
- the norm here fell 1.6e6 → 1.31e5 → 0.32.

This supports the R8 diagnosis. It does not rule out other slow modes in general, but none blocked this PSS.

## Gate A — fixture isolation is physically neutral (chopper OFF)

- **Netlist audit** (`r8b_netlist_audit.txt`, 7 netlists: A, B, C, D S10/30/60/90):
  - removed = {EOC, CHP} only;
  - nothing added or changed;
  - the parameters are identical, except pacd 0 → 1 in the PAC/PNoise runs, which is the PAC drive;
  - all 6 subckts are identical;
  - node `ocx` has no connection left;
  - RHP (1 TΩ, oac–vref) and EB2 (gain −kb·wob, with kb = 0 and wob = 0) are kept.
  - **AUDIT PASS × 7.**
- **OFF equivalence** (`r8b_gateA.csv`, `r8b_gateA_groups.csv`):

| Quantity | Result |
|---|---|
| 13 DC nodes (op, on, fp, fn, p, n, bufp, bufn, outp, outn, vg, ib, pref) | identical (0 V difference) |
| I_VDD / I_VDDD | identical |
| \|Hoff\| at 0.1 / 1 / 10 / 60 / 100 / 250 Hz | identical (100 Hz: 85.66635) |
| Sout checkpoints | ≤ 6.5e-5 % |
| Input RMS | app 16.8670 µV, de-embedded 16.3247 µV, both identical to R8 |
| Source-group ranking | identical (input pair 1/f 54.0 %, PMOS loads 1/f 44.9 %, …) |

## Gate B — PSS (chopper ON, zero input)

- **Settings:** identical to R8 a1 (fund 2k, harms 40, maxacfreq 200k, errpreset moderate, tstab 5 ms, maxperiods 40, cmin 1e-17, itres 1e-4).
- **Run** (`raw/gateB/`): tstab 2.9 s, 3 shooting iterations, 4.7 s in total, 1091 accepted steps.
- **Saved solution:** `pss_converged.pss` (SHA-256 in `raw/gateB/pss_converged.pss.sha256`). The PAC/PNoise runs reuse it through `readpss`; each re-check reports "achieved in 1 shooting-Newton iteration".
- **Periodic waveform** (`r8b_pss_check.csv`, compared with the R8 20 ms zero-input transient over 10–20 ms):
  - every node returns exactly to its start value (finite-difference refinement);
  - the ranges match the transient within 30 µV — for example p: 0.896735–0.902408 V (PSS) vs 0.896713–0.902432 V (transient); vg: 1.318914–1.321479 vs 1.318914–1.321483 V;
  - out DM is −5.3 to −3.4 nV;
  - no clipping.
- Spectre noted trapezoidal ringing in tstab and suggested `method=trap`. Not applied: it converged without it.

## Gate C — PAC sideband 0 (pacd 1, VSN pacphase 180, clocks pacmag 0)

Data: `r8b_pac.csv`, `raw/gateC/`.

| f (Hz) | 0.1 | 1 | 10 | 100 | 250 |
|---|---|---|---|---|---|
| \|Hon\| (PAC, chopper ON) | 25.57 | 85.75 | 90.36 | **83.251** (−23.8°) | 61.93 |
| \|Hoff\| (static AC, chopper OFF) | 67.73 | 92.78 | 93.03 | 85.67 | 63.73 |

- The measured ep − en drive is 2.000 V.
- Hon(100 Hz) agrees with the R7F 60 ms chopped transient (83.2466 V/V with a 1 mV, 100 Hz input) to 0.006 %. The two definitions differ (small-signal PAC around the zero-input PSS vs a large-signal fit), but the gains match.
- **New finding:** with the chopper running, the sideband-0 high-pass corner rises.
  - The plateau-referenced −3 dB point is **fL ≈ 0.34 Hz**: maximum 90.36 at 8.9 Hz.
  - The static TG-phase-A value is 0.095 Hz.
  - At 0.1 Hz the ON gain is 25.6, i.e. −10.9 dB below the plateau.
- The upper corner is unchanged (234.5 Hz with the 10 pF load).
- Mechanism not isolated. One candidate is a switched-capacitor conductance at the high-impedance summing nodes p/n through the input chopper.
- **This means the course fL 0.09–0.11 Hz is met only statically, not under chopping.** It is a PAC result; a slow-signal transient check was not run.

## Gate D — PNoise sideband ladder

- Settings: timeaverage (the Spectre default, confirmed in its help), output (outp, outn), relative, relharmnum 0, 0.1–250 Hz at 20 points/decade, pnoisemethod default.
- Each count took 30–46 s.
- Data: `r8b_sideband_convergence.csv`, `raw/gateD/`, `r8b_sideband.png`.

| maxsideband | Output RMS | Input app | Input de-embedded | Input density at 1 / 10 / 100 Hz (nV/√Hz) |
|---|---|---|---|---|
| 10 | 248.97 µV | 2.9906 µV | 3.7362 µV | 898 / 193.6 / 152.3 |
| 30 | 255.62 µV | 3.0704 (+2.67 %) | 3.8708 (+3.60 %) | 950 / 196.7 / 153.2 |
| 60 | 258.99 µV | 3.1110 (+1.32 %) | 3.9410 (+1.81 %) | 978 / 198.2 / 153.4 |
| **90 (final)** | **261.50 µV** | **3.1411 (+0.97 %)** | **3.9938 (+1.34 %)** | **998 / 199.3 / 153.5** (+2.1 / +0.55 / +0.04 %) |

- **Convergence.** The last two counts (S60/S90) are within the registered 5 % / 10 % limits; so was S30/S60.
- **Residual truncation.** The values still rise by about 1 % per step, so the untruncated noise is probably a few percent higher than the S90 value. That only strengthens the conclusion that the spec fails.
- **Integration check.** OCEAN `integ` and the Python trapezoid (`r8_spec.py`) agree to < 0.001 % at every count.

## Chopper OFF vs ON, same hardware

Each case is normalised by its own transfer. Data: `r8b_onoff_summary.csv`, `r8b_onoff.png`.

| Quantity | OFF (static phase A) | ON (2 kHz, S90) | OFF / ON |
|---|---|---|---|
| \|H(100 Hz)\| | 85.67 | 83.25 | |
| Output RMS 0.1–250 Hz | 1.4449 mV | 0.2615 mV | 5.5× |
| **Input, application type** | **16.87 µV** | **3.141 µV** | **5.37× RMS, 28.8× power** |
| **Input, point-wise de-embedded** | **16.32 µV** | **3.994 µV** | **4.09× RMS, 16.7× power** |
| Input density at 0.1 / 1 / 10 / 100 / 250 Hz (µV/√Hz) | 22.66 / 6.04 / 1.72 / 0.529 / 0.343 | 10.23 / 0.998 / 0.199 / 0.153 / 0.153 | |
| Output density at 0.1 / 1 / 10 / 100 Hz (µV/√Hz) | 1535 / 561 / 160 / 45.4 | 262 / 85.6 / 18.0 / 12.8 | |
| **< 3 µVrms** | FAIL | **FAIL** (both metrics) | |

**Why the de-embedded ON value is higher than the application value.** The de-embedded metric weights 0.1–0.5 Hz by 1/|Hon|². |Hon| is low there because of the 0.34 Hz periodic corner. The ON input density at 0.1 Hz (10.2 µV/√Hz) is mostly this de-embedding factor; at the output, ON is 5.9× lower than OFF at 0.1 Hz.

**Sources, ON (S90) vs OFF, 0.1–250 Hz** (`r8b_noise_groups.csv`, `r8b_sources.png`). The input split is approximate: each group's share of the band output power times the band's de-embedded input power.

| Group | OFF share / ≈ input µV | ON share / ≈ input µV |
|---|---|---|
| XA input pair M1/M2, 1/f | 54.0 % / 12.0 | **36.6 % / 2.42** (5× lower) |
| XA PMOS loads M3/M4, 1/f | 44.9 % / 10.9 | 3.8 % / 0.78 (14× lower) |
| XA PMOS loads M3/M4, thermal | 0.5 % / 1.16 | **27.7 % / 2.10** (folded white noise) |
| XA input pair M1/M2, thermal | 0.4 % / 0.98 | **19.5 % / 1.76** |
| Electrode / source resistors, thermal | 0.07 % / 0.43 | 4.6 % / 0.85 |
| XCD CD, 1/f (after the demodulator, not chopped) | 0.14 % / 0.61 | 4.2 % / 0.82 |
| XCI input TG, thermal + 1/f | ~0 | 1.9 % + 1.4 % / 0.55 + 0.47 |
| XPRN/XPRP pseudo-R, thermal | 0.01 % | 0.18 % / 0.17 |
| CMFB, DRL, XCO TG, bias, RLP | ≈ 0 | ≈ 0 |

What the source split shows:
- The chopper removes most of the PMOS-load 1/f noise (14×) and 80 % of the input-pair 1/f amplitude.
- The ON floor is now about half OTA thermal noise folded down from the chopper harmonics (about 2.7 µV of the 3.14) and half residual input-pair 1/f noise (about 2.4 µV).
- Small additions come from the electrodes, the CD (which sits after the demodulator) and the TG.
- **Reaching < 3 µV would need lower OTA thermal noise or a different residual-1/f behaviour, not more chopping of the same kind.**
- These are observations, not tested remedies.

## Not mixed in, not verified

- The deterministic R7F items (141.7 µV switching residual at the output, H3, the pseudo-R rectification drift of −0.22 mV/s) are not noise and are not in any number above.
- The noise is time-averaged (timeaverage), tt 27 °C only.
- Not modelled: clock jitter, supply noise, sampling by any ADC, PVT/MC.
- The ideal 4 MΩ / 148 pF LP resistor is not checked as a physical device.
- The periodic fL of 0.34 Hz has not been checked by a transient.
- R5N-F F2 (2.88 µV) is a different, larger OTA. It is an engineering comparison only, not a causal baseline.

## Files

`ece203_data/round8b/`:
- `r8b_plan.md`
- `r8b_netlist_audit.py`, `r8b_netlist_audit.txt`
- `r8b_gateA.py`, `r8b_gateA.csv`, `r8b_gateA_groups.csv`
- `r8b_pss_check.csv`
- `r8b_pac.csv`
- `r8b_sideband_convergence.csv`
- `r8b_onoff_summary.csv`
- `r8b_noise_groups.csv`
- `r8b_analysis.py`
- `r8b_onoff.png`, `r8b_sideband.png`, `r8b_sources.png`
- `raw/gateA..D`: netlists, spectre.out(.gz), noise summaries per band and spot, spectra, PAC curves, PSS waveforms, job logs, watchdog log

New Cadence cell: `Project/ece203_r8b_tb_noeoc_chp`. All old cells were read only.

Stopped; waiting for GPT review.
