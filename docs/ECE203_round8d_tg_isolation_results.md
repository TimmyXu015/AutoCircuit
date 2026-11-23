# ECE203 R8D — XCI / XCO TG idealisation: the 0.34 Hz periodic corner persists with ideal switches (2026-11-23)

- Task: [ECE203_round8d_tg_isolation_task.md](ECE203_round8d_tg_isolation_task.md).
- Pre-run plan: [ece203_data/round8d/r8d_plan.md](ece203_data/round8d/r8d_plan.md), commit db61f5b, before any R8D Spectre run. Update 1 (644d53f) was a numeric-parse fix in the Stage A script, made before any system run; no gate changed.
- Code: `ece203_r8d.il`, `tools/r8d_watchdog.sh`, batch jobs `ece203_r8d_{unit,build,off,pss,pac}`.
- R8C code change: `ece203_r8c.il` gained `r8cWd` / `r8cExtraOps`. Both are backward compatible, and their defaults give exactly the R8C behaviour.
- Data: [ece203_data/round8d/](ece203_data/round8d/).
- Setup: cmrf7sf tt, 27 °C, Spectre 15.1, gmin 1e-18, iabstol 1e-17, reltol 1e-5. Clocks are the frozen `r6bClocks()` (2 kHz, 1 ns edges, 10 ns dead time). Zero input.

## Verdict

| Stage | Result | Key numbers |
|---|---|---|
| **A — ideal TG surrogate** | **PASS** (15/15 checks) | 4 relays as specified; Ron 1680.00 Ω both phases; polarity ±1.000000; Roff ≫ 1e15 Ω; 2 ms chopped smoke +1/−1, no overlap, dead time 10 ns |
| **B — II (both TGs ideal), OFF** | **PASS** | fL_flat 0.09429 Hz (MM 0.09430); \|H(100)\| 85.668 (−0.002 %); DC of 15 nodes within 0.0008 mV; power and CMFB current identical |
| **B — II, ON** | PSS **converged** (b1, 2 iterations); PAC done (readpss, 1 iteration) | **fL_flat ON 0.3356 Hz, Q = 3.559** (MM 0.3381 Hz, Q 3.585); \|H(100)\| 83.472 (MM 83.251) |
| Altered-operation flag (pre-registered) | **raised → attribution downgraded** | The ideal-TG PSS has 0 V peak-to-peak at p/n/fp/fn. MM has 5.7–5.9 mV, all of it edge spikes from MOS TG charge injection (see below) |
| **II reading (pre-registered)** | **Q ≥ 2.7 → MOS-TG-specific parasitics are not necessary → STOP** | IM / MI not run |
| **C — IM, MI** | **NOT RUN** (gated by II) | — |

**What this means**
- Replacing both real MOS TGs by ideal, parasitic-free 1.68 kΩ switches leaves the chopped corner almost unchanged: 0.338 → 0.336 Hz, Q 3.59 → 3.56.
- The TG overlap/junction capacitance, charge injection, leakage and nonlinear Ron are therefore **not needed** to produce it.
- Together with R8C, which showed the pseudo-R nonlinearity is not needed either, the corner rise comes from the periodic chopping topology itself, with ideal switches.
- Formally, the attribution is downgraded by the pre-registered flag.
- This is diagnostic evidence only. The real MOS circuit still has the 0.338 Hz corner, and the R8B noise (3.141 / 3.994 µVrms) is unchanged.

## Stage A — ideal TG master `Project/ece203_r8d_ideal_tg`

Files: `r8d_stageA_gate.txt`, `r8d_stageA.png`, `raw/stageA/`.

**What Cadence reports for analogLib `switch`** (`A_switch_probe.txt`):
- terminals N+ N− NC+ NC−;
- CDF parameters vt1, vt2, ro, rc;
- Spectre component `relay`, with propMapping ro→ropen and rc→rclosed.

**Spectre relay behaviour** (`spectre -h relay`): the conductance is a smooth cubic between vt1 and vt2, and the model hysteresis defaults to 0 V, so there is no switching memory.

**Netlisted master:**
- SA1 (INP OUTP CKA GND), SA2 (INN OUTN CKA GND), SB1 (INP OUTN CKB GND), SB2 (INN OUTP CKB GND);
- every one `relay vt1=800.0m vt2=1.0 ropen=100e+18 rclosed=1.68K`;
- CKAB, CKBB and VDD are pins only.

