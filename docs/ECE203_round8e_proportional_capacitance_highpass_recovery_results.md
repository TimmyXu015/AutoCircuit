# ECE203 R8E — proportional Cc/Cfb scaling: B35 (210 p / 1.75 p) restores the chopped fL to 0.0997 Hz and passes the operating-mode course gates at tt/27 °C (2026-11-23)

- Task: [ECE203_round8e_proportional_capacitance_highpass_recovery_task.md](ECE203_round8e_proportional_capacitance_highpass_recovery_task.md).
- Pre-run plan: [ece203_data/round8e/r8e_plan.md](ece203_data/round8e/r8e_plan.md), commit a022e02, before any R8E Spectre run. No plan updates; no retries were needed.
- Code:
  - `ece203_r8e.il`, `tools/r8e_watchdog.sh`, `tools/r8e_tran_watchdog.sh`, batch jobs `ece203_r8e_{build,static,pss,pac,pnoise,tran}`;
  - backward-compatible hooks: `r8VarsExtra` / `r8SaveI` in `ece203_r8_noise.il`, and `r8cCurSave` / `r8cPacStop` in `ece203_r8c.il`. Their defaults give exactly the old behaviour.
- Data: [ece203_data/round8e/](ece203_data/round8e/).
- Setup: cmrf7sf tt, 27 °C, Spectre 15.1, gmin 1e-18, iabstol 1e-17, reltol 1e-5. 2 kHz real MOS TG chopper, real MOS pseudo-R, COUT 10 pF/side.

## Verdict

| Stage | A2 (`ece203_r8e_tb_c2`, 120 p / 1 p) | B35 (`ece203_r8e_tb_c35`, 210 p / 1.75 p) |
|---|---|---|
| Netlist audit | PASS. Only `cc` and `cfb` differ from G0. | PASS. Only `cc` and `cfb` differ; 7 netlists checked. |
| A — static hard gates | PASS | PASS |
| B — ON PSS/PAC | PSS converged. **fL_ON 0.1707 Hz → FAIL** (scout; model 0.169) | PSS converged. **fL_ON 0.0997 Hz PASS**; fH, gain and Zin also PASS |
| C — PNoise | NOT RUN (gated) | **S90 converged: app 2.470 µV, de-embedded 2.574 µV — both < 3 µVrms** |
| D — 60 ms tran | NOT RUN | **PASS:** 38.44 dB; H3 −94.2 dBc; residual 76 µVrms; no clipping; 2.306 µW |

**B35 meets every operating-mode (chopper ON) course gate measured here, at tt/27 °C nominal.** This is not a full sign-off:
- The static OFF fL drops to 0.027 Hz. That is outside 0.09–0.11 Hz, a known and stated conflict, and is not claimed as PASS.
- CMRR, the phase margins and Zin are static (OFF) measurements, plus a PAC Zin. ON-mode CMRR was not measured.
- Not run: PVT, MC, clock jitter, physical R/C models, ADC loading.

## Design values and budget (from real netlists; `r8e_design_budget.csv`)

| | G0 (R8B, read-only) | A2 | B35 |
|---|---|---|---|
| Cc / Cfb per side | 60 p / 0.5 p | 120 p / 1.0 p | 210 p / 1.75 p |
| Design capacitance | 439.0 pF | **560.0 pF** | **741.5 pF** (< 1 nF) |

- Counted: CCP, CCN, CFP, CFN, CLBP, CLBN, CLP_P, CLP_N, CCMP, CCMN, CVG.
- Excluded: COUT 10 pF/side (stress load), the electrode/body model, and the CCX mismatch fixture.
- The script reproduces 439.0 pF on the R7F G0 netlist.
- **Audit:** each case's B_/L_ static, PSS, PAC and PNoise netlists, and the B35 tran netlist, were compared with the G0 / R8B / R8C / R7F netlists of the same analysis type. In all of them: zero instance changes (vs R7F, only the EOC and CHP that R8B already removed), identical subckts, and parameter differences limited to `cc` and `cfb` (`r8e_netlist_audit_c2.txt`, `_c35.txt`).

