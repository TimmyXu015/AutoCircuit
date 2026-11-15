# AutoCircuit

## Current active project: ECE203 ECG (2026 Fall)

**Claude Code: begin with [ECE203 handoff](docs/ECE203_HANDOFF.md).** This short document states the latest design choices, Round-1 priorities, naming and execution checks. The detailed [Round-1 task](docs/ECE203_round1_task.md) provides full specs; [automation playbook](docs/automation_playbook.json) explains the existing Cadence automation environment.

Round 1 works on reusable real A1/A2 cascode and A3 5T OTA cells, a VCVS-validated capacitive feedback high-pass/pseudo-R macro, a passive 250Hz output RC, and an **entirely ideal-VCVS ECG** with **ideal VCVS DRL only**. **There are no completed ECE203 Cadence results in this handoff.** Preserve historical homework scripts; add new `ece203_*` files rather than overwriting them.

SKILL/OCEAN scripts that draw and simulate circuits in Cadence Virtuoso (UCSD ieng6, IBM cmrf7sf PDK).

Agents: start with [`AGENTS.md`](AGENTS.md) and [`docs/automation_playbook.json`](docs/automation_playbook.json).
Local Claude Code workspace (the user's lab-notebook folder): [`local_workspace/`](local_workspace/).

## Batch over SSH (no remote desktop needed)

```bash
ECE203_FA26_001              # course environment, once per login
~/AutoCircuit/run.sh p1a     # pulls, runs the job in a windowless Virtuoso, prints the results
```

Results land in the library, in `~/simulation/<cell>/...` (ADE L's folder) and in
`~/AutoCircuit_results/<job>.{txt,csv,log}`. Later, in the CIW, `p1aPlot()` plots them
without simulating again. Close the schematic in the GUI before re-running a job on it.

## One line in the CIW (remote desktop)

```lisp
load("~/AutoCircuit/ac.il") acGo("p1a")
```

Pulls, reloads, builds, simulates, plots, opens ADE L filled in and saves it as state
`p1a_auto`. The report is written to `~/AutoCircuit_results/ciw_p1a.txt` -- read it over
SSH with `cat ~/AutoCircuit_results/ciw_p1a.txt`.

## Use (in the CIW)

First time in a Virtuoso session:

```lisp
sh("cd ~/AutoCircuit && git pull")  load("~/AutoCircuit/ac.il")
```

Pick up new changes later:

```lisp
acReload()
```

Common-source amp:

```lisp
csBuild("SelfPractice" "cs_amp")   ; draw
csSim()                            ; simulate and print results
csSim(?vbias 0.55)                 ; another bias point
```

Width sweep at constant 10 uA (HW1 P2 c/d/e):

```lisp
csWSweep()                          ; table in CIW + ~/AutoCircuit_results/cs_wsweep.csv + plots
acDumpParams("SelfPractice" "cs_amp_w" "M0")   ; check the NMOS CDF parameter names
```

## Layout

| File | What |
|---|---|
| `ac.il` | entry point, loads everything, `acReload()` |
| `pdk_cmrf7sf.il` | PDK specifics: device names, model files, PDK variables |
| `lib_draw.il` | drawing helpers: place by pin, wires, grounds, substrate tie |
| `lib_sim.il` | OCEAN helpers: simulation setup with PDK models |
| `lib_ade.il` | ADE L helpers: open, models, variables, analyses, save state, API probe |
| `cs_amp.il` | common-source amp: `csBuild`, `csSim` |
| `cs_wsweep.il` | W sweep at constant Id: `csWSweep` |
| `hw1_p1a.il` | HW1 P1a: nfetx 5/1, Ids vs VGS at VDS = 1.8 V: `p1aRun`, `p1aPlot` |
| `sps.il` | self-practice: subthreshold vs strong-inversion CS amp at the same Id (`run.sh spsscan`, `sps`, `spsade`) |
| `spsg.il` | same comparison with the signal straight into the gate, Rs and CL as variables (`run.sh spsg`, `spsgade`) |
| `run.sh`, `batch/` | SSH batch runner and its jobs |

New circuit: add `name.il` and list it in `acFiles` in `ac.il`.
