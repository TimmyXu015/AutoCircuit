# R8D pre-run plan — XCI / XCO TG idealisation (2×2), real MOS pseudo-R kept

Task: `docs/ECE203_round8d_tg_isolation_task.md`. Committed **before any R8D Spectre run**.

## Code

- New: `ece203_r8d.il`, `tools/r8d_watchdog.sh`, `batch/ece203_r8d_{unit,build,off,pss,pac}.il`, and in this folder `r8d_unit_analysis.py`, `r8d_analysis.py`, `r8d_netlist_audit.py`.
- `ece203_r8c.il` gains two backward-compatible globals, `r8cWd` and `r8cExtraOps`. Their defaults give exactly the R8C behaviour; R8D rebinds them like R8B rebinds `r8Wd`.
- The measurement code is the R8C code: `r8cOff` for dc + ac 1 mHz–100 kHz, and `r8cPeriodic` for PSS with writepss and for PAC with readpss.
- PSS and PAC runs of one case use the same procedure and the same save list (`isPr t`: node voltages + `XPRP:A`/`XPRN:A`). Equation sizes are therefore identical and readpss must report "achieved in 1 shooting-Newton iteration"; the analysis checks this.

Common settings: cmrf7sf tt 27 °C, gmin 1e-18, iabstol 1e-17, reltol 1e-5. Clocks are the frozen `r6bClocks()`: tch 500 µs, 1 ns edges, 10 ns dead time. Zero input (vd 0, adm 0 when ON, dcc 0).

## Ideal TG master `Project/ece203_r8d_ideal_tg`

- Pins: the same 10 pins as `ece203_r6b_tgchop` (INP INN OUTP OUTN CKA CKAB CKB CKBB VDD GND).
- Devices: 4 analogLib `switch` instances, which netlist as Spectre `relay`:
  - SA1 INP–OUTP and SA2 INN–OUTN, controlled by CKA;
  - SB1 INP–OUTN and SB2 INN–OUTP, controlled by CKB.
- Every switch has NC− = GND pin, vt1 0.8 V, vt2 1.0 V, ro 1e20 Ω, **rc 1.68 kΩ** (R6B real TG at Vcm 0.9 V: 1681 Ω).
- CKAB, CKBB and VDD are pins only, with no device attached. No added capacitor, controlled source or OTA.
- This is a diagnostic idealisation: no overlap or junction capacitance, no charge injection, no leakage, no nonlinear Ron. It is never a design.

## Stage A — surrogate check (job `ece203_r8d_unit`)

- **Probe in Cadence:** the analogLib `switch` CDF parameters, `simInfo`, and symbol terminals, plus `spectre -h relay`. Saved to `A_switch_probe.txt` and `spectre_help_relay.txt`.
- **Unit bench** `Project/ece203_r8d_tg_tb`: `r6bUSpecs()` with XT's master swapped. It has ideal sources at Vcm, 1 pF per output, Ron probe current, leak resistors, and the R6B clocks. gmin 1e-18.

**Stage A PASS requires all of:**
1. The probe shows terminals N+ N− NC+ NC− and parameters vt1 vt2 ro rc.
2. The netlisted subckt `ece203_r8d_ideal_tg` has exactly 4 relays, with the connectivity above and vt1 0.8, vt2 1.0, ropen 1e20, rclosed 1.68k.
3. Ron in phase A and phase B (100 nA probe) = 1680 Ω ± 0.5 %.
4. Static polarity: 10 mV gives +1 / −1 within 1e-4; 0.1 mV gives +1 / −1 within 1e-3.
5. Off: with both phases off, inputs ±0.1 V and 1 TΩ to Vcm, the implied Roff is ≥ 1e15 Ω (≫ 3.128 TΩ).
6. 2 ms chopped tran at 2 kHz (vd 1 mV at 100 Hz, maxstep 50 ns) reaches 2 ms, and:
   - per-phase vod/vid is +1 / −1 within 1e-3 (sampled at 45 % / 95 % of each period where |vid| > 0.2 mV);
   - no overlap: max over time of min(V(cka), V(ckb)) < 0.8 V;
   - every dead time (both < 0.8 V) is ≥ 5 ns;
   - max|vod| ≤ 1.02·max|vid|.

**A FAIL → STOP.** A different switch model will not be substituted.

## Matrix and order

| Case | XCI | XCO | Cell |
|---|---|---|---|
| MM | real | real | `Project/ece203_r8b_tb_noeoc_chp` (read-only) |
| II | ideal | ideal | `Project/ece203_r8d_tb_ii` |
| IM | ideal | real | `Project/ece203_r8d_tb_im` |
| MI | real | ideal | `Project/ece203_r8d_tb_mi` |