## Stage A — static TG phase A (R7F measurement: `r7cStageB1` + `r7eLp`)

Data: `r8e_static_gates.csv`, `raw/static/`.

| Static (chopper OFF) | G0 | A2 | B35 | Gate |
|---|---|---|---|---|
| fL_flat (5–10 Hz plateau, −3 dB) | 0.0943 Hz | 0.0473 Hz | **0.0270 Hz** | reported only (expected ≈ 0.047 / 0.027) |
| fH_flat | 234.8 Hz | 234.0 Hz | 232.2 Hz | 225–275 Hz: in range |
| \|Hout(100)\| | 86.06 (38.70 dB) | 86.38 (38.73 dB) | 86.37 (38.73 dB) | 38–42 dB: in range |
| Zin(10 Hz) | 556 MΩ | **281 MΩ** | **162 MΩ** | ≥ 100 MΩ: PASS |
| CMRR60 | 110.5 dB | 111.3 dB | 111.7 dB | ≥ 85 dB: PASS |
| PM CMFB / DRL | 84.5° / 90.25° | 87.0° / 90.26° | 88.3° / 90.29° | ≥ 60°: PASS |
| CMFB UGF | 125 kHz | 69.8 kHz | 42.2 kHz | (info) |
| Internal Hpre −3 dB (vs \|H(100)\|) | 6.62 kHz | 3.63 kHz | 2.17 kHz | (info, see Stage D) |
| P | 2.309 µW | 2.309 µW | 2.309 µW | < 4 µW: PASS |
| op/on CM; min XA margin | −0.495 mV; 92.2 mV | same | same | PASS |

G0 reproduces R7F exactly (86.06, 556 MΩ, 110.5 dB, 84.5°/90.25°).

## Stage B — ON (2 kHz real TG) PSS + PAC sideband 0, 0.01–1000 Hz at 40/dec

Data: `r8e_pac.csv`, `r8e_frequency.png`, `raw/c2`, `raw/c35`.

- **PSS b1** (R8B a1 settings) converged in 3 shooting-Newton iterations for both cases. The norm went 1.6e6 → 1.4e5 → 0.33, the same pattern as R8B.
- **PAC** reused the PSS ("achieved in 1 shooting-Newton iteration"). The save list was identical in all runs, including the VSP current for Zin.
- The measured input was 2.000 V at 0°.

| ON (PAC sb0) | G0 (R8C A1) | A2 | B35 | Course gate |
|---|---|---|---|---|
| **fL_flat** | 0.3381 Hz | **0.1707 Hz** | **0.0997 Hz** | 0.09–0.11 Hz: A2 FAIL, **B35 PASS** |
| Model 0.338/k | — | 0.169 | 0.0966 | prediction |
| Q = fL_ON / fL_OFF | 3.59 | 3.61 | 3.69 | — |
| fH_flat | 235.4 Hz (data to 250 Hz) | 234.2 Hz | **232.4 Hz** | 225–275 Hz: PASS |
| \|H(100)\|, phase | 83.251 (38.41 dB), −23.8° | 83.562 (38.44 dB), −24.6° | **83.561 (38.44 dB)**, −25.7° | 38–42 dB: PASS (+0.44 dB margin) |
| \|H\| at 0.1 / 1 / 10 / 250 Hz | 25.58 / 85.75 / 90.36 / 61.93 | 45.86 / 89.71 / 90.77 / 62.08 | 64.37 / 90.75 / 90.84 / 61.88 | — |
| Node corners p−n / fp−fn | 0.3385 / 0.3384 | 0.1709 / 0.1708 | 0.0999 / 0.0998 | — |
| PAC sb0 Zin(10 Hz) | — | 248.5 MΩ | **157.2 MΩ** | ≥ 100 MΩ: PASS |
| PSS p range / op range | 0.8967–0.9024 / 0.8973–0.9079 V | same within 0.03 mV | same within 0.05 mV | no clipping |

- fL_ON follows the 1/k model within 1 % for A2 and 3 % for B35, and Q stays near 3.6.
- In other words, the extra periodic high-pass conductance stays almost unchanged while Cfb grows, so the chopped corner scales like the static one. This is consistent with R8C/R8D. Q rises slightly (3.59 → 3.69), so the model slightly under-predicts at large k.