**Unit bench** `Project/ece203_r8d_tg_tb` (the R6B unit topology with the master swapped):

| Check | Result |
|---|---|
| Ron, phase A / B (100 nA probe) | 1680.00 / 1680.00 Ω (real TG at 0.9 V: 1681) |
| Static polarity, 10 mV | +1.000000 / −1.000000 |
| Static polarity, 0.1 mV | +1.00000 / −1.00000 |
| Both phases off, ±0.1 V in, 1 TΩ to Vcm | output offset 0 V → Roff ≥ 1e30 (ro 1e20) |
| 2 ms tran, 2 kHz, 1 mV at 100 Hz | per-phase +1.00000 / −1.00000 (3 + 4 samples) |
| Clock overlap | max of min(V(cka), V(ckb)) = 0 V |
| Dead times | 7 intervals, each 10 ns |
| Spikes | max\|vod\| = max\|vid\| = 0.951 mV; output CM deviation 1e-16 V (no charge injection, as intended) |

The first gate script compared the netlisted parameter strings (`800.0m`, `1.68K`) to `0.8` / `1.68k` and reported 4 FAILs. The values are the registered ones. The fix compares them numerically, recorded in plan update 1; the pre-fix output is kept in `r8d_stageA_gate_prefix.txt`.

## Stage B — II cell `Project/ece203_r8d_tb_ii`

Files: `r8d_netlist_audit.txt`, `r8d_gates.txt`, `r8d_matrix_summary.csv`, `r8d_dc_ii.csv`, `r8d_pss_levels.csv`, `r8d_matrix.png`, `r8d_pss_waveforms.png`, `raw/stageB/`.

**Netlist audit (4 × PASS):**
- MM OFF (R8B cell, rerun read-only with the R8D op list) vs R8B gate A: identical.
- II OFF vs MM OFF, II PSS vs R8B gate B, and II PAC vs the R8C A1 MM PAC:
  - the only changed lines are XCI and XCO;
  - nets are identical — `XCI (cka ckab ckb ckbb 0 n p ibx ia vdd)` and `XCO (cka ckab ckb ckbb 0 on op fn fp vdd)` — and only the master changed, `ece203_r6b_tgchop` → `ece203_r8d_ideal_tg`;
  - nothing added or removed, parameters identical, the other 5 subckts identical (pseudo-R `ece203_ss_pr_cell` kept);
  - `ece203_r6b_tgchop` is no longer netlisted and `ece203_r8d_ideal_tg` is added.

**OFF** (chen 0, dc + ac 1 mHz–100 kHz): gate **PASS**.

| | MM | II |
|---|---|---|
| fL_flat | 0.094296 Hz | 0.094294 Hz |
| \|H(100)\| | 85.6664 | 85.6684 |
| DC p, n, ia, ibx, op, on, fp, fn, vg, ib, pref, buf, out | | worst difference 0.0008 mV |
| Power / CMFB XC.MD current | 2.30938 µW | identical (+0.000 %) |

**ON** (chen 1, zero input):
- **PSS b1** (R8B a1 settings): "achieved in 2 shooting-Newton iterations", norm 1.6e6 → 1.8e-6.
- **PAC:** readpss gave "achieved in 1 shooting-Newton iteration". PSS and PAC used the same save list, so readpss was reused this time (no R8C-type equation-size mismatch). The sweep was 0.01–250 Hz at 40/dec, maxsideband 1, with a measured input of 2.000 V at 0°.

| \|H_out\| (PAC sb0) | 0.03 Hz | 0.1 Hz | 0.3 Hz | 1 Hz | 10 Hz | 100 Hz | Phase at 100 Hz | fL_flat | Q |
|---|---|---|---|---|---|---|---|---|---|
| MM (R8C A1, real TGs) | 7.97 | 25.58 | 59.95 | 85.75 | 90.36 | 83.251 | −23.80° | 0.3381 Hz | 3.585 |
| II (ideal TGs) | 8.05 | 25.81 | 60.35 | 86.04 | 90.60 | 83.472 | −23.78° | 0.3356 Hz | 3.559 |

- Node corners under II: p−n 0.3360 Hz, fp−fn 0.3360 Hz, bufp−bufn 0.3359 Hz. As in MM, all baseband nodes back to the summing nodes share the same corner.
- The ±1 carrier sidebands at 1 Hz are essentially identical between II and MM (op−on: −1 sideband 69.67 vs 69.58, +1 sideband 2.07 vs 2.05). The asymmetry from R8C appears in the ideal case too and is still not interpreted.

