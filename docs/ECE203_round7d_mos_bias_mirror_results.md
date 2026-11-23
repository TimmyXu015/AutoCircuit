# ECE203 R7D — one ideal IREF + real PMOS bias mirrors replace the two ideal 50 nA sources (2026-11-23)

- Task: [ECE203_round7d_mos_bias_mirror_integration_task.md](ECE203_round7d_mos_bias_mirror_integration_task.md).
- Pre-run plan with the gates: `ece203_data/round7d/r7d_plan.md`, committed in 16c99b5 before any run. All runs used scripts at 16c99b5.
- Script: `ece203_r7d.il`.
- Jobs: `ece203_r7d_build / a / b / c / ade`, with the candidate chosen by env `AC_R7D_CAND=a0`.
- Watchdog: `tools/r7d_watchdog.sh`.
- Data: [ece203_data/round7d/](ece203_data/round7d/).

## Verdict

| Stage | Result |
|---|---|
| A: build + DC + netlist audit | **PASS**. MP1 = MP2 = **53.45 nA** (gate 45–55 nA). |
| B: TG static DC / AC / STB + power | **PASS**, all gates |
| C: 2 kHz TG chopper, 60 ms transient | **PASS**, all gates |
| Mirror sizing correction (a1) | not needed, not built |
| ADE state | `Project/ece203_r7d_tb_bias_a0` / `r7d_bias_phaseA` |
| PSS / PAC / periodic fL, noise, MC, PVT, long-term (> 60 ms) | NOT RUN |

The bias change is functionally neutral:
- gain changed by +0.17 % (chopped, Hpre);
- edge error changed by +0.5 %;
- CMFB and DRL phase margins did not change.

**Costs:**
- Total power rises from 1.994 to **2.309 µW** (+0.315 µW). Of that, 0.180 µW is the new 100 nA reference branch. The other 0.135 µW comes from every bias current rising by +6.9 %, because the mirror ratio is 0.5345, not 0.5.
- The output CM DC offset moves from −0.08 to −0.49 mV. That is still within the 1 mV gate.

## Topology and netlist evidence

```
VDD 1.8 V (vdd 0)                                   VDDD 1.8 V (vddd 0)   (two independent sources, unchanged)
MP0 (pref pref vdd vdd)  pfet W 4u L 4u              MP2 (ibd pref vddd vddd) pfet W 2u L 4u -> XD.MREF
MP1 (ib   pref vdd vdd)  pfet W 2u L 4u -> XA.MREF diode + IBIAS gates of XC (MTA/MTB) and XCD (MKP/MKN)
IREF (pref 0) isource dc=100n          (the only bias current source)
```

- The devices are `pfetx` schematic symbols, which netlist as model `pfet`. Pins are D G S B.
- MP2's source and bulk are on `vddd`, so the DRL current is still metered on VDDD.
- The original NMOS MREF/MT devices inside XA and XD are untouched.

`r7d_netlist_audit.py` gives **AUDIT PASS** on the Stage A, B and C netlists. The outputs are `r7d_netlist_audit_stage{A,B,C}.txt`, each compared against the matching R7C netlist. The top-level diff from R7C to R7D is exactly:
- removed: `IB (vdd ib) isource dc=ib3` and `IBD (vddd ibd) isource dc=ibd`;
- added: `IREF (pref 0) isource dc=100n`, `MP0`, `MP1`, `MP2`.

Notes on the audit:
- `IINT` shows up as −/+ only because the line order changed. The line itself is identical.
- All 6 subcircuits are byte-identical: DRL OTA, FD OTA, TG chopper, CD, CMFB a2 and the pseudo-R cell.
- No other current source has a non-zero dc value. The remaining ones are stimulus sources, not bias sources:
  - `IINT`: dc 0, AC common-mode injection;
  - `IINTT`: 60 Hz sine, amplitude 0 here;
  - `IZN` / `IZP`: pulse injection used by the STB/step benches, idle here.
