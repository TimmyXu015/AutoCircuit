# ECE203 ECG Project — Round 1 parallel build brief

Status: **approved first-pass plan; NOT final verified circuit.** Created 2026-11-15 for GPT ↔ GitHub ↔ Claude Code ↔ Cadence collaboration.

## Agent instructions and scope

Read `CLAUDE.md`, `AGENTS.md`, and `docs/automation_playbook.json` FIRST. Reuse the existing `ac.il` / `lib_draw.il` / `lib_sim.il` / `lib_ade.il` / `run.sh` pattern. Do not overwrite existing HW cells, scripts, results, or processes. Keep the IBM PDK model text and all credentials out of this **public** repo. On successful discovery of a new working API, document it in the playbook. Prefer independent batch jobs so one failure does not block the other experiments.

The user's specific Round 1 request: **build transistor-level A1/A2 and A3 as independent reusable Cadence blocks IN PARALLEL with a separate complete ECG behavioral schematic that substitutes ideal VCVS-based amplifiers.** These are **three distinct experiments**, NOT an instruction to immediately assemble actual transistors into the ECG top-level. No clock, chopper, switched-capacitor block or PSS work.

### Required deliverables

1. **`ece203_a12_ota`**: one reusable real PDK schematic/cell, later instantiated twice as A1 and A2. Also an independent testbench.
2. **`ece203_a3_ota`**: one reusable real PDK 5T OTA schematic/cell, plus independent testbench.
3. **`ece203_ideal_ecg`**: separate complete behavioral block-level schematic built from ideal VCVSs and actual/passive-equivalent networks; NO PDK transistor OTAs in this cell. Include body, two signal electrodes, right-leg electrode, DRL, CM sense, A1/A2 feedback, A3 subtraction.
4. Three individually runnable `run.sh` jobs, relevant SKILL files registered in `ac.il`, and numerical/CSV results plus a compact summary. Clearly distinguish **script created**, **netlist/sim tested**, and **not yet tested**. Prefer saving schematic cellviews and ADE states where feasible. Do not claim simulations passed without a run log.

Do not invent PDK names, device pin names or CDF field names: `pdk_cmrf7sf.il` notes that PMOS `pfet` and width/length bindings are *not verified*. Probe available PDK instances/parameters, inspect fresh netlist and OP, then commit reproducible scripts. Treat all device dimensions as tunable first guesses.

## Instructor hard constraints (ECG standard track, ECE203Project-2026F.pdf)

- Differential gain 40 dB ±2 dB (nominal ×100).
- Passband lower/upper −3 dB corners: 0.1 Hz and 250 Hz, each ±10%.
- Total integrated input-referred noise <3 µV RMS.
- Total power <4 µW; at 1.8 V this means total supply current <2.22 µA, **including DRL and bias circuits**.
- CMRR >85 dB at 60 Hz, DRL ON; show DRL OFF and ON; DRL phase margin reported.
- Total *employed design capacitance* <1 nF, input |Z| at 10 Hz >100 MΩ; report forward-path NEF.
- Only one circuit voltage source up to 1.8 V and one ideal current reference of exactly 100 nA (additional internal ideal sources penalized). Testbench excitation sources are separate from the circuit implementation; document source usage carefully rather than assuming the instructor exempts them.
- Electrode model per connection: **2 kΩ series with (1 MΩ || 50 nF)**; body-to-ground **200 pF** in parallel with **0.1 µA at 60 Hz** interference current source for interference/CMRR experiments. Electrode offsets can be omitted.
- No special temperature/corner sweep required in rubric, BUT mismatch Monte Carlo N>10 (prefer N=100) is required in final; first-round focus on TT baseline and report that mismatch validation is pending.
- No clock or chopping needed. Do not include the external/body 50 nF electrode-model capacitors in the on-chip design-capacitor tally, but show both totals separately to avoid confusing the specification.

## Track A — A1/A2 physical OTA (one reusable cell)

