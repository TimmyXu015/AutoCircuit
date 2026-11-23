# ECE203 R7E — differential 31.8 MΩ / 20 pF output RC low-pass on the R7D a0 system (2026-11-23)

- Task: [ECE203_round7e_output_lp_integration_task.md](ECE203_round7e_output_lp_integration_task.md).
- Pre-run plan with gates and expectations: `ece203_data/round7e/r7e_plan.md`. Committed in 80c8dc7 before any run; all runs used scripts at 80c8dc7.
- Script `ece203_r7e.il`; jobs `ece203_r7e_build / a / b / c / ade`, case chosen with env `AC_R7E_CASE=lp_a0|lp_load10p`; watchdog `tools/r7e_watchdog.sh`.
- Data: [ece203_data/round7e/](ece203_data/round7e/).
- C0 = `Project/ece203_r7d_tb_bias_a0`, read-only. Its R7D Stage B/C data come from the same code and options.

## Verdict

| Item | Result |
|---|---|
| LP-only, Stage A (static DC/AC/STB, unloaded outp/outn) | **PASS**. fH = 247.6 Hz, \|H_LP(100)\| = 0.9286 at −21.78°, nothing upstream changed |
| Loaded-output sensitivity, Stage B (+10 pF on each side of outp/outn) | **LIMITATION**: fH drops to **165.5 Hz** |
| Chopped 60 ms, Stage C | **PASS**. Hout/Hbuf = 0.9286 and the switching residue at the output is 24× lower |
| System gain | **SYSTEM GAIN PENDING**: Hout(100 Hz) = **71.04 chopped (37.03 dB)** and 73.12 static (37.28 dB). Even the plateau maximum, 78.85 (37.94 dB), is below the 38 dB course minimum |
| Periodic PSS/PAC fL/fH, noise, MC, PVT, a real 31.8 MΩ PDK resistor | NOT RUN / NOT VERIFIED |

Stage B in one sentence: **LP-a0 passes unloaded, but with a 10 pF downstream load it misses the fH target; a later interface solution is needed.**

No resistor, capacitor, MOS, bias, feedback or clock value was changed. The old Cadence cells were not renamed or rebuilt.

## What was added (netlist audit)

| Instance | Connection | Value |
|---|---|---|
| RLP_P | bufp → outp | 31.8M |
| CLP_P | outp → 0 | 20p |
| RLP_N | bufn → outn | 31.8M |
| CLP_N | outn → 0 | 20p |
| COUTP / COUTN | outp → 0 / outn → 0, 10p | Stage B bench only |

- All parts are ideal analogLib R/C.
- A 31.8 MΩ on-chip resistor (area, noise, parasitics, process spread) is **NOT VERIFIED**.

`r7e_netlist_audit.py` gives **AUDIT PASS** on all three netlists:

| Stage | Netlist | Audit output |
|---|---|---|
| A | `ece203_r7e_tb_lp_a0` | `r7e_netlist_audit_stageA.txt` |
| B | `ece203_r7e_tb_lp_load10p`, with `--load` | `r7e_netlist_audit_stageB.txt` |
| C | tran netlist vs R7D tran netlist | `r7e_netlist_audit_stageC.txt` |

What the audit confirms:
- The diff against R7D is exactly the 4 (or 6) new passives. Nothing was removed.
- All 6 subckts are identical.
- CLBP/CLBN (10 pF) are still on bufp/bufn.
- CFN, CFP, XPRN and XPRP are still on fp/fn.
- IREF, VDD and VDDD are unchanged.
- Only the LP/load parts touch outp/outn. There is no extra C, buffer or VCVS.

## Stage A — TG static phase A, unloaded output

Setup:
- Options: gmin 1e-18, iabstol 1e-17, reltol 1e-5. Cc mismatch 1 %.
- DM/CM AC from 1 mHz to 100 kHz, 50 points per decade.
- The same `r7cStageB1` measurement as R7C/R7D (DC op, margins, CMFB and DRL STB, Zin, CMRR), plus `r7eLp` for the LP transfer.
- Data: `raw/stageA/` (`B_lp_a0*` = system measurement, `L_lp_a0*` = LP measurement), `r7e_stageA_summary.csv`, `r7e_stageAB.png`.