- The cells are `r8bSpecs()` with only the master of XCI and/or XCO changed. Instance names, nets and all other instances are identical. MOS pseudo-R XPRP/XPRN are kept; EOC/CHP stay removed.
- **Audit** (`r8d_netlist_audit.py` vs the R8B netlist of the same analysis type): nothing removed or added; the only changed lines are the swapped instances, differing only in master; the parameters are identical; the common subckts are identical; `ece203_r8d_ideal_tg` is added; `ece203_r6b_tgchop` is absent only in II.
- **MM OFF reference:** `ece203_r8d_off` with `AC_R8D_CASE=mm` runs the read-only R8B cell once, with the R8D op-info list (incl. CMFB XC.MD). No change to the cell, no PSS.
- **MM ON reference:** the R8C A1 PAC (maxsideband 1, same 0.01–250 Hz 40/dec sweep, same save list). Read only; the R8B PSS is not rerun.

### OFF gate (each of II, IM, MI)

All of the following:
- fL_flat OFF within 0.0943 Hz ± 15 %;
- |Hout(100)| within 85.67 ± 5 %;
- DC of op, on, p, n, ia, ibx, fp, fn, vg, ib, pref, bufp, bufn, outp, outn each within 2 mV of MM;
- power 1.8·(I_VDD + I_VDDD) and CMFB XC.MD current within 5 %;
- op/on/fp/fn/buf/out/p/n DC between 0.1 and 1.7 V.

**FAIL → STOP for that case** (no ON attribution).

### ON (each case that passed OFF)

- **PSS:** attempt **b1** = R8B a1 (fund 2k, harms 40, maxacfreq 200k, moderate, tstab 5 ms, maxperiods 40, cmin 1e-17, itres 1e-4), writepss `/tmp/lix015_r8d/pss_<case>.pss`. PAC runs only after the explicit message "steady-state solution was achieved".
- **PAC:** readpss, relative relharmnum 0, 0.01–250 Hz at 40/dec, maxsideband 1. Transfers outp−outn, bufp−bufn, fp−fn, p−n, ia−ibx and op−on at sideband 0, divided by the measured sideband-0 V(ep)−V(en).
- **Retry:** the only allowed one is **b2** = R8 a2 (maxperiods 60, itres 1e-7), PSS only, circuit unchanged, failed log kept. At most 2 retries in all of R8D; at most 3 first PSS runs (II, IM, MI).
- **Altered-operation flag** (attribution downgraded, data still reported), raised if either:
  - |H100_ON − 83.251| > 10 %;
  - for p, n, fp or fn, the PSS peak-to-peak ratio vs MM is outside 0.7–1.3, or the mean differs by more than 2 mV.

### II classification (Q = fL_ON / fL_OFF of the same cell; MM Q ≈ 3.59)

| II result | Reading | Next |
|---|---|---|
| Q ≤ 1.4 and fL_ON in 0.08–0.13 Hz | real MOS TG non-idealities are necessary | **Stage C** (IM + MI) |
| Q ≥ 2.7 | MOS-TG-specific parasitics are not necessary | **STOP**, no IM/MI |
| anything else (1.4 < Q < 2.7, or Q ≤ 1.4 with fL_ON outside 0.08–0.13) | intermediate | **Stage C allowed** |

- If II is flagged altered, the classification is still reported, but every conclusion is labelled downgraded.
- If II PSS fails after b2 → **STOP (BLOCKED)**.

### Stage C (only if gated)

- IM and MI run with exactly the II settings. A branch that fails OFF or PSS is reported as NOT VERIFIED.
- **2×2 descriptive factorial** on Q and on fL_ON:
  - effect of idealising XCI = ½[(MM − IM) + (MI − II)];
  - effect of idealising XCO = ½[(MM − MI) + (IM − II)];
  - interaction = ½[(MM − IM) − (MI − II)].
- **Proxy:** ΔG_model = (Q − 1)/3.128 TΩ per case. This is a hypothesis proxy for later modelling, not a measured element.

## Not run / budget / safety

- Not run: PNoise, ordinary noise, 60 ms tran, PVT/MC, fch sweep, any change to MOS W/L, clock, capacitors, LP or pseudo-R.
- The unit smoke tran is ≤ 2 ms.
- The watchdog (stall 900 s, hard 5400 s) kills only `lix015_r8d/sim_<tag>`. The user's Virtuoso/Spectre is never touched.
- R8B/R8C cells and data are read-only. No PDK model content goes into the repo.

## Update 1 (after Stage A ran, before any system run) — parser fix, no gate change

- The netlister writes relay values as `vt1=800.0m`, `ropen=100e+18` and `rclosed=1.68K`.
- The first `r8d_unit_analysis.py` compared them as strings ('0.8', '1e20', '1.68k'), so the four connectivity/parameter lines reported FAIL although the values are the registered ones.
- Fix: compare numerically with SI suffixes (relative 1e-9). Gate meaning unchanged. The pre-fix output is kept in `r8d_stageA_gate_prefix.txt`.
- Spectre relay help (`raw/stageA/spectre_help_relay.txt`): smooth cubic conductance between vt1 and vt2; model `hysteresis` default 0 V, so the relay carries no switching memory.
