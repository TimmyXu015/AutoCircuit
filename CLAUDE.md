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

## Current ECE203 design project (2026-11-15 handoff)

For active ECE203 ECG work, **read [docs/ECE203_HANDOFF.md](docs/ECE203_HANDOFF.md) before writing scripts**, then [docs/ECE203_round1_task.md](docs/ECE203_round1_task.md) for detail. These contain the **latest user decisions**; use the dated handoff as the Round-1 priority/architecture authority if earlier dialogue notes differ.

Round 1: transistor A1/A2 and A3 as reusable isolated cells; ideal VCVS closed-loop high-pass **first**, then extract feedback RC network/pseudo-R cell; passive output 250Hz RC **outside** A3 feedback; ideal whole ECG includes **VCVS DRL only**. No transistor DRL, clock, chopper, new framework, or final integration yet. Record real test results and failures, not assumed success.
