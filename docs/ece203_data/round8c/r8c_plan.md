# R8C pre-run plan — periodic high-pass corner (chopper ON fL ≈ 0.34 Hz vs OFF ≈ 0.095 Hz)

Task: `docs/ECE203_round8c_periodic_highpass_rootcause_task.md`. Committed **before any R8C Spectre run**.
Code: `ece203_r8c.il`, `tools/r8c_watchdog.sh`, `batch/ece203_r8c_{a1off,a1pac,build,b0,bpss,bpac}.il`; analysis `r8c_lib.py`, `r8c_a0.py`, `r8c_analysis.py`, `r8c_netlist_audit.py`.
Options for every run: cmrf7sf tt 27 °C, gmin 1e-18, iabstol 1e-17, reltol 1e-5 (R8/R8B). Zero input (vd 0, adm 0 for ON, dcc 0), `tch` 500 µs.

## Definitions (fixed now)

- **Transfer** = (V(x+) − V(x−)) / (V(ep) − V(en)), dividing by the *measured* input (AC, or PAC sideband 0). Output = `outp − outn`.
- **fL_flat** (`r8c_lib.fl_flat`): plateau P = mean |H| over the grid points with 5 ≤ f ≤ 10 Hz; fL = the frequency, scanning downward from 5 Hz, where |H| first falls below P/√2, log|H|–log f interpolation. Sensitivity: the same with P = max (reported, not used for gates).
- **Q** = fL_flat(ON, PAC sb0) / fL_flat(OFF, static AC), same cell.

## Stage A0 — zero-cost recomputation from archived R8B data (done before this plan; no simulation)

`r8c_a0.py` → `r8c_a0_fl.csv`, `r8c_a0_checks.txt`, `r8c_a0.png`:

| | plateau 5–10 Hz | fL_flat |
|---|---|---|
| OFF static AC (R8B gate A, 1 mHz–100 kHz) | 93.071 | **0.0943 Hz** (max-plateau 0.0944) |
| ON PAC sb0 (R8B gate C, 0.1–250 Hz) | 90.340 | **0.3386 Hz** (max-plateau 0.3387) |

Definition checks all PASS (13): PAC relative relharmnum 0; the four clock sources pacmag 0; VSP pacmag=pacd phase 0, VSN pacmag=pacd phase 180, pacd 1; measured |V(ep)−V(en)| = 2.000 V at 0° at all 69 points; outp/outn saved; readpss of the converged file; PSS re-check "achieved in 1 shooting-Newton iteration". **A0 supports both numbers → Stage A1 may run.** (Q_MOS from archived data = 3.59.)

## Stage A1 — read-only R8B cell, archived converged PSS

- Reuse `/tmp/lix015_r8b/pss_converged.pss` only if SHA-256 = `7d6ab501…aad2` (checked in SKILL before each run; verified 2026-11-23 05:4x). Otherwise rebuild once with the a1 settings (the one allowed rebuild).
- **A1 OFF** (`ece203_r8c_a1off`): chen 0, dc + ac 1 mHz–100 kHz 50/dec; transfers outp−outn, bufp−bufn, fp−fn, p−n, ia−ibx, op−on; DC nodes, I(VDD), I(VDDD); op info XA M1–M4, MP0–2, XPRP/XPRN MP.
- **A1 PAC** (`ece203_r8c_a1pac`, AC_R8C_MSB = 1 then 3): readpss (same a1 PSS settings), PAC relative relharmnum 0, **0.01–250 Hz at 40 points/dec** (superset of 0.025–5 Hz ≥ 40/dec and of 5–250 Hz; grid hits 0.1/1/10/100 Hz exactly). Same six transfers at sideband 0; for ia−ibx, op−on and p−n also sidebands +1 and −1 divided by the sideband-0 input (carrier-band content; magnitude only interpreted as modulated signal size, no phase claim). PSS waveforms of all nodes; pseudo-R terminal current `XPRP:A`/`XPRN:A` if Spectre saves it (optional).
- Spectre 15.1 PAC help (archived `round8/raw/spectre_help/lix015_pac_help.txt`): maxsideband only selects the output sidebands, "the number of requested sidebands does not change substantially the simulation time" → maxsideband 1 vs 3 is a pure read-out consistency check.
- Netlist audit (`r8c_netlist_audit_A.txt`): A1 OFF vs R8B gate A netlist, A1 PAC m1/m3 vs R8B gate C netlist: no instance removed/added/changed, parameters identical (pacd as in reference), subckts identical; analysis lines printed.

