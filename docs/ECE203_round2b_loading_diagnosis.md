# ECE203 Round 2B — Real A1/A2 → A3 loading diagnosis and controlled interface tests

**Work order approved by user: 2026-11-15.** Owner: Claude Code execution; user + GPT retain architecture decisions.

**Mission:** Diagnose whether the existing transistor-level ECG chain really delivers its required differential gain when A1/A2 drive A3, separate the individual loading mechanisms, and compare only low-risk *testbench* interface options. **Fix/understand loading before restarting noise optimization.** Do not silently choose a new circuit architecture.

## 0. Read and preserve

Read in this order:

1. `CLAUDE.md`, `AGENTS.md`, and `docs/automation_playbook.json` — execution path, SKILL/OCEAN job registration, safe batch workflow, Windows lab notebook.
2. `docs/ECE203_HANDOFF.md` and `docs/ECE203_round1_task.md` — agreed system architecture, pin topology, constraints, measurement definitions.
3. `docs/ECE203_round1_results.md` and `docs/ECE203_round2_noise_results.md` — independently reproduced Cadence results and frozen noise geometries.
4. `ece203_ota.il`, `ece203_hp.il`, `ece203_ideal.il`, `ece203_noise_scan.il`, `ece203_lib.il` — **inspect actual pin connectivity and sources** before writing a cascade test.

Preserve all working HW and ECE203 schematic cells, scripts, and result folders. Round 1, Round 2A and the calibrated `ece203_a12n_ota` variants are **read-only baselines** for this task. New work should use uniquely named cells and separate analysis directories, e.g. `ece203_load_...` and `docs/ece203_data/round2b/`. Use existing `ac.il`/SKILL/OCEAN/`run.sh` framework, not a new toolchain. Do not overwrite the user's interactive GUI/ADE sessions or kill any user processes. This is a public repository: **never commit any IBM PDK contents, confidential netlists/models, credentials, keys, license files, or course homework solutions**.

## 1. Why we are running this round — *measured baseline*, not a proven cascade result

| Quantity | Spectre result from existing tests | Correct interpretation |
|---|---:|---|
| A1/A2 original unloaded OL A0 | 14,191 V/V = 83.0 dB | Standalone real PMOS-input telescopic OTA |
| A1/A2 original OL with external 1 MOhm output load | 6.48 V/V = 16.2 dB | **Standalone loading diagnostic**, NOT measured full cascade closed-loop gain |
| A1 original isolated capacitive-feedback closed-loop gain | 24.95 at 100 Hz | Working unloaded/5-pF testbench; target 25 |
| A3 original real 5T OA open-loop A0 | 71.1 V/V = 37.0 dB | Loaded open-loop test |
| A3 real 4x resistor difference amp, 1 M/4 M | 2.76 V/V | Falls below ideal 4 |
| A3 real 4x resistor difference amp, 100 M/400 M | 3.73 V/V | Gain improves, but reported closed-loop BW at o ~624 Hz |
| Ideal VCVS whole ECG (no transistor OTAs) | 39.994 dB, 0.100–249.85 Hz | **Behavioral golden reference**, not physical cascade proof |
| A1/A2 best Round 2A *single-path* in-band noise | 5.28 uVrms (0.1–250 Hz) | Rebiased W160/L1 input pair + M7/M8 2/20, ~23 mV minimum margin; noise remains unresolved |

Likely mechanisms to verify rather than assume:

- The A1 telescopic stage has very high open-loop output resistance; A3 resistor input networks load its output. The **actual closed-loop output impedance** and coupled transfer can differ dramatically from the standalone open-loop loading test.
- The A3 conventional differential subtractor has **different impedances at its two source-facing ports**, including the path to the virtual summing node and the reference-side resistor divider. Check both individually and mismatches.
- A3's finite open-loop gain and its R1/R2 feedback paths lower the actual 4x transfer. The output RLP=3.18 MOhm / CLP=200 pF passive pole can also draw current from the high-impedance 5T output. The RC must stay **after the A3 feedback pickup node**, per locked system architecture.
- These effects interact; simple `Aol*beta` hand approximations are for reasoning, **not** substitutes for measured full-cascade closed-loop results.

## 2. Frozen architecture and numerical starting setup

