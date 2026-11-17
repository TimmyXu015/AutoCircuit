# ECE203 Round 5N-F — Final Noise Closure (task, as given)

Base: R5N-N best `ece203_r5nn_tb_n2` (M1/M2 50/40 µm, M3/M4 8/36 µm, MC/MT/OTA2/DRL/caps/pseudo-R/bias unchanged).
Stage A: only M3/M4 L: F1 8/40 µm, F2 8/42 µm (DC + AC + noise). If both fail and M4 still has margin, one extra F3 8/44 µm.
Stage B: full signoff of the best valid case: noise < 3 µVrms by BOTH methods (prefer < 2.95 µV), 38–42 dB,
fL 0.09–0.11 Hz, fH 225–275 Hz, CMRR60 > 85 dB, Zin10 > 100 MΩ, P < 4 µW (VDDD 0 V meter already in I(VDD)),
main PM ≥ 55°, DRL stable, CM transient no clipping, M1–M4/MC valid (M4 VSD/VDSAT/margin; < 50 mV = reliability risk),
design C < 1 nF. New cells/SKILL/ADE state only; keep raw AC/noise/DCOP/STB/tran CSV; no other optimization, no MC/PVT/chopper/PSS.
All nominal PASS → label `NOMINAL PASS — PVT/MC PENDING` and stop. Report: docs/ECE203_round5nf_final_noise_results.md.
Script `ece203_r5nf.il` (jobs ece203_r5nf_a, ece203_r5nf_a3, ece203_r5nf_b, ece203_r5nf_ade).
