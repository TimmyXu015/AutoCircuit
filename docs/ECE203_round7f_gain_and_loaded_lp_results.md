# ECE203 R7F — loaded-output LP bandwidth + capacitive gain correction (2026-11-23)

- Task: [ECE203_round7f_gain_and_loaded_lp_task.md](ECE203_round7f_gain_and_loaded_lp_task.md).
- Pre-registration (`ece203_data/round7f/r7f_plan.md`):
  - plan with gates: commit 16f68b5;
  - update 1, L0 failure and the registered L1 correction: e8c9219, committed before any L1 run;
  - update 2, Stage A/B results and the killed mis-launch: a5958e5.
- Script: `ece203_r7f.il`.
  - Measurement code is the unchanged R7C `r7cStageB1` plus R7E `r7eLp` / `r7eStageC`.
  - The only edits to `ece203_r7c.il` / `ece203_r7e.il` are backward-compatible hooks: optional per-case design-variable overrides, and a watchdog-name variable. They do nothing for the old cases.
- Jobs: `ece203_r7f_build / a / c / ade`, with env `AC_R7F_CASE` (and `AC_R7E_CASE` for the transient).
- Data: [ece203_data/round7f/](ece203_data/round7f/).
- C0 = R7E `Project/ece203_r7e_tb_lp_a0` / `_lp_load10p`, read-only.

## Verdict

| Item | Result |
|---|---|
| Stage A L0 (4.77 MΩ / 133 pF) | **FAIL with the 10 pF load**: fH_flat 219.87 Hz (unloaded 236.30 Hz PASS) |
| Stage A L1 (4.0 MΩ / 148 pF), the one registered correction | **PASS**: fH_flat 250.42 Hz unloaded, **234.65 Hz with 10 pF per side** |
| Stage B G0 (cc 50 → 60 pF on L1), static | **PASS**: Hout(100 Hz) 86.06 (38.70 dB) with 10 pF, 86.88 (38.78 dB) unloaded; plateau 93.54 (39.42 dB). G1 not needed |
| Stage C G0 + 10 pF, 2 kHz TG, 60 ms | **PASS**: Hout(100 Hz) **83.25 = 38.41 dB**; CM, power, H3 and residual all within gates |
| Course gain (38–42 dB) | **PASS at nominal tt / 27 °C**, chopped and loaded. **Margin is only 0.41 dB** |
| Noise / PNoise, PSS/PAC periodic corners, MC/PVT, physical R/C implementation | **NOT RUN / NOT VERIFIED** |

No MOS, bias, CMFB, DRL, pseudo-R, Cfb, CLB, clock or old cell was changed. Nothing was renamed.

## Single-variable steps (netlist audit, `r7f_netlist_audit.txt` and `r7f_netlist_audit_stageC.txt`, all PASS)

| Step | Only difference (audited) |
|---|---|
| R7E lp_a0 → L0 / L1 | RLP_P/N 31.8M → 4.77M / 4.0M; CLP_P/N 20p → 133p / 148p |
| L0 / L1 → +10 pF | adds COUTP (outp 0) 10p and COUTN (outn 0) 10p |
| L1 (+10 pF) → G0 (+10 pF) | design variable `cc` 5e-11 → 6e-11. It drives CCP/CCN together; the 1 % mismatch aid CCX = cc·dcc scales with it, as in every round |

In every step all 6 subcircuits are identical and nothing was removed.

The Stage C netlist against the R7E transient netlist differs by exactly the LP values, the two COUT, and `cc`. Against the Stage B static G0 netlist it differs only by the analysis-setting variables (adm, chen, dcc, vd).

## Stage A — LP impedance scaling (TG static phase A, cc 50 pF)

Data: `raw/static/`, `r7f_static_summary.csv`, `r7f_static.png`.