**Keep:** two **real** `ece203_a12_ota` PMOS-input single-ended telescopic cascode first-stage instances with independent capacitive feedback, plus one **real** `ece203_a3_ota` single-ended 5T differential-input OTA in the conventional matched-resistor difference amplifier, followed by the passive output RC outside A3's feedback node.

- Supply 1.8 V, VREF=0.9 V initially. Testbench-only ideal VCP=0.70 V / VCN=0.75 V and ib12=100 nA reference sink per A1 **are allowed as diagnostic boundaries**, not a final implementable source count. Use the existing A3 testbench's ib3=50 nA excitation for the physical 5T until a real bias circuit is designed. Record all actual VDD supply currents, bias-source roles and what is NOT yet physically implemented.
- A1/A2 feedback each: Cc=100 pF input coupling, Cf=4 pF parallel with Rp=398 GOhm (currently **ideal resistor**), ideal midband -25. Reuse `ece203_hp_fb` and correct `INP/INN` sign. Do NOT replace Rp by unverified PDK pseudo-R here.
- A3 difference network R1=1 MOhm, R2=4 MOhm baseline. The independent comparison 100 M/400 M is evidence, not an already-approved replacement for a final IC. Be precise about which A3 port sees R1 toward its feedback summing node and which sees the R1+R2 divider.
- Output filter RLP=3.18 MOhm, CLP=200 pF; output node AFTER RC is the ECG reporting output, while A3 negative-feedback sense must be BEFORE RLP.
- Intended differential gain magnitude ~100 = 40 dB; band limits 0.1 Hz and 250 Hz; |Zin(10 Hz)|>100 MOhm; total designed capacitance <1 nF; whole power <4 uW; noise <3 uVrms **eventual system goals**. Do not claim these pass based on ideal VCVS or standalone simulations.
- Keep actual transistor DRL, real bias generator, PDK pseudo-R, Monte Carlo, chopper/PSS, and new noise sizing sweeps OUT OF SCOPE. The ideal behavioral DRL may be reused in a final validation sandbox after basic loading has been understood, not for the first isolated diagnosis.

## 3. Stage A — verify the actual real-OTA cascade first (highest priority; do this before any "fix")

Create a new isolated and reproducible 3-OTA **real transistor** testbench (example `Project/ece203_load_chain_tb`) with two independent instances of A1/A2 and one A3, all existing capacitor feedback, A3 resistor feedback and the A3 output RC. Reuse validated cells and symbols; **do not rewrite or overwrite the validated cells**.

1. Apply balanced differential signal about 0.9 V: AC +0.5 / -0.5 V at the two input-facing ports for a 1 V differential AC stimulus. Check both signs and A3 subtraction polarity in the actual netlist. Set all DC supplies/biases VREF/VCP/VCN AC magnitude to 0. Use one AC excitation at a time where needed for transfer matrices, and confirm no unintended concurrent AC source.
2. Start with **direct electrical inputs** (without electrodes, body and DRL) to isolate circuit loading. Preserve each nominal input capacitor/feedback cell. Do not use the external 50 nF electrode capacitors in this first diagnostic test.
3. Run dcOp + AC over 0.01 Hz–100 kHz or wider as needed; measure both A1 output nodes, A3 internal raw output before RC, final output after RC, A3 +/- input nodes and A1 summing nodes. Report complex/signed transfer from true differential excitation, magnitude+phase, 10 Hz / 60 Hz / 100 Hz gain, DC offset, low/high -3-dB corners where meaningful, and every active transistor's OP/headroom + total power (not just reference-current values).
4. Compare **on the same 1 V differential source normalization**: (i) expected ideal A1 ~-25 per path, (ii) expected ideal A3 ~4 between A1 outputs, (iii) measured real A1 effective transfer under A3 loading, (iv) real A3 transfer relative to actual A1 output difference, (v) full-chain total relative to differential stimulus. Identify where the gain is lost instead of merely reporting a final 40 dB number.
5. Recreate the same waveform definitions from the ideal VCVS-only whole system as a **golden transfer reference**, but clearly label differences caused by omitted electrodes/DRL. For an apples-to-apples check, add an all-ideal no-electrode sandbox with identical A3 resistor / LP network if necessary.
6. If the chain fails DC bias, rails, netlisting, stability or AC, preserve failure logs and return **the precise pin/node/OP blocker**; do not change topology to make the tests look good.

