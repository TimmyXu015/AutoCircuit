# ECE203 ECG — Claude Code handoff (2026-11-15)

> **START HERE for the current ECE203 project.** This is the **execution handoff**, not evidence of completed design or successful Cadence runs.
>
> Authoritative detail: [Round 1 task and specification](ECE203_round1_task.md).
> Automation and server workflow: [playbook](automation_playbook.json).
> Repo rules: [../CLAUDE.md](../CLAUDE.md).

## What the user wants

Build **reusable Cadence schematic "LEGO bricks"** for an ECG front end, while separately checking an **ideal VCVS entire system**. Use the existing AutoCircuit SKILL/OCEAN infrastructure, not a new framework. User/GPT decide architecture and interpret electrical tradeoffs; Claude Code does repetitive schematics, robust batch jobs, simulations and reports. The user is handing the repo to Claude Code now.

Do **not** ask to redesign the system or implement a clock. No chopper, switched capacitor, clock generator, or PSS. Do not implement transistor-level DRL this round.

## Locked system choices versus test assumptions

| Topic | Current choice | Status |
| --- | --- | --- |
| Amplifier blocks | Two identical first-stage **PMOS-input single-ended cascode OTA** instances A1/A2, then one **single-ended 5T differential-input OTA** A3 | **Candidate physical topology**; prove with PDK and 1.8V headroom |
| Input amplification | Each A1/A2 in **inverting capacitive feedback**, nominal −25 midband per path; A3 subtracts paths ×4 -> overall gain magnitude 100 (40dB) | **Architecture choice**; this is NOT the original non-inverting three-op-amp INA |
| High-pass | `Cc` at input; `Cf || Rp` between summing input and OTA output, with VREF on OTA (+); `Rp` initially an **ideal resistor** | **Architecture choice**; **test the COMPLETE closed loop with VCVS first**, then extract `ece203_hp_fb` three-pin passive sub-cell |
| High-pass first numbers | Per branch Cc=100pF, Cf=4pF, Rp≈398GΩ -> nominal fL≈0.1Hz and gain −25 | **Starting numbers, NOT validated** |
| Pseudo-R | Standalone **two-terminal** MOS pseudo-resistor cell later replaces ideal Rp; test I–V, differential resistance and nonlinearity independently | **Exploratory PDK module**; do not let it block ideal HP or OTAs |
| Low-pass | **Permanent passive output RC after A3**, placed **outside** A3's feedback node | **Architecture choice**; start RLP=3.18MΩ/CLP=200pF (~250Hz) with a high-Z output load |
| A3 frequency goal | **Do NOT deliberately make its closed-loop pole 250Hz.** Make A3 safely wider band than 250Hz; first aim closed-loop BW≥5kHz and adequate PM | **Provisional engineering targets**, e.g. GBW≥25kHz at noise gain ≈5 |
| DRL | **IDEAL VCVS ONLY within whole-system schematic** for Round 1. Sense common-mode before coupling caps via high-Z sense network; negative feedback through R0 and right-leg electrode | **Behavioral test only**; finite-gain/pole sensitivity and loop sign must be tested |
| Bias | 1.8V system supply; standalone OTA testbenches may use ideal bias for characterization | **Final bias generator postponed**; must track realistic total current |
| Fabrication | Schematic + Spectre verification, no layout work assigned | **Round-1 scope** |

## EXACT Round-1 execution order

**Parallel workstreams, not a single serial critical path:**

1. **Physical A1/A2 OTA**: create `ece203_a12_ota` (instantiate twice later) and an independent `ece203_a12_tb`; discover verified IBM cmrf7sf device pins/CDF first. Single-ended output is mandatory for this candidate. Check OP (currents, gm, gds, saturation/headroom), A0, GBW, PM in a real feedback test, input-referred white/flicker noise, output swing. Initial whole-module supply budget ~0.7µA **per OTA**, not per input transistor.
2. **Physical A3 OTA**: create `ece203_a3_ota` and `ece203_a3_tb`. 5T differential-input, single-ended-output; characterize physical OP, A0, ×4 resistor-difference closed loop, PM, BW (target ≥5kHz), supply current (~0.25µA starting budget), noise, load. **Never add huge C just to make 250Hz.**
3. **Closed-loop ideal high-pass first**: build `ece203_hp_ideal_tb` with **VCVS + actual Cc/Cf/ideal Rp + VREF**. Verify DC bias, −25 midband, 0.1Hz corner and |Zin| @10Hz. Only THEN extract reusable `ece203_hp_fb` **passive** (VIN/SUM/VOUT) and rerun same VCVS testbench; before/after results should match. Keep VCVS testbench intact as golden reference.
4. **Ideal whole ECG, in parallel**: create `ece203_ideal_ecg` from VCVS A1/A2/A3, passive feedbacks, A3 outside-loop output RC, electrode model, body, 60Hz interferer, and **ideal VCVS DRL**. Verify AC differential gain/passband, Zin @10Hz, DRL polarity, 60Hz interference with DRL OFF/ON. A VCVS is rail-unlimited/noiseless and its power/PM are not proof of final spec. If finite A/pole needed, test separately and label those assumptions.
5. **After main blocks are under control**: independent `ece203_lp_out` passive RC macro and load test; attempt `ece203_pseudor` two-pin MOS I–V testbench (nominal differential R≈398GΩ near zero). Replace only Rp inside feedback network after an independent check. Do not claim transistor pseudo-R is verified from a schematic alone.