| | R7E 31.8M/20p | L0 4.77M/133p | L1 4.0M/148p |
|---|---|---|---|
| fH_flat unloaded (vs \|Hout(10)\|; vs plateau) | 247.6 Hz (247.2) | 236.3 Hz (235.9) | **250.4 Hz (250.0)** |
| fH_flat + 10 pF per side | 165.5 Hz | **219.9 Hz FAIL** | **234.7 Hz (234.2) PASS** |
| H_LP alone, unloaded / + 10 pF | 249.7 / 166.4 Hz | 250.3 / 232.8 Hz | 268.2 / 251.2 Hz |
| Hbuf100 (Hpre100 = 93.593 for all) | 78.747 | 78.185 (−0.71 %) | 78.144 (−0.77 %) |
| Hout100 unloaded / + 10 pF | 73.12 / 67.47 | 72.63 / 71.78 | 73.24 / 72.55 (37.30 / 37.21 dB) |
| fL (plateau-referenced) | 0.0956 Hz | 0.0956 Hz | 0.0956 Hz |
| op/on CM, CMFB / DRL PM, CMRR60, Zin(10 Hz), P, min margin | −0.49 mV, 84.5° / 90.25°, 108.9 dB, 658 MΩ, 2.309 µW, 0.092 V | same | same |