- The Stage C netlist keeps `VSPS sinephase=0` and the same analysis settings as R7C.

## Stage A — DC operating point (TG static phase A, tt 27 °C, dcc 0.01)

Data: `raw/stageA/A_a0.csv`, `A_C0_r7c_dcop.csv`, `A_C1_a0_dcop.csv`, plus netlists and spectre.out.

| | C0 R7C (ideal IB/IBD) | C1 R7D a0 |
|---|---|---|
| V(pref) | – | 1.3720 V (VSG of MP0 0.428 V) |
| V(ib) / V(ibd) | 0.30863 / 0.30863 V | 0.31158 / 0.31158 V (+2.9 mV) |
| IREF / MP0 | – | 100.00 / 100.00 nA |
| Bias into ib / ibd | 50.00 / 50.00 nA (ideal) | MP1 **53.45** / MP2 **53.45** nA (ratio 0.5345) |
| XA.MREF / XD.MREF | 50.00 / 50.00 nA | 53.45 / 53.45 nA (KCL closes exactly) |
| MP0 / MP1 / MP2 region | – | 2 / 2 / 2 (saturation) |
| MP0 VSD = VSG, \|VDSAT\| | – | 0.428 V, 0.067 V |
| MP1 / MP2 VSD, \|VDSAT\|, margin | – | 1.488 V, 0.068 V, **1.388 V** |
| OTA bias currents (XA tail, M1–M4) | 233.1 / 116.5 nA | 248.9 / 124.4 nA (+6.8 %) |
| CMFB tails / CD sinks / DRL tail | 165.7 / 105.1 / 233.1 nA | 176.8 / 112.3 / 248.9 nA (+6.7–6.8 %) |
| Minimum saturation margin, OTA / CMFB / DRL / CD | 0.0917 XA.M1 / 0.200 XC.MTB / 0.209 XD.MREF / 0.443 XCD.MKP | 0.0922 / 0.193 / 0.212 / 0.440 V |
| I_VDD / I_VDDD | 824.8 / 283.1 nA | 980.6 / 302.4 nA |

**Why the mirror ratio is +6.9 % rather than 1:2.**
- MP0 is a diode at VSD 0.428 V, while MP1 and MP2 sit at VSD 1.488 V.
- The extra 1.06 V across the outputs raises their current through channel-length modulation. Moderate inversion (gm/Id 18) at L = 4u.
- This was the direction expected in the plan.
- It is inside the ±10 % gate, so the one allowed correction (a1, with W about 1.87u) was not used.

## Stage B — TG static phase A, system DC / AC / STB

- Same `r7cStageB1` measurement, options (gmin 1e-18, iabstol 1e-17, reltol 1e-5) and 1 % Cc mismatch as R7C.
- C0 = R7C's Stage B CSV: same code and options, not re-run.
- Data: `r7d_stageB_summary.csv`, `raw/stageB/` (DC op, DM AC curve, CMFB/DRL STB, netlist, logs), and `r7d_stageB.png`.

