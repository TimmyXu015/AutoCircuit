# ECE203 R8 — real-MOS 2 kHz chopper noise on R7F: OFF anchor measured, periodic analysis BLOCKED (2026-11-23)

- Task: [ECE203_round8_real_mos_chopper_noise_task.md](ECE203_round8_real_mos_chopper_noise_task.md).
- Pre-registration (`ece203_data/round8/r8_plan.md`):
  - plan: commit 9c7c43b, before any run;
  - update 1, with the a1 failure and the a2 retry: 17c1436, before a2.
- Script: `ece203_r8_noise.il`.
- Watchdog: `tools/r8_watchdog.sh` (stops a run if spectre.out stops growing or a wall-clock limit is hit).
- Jobs: `ece203_r8_a / t0 / pss / pac / pn`.
- Data: [ece203_data/round8/](ece203_data/round8/).
- Circuit: `Project/ece203_r7f_tb_gain_g0_load10p`, **read-only**. Nothing was rebuilt or modified.

## Verdict (evidence level in brackets)

| Stage | Result |
|---|---|
| **A — chopper OFF, ordinary noise** | **PASS** [Spectre noise + noiseSummary, real cmrf7sf MOS; integrals cross-checked to 0.05 %] |
| **B — PSS / PAC (chopper ON)** | **BLOCKED**. PSS a1 and the one registered retry a2 both **NOT CONVERGED** [Spectre `ERROR (SPCRTRF-15433): pss analysis did not converge`]. PAC NOT RUN |
| **C — PNoise, sideband ladder** | **NOT RUN** (Stage B blocked) |
| **ON/OFF 1/f suppression** | **NOT QUANTIFIED**. No chopper-ON noise number exists from this round |
| **Course spec < 3 µVrms (0.1–250 Hz)** | **OFF: FAIL** (16.32–16.87 µV). **ON: NOT VERIFIED** |

STOP, as the task requires: two PSS attempts used, no circuit changes, no switch to another noise method.

## Measurement setup (checked)

- **The only operational variable is `chen`**: 0 is the static phase A (pa = 1, pb = 0); 1 is the 2 kHz TG with tch = 500 µs.
- **Noise-run settings:** vd = 0, dcc = 0, vcmin = 0. Everything else is R7F G0 as accepted: cc 60 p, LP 4.0 MΩ / 148 pF, COUT 10 pF per side, real TG / FD OTA / CMFB a2 / DRL / CD / pseudo-R / PMOS bias.
- **Simulator:** Spectre 15.1.0 64-bit, cmrf7sf tt, 27 °C. Options gmin 1e-18, iabstol 1e-17, reltol 1e-5.
- **Netlist audit** (`r8_netlist_audit.txt`): every R8 netlist (A, T0, PSS a1, PSS a2) has instances and subckts identical to the R7F G0 loaded netlist. Only the analysis variables chen / adm / dcc differ, plus the analysis statements. **AUDIT PASS** for all four.
- **Stimulus:**
  - VSP: `mag = adm/2`, `pacmag = pacd`, `pacphase = 0`.
  - VSN: `mag = −adm/2`, `pacmag = pacd`, `pacphase = 180` (positive PAC amplitude + 180°).
  - The clocks have pacmag 0. VSPS/VSNS have amplitude vd/2 = 0.
  - Transfers are divided by the measured ep − en.
- **Output:** differential, `noise (outp outn)`.
- **Spectre facts read from its own help on the server** (`raw/spectre_help/`):
  - pnoise `noisetype` defaults to `timeaverage`, i.e. the time-average output noise density;
  - shooting `maxsideband` defaults to 7;
  - pss has `cmin`, `tstab`, `maxperiods`, `maxacfreq`, `itres`, `writepss` / `readpss`.

## Stage A — chopper OFF (TG static phase A), ordinary noise 0.1–250 Hz

Data: `r8_static_noise.csv`, `r8_noise_summary.csv`, `raw/stageA/` (spectra, AC, noiseSummary dumps per band and spot, netlist, spectre.out), `r8_stageA.png`.

