# ECE203 R8C — periodic high-pass corner under chopping: not a PAC artefact, not the pseudo-R nonlinearity (2026-11-23)

- Task: [ECE203_round8c_periodic_highpass_rootcause_task.md](ECE203_round8c_periodic_highpass_rootcause_task.md).
- Pre-run plan: [ece203_data/round8c/r8c_plan.md](ece203_data/round8c/r8c_plan.md), commit 16c1e8d, made before any R8C Spectre run.
- Code: `ece203_r8c.il`, `tools/r8c_watchdog.sh`, batch jobs `ece203_r8c_{a1off,a1pac,build,b0,bpss,bpac}`.
- Data: [ece203_data/round8c/](ece203_data/round8c/).
- Setup: cmrf7sf tt, 27 °C, Spectre 15.1, gmin 1e-18, iabstol 1e-17, reltol 1e-5. Zero input, 2 kHz (`tch` 500 µs).

## Verdict

| Step | Result | Key numbers |
|---|---|---|
| A0 — recompute from archived R8B data | **supports both corners** | OFF fL_flat 0.0943 Hz, ON 0.3386 Hz; 13 definition checks PASS |
| **Stage A — PAC set-up / read-out** | **PASS** (7/7 gates) | ON \|H(100)\| 83.2514, fL_flat 0.3381 Hz; maxsideband 1 = 3 (0 % difference); new run vs R8B ≤ 0.011 %; netlist audits ×3 PASS |
| **B0 — linear surrogate, static** | **PASS** (no correction needed) | fL_flat 0.0946 Hz (MOS 0.0943); \|H(100)\| 86.53 (+1.01 %); DC CM within 0.0001 mV; power identical (2.3094 µW) |
| **B1 — linear surrogate, chopper ON** | **PSS converged** (b1, 3 iterations); PAC done | fL_flat 0.3409 Hz → **Q_R = 3.60** vs **Q_MOS = 3.59** |
| Pre-registered reading | **Q_R ≥ 2.7 → the TG or another periodic switching coupling is the main suspect.** The pseudo-R nonlinearity is not needed to produce the corner shift | The operating state is preserved: p/n/fp/fn peak-to-peak ×1.000, mean within 0.02 mV |

This is diagnostic evidence, not a physical proof of a mechanism. No course spec (fL, noise) is claimed. The linear-R cell is a diagnostic surrogate, not a design candidate.

## Definitions

- **Transfer:** (V(x+) − V(x−)) divided by the measured V(ep) − V(en). The input is static AC when the chopper is OFF, and PAC sideband 0 when it is ON.
- **fL_flat:** first take the plateau P, the mean |H| over the grid points from 5 to 10 Hz. Then scan downward from 5 Hz and take the first frequency where |H| drops below P/√2, using log–log interpolation (`r8c_lib.py`). Using the maximum instead of the mean as the plateau changes fL by ≤ 0.1 %.
- **Q** = fL_flat with the chopper ON (PAC) divided by fL_flat with it OFF (static AC), for the same cell.

## Stage A0 — archived R8B data only (no simulation)

Files: `r8c_a0.py`, `r8c_a0_fl.csv`, `r8c_a0_checks.txt`, `r8c_a0.png`.

- **OFF** (R8B gate A, 1 mHz–100 kHz): plateau 93.071, **fL_flat 0.0943 Hz**.
- **ON** (R8B gate C, 0.1–250 Hz): plateau 90.340, **fL_flat 0.3386 Hz**.
- Definition checks (all PASS):
  - PAC is set to `relative`, `relharmnum 0`;
  - all four clock sources have pacmag 0;
  - the PAC input is applied as VSP at 0° and VSN at 180°, pacd 1;
  - the measured input is 2.000 V at 0° at all 69 points;
  - outp/outn are saved;
  - the run reads the converged PSS, and the re-check took 1 iteration.

## Stage A — same R8B cell (read-only), new PAC 0.01–250 Hz at 40 points/decade

Files: `r8c_stageA_fl.csv`, `r8c_gates.txt`, `r8c_netlist_audit_A.txt`, `r8c_node_transfer.csv`, `r8c_stageA_nodes.png`, `raw/stageA/`.

