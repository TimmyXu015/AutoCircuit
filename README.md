# AutoCircuit

SKILL/OCEAN scripts that draw and simulate circuits in Cadence Virtuoso (UCSD ieng6, IBM cmrf7sf PDK).

## Batch over SSH (no remote desktop needed)

```bash
ECE203_FA26_001              # course environment, once per login
~/AutoCircuit/run.sh p1a     # pulls, runs the job in a windowless Virtuoso, prints the results
```

Results land in the library, in `~/simulation/<cell>/...` (ADE L's folder) and in
`~/AutoCircuit_results/<job>.{txt,csv,log}`. Later, in the CIW, `p1aPlot()` plots them
without simulating again. Close the schematic in the GUI before re-running a job on it.

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
| `cs_amp.il` | common-source amp: `csBuild`, `csSim` |
| `cs_wsweep.il` | W sweep at constant Id: `csWSweep` |
| `hw1_p1a.il` | HW1 P1a: nfetx 5/1, Ids vs VGS at VDS = 1.8 V: `p1aRun`, `p1aPlot` |
| `run.sh`, `batch/` | SSH batch runner and its jobs |

New circuit: add `name.il` and list it in `acFiles` in `ac.il`.
