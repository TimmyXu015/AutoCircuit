# Notes for AI agents working on this repo

Read `docs/automation_playbook.json` first. It covers how to reach the UCSD ieng6 server
(SSH from the user's Windows PC through the MATLAB MCP server's `system()`), the
edit -> push -> `run.sh <job>` -> scp -> MATLAB plot loop, the SKILL framework in this
repo, the ADE L API calls that are known to work, and the traps already hit.

Ground rules (details in the playbook, `user_and_policies`):
- The user does the homework reasoning: deliver tools, data and plots, not final answers.
- Results for the user go to `C:\Users\Timmy\AutoCircuit_Results\<date>_<job>_<desc>\`; never delete there.
- Never kill the user's own Virtuoso/spectre processes without asking.
- This repo is public: no keys, no IBM PDK model contents, no homework results.

When you learn something new (a working API call, a fix, a trap), add it to the playbook
in the same commit.
