# R7D pre-run plan (registered before any Spectre run)

Task: docs/ECE203_round7d_mos_bias_mirror_integration_task.md. Script ece203_r7d.il (code commit = this commit).

**Only change** vs C0 = Project/ece203_r7c_tb_pr_w4 (read-only): remove IB (vdd -> ib, 50 nA) and IBD (vddd -> ibd, 50 nA);
add IREF (idc 100 nA, pref -> gnd!) and pfetx, L 4u:

| inst | D G S B | W (a0) |
|---|---|---|
| MP0 | pref pref vdd vdd | 4u |
| MP1 | ib pref vdd vdd | 2u |
| MP2 | ibd pref vddd vddd | 2u |

Candidate a0 = the task's 4:2:2 (R4 C3 sizes; R4 had MP2 source on vdd, here vddd keeps the two independent supplies).
Candidate a1 (only if a0 fails Stage A/B, one correction): MP1/MP2 (and if needed MP0) W from the measured a0 mirror ratio,
L unchanged, rationale written into this file before the build.

Expectation (not a result): MP1/MP2 VSD ~1.8 - V(ib) is larger than MP0 VSD = VSG, so channel-length modulation should push
I(MP1), I(MP2) a few % above 50 nA.

Gates (copied from the task):
- Stage A: I(MP1), I(MP2) in 45-55 nA; IREF the only bias source (no other non-zero isource); MP0-2 valid (MP1/MP2 |VDS| > max(|VDSAT|, 0.1 V));
  KCL: I(MP1) = I(XA.MREF), I(MP2) = I(XD.MREF); V(ib), V(ibd) vs C0 quantified (reference |dV| < 15 mV, not a gate);
  DC open / clamp / no convergence -> FAIL, stop.
- Stage B (TG static phase A, dcc 0.01, AC 1 mHz-100 kHz, same r7cStageB1 measurement and options as R7C):
  |Vcm(op/on) - 0.9| <= 1 mV; fL 0.09-0.11 Hz; Hpre100 and Hbuf100 |delta| <= 5 % vs C0; CMFB PM >= 60, DRL PM >= 60;
  CMRR60 >= 85 dB; Zin(10 Hz) > 100 MOhm; OTA and CMFB min margin >= 50 mV (C0 XA.M1 0.0917 V); mirror PMOS saturated;
  P = 1.8 (I_VDD + I_VDDD) (supply delivered, IREF not counted twice) < 4.0 uW.
  C0 numbers = R7C Stage B CSV (docs/ece203_data/round7c/r7c_stageB_summary.csv, same code and options), not re-run.
- Stage C (only if A and B pass; no sizing change): 60 ms, 2 kHz TG, 100 Hz 1 mV DM, maxstep 0.5u, cmin 1e-17, gmin 1e-18,
  iabstol 1e-17, reltol 1e-5. C0 = R7C T_pr_w4 wave (read-only). PASS: full 60 ms, no clipping; Hpre/Hbuf |delta| <= 5 %;
  CM avg within 1 mV, CM 200 Hz <= 0.20 mV; P < 4 uW; performance FAIL if DM edge max > 1.15 x 31.45 mV, residual > 1.30 x 3.520 mV,
  or H3 worse than -85.7 + 10 = -75.7 dBc. At most 2 new 60 ms runs.