| Quantity | Value |
|---|---|
| \|Hoff\| at 0.1 / 1 / 10 / 60 / 100 / 250 Hz | 67.73 / 92.78 / 93.03 / 90.21 / **85.67** / 63.73 V/V (100 Hz phase −23.96°) |
| Output noise outp − outn, 0.1–250 Hz | **1.4449 mVrms** |
| Input-referred, application type (out RMS / \|Hoff(100)\|) | **16.87 µVrms** |
| Input-referred, point-wise de-embedded | **16.32 µVrms** |
| Input density at 0.1 / 1 / 10 / 100 / 250 Hz | 22.66 / 6.04 / 1.72 / 0.529 / 0.343 µV/√Hz |
| Output density at the same points | 1535 / 561 / 160.2 / 45.4 / 21.9 µV/√Hz |
| DC operating point | op = on = 0.89951 V, p = n = 0.89951 V, out = 0.54014 V; I_VDD / I_VDDD = 980.6 / 302.4 nA (= R7F) |

**Cross-checks:**
- OCEAN `integ` vs Python trapezoid on the exported output spectrum: 0.000 % difference. The de-embedded value differs by 0.044 %.
- The noiseSummary total (2.0878e-6 V²) equals the trapezoid in every band to 0.00 %.
- One flaw found and worked around: the de-embedded input column the SKILL script wrote into `A_off_noise.csv` sits on a different x-grid (the OCEAN waveform quotient). It is **not used**. All input-referred numbers come from `r8_spec.py`, which uses the output PSD plus the exported AC |H|.

**Noise sources, chopper OFF, 0.1–250 Hz, output power share** (the input-referred split is approximate; see the script):

| Group | Kind | Share | ≈ input µVrms |
|---|---|---|---|
| XA input pair M1/M2 | flicker | **53.99 %** | 12.00 |
| XA PMOS loads M3/M4 | flicker | **44.91 %** | 10.94 |
| XA M3/M4, M1/M2 | thermal | 0.51 % + 0.36 % | 1.16, 0.98 |
| XCD CD | flicker | 0.14 % | 0.61 |
| Electrode / source resistors | thermal | 0.07 % | 0.43 |
| XPRN/XPRP pseudo-R, XCI TG, XA cascodes, RLP | – | ≤ 0.013 % each | ≤ 0.19 |
| XC CMFB, XD DRL, XCO TG, XA tail, bias MP0–2 | – | < 1e-7 % | ~0 |

Per band (`r8_noise_summary.csv`, `r8_stageA.png`): the input pair dominates from 1 Hz up; the PMOS loads dominate below 1 Hz. **98.9 % of the OFF noise is OTA 1/f noise.** This is the noise a chopper is meant to move away from baseband, which is why the ON measurement matters.

## Stage B — chopper ON: zero-input transient, then PSS (BLOCKED)

**Zero-input ON transient** (T0: 20 ms, setting C — maxstep 0.5 µs, cmin 1e-17; data `r8_t0_summary.csv`, `raw/stageB/T0_*`):
- Symmetric. The out DM mean is −5 nV and its peak-to-peak 3 nV.
- The pseudo-R nodes p = n sit at 0.8996 V mean, with ±2.9 mV of chopper ripple.
- The CMFB output vg is 1.3189–1.3215 V. Nothing clips.
- Every node changes by less than 1e-7 V per period after 10 ms, and by about 1e-9 V on average. **The circuit is periodic in practice.**

**PSS attempts** (`r8_pss_attempts.csv`, `r8_stageB_pss.png`, `raw/stageB/B_pss_a*_spectre.out.gz`, netlists, convergence lines):

| | a1 (pre-registered) | a2 (the one registered retry) |
|---|---|---|
| Settings | fund 2k, harms 40, maxacfreq 200k, errpreset moderate, tstab 5 ms, maxperiods 40, cmin 1e-17, itres 1e-4 (default) | identical except **itres 1e-7, maxperiods 60** |
| Integrator | tstab: traponly (TG gate ringing notices); iterations: gear2only, steadyratio 1e-3 | same |
| Shooting iterations | 40 in about 45 s (0.7 s each) | 60 in about 60 s |
| Conv norm | 1.6e6 after tstab, then oscillating 4.35 … 4.97e4, no downward trend | oscillating 4.58 … 1.34e5, no trend |
| Largest residual | branch currents of ideal sources **VREF:p** and **EOC:p** (pA–nA, against abstol(I) = 10 aA) | same: VREF:p and EOC:p in 92 of the 99 logged norms, VCAS:p 4, VCKA:p 2, XCI.MP1.g1 1 (after tstab) |
| Result | `pss analysis did not converge` | `pss analysis did not converge` |