| | C0 R7C | C1 R7D a0 | Change | Gate |
|---|---|---|---|---|
| op/on CM | 0.8999181 V | 0.8995052 V | −0.41 mV | \|Vcm − 0.9\| = 0.49 mV ≤ 1 mV **PASS** |
| fL (−3 dB vs \|H(100)\|) | 0.09563 Hz | **0.09564 Hz** | +0.02 % | 0.09–0.11 **PASS** |
| Hpre 10 / 60 / 100 Hz | 93.589 / 93.583 / 93.578 | 93.604 / 93.598 / 93.593 | +0.017 % | ≤ 5 % **PASS** |
| Hpre phase at 100 Hz | −0.728° | −0.683° | | |
| Hbuf(100) | 78.838 | 78.845 | +0.009 % | ≤ 5 % **PASS** |
| fH (static) | 7394 Hz | 7849 Hz | +6.2 % (gm follows the bias) | |
| CMRR60 | 108.42 dB | 108.90 dB | | ≥ 85 dB **PASS** |
| \|Zin\| at 10 Hz | 658.0 MΩ | 657.9 MΩ | | > 100 MΩ **PASS** |
| CMFB UGF / PM | 121.4 kHz / 84.51° | 125.3 kHz / 84.55° | | ≥ 60° **PASS** |
| DRL UGF / PM / LG60 | 1983 Hz / 90.25° / 32.4 | 2106 Hz / 90.25° / 34.2 | | ≥ 60° **PASS** |
| Minimum margin OTA / CMFB | 0.0917 / 0.200 V | 0.0922 / 0.193 V | | ≥ 50 mV **PASS** |
| Mirror PMOS | – | saturated, margin 1.39 V | | **PASS** |
| p/n DC (pseudo-R) | 0.8999189 V, V_AB 0.81 µV | 0.899506 V, V_AB 0.83 µV | | |
| P = 1.8·(I_VDD + I_VDDD) | 1.994 µW | **2.309 µW** | +0.315 µW | < 4 µW **PASS** |

**Power bookkeeping.**
- The power is the supply-delivered total, −1.8·[i(VDD:PLUS) + i(VDDD:PLUS)]. Spectre reports the current into PLUS, which is negative for a delivering source.
- IREF sinks pref → ground through MP0 from VDD. Its 100 nA is already inside I_VDD and is not added again.
- ΔI_VDD = +155.8 nA, made up of:
  - IREF branch: +100.0 nA;
  - MP1 excess: +3.45 nA;
  - XA tail: +15.8 nA;
  - XC tails and MD: +22.1 nA;
  - XCD sinks: +14.4 nA.
- ΔI_VDDD = +19.3 nA: MP2 excess +3.45 nA plus XD tail +15.8 nA.
- The ideal-source bench excludes the clock driver, a bandgap and the physical IREF generator.

**Output-CM shift.**
- The CM error grew from −0.08 to −0.49 mV. A hypothesis, not separately tested: the R7A a2 CMFB DC zero was trimmed through the MD width at a 50 nA ib. At +6.9 % bias the detector and load currents no longer balance exactly.
- The same −0.41 mV appears at (p+n)/2, because the pseudo-R ties the input-node CM to fp/fn.

## Stage C — 2 kHz TG chopper, 100 Hz 1 mV DM, 60 ms

Settings, identical to R7C (spectre.out echoes in brackets):
- cmin 1e-17 (`cmin = 10 aF`);
- maxstep 0.5 µs (`500 ns`);
- gmin 1e-18 (`1 aS`);
- iabstol 1e-17;
- reltol 1e-5 (`10e-06`).

Run facts:
- t_end = 60 ms; the watchdog was not triggered; the run took about 2 minutes.
- CSV SHA-256 `637805b0…94a5b9` was verified after transfer.
- C0 is the R7C T_pr_w4 wave, used read-only.
- Only one new 60 ms run was used.
- Analysis: `r7d_analysis.py`, which is `r7c_analysis` plus bias terms. Outputs: `r7d_stageC_summary.csv`, `r7d_stageC.png`.

Values are for the 40–60 ms window; 20–40 ms agrees.