**Altered-operation check** (pre-registered: p/n/fp/fn PSS peak-to-peak ratio within 0.7–1.3 and mean within 2 mV):
- **FLAG RAISED.** The II PSS is a constant: peak-to-peak 0 V at every node. MM has p/n 5.67 mV, fp/fn 5.95 mV, op/on 10.6 mV.
- `r8d_pss_waveforms.png` shows that the MM ripple consists only of the MOS TG edge spikes at 0 / 250 / 500 µs. Between edges the MM levels coincide with II: median and time-weighted mean agree within 0.0008 mV at all 12 nodes (`r8d_pss_levels.csv`). The removed ripple is therefore exactly the MOS TG charge injection, i.e. the variable under test.
- The pre-registered arithmetic sample mean (op −0.75 mV, ia −0.63 mV) is biased by the dense time points at the spikes.
- The flag stands as registered, so the mechanism attribution is **downgraded**: data reported, no strong mechanism claim.

**II reading** (pre-registered): Q = 3.559 ≥ 2.7 → MOS-TG-specific parasitics are not necessary → **STOP**. IM and MI were not built or run. The 2×2 factorial was not computed.

**Budget used:**
- 1 ideal-TG master and 1 unit bench (DC + one 2 ms tran);
- 1 system cell (II);
- OFF runs: MM reference (read-only cell) and II;
- PSS: 1 (II b1), no retries; PAC: 1;
- no PNoise, no noise, no 60 ms tran; no change to MOS W/L, clocks, capacitors, LP or pseudo-R.

## Next step (proposal only, not run; hypothesis, not evidence)

**Constraint.** With both TGs ideal, the only charge-storing elements switched by XCI are the OTA input capacitances at ia/ibx (gate–source, gate–drain, gate–bulk of XA M1/M2). Everything on the p/n side is baseband.

**Candidate mechanism.** Every half period the chopper reverses the charge that the OTA input error voltage leaves on that capacitance. This acts like a switched-capacitor conductance across the summing nodes p/n, in parallel with the pseudo-R path.

**Order of magnitude** (proxy only, not fitted):
- ΔG_model = (Q − 1)/3.128 TΩ = 0.82 pS referred to the pseudo-R position (MM 0.826 pS, II 0.818 pS).
- Referred to p−n instead: (p−n)/(fp−fn) ≈ 8.6e-4 in-band (R8C). The required conductance across p–n is then ≈ 0.5 nS.
- As 4·f_ch·C, that is ≈ 60 fF of differential input capacitance — tens of fF, the same order as the gate capacitance of a 10 µm/8 µm weak-inversion input pair.
- None of this is measured.

**A minimal controlled test for a later round** (if approved): on the II cell, add one known ideal differential capacitor between ia and ibx (for example +50 fF and +100 fF) and check whether ΔQ scales linearly. Optionally also model the same switched-capacitor network in MATLAB. Neither is run here, and no MOS W/L change is proposed.

## Files

`ece203_data/round8d/`:
- `r8d_plan.md`
- `r8d_unit_analysis.py`, `r8d_analysis.py`, `r8d_netlist_audit.py`
- `r8d_stageA_gate.txt`, `r8d_stageA_gate_prefix.txt`, `r8d_stageA.png`
- `r8d_netlist_audit.txt`, `r8d_gates.txt`
- `r8d_matrix_summary.csv`, `r8d_dc_ii.csv`, `r8d_pss_levels.csv`
- `r8d_matrix.png`, `r8d_pss_waveforms.png`
- `raw/stageA`: switch probe, relay help, unit netlist, static CSV, 2 ms tran CSV.gz + SHA-256, spectre.out.gz, logs
- `raw/stageB`: MM/II OFF CSV, AC and DC op, II PSS/PAC netlists, spectre.out.gz, convergence lines, PAC curves (sb0, ±1), PSS waveforms incl. pseudo-R terminal currents, PSS SHA-256, job logs
- `raw/watchdog.log`

New cells (diagnostic only, never a design): `Project/ece203_r8d_ideal_tg`, `Project/ece203_r8d_tg_tb`, `Project/ece203_r8d_tb_ii`. R8B/R8C cells and data are read-only.

Stopped; waiting for review. No next round started.
