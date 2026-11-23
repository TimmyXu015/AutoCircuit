# R7F pre-run plan (registered before any Spectre run)

Task: docs/ECE203_round7f_gain_and_loaded_lp_task.md. Script ece203_r7f.il (code = this commit). Measurement code is unchanged
R7C r7cStageB1 + R7E r7eLp / r7eStageC; the only edits to ece203_r7c.il / ece203_r7e.il are backward-compatible hooks
(optional per-case 'extra design-variable overrides, a watchdog-name variable) that do nothing for the old cases.
C0 = Project/ece203_r7e_tb_lp_a0 / lp_load10p (read-only; data = round7e).

| Stage | Cell (new) | RLP_P/N | CLP_P/N | COUTP/N | cc (CCP/CCN) | Only difference vs |
|---|---|---|---|---|---|---|
| A | ece203_r7f_tb_lp_l0 | 4.77M | 133p | - | 50p | R7E lp_a0: RLP/CLP values |
| A | ece203_r7f_tb_lp_l0_load10p | 4.77M | 133p | 10p | 50p | lp_l0: + COUTP/COUTN |
| B | ece203_r7f_tb_gain_g0_load10p | 4.77M | 133p | 10p | **60p** (design var) | lp_l0_load10p: cc 50p -> 60p |
| B | ece203_r7f_tb_gain_g0_unloaded | 4.77M | 133p | - | **60p** (design var) | lp_l0: cc 50p -> 60p |

cc is the existing design variable of CCP/CCN (and of the CCX 1 % mismatch aid, c = cc*dcc, which therefore scales with it as in every
earlier round); the G0 cells are schematically identical to the L0 cells and get cc = 60e-12 as a bench variable, checked in each netlist.

Hand expectations (not results): LP fc unloaded 250.9 Hz, +10 pF 233.3 Hz; |H_LP(100)| 0.929 / 0.919. Gain: R7E static Hout100 73.12
= Hpre 93.59 x CD 0.8415 x LP 0.9286. If Hpre scales ~ cc (minus some loop-gain loss), cc 60p -> Hpre ~110-112, Hout100 static ~85-87
(38.6-38.8 dB) loaded/unloaded, chopped ~ x0.97 -> ~83-84 (38.4-38.5 dB): small margin over 38 dB. fL ~ 1/(2 pi Rpr Cfb), not expected
to move. Zin(10 Hz) drops ~ with 1/cc (R7E 658 MOhm -> ~550 MOhm).

Designed capacitance (from the R7E netlist; electrodes 3 x 50 nF, body 200 pF, CHP/CVG test aids, COUT stress load and CCX mismatch aid
listed separately): R7E 163 pF (Cc 2x50, Cfb 2x0.5, CLB 2x10, CLP 2x20, DRL CCM 2x1) -> L0 389 pF (+226) -> G0 409 pF (+20) < 1 nF.

Gates (from the task):
- Stage A (L0): fH_flat (-3 dB vs plateau) 225-275 Hz both unloaded and +10 pF; fL (plateau) 0.09-0.11 Hz; Hpre100 / Hbuf100 within 2 %
  of R7E; CMFB and DRL PM >= 60 deg; CMRR60 >= 85 dB; Zin(10 Hz) >= 100 MOhm; op/on CM within 1 mV; P < 4 uW; no clipping; margins
  unchanged. Gain not gated here. One RC-ratio correction (tau kept ~ 0.636 ms) allowed only after a measured fH failure; else STOP.
- Stage B (G0, static): for both loads: plateau and 100 Hz Hout within 38-42 dB; fH_flat 225-275 Hz; fL 0.09-0.11 Hz; CMFB/DRL PM >= 60;
  Zin(10 Hz) > 100 MOhm; CMRR60 >= 85 dB; P < 4 uW; OTA min margin >= 50 mV; symmetric, no CM anomaly. One data-driven cc correction (G1)
  allowed, registered here first; otherwise FAIL / STOP.
- Stage C (only after A and B pass): one 60 ms run of the final loaded candidate (R7E settings; second run only if needed for
  comparability, max 2). Gate: 38 <= 20 log10(Hout100) <= 42 dB; op/on CM within 1 mV; P < 4 uW; H3 not worse than -88.9 + 10 dBc;
  out residual RMS >= 1 kHz not above 2 x 112 uV (alarm line); no stall / clipping. Static fH/fL/PM/CMRR/Zin from Stage B.
