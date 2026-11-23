# ECE203 R7B — CMFB input loading vs. Chopper differential edge error (bounded causality test)

**Status at creation: TASK ONLY — no new Spectre results.** This is a *diagnostic* round, not a MOS redesign.

## 0. Research question and frozen scope

R7A's linearised **real MOS CMFB** met every registered integration gate, but swapping it for the R6D-R ideal CMFB increased the 2 kHz chopped differential edge error (max 9.58 → 31.97 mV), and the fitting residual RMS (0.912 → 3.589 mV) while reducing the OTA output common-mode edge spike (47.78 → 8.46 mV). R7A hypothesized that the **real detector input-gate loading on `op/on`** accounts for the differential degradation. No isolated test has established causality.

**R7B tests that hypothesis by adding ONLY symmetric passive capacitors `op → gnd!` and `on → gnd!` to the **R6D ideal CMFB** testbench**, comparing with both previously recorded complete 60 ms waves. Preserve all existing behavior and numbers; don't modify the R7A MOS cell.

Frozen:
- Real two TG choppers (2 kHz), `ece203_r6a_fd_ota`, real DRL, real `ece203_r6d_cd`, 10 pF per buffer output, `Cc/Cfb`, ideal `Rfb`, ideal VREF/VCAS/IB/IBD, ideal VPULSE and **the same ideal R6C CMFB**.
- Same `VDD=1.8 V`, tt/27°C, differential 100 Hz 1 mV input, `tch=500 µs`, `VSPS sinephase=0`, `tran 60 ms`, `maxstep=0.5 µs`, **`cmin=1e-17 F`**, `reltol=1e-5`, `iabstol=1e-17`, `gmin=1e-18`. Frozen output load, all active devices and bias.
- Compare against R6D-R `F_C_buf_10p` ideal-CMFB (40–60 ms Hpre 93.5025, DM max-edge error 9.577 mV, residual RMS 911.81 µV, CM+ glitch 47.78 mV) and R7A a2 (Hpre 91.7333, DM error 31.969 mV, residual RMS 3588.96 µV, CM+ glitch 8.464 mV).
- Goal: determine **how much of the observed R7A–R6D differential-edge degradation is explained by detector input capacitance alone**, not to make a tuned case look like R7A.

Source of truth: `docs/ECE203_round7a_real_mos_cmfb_results.md`, `docs/ece203_data/round7a/r7a_stage3_summary.csv`, `docs/ece203_data/round7a/r7a_sys_analysis.py`, `docs/ECE203_round6d_chopper_tran_recovery_results.md`, `docs/ece203_data/round6dr/r6dr_analysis.py`, `ece203_r6d.il`, `ece203_r6dr.il`, `ece203_r7a.il`. Read `AGENTS.md`, `CLAUDE.md`, and `docs/automation_playbook.json` before running. Older handoff Round-1 no-chopper scope is historical; this task concerns the already-authorized R7B research branch.

## 1. FIRST measure/justify an independent physical C estimate (no fitting)

The only new capacitances being modeled are **the extra input loading from XC.MA1 on `op` and XC.MB1 on `on`** of the R7A a2 real CMFB. These are nfetx 0.5 µm/40 µm (20 µm² each), in moderate inversion, ~83 nA/device. Do **not** equate lithographic gate area directly to capacitance and do **not** invent an oxide C density.

1. Preferred: extract per-device `cgg/cgs/cgd` (or PDK-supported equivalent charge derivatives) from the **actual R7A a2 system DC op**; inspect the PDK OP names used by Spectre. If unavailable, use a *small standalone AC gate-input admittance test* of the unchanged R7A detector at its actual DC operating point, with fixed ideal input sources: measure the imaginary input current, compute `C_eff(f) = Im(Y_in)/(2πf)` and report its frequency dependence and AC biases. Be careful about sign convention and any non-capacitive terms.
2. Extract/summarize **per OP branch** and per ON branch, not the sum of both; include known uncertainty (MOS gate-source motion/feedback makes C frequency- and operating-point-dependent). Distinguish total gate capacitance from the *extra capacitance* already present in R6D without an MOS CMFB. The added test capacitor should represent the extra detector load only.
3. Log `C_est` numerically **before running any new chopped transient**; store measurement method, netlist/OP evidence and estimate in a pre-run plan `docs/ece203_data/round7b/r7b_cap_plan.md` committed beforehand. If C cannot be measured reliably, label *estimate unavailable* and use one explicitly declared exploratory capacitor value from an explainable non-fitted bound; do not claim physical attribution without a justified C estimate.

## 2. Controlled A/B/C experiment

Build **new cells only**, e.g. `Project/ece203_r7b_tb_c0`, `ece203_r7b_tb_c1`, `ece203_r7b_tb_c2`, by copying **the same** `r6dBaseSpecs()` plus the same R6D XCD and CLBP/CLBN = 10 pF parts. The ideal CMFB must retain its VCVS sense, output, and PMOS actuator; it must not be rebuilt into a different model. The ONLY circuit difference between these new benches is `CCOP (op gnd!)` and `CCON (on gnd!)`, both `Cextra`. No intentional AC input to capacitors, no ideal current source injection, no hidden R or extra parasitic in only one group.

