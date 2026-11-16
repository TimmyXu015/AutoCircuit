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


## Active next task — ECE203 Round 2A noise scan (2026-11-15)

**User-approved next experiment:** [docs/ECE203_round2_noise_scan.md](docs/ECE203_round2_noise_scan.md). **Results (2026-11-15): [docs/ECE203_round2_noise_results.md](docs/ECE203_round2_noise_results.md)** (data in docs/ece203_data/round2a/). First diagnose A1/A2 device-resolved noise, then run a controlled input-PMOS W/L matrix at fixed 100nA reference; report noise, OP, gain, BW, PM, power and tradeoffs. **Do not autonomously change the architecture, DRL, A3, or the known-good baseline cells.** This Round-2A order supersedes earlier Round-1 implementation priorities only for the current experiment. Read the Round-1 results and automation playbook as prerequisites.

## Current ECE203 design project (2026-11-15 handoff)

Latest measured status: [docs/ECE203_round1_results.md](docs/ECE203_round1_results.md) (data in docs/ece203_data/).
For active ECE203 ECG work, **read [docs/ECE203_HANDOFF.md](docs/ECE203_HANDOFF.md) before writing scripts**, then [docs/ECE203_round1_task.md](docs/ECE203_round1_task.md) for detail. These contain the **latest user decisions**; use the dated handoff as the Round-1 priority/architecture authority if earlier dialogue notes differ.

Round 1: transistor A1/A2 and A3 as reusable isolated cells; ideal VCVS closed-loop high-pass **first**, then extract feedback RC network/pseudo-R cell; passive output 250Hz RC **outside** A3 feedback; ideal whole ECG includes **VCVS DRL only**. No transistor DRL, clock, chopper, new framework, or final integration yet. Record real test results and failures, not assumed success.