## Stage C — PNoise on B35 only (R8B Stage D definition)

Data: `r8e_pnoise_convergence.csv`, `r8e_noise_groups.csv`, `r8e_pnoise.png`, `raw/c35/C_pnoise_s*`.

- readpss of the same PSS (each run "achieved in 1 shooting-Newton iteration").
- PAC 0.1–250 Hz for normalisation (\|H(100)\| 83.561, the same as Stage B).
- PNoise timeaverage on (outp, outn), 0.1–250 Hz at 20/dec.

| maxsideband | Application (out RMS / \|H(100)\|) | De-embedded (√∫(S/\|H\|)²) | Input density at 1 / 10 / 100 Hz (nV/√Hz) |
|---|---|---|---|
| 30 | 2.4545 µV | 2.5579 µV | 359.2 / 175.2 / 151.8 |
| 60 | 2.4637 µV (+0.37 %) | 2.5674 µV (+0.37 %) | 363.7 / 175.5 / 152.0 |
| **90** | **2.4704 µV (+0.27 %)** | **2.5744 µV (+0.27 %)** | 367.8 / 175.6 / 152.1 (+1.2 / +0.1 / +0.05 %) |

- **Converged:** S60→S90 is within 5 % in RMS and 10 % in density, so S120 was not run.
- **Both metrics < 3 µVrms**, with margins of 0.53 and 0.43 µV.
- **Residual truncation:** the values still creep up (+0.27 % per step), so the untruncated values are probably a few tenths of a percent higher. That is far from the 3 µV line.
- **vs R8B G0 S90:** 3.141 / 3.994 µV.
- OCEAN `integ` and the Python trapezoid (`r8_spec.py`) agree to < 0.001 %.

**Why it is lower than G0** (`r8e_noise_groups.csv`; the input split is the approximate share × band method):
- Total 0.1–250 Hz output noise power falls from 6.84e-8 to 4.26e-8 V² (−38 %). The gain is the same, so the input-referred noise falls too.
- Every OTA group falls:

| Group | G0 | B35 |
|---|---|---|
| Input pair 1/f | 2.42 µV | 1.65 µV |
| PMOS load thermal | 2.10 µV | 1.28 µV |
| Input pair thermal | 1.76 µV | 1.08 µV |
| CD 1/f | 0.82 µV | 0.67 µV |
| Electrode R | 0.85 µV | 0.52 µV |
| XCI TG | 0.55 / 0.47 µV | 0.21 / 0.21 µV |

- The low-frequency de-embedded density also drops strongly: 1 Hz 998 → 368 nV/√Hz, because the corner moved down.
- The mechanism of the OTA-noise reduction is **not tested**. One candidate is the lower internal closed-loop bandwidth (Hpre −3 dB 6.6 → 2.2 kHz), which would reduce the white noise folded from the chopper harmonics. This is a hypothesis only.

## Stage D — 60 ms chopped transient, B35 (R7F `r7eStageC`, analysis `round7e/r7e_analysis.py`)

Setup: 2 kHz TG, 1 mV 100 Hz DM, maxstep 0.5 µs, cmin 1e-17. It finished in about 2 minutes with no watchdog stop; the tran SHA-256 was verified after transfer. Data: `r8e_tran_summary.csv`, `r8e_tran.png`, `raw/c35/T_c35_*`.

| 40–60 ms window (20–40 ms identical) | R7F G0 | **R8E B35** |
|---|---|---|
| Hout(100 Hz) | 83.247 (38.41 dB) | **83.556 (38.44 dB)** |
| H2 / H3 | −113.6 / −85.8 dBc | −140.2 / **−94.2 dBc** |
| Output deterministic residual (≥ 1 kHz, chopper; not noise) | 141.7 µVrms | **76.2 µVrms** |
| 4 kHz spur at output | 133.7 µV | 75.8 µV |
| Hpre edge error max / Hbuf residual | 37.0 mV / 3280 µV | 18.0 mV / 1498 µV |
| op/on CM; output CM | 0.899524 / 0.540187 V | 0.899524 / 0.540182 V |
| Ranges op, fp, bufp, outp | 0.844–0.964 / 0.842–0.958 / 0.494–0.586 / 0.498–0.582 V | same within 0.6 mV |
| Pseudo-R voltage XPRN (A−B) | −56.7…+55.4 mV | −55.6…+55.3 mV |
| CM drift | 0.010 mV/s | 0.0035 mV/s |
| P | 2.311 µW | 2.306 µW |

