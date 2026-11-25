# WITHDRAWN — not the user's requested experiment

Do not execute this Monte Carlo task. The user clarified that the requested experiment is the early F2 ECG gain under 1 µA interference. Use [the active replacement task](ECE203_F2_1uA_interference_gain_task.md). No MC is requested for this round.

---

Historical draft, retained for reference only:

# ECE203 — F2 ECG mismatch Monte Carlo: midband gain only (2026-11-25)

User-approved bounded diagnostic. Claude Code: execute this task on the existing ieng6 Cadence environment and return measured data. Do not redesign the circuit.

## Frozen DUT and fixture
- Use the previously nominally passing **non-chopped F2**: `Project/ece203_r5nf_tb_f2`, OTA `ece203_r5nf_ota_f2`, ADE state `r5nf_final_f2`. References: [F2 results](ECE203_round5nf_final_noise_results.md), [F2 script](../ece203_r5nf.il), [R4 MC precedent](../ece203_r4.il).
- Full ECG testbench, body, electrodes, actual DRL enabled, actual bias references, CS second stage, pseudo-R W/L=4u/2u, existing LPF. Keep all sizes, topology, model settings and frozen cells untouched; if a new fixture is necessary use an isolated copy. Do not use an ideal OTA or bypass electrode loading. If the instructor ECG TB is separately available and can be used without changing the DUT, identify it and optionally compare nominal gain; otherwise explicitly state the existing F2 full-ECG fixture was used. Do not invent access to the instructor TB.
- TT, 27 C; reproduce original F2 nominal gain (~39.22 dB at 100 Hz using historical reference definition). For the course measurement use actual **post-electrode** differential input: `H = V(out)/(V(inp)-V(inn))` (verify net names in actual netlist). Historical `ep/en` denominator is pre-electrode, so report it separately if helpful, not as the course metric.
- Pure differential AC: adm=1, vcmin=0, icm=0, itr=0; DRL enabled. No simultaneous common-mode excitation. dcc=0 for nominal/mismatch baseline; do not combine fixed 1% capacitor mismatch with statistical mismatch without a separate explicit label.

## Stage A: verify statistical models, reproduce nominal
1. Read AGENTS.md and automation playbook. Inspect existing R4 C4 MC implementation and historical F2 scripts; verify actual cmrf7sf statistical model inclusion/section and Spectre mismatch mode from available local logs/netlist metadata without exporting proprietary PDK content. Check that mismatch is actually sampled per device, not just repeated nominal. Do not invent statistical parameters.
2. Run nominal DC+AC (1 mHz–100 kHz, existing tight tolerances, adequate points/decade). Report gain in dB at 10 Hz (primary midband), 60 Hz and 100 Hz (historical comparison), plus node DC bias and validity. If grossly inconsistent with F2 baseline, stop and diagnose fixture/measurement before MC. No tuning.
3. Explicitly state which elements have supported mismatch models. AnalogLib ideal passives are not assumed to have statistical mismatch. If unsupported, report the limitation; do not silently synthesize arbitrary mismatch.

## Stage B: mismatch-only Monte Carlo
- Start with N=20, seed 12345 if supported; verify true mismatch, unique sample IDs, and finite outputs. Use Spectre statistical Monte Carlo (not merely deterministic W/L or Cc sweeps). Adapt proven R4 C4/OCEAN flow in a separate task script as needed; use actual PSF family / per-run results, not estimates.
- If pilot succeeds, extend to N=100 total (or run a clearly separate N=100 batch; report which, do not double-count samples). If blocked, report exact errors and actual completed N. No PVT/process variation, no noise optimization, no CMRR or chopper work in this round.
- Per sample: gain_dB_10Hz, gain_dB_60Hz, gain_dB_100Hz, DC validity/convergence, sample number and status. Primary pass band 38–42 dB at 10 Hz; also report 100 Hz pass rate separately. Include min/max, mean, standard deviation, median, 5th/95th percentile, count below 38 dB/above 42 dB, valid/attempted count. Treat failures explicitly, not dropped silently; report valid-sample yield and overall attempted yield. Produce histogram with spec lines and nominal marker. Inspect worst samples for lost DC headroom/operating point only if needed; do not fix sizes.

## Deliverables
- `docs/ECE203_F2_mismatch_midband_gain_results.md` with actual simulated values, concise Chinese summary, exact fixture/settings, run commands, evidence of mismatch activation, limitations.
- `docs/ece203_data/f2_mc_gain/` with per-sample CSV, summary CSV, histogram PNG and non-proprietary run-status evidence. Save complete local raw files in lab notebook per playbook. Do not publish PDK models/netlists containing protected content, course answers, credentials, or personal data. Do not kill user sessions.
- State whether nominal, N=20 and N=100 were actually run. Stop after this diagnostic; user/GPT will decide next steps.

Primary question: after device mismatch, how much of the original ~40 dB midband gain remains, and what fraction of samples still meets 38–42 dB?