| | R7D C0 | R7E lp_a0 | Gate |
|---|---|---|---|
| DC bufp = bufn | 0.54014 V | 0.54014 V | |
| DC outp − bufp | – | 0 (exact) | follows **PASS** |
| Hpre100 | 93.5934 | 93.5934 | ≤ 2 % **PASS** |
| Hbuf100 | 78.845 | 78.747 (−0.12 %, the CD now also drives the RC) | ≤ 2 % **PASS** |
| **Hout** 1 / 10 / 60 / 100 Hz | – | 78.55 / 78.79 / 76.64 / **73.12** | SYSTEM GAIN PENDING (37.28 dB at 100 Hz) |
| **Hout** 250 / 500 Hz | – | 55.51 / 34.97 | |
| **Hout** 1 / 2 kHz | – | 18.83 / 9.40 | |
| Hout maximum | – | 78.85 at 3.8 Hz (37.94 dB) | |
| \|H_LP\| at 100 Hz, phase | – | **0.92860, −21.78°** (hand calculation 0.9285, −21.8°) | 0.90–0.95, first-order **PASS** |
| \|H_LP\| at 250 Hz, phase | – | 0.7075, −44.97° | |
| fH_flat (−3 dB vs \|Hout(10)\|) | – | **247.6 Hz** (vs plateau max: 247.2) | 225–275 **PASS** |
| fH_100ref (−3 dB vs \|Hout(100)\|) | – | 284.6 Hz (ideal 287 Hz) | definition check only |
| fH of H_LP alone | – | 249.7 Hz (ideal 250.2) | |
| fL | 0.09564 Hz (Hpre vs 100 Hz) | Hpre vs 100 Hz: 0.09564; Hout vs plateau max: **0.09564**; Hout vs \|Hout(100)\|: 0.0831 (see note) | 0.09–0.11 **PASS** |
| op/on CM | −0.49 mV | −0.49 mV | ≤ 1 mV **PASS** |
| CMFB UGF / PM | 125.3 kHz / 84.55° | 125.3 kHz / 84.55° | ≥ 60° **PASS** |
| DRL UGF / PM | 2106 Hz / 90.25° | 2106 Hz / 90.25° | ≥ 60° **PASS** |
| CMRR60 (pre / out) | 108.90 dB | 108.90 / 108.90 dB | ≥ 85 dB **PASS** |
| \|Zin\| at 10 Hz | 657.9 MΩ | 657.9 MΩ | ≥ 100 MΩ **PASS** |
| Minimum margin, OTA / CMFB | 0.0922 / 0.193 V | same | |
| P = 1.8·(I_VDD + I_VDDD) | 2.3094 µW | 2.3094 µW (+0.000 %) | ≤ +2 % **PASS** |