**Why L0 failed and how L1 was chosen.**
- The CD's own output resistance Ro sits in series with RLP. `r7f_lp_model.py` uses the measured R7D buffered response × a divider Ro → buf node (CLB 10 pF) → R → C (+ Cl). One fitted Ro = 0.284 MΩ reproduces all four measured corners within 0.2 Hz.
- With that model, keeping the nominal R·C at 0.634 ms (the task's suggestion) reaches at most **220.05 Hz** with 10 pF, whatever the R/C ratio. That is because the loaded time constant is (R + Ro)(C + Cl).
- L1 instead holds the *effective* time constant (R + Ro)·C at 0.634 ms. Its nominal R·C is 0.592 ms, 6.7 % lower; this deviation from "keep R·C ≈ 0.636 ms" is stated openly.
- Prediction 250.5 / 234.6 Hz vs measured **250.42 / 234.65 Hz**.

## Stage B — gain correction G0 (cc 60 pF), static

| | L1 cc 50p + 10 pF | **G0 cc 60p + 10 pF** | G0 cc 60p unloaded | Gate |
|---|---|---|---|---|
| Hpre100 | 93.593 | 111.026 (×1.186) | 111.026 | |
| Hbuf100 | 78.061 | 92.601 | 92.699 | |
| **Hout100** | 72.55 (37.21 dB) | **86.06 (38.70 dB)** | 86.88 (38.78 dB) | 38–42 dB **PASS** |
| **Hout plateau** | 78.84 (37.94 dB) | **93.54 (39.42 dB)** | 93.54 (39.42 dB) | 38–42 dB **PASS** |
| fH_flat (plateau) | 234.7 Hz | 234.6 (234.1) Hz | 250.3 (249.9) Hz | 225–275 **PASS** |
| fL (Hpre vs 100 Hz; Hout plateau) | 0.0956 Hz | 0.09456; 0.09456 Hz | same | 0.09–0.11 **PASS** |
| CMFB UGF / PM | 125.3 kHz / 84.54° | 125.2 kHz / 84.55° | same | ≥ 60° **PASS** |
| DRL UGF / PM | 2106 Hz / 90.25° | 2106 Hz / 90.25° | same | ≥ 60° **PASS** |
| CMRR60 | 108.90 dB | 110.47 dB | 110.47 dB | ≥ 85 dB **PASS** |
| \|Zin\| at 10 Hz | 658 MΩ | 556 MΩ | 556 MΩ | > 100 MΩ **PASS** |
| op/on CM / P / min OTA margin | −0.49 mV / 2.309 µW / 0.092 V | same | same | **PASS** |

Notes on G0:
- The gain rose by 1.186× for a 1.20× change in cc. The small shortfall comes from the lower feedback factor.
- The OTA operating point is unchanged; DC does not see Cc.
- Both sides are symmetric: bufp = bufn = outp = outn = 0.54014 V.

## Stage C — 60 ms, 2 kHz TG, 100 Hz 1 mV DM

**Setup** (spectre.out echoes in brackets):
- Case: G0 with 10 pF per side.
- Settings: cmin 1e-17 (`10 aF`), maxstep 0.5 µs (`500 ns`), gmin 1e-18, iabstol 1e-17, reltol 1e-5. VSPS sinephase = 0. tt, 27 °C.
- Run: t_end 60 ms, watchdog clean, about 2 minutes. SHA-256 `9685797a…83e5d9`, verified.
- Analysis: same `r7e_analysis.py`. Outputs: `r7f_stageC_summary.csv`, `r7f_stageC.png`.
- C0 = R7E lp_a0 chopped wave (cc 50 pF, old LP, unloaded), read-only.
  - C0 differs from C1 in three things at once: LP, load and cc. It is a reference level only.
  - The attribution of each change comes from the Stage A/B static single-variable steps.

**Launch note.** The first Stage C launch did not set `AC_R7E_CASE`, so `r7eStageC` started simulating the R7E lp_a0 cell (read-only).
- I killed it after about 40 s; it was my own job.
- Its partial files are kept in `raw/stageC_killed_launch/`. No result from it is used and it is not counted as a candidate run.
- `r7fTran` now refuses to start without the right case.

Values are for 40–60 ms; 20–40 ms is identical to within the last digit.

| | R7E C0 (reference level) | **R7F G0 + 10 pF** | Gate |
|---|---|---|---|
| **Hout gain at 100 Hz** | 71.042 (37.03 dB) | **83.247 (38.41 dB)** | 38–42 dB **PASS** (margin 0.41 dB) |
| Chopped / static Hout100 | 0.9716 | 0.9673 | |
| Hpre / Hbuf gain | 90.981 / 76.506 | 107.46 / 89.572 | |
| Hout/Hbuf at 100 Hz | 0.92858 | 0.92938 | |
| Hout phase lag (fit convention) | 22.55° | 23.76° | |
| Hout H2 / H3 | −117.6 / −88.9 dBc | −113.6 / **−85.8 dBc** | H3 ≤ 10 dB worse **PASS** (+3.1 dB) |
| Hpre H3 | −85.7 dBc | −82.1 dBc | |
| Out DM residual RMS (≥ 1 kHz) | 112 µV | **142 µV** (×1.27) | ≤ 2× **PASS** |
| Out 4 kHz sideband | 104 µV | 134 µV | |
| DM edge error max, pre / buf / out | 31.59 / 14.61 / 0.281 mV | 36.96 / 16.75 / 0.362 mV | reported |
| op/on CM average / 200 Hz | 0.899524 V / 0.86 µV | 0.899524 V / 1.38 µV | ≤ 1 mV / ≤ 0.20 mV **PASS** |
| op/on CM edge spike | +8.45 / −2.84 mV | +8.45 / −3.11 mV | |
| Out CM average / 200 Hz | 0.54017 V / 19.3 µV | 0.54019 V / 22.3 µV | |
| Ranges: fp, op, bufp, outp | 0.851–0.950, 0.853–0.955, 0.501–0.579, 0.505–0.576 V | 0.842–0.958, 0.844–0.964, 0.494–0.586, 0.498–0.582 V | no clipping **PASS** |
| vg / drlr | 1.3189–1.3216 / 0.8989–0.9043 V | 1.3189–1.3216 / 0.8989–0.9043 V | |
| Bias: ib pp, MP1 average | 72 µV, 53.45 nA | 74 µV, 53.45 nA | |
| P (transient average) | 2.311 µW | 2.311 µW | < 4 µW **PASS** |
| Pseudo-R V(A)−V(B), XPRN | −48.0..+46.7 mV | −56.7..+55.4 mV | |
| (p+n)/2 slope over 10–60 ms | −0.182 mV/s | **−0.224 mV/s** | reported (more rectification at a larger swing; long-term NOT RUN) |

**What changed, and why.**
- The gain rose by the Cc ratio, minus a little closed-loop error. Static gain went up 1.186×; chopped gain went up 1.172×.
- The higher gain means a lower feedback factor, so the chopped OTA settles slightly worse:
  - pre edge error +17 %;
  - Hpre H3 +3.5 dB;
  - chopped/static ratio 0.967 vs 0.972.
- The output residual and the out edge error grew about 1.27×. This is consistent with the 17 % larger signal and edge error and a similar LP attenuation; Hout/Hbuf stayed at 0.929.
- The pseudo-R now swings ±56 mV instead of ±48 mV, so its rectification drift grew from −0.18 to −0.22 mV/s.
- Everything else is the same as R7E: op/on CM, CMFB, DRL, bias and power.

## Designed capacitance

Computed from the netlists by `r7f_netlist_audit.py`. Electrodes (3 × 50 nF), the body model (200 pF), the STB/probe aids, the COUT stress load and the CCX mismatch aid are excluded and listed separately in the audit output.

| | Cc (2×) | Cfb (2×) | CLB (2×) | CLP (2×) | DRL CCM (2×) | Total |
|---|---|---|---|---|---|---|
| R7E | 100 | 1 | 20 | 40 | 2 | 163 pF |
| L0 | 100 | 1 | 20 | 266 | 2 | 389 pF |
| L1 | 100 | 1 | 20 | 296 | 2 | 419 pF |
| **G0** | **120** | 1 | 20 | 296 | 2 | **439 pF** (< 1 nF) |

- The fix costs +276 pF over R7E: +256 pF of LP and +20 pF of Cc. These are capacitor area, not free drive.
- The ideal 4.0 MΩ resistors and the 148 pF / 60 pF capacitors are not checked as PDK devices for area, noise or parasitics.

## Honest limits

- **The 10 pF load is an assumed stress case, not a specified downstream load.** outp/outn is still a high-impedance node: 4.0 MΩ in series plus the CD Ro, about 4.3 MΩ ∥ 148 pF. It is **not shown to drive a low-impedance or switched-capacitor ADC input**.
- **Gain margin is 0.41 dB** (chopped, tt, 27 °C). Process, temperature, Cc mismatch and CD-gain spread are not run; any of them could push it below 38 dB.
- fH and fL are static AC values with the TG held in phase A, not periodic PSS/PAC corners of the running chopper. The 60 ms transient checks only 100 Hz and the switching residue.
- Noise is not run for this chain. Higher Cc may change the input-referred noise; no number is claimed.
- Carried forward:
  - the CMFB-detector gate-capacitance DM edge error (now 37 mV at fp/fn, strongly filtered at out);
  - the pseudo-R rectification drift (now −0.22 mV/s), long-term not simulated;
  - R5N-F F2 remains the separate course baseline and was not touched.

## Files

`ece203_data/round7f/`:
- `r7f_plan.md` (with updates 1 and 2)
- `r7f_lp_model.py`
- `r7f_netlist_audit.py`, `r7f_netlist_audit.txt`, `r7f_netlist_audit_stageC.txt`
- `r7f_static_summary.py`, `r7f_static_summary.csv`
- `r7f_stageC_summary.csv`
- `r7f_plots.py`, `r7f_static.png`, `r7f_stageC.png`
- `raw/static`: per-case system and LP CSVs, DC op, AC curves, STB, netlists, build and static job logs, for L0, L1 and G0 in both loadings
- `raw/stageC`: full-resolution transient `.csv.gz` + sha256, spectre.out.gz, netlist, C and ADE job logs
- `raw/stageC_killed_launch`

New Cadence objects:
- cells `Project/ece203_r7f_tb_lp_l0`, `_lp_l0_load10p`, `_lp_l1`, `_lp_l1_load10p`, `_gain_g0_load10p`, `_gain_g0_unloaded`;
- ADE state `r7f_gain_g0_load10p_phaseA`.

Stopped. Noise and R8 were not started.
