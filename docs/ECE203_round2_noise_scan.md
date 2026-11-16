# ECE203 Round 2A — A1/A2 noise diagnosis and controlled parameter sweep

**Requested by user: 2026-11-15. Actionable work order for Claude Code.**
**Scope: optimize noise of the EXISTING single-ended PMOS-input telescopic/cascode OTA. Do not change overall topology without user/GPT review.**
This is an experiment / characterization round; **do not advertise the stage as meeting the full project spec** until independently verified in the full chain.

## Read before editing

1. `CLAUDE.md` and `docs/automation_playbook.json` (established remote execution, Cadence naming, result policy, noninterference with user's GUI sessions).
2. `docs/ECE203_HANDOFF.md` (project requirements and architecture).
3. `docs/ECE203_round1_results.md` and its CSVs in `docs/ece203_data/` (measured baseline).
4. `ece203_ota.il`, `ece203_lib.il`, `ece203_hp.il`, `lib_sim.il`. Reuse `ece203_a12_ota`, `ece203_a12_ol_tb`, `ece203_hp_real_tb`; do not rewrite the working baseline.

### Proven Round-1 baseline to reproduce

| Item | Existing measured value / setting |
|---|---|
| A1/A2 transistor input pair | `M1/M2 pfetx W=20um L=1um` (same W/L on both) |
| Other devices | Leave EXACTLY as in `a12Cfg->devs` in `ece203_ota.il` for first sweep |
| Reference and cascode biases in testbench | `ib12=100nA` ideal sink, `VCP=0.70V`, `VCN=0.75V` |
| DC `VREF` and VDD | 0.9V and 1.8V |
| Whole A1 OTA VDD current | 668nA incl. internal current mirror branch |
| A1 feedback | `Cc=100pF, Cf=4pF, Rp=398GΩ` IDEAL resistor, high-pass ~0.1Hz, closed gain `|-25|` |
| Closed-loop result | `|H(100Hz)|=24.95`, fL~0.1Hz, fH~4.49kHz, PM~90°, Zin(10Hz)~159.4MΩ |
| Open-loop unloaded | A0~83dB, UGF~207kHz |
| High output loading warning | A0 with an added 1MΩ output load collapses to ~16.2dB. **This is a separate architecture issue; do not hide it.** |
| Input-ref. noise PSD | 1Hz 4.87µV/√Hz, 10Hz 1.43µV/√Hz, 100Hz 0.445µV/√Hz |
| Input-ref. integrated noise | **13.3µVrms over 0.1–250Hz** (single real OTA + feedback network) |
| Project requirement | **<3µVrms for the complete differential ECG chain** (TWO input OTAs + A3 + resistor noise, etc.) |

Reproduce Round-1 baseline with the **new** pipeline before altering sizes; tolerance target ≈2% for noise RMS and ≈5% for other quantities if environment unchanged. If mismatch is larger, stop and report setup differences.

## Stage 1 — explain where the noise originates (MANDATORY, before any optimization)

1. For `Project/ece203_hp_real_tb`, run Spectre `noise` across **1mHz–100kHz** with the intended `/VIN` input source and output `/o`; obtain both `getData("in" ?result "noise")` and `getData("out" ?result "noise")` in **V/√Hz**. Check source AC magnitude is 1 and every unrelated DC source has AC magnitude zero. Use same setup for every sweep point.
2. Extract noise contributions of the **individual physical devices** (`XA/M1`, `XA/M2`, `XA/M3…M8`, `XA/M0`, `XA/MREF`) and feedback `RP`, wherever Spectre's documented noise summary / device-noise source report supports it. Group as: input pair; PMOS cascodes; NMOS cascodes; mirror; tail & reference; feedback Rp; other. **Do not assume the noise-summary API works**—first probe supported Spectre/OCEAN output and check contribution sums against total **noise power** (not amplitude). If the PDK hides individual sources, report exactly what is unavailable instead of inventing allocations; consider independently toggling the resistor's thermal noise in a **separate, physically labelled diagnostic testbench**, without editing licensed PDK model files.
3. Distinguish **white/thermal floor** versus **1/f noise**, by PSD at 0.1, 1, 10, 100, 250, 1000Hz and log-log slopes. A ~1/√f amplitude slope suggests flicker-like behavior but does not prove the device source.
4. Capture (a) input-referred spectral density, (b) output-referred density, and (c) integrated RMS, and document exact integration endpoints. Do not confuse V/√Hz with V²/Hz.

**Output:** `ece203_noise_breakdown.csv` + a plot and short Chinese analysis; include unverified categories if the noise API cannot return device-level contributions.

## Stage 2 — fixed-current input-pair W/L sweep (MANDATORY)

**Independent variable:** change `M1` **AND** `M2` together, keeping matched geometry; everything else frozen initially. Choose values:

- Width W (µm): **20 (baseline), 40, 80, 160**.
- Length L (µm): **1 (baseline), 2, 4**.
- Total **12** first-grid geometries, including original baseline; do not restrict to simple constant W/L sweeps.

At each point:
1. **Hold the externally supplied ideal bias current at 100nA** and initially hold VCP/VCN at 0.70/0.75V; report actual VDD current and input-branch currents. "Fixed bias reference" does **not** imply every transistor remains at fixed inversion level when W/L changes.
2. Rebuild/parameterize an **isolated sweep testbench / cell or explicit job** so original `ece203_a12_ota` and its validated Round-1 cell can be reconstructed exactly. Prefer minimally extending the existing builder in an isolated new `ece203_noise_scan.il` and `batch/ece203_noise_scan.il`. Unique result directories per sweep to avoid overwriting in-use ADE/GUI PSF data. Do not run concurrent writes into the same Cadence cellview.
3. For any point with a bad DC operating point, attempt a **small bounded VCP/VCN re-bias scan** as a separately flagged rescued point; record both the fixed-bias failure and the retuned result. Do not silently optimize VCP/VCN independently for each point and then treat results as a pure W/L study.
4. Run `dcOp`, `ac`, `stb`, `noise` on the same feedback circuit. Measure at minimum:
   - W/L, W×L, |Id(M1/M2)|, total I(VDD) (including mirror/reference), gm, gm/Id, gds, VGS/VDS/VDSAT, region, min headroom/saturation margin and DC output.
   - `A0` unloaded and unloaded `UGF`; **gain under 1MΩ load** optionally as a diagnostic, not to be interpreted as full-system gain.
   - `|H(100Hz)|`, `fL`, `fH`, feedback-loop UGF and **phase margin**, `|Zin(10Hz)|`.
   - Input noise amplitude at 0.1/1/10/100/250/1000Hz and **integrated input-referred noise RMS over 0.1–250Hz**.
   - Also output noise RMS integrated **1mHz–100kHz divided by midband closed-loop gain** (separate instructor-style metric); and raw input-referred integration over 1mHz–100kHz to show high-pass noise amplification. Clearly distinguish these different metrics.
5. **Use PSD (amplitude spectral density squared) when integrating**: `vrms = sqrt(integral(S_v(f) df))`. Trapezoid integration in linear Hz with enough AC/noise points; run a frequency-density convergence spot-check on baseline and best candidate. For integrated output/midgain, use the real |H(midband)| value (not hardcoded 25 or 100).
6. A1/A2 paired differential floor estimate: `sqrt(2)*v_in_single` ONLY as a quick assumption of uncorrelated matched stages; label as an estimate, **not** the final full-chain noise simulation.

**Sweep CSV:** one row per W/L point, one column per measurement, with `run_status`, error reason, bias mode (fixed vs rebiased), and flags. Preserve per-point raw noise/AC/STB CSV under a clearly named folder or artifact path, plus images.

## Stage 3 — reasoned follow-up, only if diagnosis warrants it

After Stage 1 and the 12-point grid:

- If **M1/M2 flicker dominates**, extend ONLY promising geometries to W=320µm or L=8µm (separate follow-up batch, labelled). Watch gate/feedback parasitics and circuit cap budget; do not assume ideal 1/(WLf) scaling in this actual PDK.
- If **mirror/cascode devices dominate**, perform a small isolated 2× and 4× *area* sweep of the identified devices while holding topology and required current fixed; one group at a time. Do not indiscriminately enlarge everything.
- If feedback **Rp noise dominates**, distinguish ideal Johnson-noise limit versus MOS pseudo-resistor not-yet-created. Do not substitute an unverified MOS pseudo-R in this study.
- If results remain far above budget after sensible geometry-only experiments, **STOP**; provide a grounded topology-change recommendation (e.g. input pair optimization, input device choice, rebalancing noise sources) for GPT/user approval. No automatic folded-cascode, chopper, source follower, or reconfigured system gains.

## Acceptance filters (first-pass engineering guardrails, not fake final-spec pass)

- **Primary score:** minimum single-path **integrated input-referred noise 0.1–250Hz**, while maintaining valid operation. To give noise budget to 2 stages and A3, a **provisional aspiration** is ≤1.5µVrms *per A1*, preferably around 1µV; if impossible, report Pareto front and limitation rather than forcing.
- Full-project `I_total <4µW/1.8V ≈2.22µA`. Current baseline: 2×668nA + A3 284nA = **1.62µA** before real DRL/bias/VREF, so any A1 increased current needs an explicit whole-system budget.
- A1 standalone first-pass current ideally ≤0.7µA (higher points reported but marked budget-risk).
- `|H(100Hz)| ≈25` (±2% preferred), `fL≈0.1Hz` (±10%), `Zin(10Hz)>100MΩ` (in the correct closed-loop testbench), PM ≥60°, closed-loop bandwidth ideally >1kHz (original ~4.49kHz). All dimensions are **tunable** and these are screening criteria.
- Check every device is at a sensible DC operating point and output not close to 0 or 1.8V rail. Original min headroom estimate only ≈57mV. Flag candidates with margin <~0.1V; do NOT falsely reject every subthreshold device using only a strong-inversion VDSAT rule. Show actual region and VDS for review.
- At the end, verify any selected candidate has **no degradation in A1-to-A3 load compatibility** compared with baseline; A3 input network loading is still an **unresolved independent issue**.

## Deliverables, reporting, and do-not-touch

Deliver in the public AutoCircuit repo:
- A new reproducible `ece203_noise_scan.il` plus wrapper `batch/ece203_noise_scan.il`, registered in `ac.il`; a **safe** new workflow without breaking `ece203_a12` and previous homework jobs.
- `docs/ECE203_round2_noise_results.md`: results, evidence of actual Spectre runs, grouped noise contributors (or explicit unsupported), complete W/L sweep table and Pareto chart / plot paths, best candidates with tradeoffs.
- CSVs for sweep table, point-level spectra, plots; follow existing notebook conventions. Avoid uploading IBM proprietary models, credentials, license details, large private netlists, or proprietary model excerpts into this public repository.
- In Chinese, answer specifically: **(1) Which devices dominate noise? (2) How does W vs L affect flicker and thermal noise? (3) How much improvement is achieved at unchanged current? (4) Which changes impact gain, PM, headroom, input impedance? (5) Is ≤1–1.5µVrms per branch plausible without architecture change?**
- Report failures and commands to reproduce. If a portion of the sweep cannot run, keep successful measurements and explicitly list missing points.

**Do not** modify the ideal ECG model, A3 topology, DRL architecture, final Pseudo-R implementation, external electrode model or the system gain split in this round. Do not declare a new topology or edit the existing known-good A1 cell as a silent optimization. After experiment, return results **for user/GPT discussion and selection**. The user wants to learn the noise tradeoffs, not merely get an opaque "optimized" schematic.

## Implementation notes / pitfalls already encountered

- Working transistor devices are `cmrf7sf/nfetx` and `cmrf7sf/pfetx`; physical pins are D/G/S/B; source code `ece203_ota.il` uses `hw2DiffParams(w)` in builder to set source/drain geometry because native PDK CDF callbacks fail in batch. Preserve verified netlisting conventions.
- Original `ece203_hp_real_tb`: output `/o`, stimulus `/VIN`; noise used `analysis('noise ?start "1m" ?stop "100k" ?dec "20" ?p "/o" ?n "/gnd!" ?iprobe "/VIN")` and `getData("in" ?result "noise")`. Adapt verified commands, not imagined APIs.
- Probing a new `noise summary` API is exploratory; if unsupported, document the error. No fabricated device contribution percentages.
- Spectre impedance and gain measurements need their true reference/signal nodes; AC sources on DC-only VDD, VCP, VCN, VREF, IBIAS must be 0.
- Rebuilding the `Project` cell in an already-open interactive Virtuoso may create locks; never kill user's process or remove their files without approval.
