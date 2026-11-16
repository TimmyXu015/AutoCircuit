# ECE203 ECG — Round 1 results (2026-11-15)

> Status report for GPT / the user. Every number below comes from an actual Spectre run on ieng6
> (logs + CSVs in [`ece203_data/`](ece203_data/)). Nothing is claimed that was not simulated.
> Sizes and test values are **first guesses** chosen to make the blocks characterisable, not a
> verified design. Architecture follows [ECE203_HANDOFF.md](ECE203_HANDOFF.md); it was **not**
> changed to chase specs. Open decisions are listed at the end.

## Status per workstream

| Workstream | Cells (library `Project`) | Job (`~/AutoCircuit/run.sh <job>`) | Built / netlisted / simulated | Result |
|---|---|---|---|---|
| D-1 closed-loop ideal HP | `ece203_hp_ideal_tb` (golden reference, keep) | `ece203_hp` | yes / yes / yes | -25 gain, 0.1 Hz, 159 MOhm — matches design |
| D-2 extract feedback network | `ece203_hp_fb` (pins VIN SUM VOUT, symbol), `ece203_hp_fb_tb` | `ece203_hpfb` | yes / yes / yes | identical to D-1 (max diff 0 dB, 0 deg) |
| C ideal whole ECG | `ece203_lp_out` (pins IN OUT, symbol), `ece203_ideal_ecg` | `ece203_ideal` | yes / yes / yes | 39.99 dB, 0.100–249.8 Hz, Zin 159 MOhm; CMRR depends on assumed mismatch |
| B A3 5T OTA | `ece203_a3_ota` (symbol), `ece203_a3_ol_tb`, `ece203_a3_cl_tb` | `ece203_a3` | yes / yes / yes | works; low A0 (37 dB); x4 loop loaded by resistors; noise 46 uVrms |
| A A1/A2 telescopic OTA | `ece203_a12_ota` (symbol), `ece203_a12_ol_tb`, `ece203_hp_real_tb` | `ece203_a12bias`, then `ece203_a12` | yes / yes / yes | closed loop -24.95, 0.1 Hz–4.49 kHz, PM 90 deg, 668 nA; noise 13.3 uVrms (spec 3 for the whole chain) |
| Pseudo-R (`ece203_pseudor`) | — | — | **NOT STARTED** | — |
| Transistor DRL, bias generator, MC | — | — | out of Round-1 scope | — |

All schematics are drawn "netlist style" (instances on a grid, every pin a short labelled stub,
connections by net name, ground = label `gnd!`). Electrically checked by schCheck (0 errors) and by
reading the netlists; visually they are not pretty.

## Design variables / parameters used

| Name | Value | Where |
|---|---|---|
| `vref` | 0.9 V (ideal source in all testbenches — not a final-circuit source) | all |
| `cc`, `cf`, `rp` | 100 pF, 4 pF, 398 GOhm (ideal resistor) | `ece203_hp_fb` (top-level vars, shared by A1/A2) |
| `aol` (A1/A2 VCVS), `aol3` (A3 VCVS) | 1e5 (sweep 1e3/1e4/1e6 in D-1/D-2) | ideal tbs |
| `r1`, `r2` (A3 difference amp) | ideal ECG: 1 M / 4 M; A3 tb: 1 M/4 M and 100 M/400 M | **test assumption** |
| `rlp`, `clp` (output RC) | 3.18 MOhm, 200 pF | `ece203_lp_out`, A3 tbs as load |
| `rcm` (DRL CM sense, each side) | 10 GOhm | **test assumption** |
| `adrl` (DRL VCVS gain, inverting, ref vref) | 100 (sweep 10 / 1000) | **test assumption** |
| `rdrl` (R0) | 1 MOhm on; 1e15 Ohm = DRL off (keeps a DC path) | |
| electrode `rs`, `re`, `ce` | 2 kOhm, 1 MOhm, 50 nF (x3) | instructor model |
| `cbody`, `icm` | 200 pF, 0.1 uA AC (60 Hz interferer, ground -> body) | instructor model |
| mismatch `dcc`, `delec` | 0 / 0.01 (Cc on A1 side) / 0.1 (P-electrode Z) | **test assumption** |
| `ib3` | 50 nA into A3 IBIAS (mirror 1:4 -> tail) | A3 tbs |
| `ib12` | 100 nA out of A1/A2 IBIAS (mirror 1:6 -> tail) | A12 tbs |
| `vcp`, `vcn` | 0.70 V, 0.75 V (from the `ece203_a12bias` scan) | A12 tbs (ideal) |
| `cl12` | 5 pF load on A1/A2 output | A12 tbs |