**Required Stage-A table:** source definition, per-stage measured gains (including sign/phase), complete cascade `|Hdm(100 Hz)|` and dB, DC node voltages, fL/fH, A1/A2 and A3 actual I(VDD), device margin, assumptions/bias sources, and PASS/FAIL/NOT RUN. **Do not conflate the standalone 1 MOhm OL A1 test with measured closed-loop full-chain gain.**

## 4. Stage B — isolate three loading mechanisms with controlled controls

Run the minimum set of independently comparable controls **with all other settings held fixed**. Prefer reusing the new testbench with explicit variant tags and automated CSV output:

- **B1 / A1→A3 port loading:** keep *real A1/A2*, compare (i) A1 isolated `ece203_hp_real_tb`, (ii) A1/A2 outputs connected to the actual A3 input resistor networks with A3 driven by its actual feedback, (iii) diagnostic high-Z voltage sensing at A1 outputs (testbench-only, ideal buffer/VCVS or probe) while A3 and resistor network remain clearly identified. The ideal buffer control is **not** an approved final buffer; explain exactly whether it changes A1 output loading.
- **B2 / A3 intrinsic finite gain and feedback-network load:** keep *real A3* and compare stimulus from ideal low-impedance signal sources versus actual real A1 outputs, with the same R1/R2. Report effective A3 gain referred to the *actual A1 outputs*, not only to the original ECG source. Optionally compare a VCVS-A3 with the **same physical resistor network** as a diagnostic of the finite-real-A3 effect. Test both differential source directions where helpful.
- **B3 / output RC loading:** with real A3 and frozen R1/R2, separately test (i) the full RLP+CLP present, (ii) a diagnostic no-RC/very-light-output-load variant, and (iii) capacitor or load isolation only if needed. Measure gain and bandwidth **at A3 raw output before RC** as well as **at final output after RC**. Distinguish intended passive 250 Hz filtering from unintended output loading. If a test temporarily removes the RC, do not compare its bandwidth to the 250 Hz final spec.

For any measured `Rout`, explicitly distinguish **open-loop OTA output resistance** from **closed-loop effective output resistance** and specify the perturbation method, operating point and loop status. Determine frequency-dependent input impedance **as seen looking into each A3 resistor-network input from A1** (e.g. 1/10/60/100/250 Hz) by a clean AC test-source injection, with the other inputs properly biased; do not infer from nominal 1 MOhm alone. Report both positive and negative branches because they are not automatically identical.

If full cascade STB is possible, place probes one feedback loop at a time with other loops intact; report gain crossover and PM for A1, A2, A3 separately. Do not quote a global PM from an arbitrary multi-loop break. If full loop analysis is blocked, explain how it was attempted and show transient/DC sanity instead of inventing stability.

## 5. Stage C — small bounded interface sweep; **diagnostic only, not topology redesign**

After Stage A/B work, use a small, targeted resistor-impedance sweep with constant A3 gain ratio=4:

| Case | R1 | R2 | Intent |
|---|---:|---:|---|
| C0 baseline | 1 MOhm | 4 MOhm | Show actual loaded failure |
| C1 | 10 MOhm | 40 MOhm | Check whether lighter A1 loading restores transfer |
| C2 | 100 MOhm | 400 MOhm | Compare existing standalone promising gain with full cascade |

Run identical dcOp+AC+stb (where reliable) for each point. Record both A1 actual midband -25 accuracy, A3 gain relative to A1 output differential, total 100x/40dB accuracy, -3dB corners, phase/PM, actual supply current, differential swing and all saturation/headroom margins. Also check loading from the **RLP/CLP**, resistor Johnson noise impact at least analytically or with an optional unmodified noise sanity run, added passive area feasibility and vulnerability to intrinsic node capacitance. **Do not launch a renewed transistor noise W/L optimization or claim low-noise success.**

Add at most one or two *clearly labeled conceptual diagnostics* (e.g. ideal high-input-impedance buffer vs resistor input; ideal capacitive sensing) **if** R1/R2 alone cannot reasonably recover transfer. These can be behavioral boundary cases only: do NOT automatically implement a transistor buffer, folded-cascode OTA, new A3 topology or capacitor-subtractor architecture without user + GPT review. Clearly indicate performance that relies on ideal sources cannot be counted as a physical pass.