| | C0 R7C | C1 R7D a0 | Gate |
|---|---|---|---|
| Hpre gain / phase | 90.831 / 0.535° | **90.981** / 0.490° (+0.17 %) | ≤ 5 % **PASS** |
| Hbuf gain | 76.480 | 76.601 (+0.16 %) | ≤ 5 % **PASS** |
| Hpre H2 / H3 | −102.1 / −85.7 dBc | −102.1 / −85.7 dBc | H3 not worse by > 10 dB **PASS** |
| DM edge error max / mean | 31.45 / 20.37 mV | 31.59 / 20.46 mV (+0.5 %) | ≤ +15 % **PASS** |
| DM residual RMS | 3520 µV | 3434 µV (−2.4 %) | ≤ +30 % **PASS** |
| op/on CM average | 0.899940 V | 0.899524 V (−0.48 mV) | ≤ 1 mV **PASS** |
| op/on CM at 200 Hz | 3.87 µV | 0.86 µV | ≤ 0.20 mV **PASS** |
| op/on CM edge spike, recovery to 1 mV | +8.46 / −2.86 mV, 0.011 µs | +8.45 / −2.84 mV, 0.011 µs | |
| vg range | 1.3232–1.3259 V | 1.3189–1.3216 V | |
| fp / bufp / drlr range | 0.851–0.950 / 0.503–0.582 / 0.899–0.904 V | 0.851–0.950 / 0.501–0.579 / 0.899–0.904 V | no clipping **PASS** |
| P (transient average) | 1.998 µW | **2.314 µW** | < 4 µW **PASS** |
| (p+n)/2 slope over 10–60 ms | −0.181 mV/s | −0.180 mV/s | listed. Pseudo-R rectification, as in R7C; long-term behaviour NOT RUN |
| Pseudo-R V(A)−V(B), XPRN | −48.0..+46.7 mV | −48.0..+46.7 mV | |

**Bias network under clocking (C1).** The 2 kHz chopper does not disturb the bias network in any meaningful way:
- V(pref) is constant to < 1 µV.
- V(ib): 72 µV pp, with an edge spike of +62 / −10 µV that recovers in under 1 µs.
- V(ibd): 48 µV pp.
- IREF and MP0 stay at 100.000 nA.
- MP1 drain averages 53.45 nA, with 1.6–1.8 nA pp (≤ 54.3 nA). MP2 averages 53.45 nA with 2.6 nA pp. These are short capacitive spikes at the TG edges; between edges the current is flat.

## Carry-forward risks (unchanged from R7C, not R7D failures)

- The CMFB-detector gate capacitance (about 67.4 fF) causes the DM edge error of about 31 mV.
- The CD gives a gain of 0.842 and drops the output CM to about 0.50–0.58 V.
- **Buffered Hbuf = 76.60 (37.68 dB), still below the course 38–42 dB target.**
- The final 250 Hz output low-pass is not yet in the R7 chain.
- The long-term rectification offset of the pseudo-R and its 1 Hz large-signal behaviour are not tested.
- 0.0956 Hz is a static AC corner, not a periodic (PAC/PSS) fL of the running chopper.

## Next

R7D is complete. Stopped; R7E was not started.

The one item most worth solving next is the output stage of the chain:
- the buffered gain is 37.68 dB, below the 38 dB minimum;
- the 250 Hz output low-pass is still missing.

That is the planned R7E (output LP + gain/load tuning).

Optional, not needed for any R7D gate: MP1/MP2 W of about 1.87u would bring the bias back to 50 nA and recover about 0.135 µW.

## Files

`ece203_data/round7d/`:
- plan: `r7d_plan.md`;
- audit: `r7d_netlist_audit.py`, `r7d_netlist_audit_stage{A,B,C}.txt`;
- summaries: `r7d_stageB_summary.csv`, `r7d_stageC_summary.csv`;
- code: `r7d_analysis.py`, `r7d_plots.py`;
- figures: `r7d_stage{B,C}.png`;
- raw data:
  - `raw/stageA`: DC op CSVs, netlists, spectre.out, build/job logs;
  - `raw/stageB`: case CSV, DC op, bias op, DM AC, STB, netlists, spectre.out, job log;
  - `raw/stageC`: full-resolution transient `.csv.gz` + sha256 with pref/ib/ibd and IREF/MP0/MP1/MP2 currents, spectre.out.gz, netlist, job log.

New Cadence objects: cell `Project/ece203_r7d_tb_bias_a0` and ADE state `r7d_bias_phaseA`. No old cell, data or ADE state was modified.