| Case | Plateau 5–10 Hz | fL_flat | \|H(100)\| |
|---|---|---|---|
| A1 OFF static AC | 93.071 | **0.0943 Hz** | 85.6664 (= R8B) |
| A1 ON PAC sb0, maxsideband 1 | 90.342 | **0.3381 Hz** | 83.2514 |
| A1 ON PAC sb0, maxsideband 3 | 90.342 | 0.3381 Hz | 83.2514 |

- **maxsideband 1 vs 3:** identical at all 177 points (0 % difference). The Spectre 15.1 PAC help says maxsideband only selects which sidebands are output.
- **New run vs archived R8B PAC:** max difference 0.0106 % over 0.1–250 Hz.
- **Netlist audit:** no instance, parameter or subcircuit differs from the R8B gate A / gate C netlists. Only the analysis lines differ (sweep range, no noise analysis).

**Where the corner appears** (|H| at 0.1 Hz, OFF → ON, and fL_flat of each node transfer with its own plateau):

| Node pair | OFF \|H(0.1)\| | ON sb0 \|H(0.1)\| | fL_flat OFF | fL_flat ON |
|---|---|---|---|---|
| outp − outn | 67.73 | 25.58 | 0.0943 | 0.3381 |
| bufp − bufn | 67.73 | 25.58 | 0.0944 | 0.3384 |
| fp − fn (after the output chopper) | 80.40 | 30.36 | 0.0944 | 0.3384 |
| **p − n (summing nodes, before the input chopper)** | 0.0488 | 0.0262 | 0.0944 | **0.3385** |
| ia − ibx (OTA input, chopped) | 0.0488 | 7.6e-7 (sb0) | 0.0944 | 0.3385 |
| op − on (OTA output, chopped) | 80.40 | 1.25e-3 (sb0) | 0.0944 | 0.3384 |

- Every baseband node, back to the summing nodes p/n, has the same ON corner (0.338 Hz). The extra attenuation is therefore already present at p − n, the first node in the chain. The OTA, CD and LP stages add nothing to it.
- At ia − ibx and op − on the signal sits in the carrier band, so their sideband-0 values are small by construction. They are not evidence of a failure.
- **Carrier band (sideband ±1) at 1 Hz, normalised to the sideband-0 input:**
  - sideband −1: op − on 69.6 (≈ (2/π) × 110.1, the OFF value), ia − ibx 0.049;
  - sideband +1: only 2.05 and 0.0016.
  - This ±1 asymmetry is **not understood** (it may be how OCEAN `harmonic()` indexes the PAC sidebands). The carrier-band values are recorded but **not interpreted**.

**Deviation from the plan (budget).** The A1 PAC runs saved two extra terminal currents (XPRP:A, XPRN:A). These add equations to the system, so Spectre reported "equation size … does not equal" and ignored the archived PSS file. It then recomputed the PSS from scratch with the same a1 settings: 3 iterations, explicitly converged, in each of the two runs.
- The R8B baseline PSS was therefore recomputed twice instead of being reused. The plan allowed at most one rebuild.
- The results are unaffected: identical to R8B within 0.011 %.
- In Stage B the PSS and PAC jobs save the same signals, so the PAC run did reuse the written PSS (1 iteration).

## Stage B — diagnostic cell `Project/ece203_r8c_tb_linear_pr`

Files: `r8c_netlist_audit_B.txt`, `r8c_gates.txt`, `r8c_pss_ripple_l0.csv`, `r8c_stageB.png`, `raw/stageB/`.

**What changed.** Starting from `r8bSpecs()`, exactly two instances were removed and two added:
- removed: XPRP (p fn) and XPRN (n fp), both `ece203_ss_pr_cell`;
- added: analogLib `RPRP (p fn)` and `RPRN (n fp)`, each **3.128 TΩ** (the value pre-set from R7C).

The audit passes ×3 (B0, B1 PSS, B1 PAC): nothing else changed, the parameters are identical, `ece203_ss_pr_cell` is the only subcircuit no longer netlisted, and EOC/CHP are absent.

**B0, chopper OFF** (dc + ac, no noise run): all gates PASS, so the one allowed correction (case l1) was not used.

| | MOS pseudo-R (A1) | Linear 3.128 TΩ |
|---|---|---|
| fL_flat | 0.0943 Hz | 0.0946 Hz |
| \|H(100)\| | 85.666 | 86.530 (+1.01 %; the R7C hypothesis is a ~5 fF A–B parasitic of the MOS) |
| DC CM: p/n, ia/ibx, fp/fn, op/on, buf, out | | each within 0.0001 mV of MOS |
| Power | 2.3094 µW | 2.3094 µW |