For context after C0/C1/C2: optionally swap ONLY the A1/A2 geometry to the existing Round-2A best **frozen** `ece203_a12n_ota` with w12in=160u, l12in=1u, w78in=2u, l78in=20u, VCP=0.65, VCN=0.75, then repeat the most informative 1–2 loading cases, keeping all else fixed. **That variant has a reported ~23 mV minimum margin, so annotate it as headroom-risk; do not declare it the winning full chain.** No new geometry scan.

## 6. What to return — numerical evidence and decision gates

New proposed job names (final names may vary; document exact commands):

- `ece203_load_probe`: build/check new sandbox symbols and a one-point DC/AC sanity baseline.
- `ece203_load_chain`: Stage A physical cascade and transfer decomposition.
- `ece203_load_isolate`: Stage B controls and measured port impedances.
- `ece203_load_sweep`: Stage C three-point R1/R2 controlled sweep.

Register unique names in `ac.il` and add `batch/<job>.il` wrappers. Log exact `~/AutoCircuit/run.sh <job>` invocation and whether (1) file generated, (2) schematic built/schCheck passed, (3) netlisted, and (4) Spectre actually completed. Preserve full original cellviews unchanged. Reuse actual PDK `nfetx/pfetx` and verified CDF conventions from Round 1. Never label unrun calculations as Spectre results.

Commit the new source/testbench scripts and a concise **Chinese** report at `docs/ECE203_round2b_loading_results.md` with:

1. **A causal finding:** What fraction of loss is at A1 while driving A3, what fraction is intrinsic to A3/its resistor network, and what fraction is the output RC? Distinguish measured fractions from approximate explanatory models.
2. **A single comparison table** for C0/C1/C2 and baseline/best A1 variant if tested. Include actual transfer, phase, bias, gain margin/PM if meaningful, current, fL, fH, and physical limitations.
3. **At least these figures:** original standalone A1 closed transfer vs physically connected A1 transfers; per-stage and full-chain `Hdm(f)`; A3 before-/after-RC response; frequency-dependent A3 input loading and/or loaded loop gain. Use plots that the user can understand; label voltages and frequency axes.
4. **Data files:** tagged `dcOp.csv`, `ac.csv`, `stb.csv`, `zin.csv`, summary `csv`; scripts and repeatable job logs under `docs/ece203_data/round2b/` (public only if not PDK-confidential), plus the user's Windows results notebook `C:\\Users\\Timmy\\AutoCircuit_Results\\` using the documented `LOG.md` / `log.md` + PNG convention.
5. **Explicit design recommendation, NOT unapproved implementation:** e.g. whether changing A3 interface alone can save A1, whether A3 output stage/load still requires a separate design decision, and the smallest next controlled experiment. Recommend a Pareto choice based on actual system bandwidth/gain/headroom/current, not just the maximum 10 Hz gain.

**Stop and report back to user + GPT after Stages A–C. Do not proceed autonomously to transistor-level structural redesign or Round 2C noise optimization.** The goal is for the user to understand each cause and approve the next design move.

## 7. Priority, safeguards and deadline

**Priority 1:** actually connect the three real OTAs and report the measured cascade transfer. **Priority 2:** identify where gain is lost and separate the effects. **Priority 3:** only then the bounded R1/R2 comparison. If time/resources are constrained, deliver Stage A and as much of Stage B as works; partial honest results > invented passes.

Final course standard remains **differential gain 40 dB ±2 dB, BW 0.1–250 Hz ±10%, noise <3 uVrms, total P <4 uW, CMRR >85 dB at 60 Hz, |Zin(10 Hz)|>100 MOhm, on-chip C<1nF**, with NEF, DRL phase margin and mismatch Monte Carlo in final report. Progress Report due **2026-11-24 11:59 pm**; PDF final-report year has an apparent typo, verify Canvas. For this round **gain/stability diagnosis is the goal; do NOT represent the whole project as meeting specs**.

**Required final chat response from Claude (Chinese, concise):** jobs and execution status; numerical table of measured per-stage and overall gain including 1 M/4 M vs 10 M/40 M vs 100 M/400 M; identified physical mechanism(s) with plots; exact files and command(s); unresolved items; one specific next decision for user/GPT.