- The unconverged solutions Spectre saved were renamed `*_UNCONVERGED_saved.pss` in /tmp and **never read**.
- PAC and PNoise were not run.

**Diagnosis (strongly supported by the logs, not tested — no run was allowed for it).**
- The R7F bench still contains an **inert diagnostic common-mode-sense branch** from the R6A era:
  - `EOC (ocx vref ocm vref) vcvs gain=1`, driving `CHP (ocx oac) capacitor c=1M`, i.e. **1 megafarad**;
  - `RHP (oac vref) resistor r=1T`;
  - which feeds `EB2 ... gain = −kb·wob`, where **kb = 0**.
- This branch has no effect on the signal path, the DC operating point, AC or ordinary noise. CHP is an open circuit at DC and EB2 has zero gain.
- For PSS, however, it adds a mode with τ = 1 MF × 1 TΩ = 1e18 s. Its Floquet multiplier is exp(−500 µs / 1e18 s) = 1 to machine precision, so the DC charge on CHP is undetermined and the shooting Newton matrix is singular.
- That matches the logs:
  - the residual sits on exactly the two sources of that loop, EOC and VREF;
  - the two residuals are equal and opposite iteration to iteration (e.g. +33.22 / −33.29 nA, −53.33 / +52.07 nA);
  - the norm oscillates instead of converging;
  - a tighter linear solve (a2) did not help.
- The real slow modes (pseudo-R × 60 pF, τ ~ seconds; multipliers ≈ 0.9997) are close to singular, but not singular.

**Possible next round (needs your authorization; not done):**
- Make a noise-only copy of the R7F bench with the inert diagnostic branches removed: EOC/CHP/RHP/EB2, and the other zero-gain aids EB1 / EG1 / EG2 / VUB / VUG.
- First prove its static DC/AC/noise is identical to R7F, then rerun the PSS a1 settings.
- Alternatives: PSS with a loosened `steadyratio`, or a transient-noise method. Each is a method change that needs its own task.

## Results the task asked for

| Item | OFF | ON |
|---|---|---|
| H(100 Hz), same MOS | 85.67 V/V (static AC, COUT 10 pF, dcc 0) | NOT RUN (PAC blocked); the R7F chopped transient gave 83.25 with a 1 mV signal (reference only) |
| Output RMS 0.1–250 Hz | 1.4449 mV | NOT RUN |
| Input, application type / de-embedded | 16.87 / 16.32 µVrms | NOT RUN |
| Low-frequency input PSD | 22.66 µV/√Hz at 0.1 Hz, 6.04 at 1 Hz, 1.72 at 10 Hz | NOT RUN |
| Sideband convergence (S10/30/60/90) | – | NOT RUN (`r8_sideband_convergence.csv` = NOT RUN) |
| PSS convergence evidence | – | **two non-converged attempts, logs kept** |
| Noise sources | OTA input-pair 1/f 54 %, PMOS-load 1/f 45 % | NOT RUN (folding unknown) |
| < 3 µVrms | **FAIL** | **NOT VERIFIED** |

**Not mixed in:** the deterministic R7F items (141.7 µV switching residual, H3, the pseudo-R rectification drift) are not noise and are not part of any number above.

**Not compared:**
- R5N-F F2's 2.88 µV comes from a different, much larger OTA.
- The R3E (ideal 1 MHz) and R5 (4 kHz, sidebands not converged) results come from other circuits.
- None of them is used to infer a chopper improvement here.
- The OFF 16.3–16.9 µV is in the same range as the earlier small-OTA non-chopper results (R4/R5 ~16.6 µV); that is noted only as context.

## Files

`ece203_data/round8/`:
- `r8_plan.md`
- `r8_netlist_audit.txt`
- `r8_static_noise.csv`, `r8_noise_summary.csv`, `r8_pss_attempts.csv`, `r8_t0_summary.csv`
- `r8_pac.csv`, `r8_sideband_convergence.csv` (both NOT RUN markers)
- `r8_analysis.py`, `r8_spec.py`, `r8_integrate.py`, `r8_noise_groups.py`
- `r8_stageA.png`, `r8_stageB_pss.png`
- `raw/stageA`, `raw/stageB` (incl. the T0 transient `.csv.gz` + sha256, PSS spectre.out.gz, watchdog log)
- `raw/spectre_help`

No new Cadence cell or ADE state was created (the circuit was used read-only). Stopped; waiting for GPT review.