**Stage D PASS:** gain 38–42 dB, no clipping, power < 4 µW. The chopper's deterministic output residual and H3 are both better than R7F.

Two caveats:
- The internal Hpre bandwidth (2.17 kHz static) is now close to the 2 kHz chopping frequency. The tran shows no settling penalty: edge error halves and residual halves. But this narrower internal margin is a new sensitivity to watch under PVT.
- The pseudo-R still sees ±55 mV, beyond its ±10 mV linear range, as in R7F. The long-term rectification drift estimate from R7C is not re-simulated.

## Course-gate summary for B35 (tt, 27 °C, 1.8 V, 10 pF/side)

| Spec | Value | Source | Status |
|---|---|---|---|
| Gain at 100 Hz, chopper ON | 38.44 dB (PAC) / 38.44 dB (tran) | B / D | PASS (+0.44 dB) |
| fL, chopper ON | 0.0997 Hz | B, PAC sb0 | PASS |
| fL, chopper OFF (static) | 0.0270 Hz | A | outside 0.09–0.11 Hz (known conflict, not claimed) |
| fH, chopper ON | 232.4 Hz | B | PASS |
| Noise 0.1–250 Hz, input-referred, ON | 2.470 µV app / 2.574 µV de-embedded | C, S90 converged | PASS / PASS |
| Zin(10 Hz) | 162 MΩ static / 157 MΩ PAC sb0 | A / B | PASS |
| CMRR60 | 111.7 dB | A (static only) | PASS static; ON not measured |
| PM CMFB / DRL | 88.3° / 90.3° | A (static STB) | PASS |
| Power | 2.31 µW | A / D | PASS |
| Design capacitance | 741.5 pF | netlist | PASS (< 1 nF) |

## Limits and not run

- **Not run:** PVT/MC, ON-mode CMRR, clock jitter, physical R/C, ADC loading, any other k, any MOS/bias change, MATLAB.
- **Not run for A2:** PNoise and tran (it failed the ON fL gate).
- **Not run for B35:** PNoise S120 (not needed).
- **Open:** OFF vs ON fL conflict. In the static phase the design is at 0.027 Hz, so any operating mode without chopping would have a lower corner than specified.
- **Read-only:** R8B, R8C, R8D and R7F cells and data.

## Files

`ece203_data/round8e/`:
- `r8e_plan.md`
- `r8e_budget.py`, `r8e_netlist_audit.py`, `r8e_analysis.py`, `r8e_tran_plot.py`
- `r8e_design_budget.csv`, `r8e_static_gates.csv`, `r8e_pac.csv`, `r8e_pnoise_convergence.csv`, `r8e_noise_groups.csv`, `r8e_tran_summary.csv`
- `r8e_gates.txt`, `r8e_netlist_audit_c2.txt`, `r8e_netlist_audit_c35.txt`
- `r8e_frequency.png`, `r8e_pnoise.png`, `r8e_tran.png`
- `raw/static`: B_/L_ CSVs, AC, STB, DC op, netlists for G0/A2/B35, build/static job logs
- `raw/c2`, `raw/c35`: PSS/PAC (and for B35, PNoise S30/60/90 and tran) CSVs, netlists, spectre.out.gz, convergence lines, PSS SHA-256, noise summaries, full-resolution tran CSV.gz + SHA-256, job logs, watchdog logs

New cells: `Project/ece203_r8e_tb_c2`, `Project/ece203_r8e_tb_c35`. Both are `r8bSpecs()` unchanged; cc/cfb are set per run. No ADE state was saved.

Stopped; waiting for GPT review. No R8F / R9 / MATLAB optimisation started.