- Tentative PMOS-input, low-noise, high-gain **single-ended-output** cascode OTA; weak-inversion bias if useful. Do not force a fully differential telescopic core without designing a valid single-ended output and CM/headroom arrangement. If cascode fails 1.8 V headroom or single-ended conversion, record the blocker and an alternative; do not silently swap the approved architecture.
- Initial **whole-amplifier supply current** budget around 0.7 µA PER A1 or A2, including all branches; provisional, adjust only with explanation and keep a full-project budget.
- Nominal A1/A2 behavioral closed-loop gain magnitude 25, and high-frequency feedback noise gain approximately `1 + (Cc+Cin)/Cf ≈26.1` with Cc=100 pF, Cf=4 pF, Cin≈0.5 pF. Aim GBW ≥130 kHz, and closed-loop PM ≥60° where measurable. Open-loop DC gain enough to maintain ×25 accuracy (measure, don't assume).
- Run DC OP (Id branch/supply, Vgs/Vds/Vdsat, gm, gds, gm/Id, region); loop DC gain, poles/GBW, stability in a real closed-loop testbench; transistor noise (white + flicker) in relevant band. Report input-referred noise separately from total chain; include how extracted.
- First tests can use ideal feedback R/C and ideal bias boundary in TESTBENCH ONLY; final core bias generator limited to one 100nA reference plus VDD.
- Check both output swing and CM range at 1.8 V. Name all verification gaps.

## Track B — A3 physical 5T OTA

- 5T single-ended OTA (differential input pair + active mirror load + tail), 1.8 V, initially ≈0.25 µA whole-module current budget. Check PDK devices and bias (do NOT confuse tail current with total supply current).
- Used as 4× resistor difference amplifier with `R2/R1=4` and **noise gain =5**, feedback beta=0.2. Single-dominant-pole approximation suggests GBW≈1.25 kHz to achieve closed-loop 250 Hz pole. This is an **initial target**, not a guarantee for 5T.
- Characterize DC gain, OP, input range, output swing, driving load, closed-loop gain, −3dB frequency, PM and needed capacitance; measure supply current and noise. If compensating for 250Hz requires high capacitance, report and compare with available <1nF circuit capacitor budget. Avoid assuming any ideal VCVS output RC is equivalent to real OTA pole.

## Track C — ideal complete ECG schematic, isolated from A/B

- A1/A2: ideal **high finite-gain** VCVS opamps, with closed-loop capacitive INVERTING amplifiers, not non-inverting classical INA. Each input electrode → `Cc=100pF` → inverting summing node; feedback `Cf=4pF` in parallel with initially **ideal passive** `Rp≈398 GΩ` from output to summing node; non-inverting terminal at `Vref≈VDD/2`. Expected nominal per-path transfer, relative to Vref:
  `H12(s)≈-s*Rp*Cc/(1+s*Rp*Cf)`, 0.1Hz high-pass, midband gain −25.
  NOTE: pseudo-resistor is *modeled as a linear giant resistor in this phase*. A transistor pseudo-R and its leakage/nonlinearity/noise are FUTURE work, not implemented by setting a PDK resistor to 398G and calling it verified.
- A3: model a conventional matched resistor differential subtraction stage, absolute differential gain=4, noise gain=5, with proper DC common-mode reference and **correct subtraction sign**. Use a finite high-gain VCVS open-loop block for opamp.
- Since an ideal VCVS has NO dominant pole, use an **explicit ideal first-order 250Hz low-pass transfer block/RC test filter** at the whole-chain output for Round 1 only; isolate its schematic so it can later be REMOVED when A3's actual 250Hz closed-loop pole is verified. If using output RC, choose its load sufficiently high or buffer explicitly so the 250Hz corner is meaningful. Report this as *temporary ideal LP*, not a final passive filter commitment.
- With Cc=100pF, `|Zin|≈1/(2π·10·Cc)≈159 MΩ` is a **target estimate, not proof**: measure Zin at the electrode-facing input with the CM sense/electrode/feedback connected. Track circuit capacitance nominally ≥2(100+4)=208pF, plus temporary LP/compensation and parasitics.
- DRL: start with sensing the average of **electrode nodes BEFORE the input coupling capacitors** through high resistors, to avoid ±25 common-mode gain from the inverting A1/A2 stages. Driver should counteract a positive body common-mode increase: **invert this PRE-coupling positive-gain CM sense**, through right-leg series R0 (initial 1 MΩ) plus the modeled right-leg electrode. Verify **negative** feedback polarity by AC/low-frequency sign checks and transient. Avoid accidentally shorting A1/A2 outputs or tying two signal electrodes together. A1/A2 output averaging is an alternative NOT to be used without re-evaluating the inversion and saturation.
- Keep the full external electrode models and 200pF body cap; include 60Hz 0.1uA current interferer.
- Use no extra on-chip reference source beyond 1.8V supply / 100nA bias; where Vref needed in behavioral schematic, ideally use `VDD/2` via passive divider (account for divider current), or flag a pure ideal behavioral dependency.
- For first pass, generate separate test conditions: (i) **differential AC gain** measured **after electrodes** to final output, and 0.1Hz–250Hz transfer; (ii) Zin at 10Hz; (iii) DRL OFF/ON 60Hz CM-to-DM, and the body CM baseline measured with DRL disconnected; (iv) ideal behavioral DRL loop gain/polarity/stability if model has finite poles. Record phase margin as *not physically meaningful* if all blocks are truly memoryless VCVS; add finite poles as a SECOND behavioral sweep if needed.
- **Do not trust behavioral rail/swing/noise/power**: high-gain VCVS can output 10s of volts without saturation. The DRL OFF simulation may produce mathematically valid but physically impossible voltages. Annotate these as limitations; no hard-spec 'PASS' for power, input-referred total noise, linear swing, or final DRL PM from ideal amplifier model. Passive resistor thermal noise can be examined separately.
- First sweep pure ideal A(s), then optionally A(s) with finite DC gain and a first-order pole to test sensitivity; never hide the pole assumption.

## Proposed verification matrix (first pass)

| Job | Schematic | Required measured artifacts |
| --- | --- | --- |
| ece203_a12 | physical A1/A2 cell + testbench | OP table, supply current, A0, UGF, PM, noise PSD and integrated input noise, known limitations |
| ece203_a3 | physical A3 cell + testbench | OP, current, closed loop ×4, −3dB f, C needed, PM, noise where feasible |
| ece203_ideal | VCVS A1/A2/A3/DRL + electrodes + RCs | differential AC response (0.01–10kHz), Zin @10Hz, 60Hz body CM and CMRR OFF/ON, DRL polarity, on-chip capacitor tally |

Do not fake outputs if Cadence is inaccessible. For the first milestone, the minimum value is **three Cadence schematics + three testbenches + reproducible logs/CSVs**. PDK test results and behavioral test results must be explicitly labeled. Prefer recording in the local AutoCircuit_Results lab-notebook convention specified by the playbook if available.

## Task sequencing for Claude

1. Inspect existing scripts, check PDK symbols/CDF, prepare new job names and independent schematic/testbench cells, create isolated file additions.
2. Get the **ideal complete ECG system** to netlist and run AC first; catch wiring and source-reference issues.
3. Independently implement A3 (simpler 5T) and A1/A2 (single-ended PMOS-input cascode candidate). Run OP and small-signal tests independently.
4. Provide compact status with exact job commands, CSV paths, plots, errors, and *design decisions that require user/GPT review*. Do not automatically alter the block architecture to fix a failing spec.
5. Do NOT implement final Pseudo-R transistor, transistor DRL, chopper, PVT corner sweeps, or Monte Carlo in Round 1 without another instruction.

## Engineering cautions carried forward

- Project is a transistor-level **simulation assignment, NOT a patient-safe medical circuit**; R0 is a model, not certification of safety.
- The original 3-op-amp INA non-inverting front end and the new inverting capacitive A1/A2 front end are DIFFERENT architectures. Follow the second for this round; do not combine incompatible resistor feedback schematics.
- Noise, gain, corner, power, and even feasibility of DRL cannot be fully established by ideal VCVS. Our plan specifically separates the proof obligations.
- High-voltage electrode common mode, insufficient DRL drive at ~0.2µA, and A1/A2 inversion are major unresolved risks.
- Existing project deadlines as written: progress 2026-11-24 11:59pm; final deadline line in the 2026 PDF inexplicably reads 2025-12-04: user should check Canvas for corrected final date.