**Note on fL (a deviation from the plan's definition, stated openly).**
- The plan defined fL on Hout as −3 dB relative to |Hout(100 Hz)|. That gives 0.0831 Hz.
- That definition is ill-posed after an LP: at 100 Hz the reference is already 0.64 dB into the LP roll-off, so the "−3 dB" point is really −3.64 dB from the plateau.
- The high-pass corner itself does not move. Hpre vs 100 Hz and Hout vs its plateau maximum are both 0.09564 Hz.
- The gate is judged on those two values. This is the same plateau-referenced convention the task asks for on fH.

## Stage B — 10 pF per side on outp/outn (sensitivity only, static DC/AC)

Data: `raw/stageB/` and `r7e_stageAB.png`.

| | Unloaded (A) | + 10 pF per side (B) |
|---|---|---|
| fH_flat (vs plateau max) | 247.6 (247.2) Hz | **165.5 (164.9) Hz** (hand calculation 167 Hz) |
| Hout100 / phase of H_LP | 73.12 / −21.78° | 67.47 (36.58 dB) / −30.94° |
| \|H_LP\| at 100 / 250 Hz | 0.9286 / 0.7075 | 0.8577 / 0.5551 |
| fL (Hout vs plateau max) | 0.09564 Hz | 0.09562 Hz |
| DC, CMRR60, power | – | unchanged |

**The output node is high impedance.**
- The source impedance seen from outp, Z = Z_C·(H_unloaded/H_loaded − 1), is 31.8 MΩ at 10 Hz, 29.5 MΩ ∠−21.8° at 100 Hz, and 22.4 MΩ ∠−45° at 251 Hz.
- That equals 31.8 MΩ ∥ 20 pF. The CD's own output resistance is negligible in comparison.
- Any capacitance at the output therefore adds directly to the 20 pF.

**Verdict:** LP-a0 passes unloaded, but with 10 pF of downstream load the fH target is not met. A later interface solution is needed: an output buffer after the LP, or a redesigned R/C split for a defined load.

The 10 pF is only an example load; no real ADC or instrument load has been specified. No load-mismatch sweep was run.

## Stage C — 2 kHz TG chopper, 100 Hz 1 mV DM, 60 ms (one new run)

Settings, identical to R7D. Spectre echoes are in brackets.
- cmin 1e-17 (`cmin = 10 aF`)
- maxstep 0.5 µs (`500 ns`)
- gmin 1e-18
- iabstol 1e-17
- reltol 1e-5 (`10e-06`)
- VSPS sinephase = 0

Run facts:
- t_end = 60 ms, watchdog clean, about 2 minutes.
- CSV SHA-256 is `6b7f0047…20b067`, verified after transfer.
- C0 is the R7D T_bias_a0 wave, read-only.
- Analysis: `r7e_analysis.py`. It reuses the R7D metrics and adds Hout, out CM and spectral terms. Outputs: `r7e_stageC_summary.csv`, `r7e_stageC.png`.

The phase in this table uses the transient-fit convention, where positive means lag. That is the opposite sign to the AC phase.

Values are for 40–60 ms; 20–40 ms is the same.

| | R7D C0 | R7E lp_a0 | Gate |
|---|---|---|---|
| Hpre gain / phase | 90.981 / 0.490° | 90.981 / 0.490° | ≤ 2 % **PASS** |
| Hbuf gain / phase | 76.601 / 0.593° | 76.506 / 0.769° (−0.12 %) | ≤ 2 % **PASS** |
| **Hout** gain / phase | – | **71.042 (37.03 dB)** / 22.55° lag | SYSTEM GAIN PENDING |
| **Hout/Hbuf** at 100 Hz | – | **0.92858**, 21.78° lag (static AC: 0.92860) | 0.9285 ± 3 % **PASS** |
| Hout H2 / H3 | – | −117.6 / −88.9 dBc (Hpre −102.1 / −85.7) | |
| DM residual RMS, pre / buf | 3434 / 2737 µV | 3434 / 2715 µV | |
| DM residual RMS, **out** | – | **112 µV** | |
| DM edge error max / mean, pre | 31.59 / 20.46 mV | 31.59 / 20.46 mV | |
| DM edge error max / mean, buf | 14.72 mV | 14.61 mV | |
| DM edge error max / mean, **out** | – | **0.281 / 0.195 mV** | reported, not gated |
| DM spectrum, largest bin near 4 kHz (the edge error, as 4 kHz ± 100 Hz sidebands) | buf 1641 µV | buf 1627 µV → **out 104 µV** (RC at 4 kHz: 0.062) | |
| DM spectrum, RMS of all bins ≥ 1 kHz | buf 2737 µV | buf 2715 µV → **out 112 µV** | |
| DM spectrum, bin near 2 kHz | 0.2 µV | 0.2 µV | |
| op/on CM average / 200 Hz | 0.899524 V / 0.86 µV | 0.899524 V / 0.86 µV | ≤ 1 mV / ≤ 0.20 mV **PASS** |
| op/on CM edge spike | +8.45 mV | +8.45 mV | |
| buf CM average / 200 Hz / pp | 0.54017 V / 24.8 µV / 0.40 mV | 0.54017 V / 24.6 µV / 0.40 mV | |
| **out CM** average / 200 Hz / pp | – | 0.54017 V / 19.3 µV / 0.040 mV, edge < 0.002 mV | |
| Ranges: outp / bufp | – / 0.5008–0.5793 V | 0.5045–0.5756 / 0.5009–0.5792 V | no clipping **PASS** |
| P (transient average) | 2.314 µW | 2.311 µW | < 4 µW, ≤ C0 + 2 % **PASS** |
| (p+n)/2 slope over 10–60 ms | −0.180 mV/s | −0.182 mV/s | listed (pseudo-R rectification, long-term NOT RUN) |
| op/on CM slope | −0.016 mV/s | −0.016 mV/s | |
| out CM slope | – | +0.052 mV/s | |
| ib pp / MP1 pp | 72 µV / 1.8 nA | 72 µV / 1.5 nA | |

On the CM rows:
- The 200 Hz CM at buf and out comes from the CD source followers' even-order response to the ±39 mV DM swing. It was already present in R7D (24.8 µV). The LP passes it at |H(200 Hz)| = 0.78.
- It is not an OTA or CMFB CM error; the op/on CM is unchanged.

**What the LP buys and costs in the chopped system:**
- At 100 Hz it costs exactly the first-order factor 0.9286 (−0.64 dB, 21.8° lag).
- It removes most of the chopper switching residue that reached buf:
  - DM residual: 2715 → 112 µV (24×);
  - per-edge DM error at the output: 14.6 → 0.28 mV max;
  - 4 kHz sideband: 1627 → 104 µV.
- Nothing upstream changed: Hpre, op/on CM, the CMFB and DRL controls, the bias and the power are identical to R7D within 0.12 %.
- No pre-registered glitch-reduction gate existed; these are reported values.

## Honest limits

- The 247.6 Hz and 0.0956 Hz corners are static AC values with the TG held in phase A. They are not periodic PSS/PAC corners of the running chopper. The 60 ms transient checks only 100 Hz and the switching residue.
- **SYSTEM GAIN PENDING.** The chopped output gain is 71.04 (37.03 dB) at 100 Hz, and the plateau maximum is 78.85 (37.94 dB). Both are below the 38–42 dB course range. This is not an LP failure: it is the R7D buffered gain (76.60, 37.68 dB) times the LP factor. A separate gain-correction round is needed, and it was not started here.
- The output is a 31.8 MΩ ∥ 20 pF node. It cannot drive any real downstream capacitance without moving fH (Stage B).
- Ideal 31.8 MΩ and 20 pF parts; the physical implementation is NOT VERIFIED.
- Carried forward from earlier rounds:
  - the CMFB gate-capacitance DM edge error (about 31.6 mV at fp/fn, now strongly filtered at out);
  - the pseudo-R long-term rectification drift;
  - no noise, MC or PVT runs.

## Files

`ece203_data/round7e/`:
- `r7e_plan.md`
- `r7e_netlist_audit.py` and `r7e_netlist_audit_stage{A,B,C}.txt`
- `r7e_stageA_summary.csv`, `r7e_stageC_summary.csv`
- `r7e_analysis.py`, `r7e_plots.py`
- `r7e_stageAB.png`, `r7e_stageC.png`
- `raw/stageA`: system and LP CSVs, DC op, DM AC curves including Hout and H_LP, CMFB/DRL STB, netlists, job logs
- `raw/stageB`: loaded LP CSV, AC curve, netlist, job log
- `raw/stageC`: full-resolution transient `.csv.gz` with outp/outn, pref/ib/ibd and the bias currents, sha256, spectre.out.gz, netlist, job log

New Cadence objects:
- cells `Project/ece203_r7e_tb_lp_a0` and `Project/ece203_r7e_tb_lp_load10p`;
- ADE state `r7e_lp_phaseA` on lp_a0: DC, AC, CMFB STB, outputs Hout / Hbuf / Hpre in dB.

Nothing old was modified or renamed. Stopped: the gain correction (proposed as R7F) was not started.
