# Notes for AI agents working on this repo

Read `docs/automation_playbook.json` first. It covers how to reach the UCSD ieng6 server
(SSH from the user's Windows PC through the MATLAB MCP server's `system()`), the
edit -> push -> `run.sh <job>` -> scp -> MATLAB plot loop, the SKILL framework in this
repo, the ADE L API calls that are known to work, and the traps already hit.

Ground rules (details in the playbook, `user_and_policies`):
- The user does the homework reasoning: deliver tools, data and plots, not final answers.
- Results for the user go to the lab notebook `C:\Users\Timmy\AutoCircuit_Results\`: each experiment folder holds only
  `log.md` + PNGs, raw files go to `_raw\<same folder>\`, and `LOG.md` gets one row per experiment.
  Never delete there.
- Never kill the user's own Virtuoso/spectre processes without asking.
- This repo is public: no keys, no IBM PDK model contents, no homework results.

When you learn something new (a working API call, a fix, a trap), add it to the playbook
in the same commit.


## Active next task — ECE203 Round 3B pseudo-resistor microtest (2026-11-16)

**User-approved next tiny experiment:** [docs/ECE203_round3b_pseudoresistor_microtest.md](docs/ECE203_round3b_pseudoresistor_microtest.md). Pause OTA gain optimization. First make one **real PDK MOS–bipolar pseudo-resistor** following the ECE203 lecture and measure standalone ±50 mV I–V / differential R near 0.9 V CM; verify device/bulk and numerical precision. **Only if standalone works**, replace both ideal feedback Rfb of the single-stage S2 BioAmp, using **frozen 5T NMOS input L=8 µm** and unchanged Cc/Cfb, and compare DC + AC against ideal. No Noise/STB/tran/MC/extra topology or big sweeps; stop after one comparison. Preserve all previous cells and user data; record short results and report blockers honestly.

**Results (2026-11-16): [docs/ECE203_round3b_pseudoresistor_results.md](docs/ECE203_round3b_pseudoresistor_results.md)** (data in docs/ece203_data/pseudoresistor/; cells Project/ece203_ss_pr_cell (pfet33x, D=G=bulk=B, S=A), ece203_ss_pr_iv_tb, ece203_ss_pr_tb, ADE states pr_w3u with gmin=iabstol=1e-18). Default Spectre tolerances are gmin-bound (useless); tight: W1u/L2u r(0)=9.7 TOhm, W3u/L2u 4.09 TOhm. S2 (5T L=8u): ideal Rfb 73.13 / fL 0.074 Hz vs pseudo-R 72.70 / fL 0.057 Hz. Stopped; waiting for user + GPT decision.

## Completed Round 3A — tiny 5T length scan (2026-11-16)

**User-approved immediate job:** [docs/ECE203_round3a_5t_input_length_scan.md](docs/ECE203_round3a_5t_input_length_scan.md). One question only: with the already proven single-stage S2 BioAmp, hold everything fixed except ordinary 5T OTA NMOS input-pair M1/M2 **L = 1 / 2 / 4 / 8 µm**, W remains 10 µm; extract DC OP, OTA open-loop A0 (clearly distinguish actual vs gm/gds estimate), S2 gain at 100 Hz, minimum headroom and supply current. **DC + AC only; no Noise, STB, tran, extra sweeps, topology change, or Cascode.** Work on new isolated cells and job; keep all previous results. **Stop after four points**, post short table, wait for user + GPT decision. The user expressly prefers fast, small experiments over comprehensive multi-stage batches.

**Results (2026-11-16): [docs/ECE203_round3a_length_results.md](docs/ECE203_round3a_length_results.md)** (CSV + one plot in docs/ece203_data/single_stage_length/; cells Project/ece203_ss_lscan_ota, ece203_ss_lscan_tb, ece203_ss_lscan_ol_tb with ADE states lscan_L1u..L8u; jobs ece203_ss_lscan, ece203_ss_lscan_ade). Actual OL A0 71/107/173/280 for L 1/2/4/8 um; S2 |Hdm(100)| 41.2/51.3/62.8/73.1 (best 37.28 dB < 38 dB). Stopped; waiting for user + GPT decision.

## Completed Round 3 — classroom single-stage BioAmp (2026-11-16)

**New user-approved architecture experiment:** [docs/ECE203_round3_single_stage_bioamp_task.md](docs/ECE203_round3_single_stage_bioamp_task.md). The user explicitly does **not** want more Cascode / buffers / new second stages for this round. Build an **independent, basic single-OTA capacitive-feedback instrumentation amplifier** following ECE203 Lec8–10 slides 23–27. First reproduce the ideal-golden capacitor network and then plug in the existing **ordinary 5T** OTA as a frozen measured physical starting point. Expect limited 5T open-loop gain: report failures faithfully and stop after the bounded tests; do not silently optimize or change topology. Protect all old cells, notes and user GUI sessions. Check quota before running.

**Results (2026-11-16): [docs/ECE203_round3_single_stage_results.md](docs/ECE203_round3_single_stage_results.md)** (data/figs in docs/ece203_data/single_stage/; cells Project/ece203_ss_ideal_tb, ece203_ss_real_tb with ADE states ss_S1/ss_S2; jobs ece203_ss_run, ece203_ss_ade). Ideal S1/S2 = 9.999/99.9; real 5T S1/S2 = 8.66/41.2 (S2 32.3 dB, -7.7 dB, in-band loop gain 0.70); diff-input noise 51/47 uVrms. Stopped; waiting for user + GPT decision.

## Previous completed task — ECE203 Round 2B loading diagnosis (2026-11-15)

**User-approved next experiment:** [docs/ECE203_round2b_loading_diagnosis.md](docs/ECE203_round2b_loading_diagnosis.md). **Results (2026-11-16): [docs/ECE203_round2b_loading_results.md](docs/ECE203_round2b_loading_results.md)** (data/figs in docs/ece203_data/round2b/). Stages A–C done; waiting for user + GPT decision. This supersedes the former Round-2A active-job instruction **only for the next execution round**; preserve all earlier results. **First construct and simulate the actual three-real-OTA closed-loop ECG cascade**, then isolate A1→A3 input loading, A3 finite gain and feedback-resistor loading, and A3 output RC loading. Last, run only the bounded R1/R2 1M/4M, 10M/40M, 100M/400M interface comparison. Freeze transistor topology and noise W/L optimization; do not add buffer/new amplifier topology without user/GPT approval.

**Round-2A completed results:** [docs/ECE203_round2_noise_results.md](docs/ECE203_round2_noise_results.md) and [docs/ECE203_round2_noise_scan.md](docs/ECE203_round2_noise_scan.md). The single-branch best 5.28uVrms noise is NOT a complete-chain pass, and 1MΩ standalone loaded A1 A0=6.48 is NOT the measured real cascade closed-loop gain. Both are hypotheses/benchmarks to investigate, not reasons to invent full-chain results.

## Current ECE203 design project (2026-11-15 handoff)

Latest measured status: [docs/ECE203_round1_results.md](docs/ECE203_round1_results.md) (data in docs/ece203_data/).
For active ECE203 ECG work, **read [docs/ECE203_HANDOFF.md](docs/ECE203_HANDOFF.md) before writing scripts**, then [docs/ECE203_round1_task.md](docs/ECE203_round1_task.md) for detail. These contain the **latest user decisions**; use the dated handoff as the Round-1 priority/architecture authority if earlier dialogue notes differ.

Round 1: transistor A1/A2 and A3 as reusable isolated cells; ideal VCVS closed-loop high-pass **first**, then extract feedback RC network/pseudo-R cell; passive output 250Hz RC **outside** A3 feedback; ideal whole ECG includes **VCVS DRL only**. No transistor DRL, clock, chopper, new framework, or final integration yet. Record real test results and failures, not assumed success.