**Stage A PASS** (all of):
1. PSS explicitly converged ("steady-state solution was achieved") in both PAC runs;
2. ON |H_out(100)| within ±2 % of 83.25;
3. ON fL_flat within 0.34 ± 0.04 Hz;
4. maxsideband 1 vs 3: sideband-0 |H_out| at 0.1/0.3/1/10/100 Hz differ ≤ 2 %;
5. new PAC vs archived R8B PAC (0.1–250 Hz) ≤ 2 %;
6. measured input 2 V at 0°; A1 OFF |H(100)| = 85.666 (≤ 1e-4 relative);
7. netlist audits PASS ×3.

**A FAIL → STOP** (report the setting/read-out problem, no Stage B).

## Stage B — diagnostic linear surrogate (never a design candidate)

- New cell `Project/ece203_r8c_tb_linear_pr` (case l0) = `r8bSpecs()` minus exactly XPRP (p fn) and XPRN (n fp), plus analogLib `RPRP (p fn)` and `RPRN (n fp)` **3.128 TΩ** (pre-set from R7C r(0); not a new measurement). Nothing else changes. Audit (`r8c_netlist_audit_B.txt`): removed {XPRN, XPRP}, added {RPRN, RPRP} with r=3.128T, nothing changed, parameters identical, subckt `ece203_ss_pr_cell` absent (no longer instantiated), all others identical, EOC/CHP absent.
- **B0 OFF** (same job code as A1 OFF; no noise run). **B0 PASS** (all): fL_flat(OFF, linear) in 0.07–0.15 Hz; |H_out(100)| within ±5 % of the MOS OFF value; DC CM of (p,n), (ia,ibx), (fp,fn), (op,on), (bufp,bufn), (outp,outn) each within 1 mV of MOS; power 1.8·(I_VDD+I_VDDD) within 2 %.
- **One allowed correction** if B0 fails: case l1, new cell `Project/ece203_r8c_tb_linear_pr_b`, R_l1 = 3.128 TΩ × fL_OFF,lin(l0) / fL_OFF,MOS(A1). The value is registered in an update of this file and committed before the build; l0 results are kept. If l1 also fails B0 → **STOP** (no ON comparison on a non-equivalent static high-pass).
- **B1 ON**: PSS attempt b1 = R8 a1 settings (fund 2k, harms 40, maxacfreq 200k, moderate, tstab 5 ms, maxperiods 40, cmin 1e-17, itres 1e-4), writepss `/tmp/lix015_r8c/pss_<case>.pss`; PAC only after an explicit convergence message (readpss, identical PAC sweep to A1, maxsideband 1). If b1 does not converge: one retry b2 = R8 a2 settings (maxperiods 60, itres 1e-7), circuit unchanged; if b2 fails → **BLOCKED**. At most 2 linear PSS runs in total.
- **Pre-registered reading** (diagnostic evidence only), Q_R = fL_ON,lin / fL_OFF,lin vs Q_MOS = fL_ON,MOS / fL_OFF,MOS (A1):
  - Q_R ≤ 1.4 → pseudo-R nonlinearity / periodic admittance is the main suspect (next: MOS pseudo-R I–V / small-signal conductance vs swing);
  - Q_R ≥ 2.7 → TG / other periodic switching coupling is the main suspect (next: a controlled input-TG-only replacement);
  - 1.4 < Q_R < 2.7 → both may contribute, not separable here.
- **Operating-state check**: PSS waveforms MOS (A1) vs linear: if the peak-to-peak of p, n, fp or fn differs by more than 30 %, or the mean by more than 1 mV, the report states "the surrogate does not preserve the nonlinear operating state" and the causal reading is downgraded.

## Budget and stops

- PSS: 0 MOS rebuilds expected (max 1); ≤ 2 linear PSS (b1 + optional b2) per case actually run on the ON path.
- Not run: ordinary noise, PNoise, any tran (60 ms or longer), frequency / MOS / Cc / Cfb / LP / clock changes.
- Watchdog `tools/r8c_watchdog.sh` (stall 900 s, hard 5400 s) kills only this task's Spectre (`lix015_r8c/sim_<tag>`); the user's Virtuoso/Spectre is never touched.
- Old cells (R7F, R8, R8B, R5N-F …) read-only; the R8B archived PAC is only read.
- Outcome labels: Stage A PASS/FAIL; B0 PASS/FAIL; B1 converged / BLOCKED; final reading per the bands above. No course-spec PASS claim for fL or noise.