Device sizes (W/L, all first guesses):

- A3 (`ece203_a3_ota`): M1/M2 nfetx 10u/1u (input, M1 = INP diode side); M3/M4 pfetx 2u/4u (mirror, M3 diode); MT nfetx 8u/4u (tail); MREF nfetx 2u/4u.
- A1/A2 (`ece203_a12_ota`): MREF pfetx 2u/4u; M0 pfetx 12u/4u (tail); M1/M2 pfetx 20u/1u (input, bulk = tail); M3/M4 pfetx 4u/0.5u (cascode, gate VCP); M5/M6 nfetx 2u/1u (cascode, gate VCN); M7/M8 nfetx 1u/10u (mirror, gates at n1 = drain of M5).
- ad/as/pd/ps set to W*0.54u / 2(W+0.54u) because PDK CDF callbacks fail in batch (known).

## Results

### D-1 / D-2: closed-loop ideal high-pass (VCVS)

| aol | \|H(100 Hz)\| | f_L (Hz) | \|Zin(10 Hz)\| |
|---|---|---|---|
| 1e3 | 24.366 | 0.09796 | 163.1 MOhm |
| 1e4 | 24.935 | 0.09996 | 159.6 MOhm |
| 1e5 | 24.993 | 0.10021 | 159.2 MOhm |
| 1e6 | 24.999 | 0.10023 | 159.2 MOhm |

DC: V(sum) = V(vout) = 0.899991 V at aol 1e5. D-2 (`ece203_hp_fb` instance) reproduces D-1 exactly.

### C: ideal whole ECG (`ece203_ideal_ecg`)

- DM (matched, DRL on), measured after the electrodes: max |Hdm| 99.93 (39.994 dB); f_L 0.1001 Hz; f_H 249.85 Hz; |Adm(60 Hz)| 97.21; phase(10 Hz) -1.7 deg.
- |Zin(10 Hz)| at inp and inn: 159.17 MOhm (at 1 mHz Zin is capped at ~10 GOhm by `rcm`).
- DC: every node 0.9 V (o1/o2 0.899991, o3/out 0.899955).
- 60 Hz CM, instructor method (Acm = |out(DRL on)| / |vcm(DRL off)|):

| case | adrl | \|vcm\| off | \|vcm\| on | \|out\| off | \|out\| on | CMRR off (dB) | CMRR on (dB) |
|---|---|---|---|---|---|---|---|
| matched | 100 | 0.665 V | 0.996 mV | 1.2e-10 (num. floor) | 0 | — | — |
| Cc 1 % | 100 | 0.663 V | 0.996 mV | 0.643 V | 0.966 mV | 40.06 | 96.53 |
| electrode Z 10 % | 100 | 0.665 V | 0.996 mV | 12.9 mV | 19.3 uV | 74.01 | 130.50 |
| Cc 1 % | 10 | 0.663 V | 9.14 mV | 0.643 V | 8.86 mV | 40.06 | 77.28 |
| Cc 1 % | 1000 | 0.663 V | 0.101 mV | 0.643 V | 97.5 uV | 40.06 | 116.45 |

- Designed on-chip C (nominal): 2x100 + 2x4 + 200 = 408 pF (+ OTA compensation/parasitics, none added yet). External electrode 3x50 nF and body 200 pF not counted.
- Not valid as spec evidence: power, noise, swing, DRL phase margin (memoryless VCVS, ideal VREF).

### B: A3 5T OTA

- I(VDD) 284 nA total (50 nA reference + 234 nA tail; tail above nominal 200 nA because of Vds mismatch MT vs MREF). Budget was ~0.25 uA.
- OP (vcm 0.9 V): M1/M2 ~117 nA, subthreshold, gm/Id 26.8; M3/M4 saturated, gm/Id 15.3; smallest saturation margin 0.21 V.
- Open loop, loaded by the output RC: A0 71.1 (37.0 dB) (ro of M2 ~23 MOhm); UGF 17.3 MHz (phase -111.6 deg).
- Input noise: 15.9 uV/rtHz @1 Hz, 5.26 @10 Hz, 1.75 @100 Hz; integrated 0.1–250 Hz 46.2 uVrms (flicker-dominated).
- Input CM range (follower within 10 mV): 0.52–1.72 V.
- x4 difference amp (stb PM = loopGain phase at |LG| = 1, Spectre +180 deg convention):