**B1, chopper ON**
- **PSS:** attempt b1 (= R8 a1 settings) converged on the first attempt — "achieved in 3 shooting-Newton iterations", norm 1.6e6 → 1.38e5 → 0.33. The b2 retry was not needed.
- **PAC:** used readpss and re-converged in 1 iteration.

| | MOS pseudo-R | Linear R |
|---|---|---|
| fL_flat OFF | 0.0943 Hz | 0.0946 Hz |
| fL_flat ON | 0.3381 Hz | 0.3409 Hz |
| **Q = ON / OFF** | **3.585** | **3.604** |
| ON \|H(0.1)\| / \|H(0.3)\| / \|H(1)\| | 25.58 / 59.95 / 85.75 | 25.63 / 60.26 / 86.52 |
| ON \|H(100)\|, phase | 83.251, −23.80° | 84.066, −23.79° |
| p − n ON fL_flat | 0.3385 Hz | 0.3413 Hz |

**Operating-state check** (PSS waveform over one period, linear vs MOS, `r8c_pss_ripple_l0.csv`):
- Peak-to-peak is identical within 0.1 %:
  - p/n: 5.672 / 5.673 mV;
  - fp/fn: 5.949 / 5.952 mV;
  - ia/ibx: 7.707 mV;
  - op/on: 10.62 mV.
- Means agree within 0.08 mV.
- The surrogate therefore keeps the zero-input periodic operating state. The pre-registered downgrade clause is not triggered.

**Pseudo-R terminal current** (in the PSS):
- The MOS pseudo-R current XPRP:A has edge spikes of about ±10 nA (mostly displacement current), an RMS of 20 pA, and a time average of −0.14 fA.
- The linear R carries < 0.5 fA.
- These are recorded only, not used for the verdict.

## Reading and limits

- Replacing the nonlinear MOS pseudo-R with a linear resistor that has the same static corner leaves the chopped corner unchanged: Q_R / Q_MOS = 1.005.
- The pseudo-R's time-varying small-signal admittance under the ±2.8 mV ripple is therefore **not needed** to explain fL ≈ 0.34 Hz.
- What remains is periodic switching in the loop around p/n — the input TG XCI, the output TG XCO, and their coupling to the summing nodes. This is a suspicion, not a tested mechanism. R8C does not separate XCI from XCO and does not identify a capacitance.
- **Back-of-envelope only, not evidence.** If the extra conductance at each summing node were a single parallel element, it would be (Q − 1)/3.128 TΩ, i.e. about 1.2 TΩ. A switched capacitor at 2 kHz with that resistance would be about 0.4 fF (C = 1/(f·R)). That is the scale of TG overlap/junction mismatch. A controlled experiment would be needed to test it.
- Other limits:
  - this is PAC small-signal around the zero-input PSS; no large-signal tran at 0.1 Hz was run;
  - tt / 27 °C only;
  - the ±1 sideband asymmetry is unexplained.
- Not run (per the task): PNoise, ordinary noise, 60 ms tran, frequency/MOS/Cc/Cfb/LP/clock changes. Old cells are read-only. The R8B archived PAC/PSS were only read.

## Files

`ece203_data/round8c/`:
- `r8c_plan.md`
- `r8c_lib.py`, `r8c_a0.py`, `r8c_analysis.py`, `r8c_netlist_audit.py`
- `r8c_a0_fl.csv`, `r8c_a0_checks.txt`, `r8c_a0.png`
- `r8c_stageA_fl.csv`, `r8c_fl_summary.csv`, `r8c_node_transfer.csv`
- `r8c_pss_ripple_l0.csv`, `r8c_gates.txt`, `r8c_netlist_audit_A.txt`, `r8c_netlist_audit_B.txt`
- `r8c_stageA_nodes.png`, `r8c_stageB.png`
- `raw/stageA`, `raw/stageB`: netlists, spectre.out(.gz), convergence lines, PAC curves (sb0 and ±1), PSS waveforms incl. pseudo-R terminal currents, DC op, job logs, PSS SHA-256
- `raw/watchdog.log`

New cell: `Project/ece203_r8c_tb_linear_pr` (diagnostic only; no ADE state).

Stopped; waiting for GPT review. The next experiment is not started.
