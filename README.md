# AutoCircuit

SKILL/OCEAN scripts that draw and simulate circuits in Cadence Virtuoso (UCSD ieng6, IBM cmrf7sf PDK).

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

## Layout

| File | What |
|---|---|
| `ac.il` | entry point, loads everything, `acReload()` |
| `pdk_cmrf7sf.il` | PDK specifics: device names, model files, PDK variables |
| `lib_draw.il` | drawing helpers: place by pin, wires, grounds, substrate tie |
| `lib_sim.il` | OCEAN helpers: simulation setup with PDK models |
| `cs_amp.il` | common-source amp: `csBuild`, `csSim` |

New circuit: add `name.il` and list it in `acFiles` in `ac.il`.