| r1 / r2 | \|Hcl(10 Hz)\| (ideal 4) | -3 dB BW at o | loop UGF | PM | DC output range |
|---|---|---|---|---|---|
| 1 M / 4 M | 2.76 | 1.75 MHz | 1.11 MHz | 148.8 deg | 0.39–1.71 V |
| 100 M / 400 M | 3.73 | 624 Hz | 57.9 kHz | 124.8 deg | 0.35–1.80 V |

### A: A1/A2 telescopic cascode OTA

- Bias scan (74 points): best VCP 0.70 V, VCN 0.75 V; smallest margin |Vds| - max(|Vdsat|, 0.1 V) = 57 mV (M2). M1/M2 |Vds| 0.157–0.159 V, M5 0.157 V, M4 0.181 V: **very little headroom** with output at 0.9 V.
- I(VDD) 668 nA (100 nA reference + 568 nA tail). Budget ~0.7 uA.
- Open loop (CL 5 pF): A0 14191 (83.0 dB), UGF 207 kHz, phase -91.8 deg.
- Open loop with an extra 1 MOhm to vcm (= A3 input resistor r1): A0 **6.48 (16.2 dB)**.
- Closed loop `ece203_hp_real_tb` (real OTA + `ece203_hp_fb`): |H(100 Hz)| 24.95, f_L 0.09999 Hz, f_H 4.49 kHz, |Zin(10 Hz)| 159.4 MOhm, loop UGF 4.51 kHz, PM 90.1 deg, output DC 0.9 V.
- Input-referred noise (closed loop, from VIN): 4.87 uV/rtHz @1 Hz, 1.43 @10 Hz, 0.445 @100 Hz; integrated 0.1–250 Hz **13.3 uVrms** (1 mHz–100 kHz: 38.4 uVrms). Open-loop tb: 12.8 uVrms. Flicker-dominated.

## Open decisions for the user / GPT (nothing below was changed by Claude)

1. **Noise**: one A1/A2 alone gives 13.3 uVrms in 0.1–250 Hz vs < 3 uVrms for the whole chain. Input pair 20u/1u PMOS at 284 nA is flicker-limited. Needs a sizing/current decision (input-pair area, gm/Id, current split) within the power budget.
2. **A1/A2 -> A3 coupling**: A1/A2 (telescopic, Rout >> 1 MOhm) loses its gain with a 1 MOhm load; A3's 5T loses gain with r1+r2 = 5 MOhm and with the 3.18 MOhm output RC. Either much larger resistors (100 M/400 M worked electrically but BW at o dropped to 624 Hz, below the >= 5 kHz target, and such resistors are large on chip), buffered outputs, or a different A3 input structure (e.g. capacitive/instrumentation-style subtraction). Architecture decision.
3. **A3 bandwidth vs output RC load**: with 100 M/400 M the closed-loop -3 dB at o is 624 Hz because the output RC loads the high-impedance 5T output. Decide whether A3 needs an output stage or a different RC impedance level.
4. **A1/A2 headroom**: telescopic cascode with output at vref = 0.9 V leaves ~57 mV margin. Consider vref choice, folded cascode, or sizing. Also a real bias generator for VCP/VCN.
5. **Current budget**: A3 284 nA (target ~250), A1/A2 668 nA each (target ~700). Total so far 2x668 + 284 = 1.62 uA, leaving ~0.6 uA for DRL + bias + VREF divider within 2.22 uA.
6. **Test assumptions to confirm**: rcm 10 GOhm, adrl 100, r1/r2 values, mismatch levels 1 % / 10 %.

## Next smallest experiments

- Pseudo-R `ece203_pseudor`: two-terminal PDK MOS-bipolar pseudo-resistor, I–V at +-10/50 mV, small-signal R near 0 V (target ~398 GOhm), standalone tb. Not started.
- ADE L states for the testbenches (only OCEAN runs so far).
- Noise summary (per-device contributions) of `ece203_hp_real_tb` to show which devices dominate.

## Files

- `docs/ece203_data/ece203_<job>.txt` — summary per job; `*_op.csv` — per-device OP (id, gm, gds, vgs, vds, vth, vdsat, region, gm/Id, margin); `*_ac.csv`, `*_noise.csv`, `*_stb.csv`, `*_cmsweep.csv`, `ece203_a3sw_*.csv`, `ece203_ideal_cm_*.csv`, `ece203_ideal_cases.csv`, `ece203_a12_scan.csv` — raw curves/tables.
- Code: `ece203_lib.il` (helpers), `ece203_hp.il`, `ece203_ideal.il`, `ece203_ota.il`; plots in `matlab/ece203_*_plot.m`.
- The user's lab notebook (PC) has the PNGs and Chinese log.md per experiment.
