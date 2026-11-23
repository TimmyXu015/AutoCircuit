# R7E pre-run plan (registered before any Spectre run)

Task: docs/ECE203_round7e_output_lp_integration_task.md. Script ece203_r7e.il (code = this commit). C0 = Project/ece203_r7d_tb_bias_a0
(read-only; static data = round7d r7d_stageB_summary.csv, chopped wave = round7d raw/stageC/T_bias_a0_tran.csv.gz, same code/options).

Only change (C1 = Project/ece203_r7e_tb_lp_a0): + RLP_P bufp->outp 31.8 MOhm, CLP_P outp->gnd! 20 pF, RLP_N bufn->outn 31.8 MOhm,
CLP_N outn->gnd! 20 pF (ideal analogLib R/C; manufacturability / noise / parasitics of a 31.8 MOhm on-chip resistor NOT VERIFIED).
CLBP/CLBN 10 pF stay on bufp/bufn; feedback stays on fp/fn. Sensitivity bench (Project/ece203_r7e_tb_lp_load10p) = C1 + COUTP/COUTN 10 pF.

Expectations (hand calculation, not results): f_p = 1/(2 pi 31.8M 20p) = 250.2 Hz; |H_LP(100)| = 0.9285, phase -21.8 deg; CD output
resistance (~1/gm of the 112 nA follower, ~0.3-0.4 MOhm) adds < 1.5 %. Hout100 static ~ 78.84 x 0.9285 = 73.2 (37.3 dB), chopped
~ 76.60 x 0.9285 = 71.1 (37.0 dB) -> below the 38 dB course minimum: SYSTEM GAIN PENDING (not an R7E gate). With 10 pF extra per side:
f_p ~ 167 Hz.

Definitions: fH_flat = falling -3 dB vs |Hout(10 Hz)|; fH_100ref = falling -3 dB vs |Hout(100 Hz)|; fH_LP = -3 dB of H_LP = Hout/Hbuf
vs |H_LP(1 Hz)|; fL = rising -3 dB vs |Hout(100)|.

Stage A gates (unloaded outp/outn): audit = exactly 4 new passives; fH_flat 225-275 Hz; fL 0.09-0.11 Hz; |H_LP(100)| 0.90-0.95 with
first-order negative phase; Hpre100 and Hbuf100 within 2 % of R7D; op/on CM within 1 mV of 0.9 V; CMFB and DRL PM >= 60 deg;
static power within +2 % of R7D (2.309 uW); Zin(10 Hz) >= 100 MOhm; CMRR60 >= 85 dB; DC outp = bufp, outn = bufn (to numerical precision).
Stage B (loaded, static DC/AC only, no gate): report fH_flat, Hout100, phase, the implied output impedance; if fH_flat ~167 Hz the
verdict is "LP-a0 unloaded PASS; with 10 pF downstream load the fH target is not met; needs a later interface solution".
Stage C (only if A passes; one new 60 ms run of lp_a0; same settings as R7D): full 60 ms, no clipping; Hpre/Hbuf within 2 % of R7D C0;
Hout/Hbuf at 100 Hz = 0.9285 +- 3 %; op/on CM within 1 mV, CM 200 Hz <= 0.20 mV; P < 4 uW and <= C0 + 2 %; no new slow drift.
Edge/spur reduction at out is reported, not gated. No R/C/MOS change for any reason; one numerically justified retry at most.