**Important:** `ece203_hp_fb` is **not itself a stand-alone high-pass**. It is a passive three-terminal feedback network that forms an active high-pass only **with a correctly closed amplifier loop**.

## Baseline specs to annotate in outputs

| Metric | Requirement |
| --- | --- |
| Differential gain | 40dB±2dB |
| Lower/upper corner | 0.1Hz and 250Hz, each ±10% |
| Total integrated input-referred noise | <3µVrms |
| Total power | <4µW (**all real OTAs + DRL + bias**; at 1.8V <2.22µA) |
| CMRR @60Hz | >85dB with DRL; also show without DRL |
| Input impedance | |Zin(10Hz)|>100MΩ |
| **Designed** total capacitance | <1nF |
| Additional reporting | DRL phase margin and forward-path NEF; mismatch Monte Carlo N>10 for final |

**Do not count the instructor-specified three external electrode-model 50nF caps against designed-on-chip <1nF**, but report them separately. Electrode **each**: 2kΩ series with (1MΩ || 50nF). Body-to-ground: 200pF plus 0.1µA 60Hz current interference for CMRR. Electrode offset may be ignored. One supply ≤1.8V plus one ideal 100nA reference are the final circuit source budget. Don't silently treat extra internal sources as allowable.

Initial **design** cap tally: 2×100pF + 2×4pF + 200pF = **408pF** (not including OTA compensation, parasitics, and any other added design caps; budget <1000pF). The external testbench electrodes are not part of this tally.

All values above are preliminary. In particular the **noise**, low-frequency pseudo-R implementation, DRL common-mode headroom, and 10Hz Zin **must** be checked before declaring success. Ideal VCVS cannot validate true noise, drive current, saturation or <4µW power. High-Z CM sense must not pull Zin below 100MΩ. Do not infer valid DRL phase margin from a memoryless VCVS.

## Use the existing AutoCircuit environment

Repository: `https://github.com/TimmyXu015/AutoCircuit` (public).

- Read `CLAUDE.md` and `docs/automation_playbook.json` completely before acting. The playbook documents the MATLAB->Windows SSH->ieng6 path; no new credentials should be created or logged.
- Preserve **all** existing HW and self-practice scripts. Add isolated new `ece203_*.il` files, register them in `acFiles` / `acJobs` in `ac.il`, and add matching `batch/<job>.il` wrappers. Don't edit original project files unless necessary.
- The runner `~/AutoCircuit/run.sh <job>` executes Cadence/Spectre on the school host and pulls latest repo. Propose jobs `ece203_a12`, `ece203_a3`, `ece203_hp`, `ece203_ideal`, and optionally `ece203_lp` / `ece203_pr`. Verify exact run names work.
- `pdk_cmrf7sf.il` currently identifies PMOS `pfet` and W/L CDF names as **unverified**. Probe actual PDK parameters and pin geometry rather than assuming them. No proprietary IBM PDK models, license files, credentials, personal data, or exported course answer files in this public repo.
- Keep the existing notebook convention in the playbook. Record per experiment: schematic/cell name; how launched; PASS/FAIL/NOT RUN; actual OP, gain, noise, BW/PM and current data; run logs and CSV/plots. **Do not fabricate results.**
- Avoid killing or disturbing the user's interactive Virtuoso/Spectre sessions. Check cellview locks and avoid concurrent writes to the same Cadence cell.
- If blocked, leave a reproducible failure log and a short specific question, not a redesign or a claim of success.

## What Claude should return for the first handoff iteration

Produce a concise Chinese status table for each workstream:

- cell(s), symbol pins, job name and reproducible run command;
- whether SKILL load/build/netlist/Spectre were **actually executed**;
- actual measurements with units and links/paths to logs and plots;
- open blockers and which specific architectural decision (if any) needs GPT/user review;
- next smallest concrete experiment.

**Done for Round 1** means independent real OTA testbenches and behavioral ideal integration have been created *and tested*, with `ece203_hp_fb` extracted only after closed-loop verification. A partially blocked but honestly logged result is acceptable; unrun code is not a passing test.

## Out of scope in Round 1

- Real transistor DRL, DRL compensation optimization, full bias generator;
- Real transistor-level whole ECG final integration;
- Chopper, switched capacitors, clocks, sampling, PSS/PNoise;
- Final Monte Carlo, PVT sweep, layout/tape-out, detailed ISSCC report.

Progress report due **2026-11-24 11:59pm**. Original project PDF displays **2025-12-04** for the final deadline despite naming 2026; verify final due date in Canvas.

---
Last design decision: DRL is **VCVS only** inside whole-system testbench during Round 1; output passive 250Hz RC is **permanent** and **outside** A3 feedback; build+verify VCVS closed-loop HP **before** extracting the reusable RC network.