Predeclare run cases:
- **C0 = 0 extra** (new-cell control, should match R6D-R full ideal-CMFB 10 pF buffered).
- **C1 = C_est per branch** (calibrated estimate from §1, not fitted to observed edge error).
- **C2 = 2×C_est per branch** (sensitivity bracket; no retuning). If meaningful C_est uncertainty warrants a 0.5× case, replace C2 with 0.5× *before* seeing C1 results; keep at most 3 full-length new circuit runs.
- R7A a2 MOS and historical R6D-R remain **read-only references** with old raw waves.

Run a brief **~1 ms smoke test** only to check netlist syntax/first TG edge convergence, not to assert 100 Hz gain or full-edge settling. Then run **60 ms tran for each of C0,C1,C2**, same numerical options and cases; use the validated watchdog and isolated /tmp storage, delete only this round's rebuildable PSFs. Record code commit, correct `sinephase=0`, actual netlist diff showing two cap parts as the sole circuit difference, same Spectre settings and complete 60 ms. If C0 differs from old ideal baseline by >2% in DM edge peak or residual RMS, or >0.5% in Hpre, debug methodology and STOP before interpreting C1/C2.

## 3. Analyze *exact same definition* as R7A (don't change the ruler)

Use the existing `docs/ece203_data/round7a/r7a_sys_analysis.py` least-squares + edge-glitch definition (20–40 ms and 40–60 ms, 1 µs resample, DC + drift + 100/200/300 Hz). Prefer reuse of code, not a rewritten algorithm. Extract: Hpre, Hbuf, 100 Hz phase, **DM edge max/mean error**, post-fit DM residual RMS, CM 200 Hz component, CM edge spike, `vg` swing, total power, output common-mode. Overlay near at least 2 TG edges including the 42.5 ms edge:
- `fp−fn` vs fitted 100 Hz harmonic baseline, both raw and error curves; `op−on`, `(op+on)/2`, and `vg`.
- Edge-local measures for *immediate 0–2 µs peak*, *early 2–40 µs* and *late 40–200 µs residual* (same edge across four groups). In particular, separate injected edge error from slowly varying plateau and distinguish peak/error/settling.
- **IMPORTANT**: R7A's reported ~249 µs `settle1pct_max_us` is a *last threshold exceedance inside the 250 µs half-cycle* under a fitted-waveform error rule; it does **not** prove a clean physical 249 µs exponential time constant. Report it as **"does not settle below 1% before the next switch"**, and diagnose the plateau separately. Do not call it an intrinsic pole without measurement.

Quantify explanatory ratio (same metric, both windows):
`F_error = (metric(C1) - metric(C0)) / (metric(R7A_a2) - metric(R6D_ideal))`
for DM edge max and DM residual RMS separately. Also compare the actual wave *shape* and polarity, not only numeric RMS. This ratio can exceed 1 or be negative; report it faithfully rather than clipping.

**Interpretation decision rubric** (predeclared):
- Both ratios >=0.6 and <=1.4 **and** shape/sign resemble R7A: capacitance-only hypothesis has **strong supporting evidence** (not perfect proof: MOS input C is nonlinear and cross-coupled).
- Either ratio between 0.3 and 0.6, or only one metric reproduces: **partial contribution**, other mechanisms require study.
- Both ratios <0.3 (or opposite sign) with physically justified C_est: **capacitance alone insufficient**.
- If baseline mismatches, C_est unjustified, or simulation incomplete: **INCONCLUSIVE**, not PASS.
- Report separately any large effect on CM spike, gain, stability. C2 is only a sensitivity bracket and **must not** replace C1 in the physical attribution.

The purpose is causal diagnosis, NOT making the performance 'PASS'. Do not claim R7A has been improved, and do not tune MOS CMFB dimensions as a result of this round.

## 4. Boundaries and expected deliverables

- Max 3 full 60 ms new cases (C0/C1/C2), after the minimal diagnostic C extraction. No extra large sweep, no noise, PSS/PNoise, MC, PVT, layout, pseudo-R, bias/clock generator, R7A transistor edits or R5N-F edits.
- Save `ece203_r7b.il`, minimal new `batch/ece203_r7b_*.il`, precommitted `r7b_cap_plan.md`, `docs/ECE203_round7b_cmfb_gatecap_results.md`, numeric `docs/ece203_data/round7b/` CSV/scripts/PNG and raw important logs/waves. Output to user lab notebook according to `AGENTS.md`. Preserve all R7A/R6D artifacts and user Spectre processes.
- Pre-existing realistic sources may remain ideal: VPULSE, VREF, VCAS, IB, IBD, ideal Rfb, ideal linear CMFB (this is a causality *test bench*, not the next delivered MOS circuit). Report whether the hypothesis is supported, partially supported, refuted, or inconclusive, and the best tightly scoped next step.
- GitHub repository should get reproducible commits and report with actual commit SHA. **No simulated data may be invented.**
