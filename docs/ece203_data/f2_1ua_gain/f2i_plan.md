# F2 under 1 µA 60 Hz body interference — run plan (written before any Spectre run of this task)

- **Task:** `docs/ECE203_F2_1uA_interference_gain_task.md`. The superseded Monte Carlo task is not run.
- **Library rule (user, 2026-11-25):** nothing is ever written into any `203ECG*` library; read and copy-from are allowed. All new cells go in `Project`.

## Fixtures

**Instructor TB.** Library `ECG_tb` (`/home/linux/ieng6/ECE203_FA26_001/public/ECG_tb`), cell `ECG_tb`, schematic. Read-only dump: `raw/probe_schematics.txt`. Contents:

| Part | Elements |
|---|---|
| ECG source | V0 vsin 1 mV, 10 Hz, between net1(+) and net013 |
| Body | R1, R2, R3 = 200 Ω each in series around the loop net1–net5–net6–net013; body node net5 has C0 200 pF to gnd |
| Interference | I2 isin 1 µA, 60 Hz, gnd → net5 |
| Electrodes | 2 kΩ + (1 MΩ ‖ 50 nF) each: net1 → vRight, net6 → vLeft, net5 → vRL |

- The electrode-side ECG difference is therefore 2/3 of V0 (unloaded): (V(net1) − V(net6)) = V0 · 400/600.

**Isolated copy.** `Project/ece203_f2_1ua_prof_tb`, made with `dbCopyCellView` from the read-only source.
- Only V0 and I2 are re-parameterised, so the stimulus is set per run:
  - V0: va vecg, freq fecg, sinephase phecg, acm aecg;
  - I2: ia iint, freq fint, sinephase phint, acm aint.
- The frozen F2 system is added unchanged:
  - `r5SpecsE("cs")` with XA = `ece203_r5nf_ota_f2`, which is how `ece203_r5nf_tb_f2` was built;
  - the archived fixture is removed (CBODY IINT IINTT VSP VSN RSP REP CEP RSN REN CEN RSR RER CER).
- Net mapping:
  - vRight → F2 inp (Vref side, = the archived VSP side) through the 0 V meter VPP;
  - vLeft → F2 inn (feedback side) through VPN;
  - vRL ← 1 MΩ RDRR → IPRD ← DRL OTA (real DRL on, `rdr` 1 MΩ, `rdi` 1e15).
  - Same polarity as the user's own `203ECG_CCF_TwoStage/ECG_tb_DRL` (read-only reference).
- **Audit:**
  - the copy's netlist equals the instructor netlist for R1–R9, C0–C3 and V0/I2 topology;
  - the DUT part equals the `ece203_r5nf_tb_f2` netlist minus the fixture, with the net renames above;
  - parameters equal the F2 signoff set (`r5nOver(4e-6)` on `r4Vars`: prw 4u, real DRL, LP 31.8 M / 20 p, real bias, cm2 0.5 p), plus the stimulus variables;
  - `dcc` = 0 unless a case says otherwise.

**Options:** tt, 27 °C, gmin 1e-18, iabstol 1e-18, reltol 1e-6 (`r4Tight`, the F2 measurement set) for every run.

## Test 1 — nominal (job `ece203_f2i_ac`)

- `A_ref_f2fixture_dm`: archived F2 fixture, adm 1, DC + AC 1 mHz–100 kHz at 50/dec.
  - Hsrc = out/(ep−en) must reproduce 39.22 dB at 100 Hz (the historical definition) within 0.05 dB.
  - Hpost = out/(inp−inn) is also reported.
  - Mismatch → STOP and diagnose.
- `A_prof_dm`: copy, V0 acm 1, I2 acm 0. Reports:
  - Hsrc = out/(V0+ − V0−), which includes the 2/3 body divider;
  - **Hpost = out/(vRight−vLeft), the course metric**;
  - both at 1/10/60/100/250 Hz, plus DC of all key nodes, I(VDD) and op info.
- `A_prof_int`: V0 acm 0, I2 acm 1 A. Linear transfer from body current to out, body, electrode CM and DRL output. Diagnostic only: a linear AC run cannot show saturation.

## Test 2 — main transient (job `ece203_f2i_tran`)

- **Setup:**
  - DC op, then tran, 3 s, maxstep 50 µs; zero DC offset added;
  - the sources are the instructor vsin/isin with sinephase 0 unless stated.
- **Cases:**
  - T0 (ECG 1 mV peak at 10 Hz, I 0), T100n, T1u, I100n (interference only), I1u;
  - optional, separately labelled: T0_dcc1, T1u_dcc1, I1u_dcc1 (dcc 1 %).
- **Analysis** (`f2i_analysis.py`), on windows [1, 2] s and [2, 3] s:
  - each window is an integer number of 10 Hz periods (and of 60 Hz periods);
  - coherent least-squares fit (DC + 10–300 Hz in 10 Hz steps) of V0 (net1−net013), vpost (vRight−vLeft) and out;
  - 10 Hz gains: Gpost = |out₁₀|/|vpost₁₀| and Gsrc = |out₁₀|/|V0₁₀|;
  - Δ vs T0, |out₆₀| residual, |out₂₀|/|out₁₀| and |out₃₀|/|out₁₀|, intermodulation at 50/70 Hz, DC of out, min/max of out, oa, oa1, drlr, body, electrode CM;
  - paired subtraction: (T − I) for the 1 µA and 100 nA pairs.
- **Settled:** the two windows agree within 0.05 dB on Gpost and 1 mV on DC(out).
  - If not, **one** extension to 10 s for the unsettled cases (windows [8, 9] and [9, 10] s).
- **Clipping flag:** any of oa1, oa, out or drlr comes within 50 mV of 0 V or 1.8 V, or out harmonics at 20/30 Hz exceed −40 dBc.
- **PASS** = Gpost in 38–42 dB and no clipping flag. A clipped or distorted output is not a clean pass even when the fundamental is in band.

## Test 4 — same frequency (only if Test 2 converges)

- Cases: ECG 1 mV at 60 Hz with I 0 (S0); interference only at 1 µA (Si); mixed at 1 µA with ECG phase 0/90/180/270° (S1u_p*).
- **Reported:**
  - the apparent mixed ratio |out₆₀|/|V0₆₀| (and /vpost₆₀), labelled apparent;
  - the paired-subtraction signal estimate |out_mixed − out_Si|₆₀ / |vpost_mixed − vpost_Si|₆₀;
  - vs S0.
- Nonlinear superposition is not assumed. The mixed ratio is never called the differential gain.

## Not run

MC, PVT, chopper, any DRL / bias / size / power change, extra noise. The 1 µA result is beyond the original 100 nA spec and does not redefine project compliance.
