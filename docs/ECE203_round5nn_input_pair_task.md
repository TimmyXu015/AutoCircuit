# ECE203 Round 5N-N — NMOS Input Pair Final Noise Optimization (task, as given)

Base: Round 5N-L best circuit `ece203_r5nl_tb_l36` (M3/M4 8/36 µm, M1/M2 40/32 µm, MT 32/4 µm, prw 4 µm).
Only M1/M2 change, symmetric:

| Case | M1/M2 W/L | area / device |
|---|---|---:|
| T3 (reference) | 40/32 µm | 1280 µm² |
| N1 | 45/36 µm | 1620 µm² |
| N2 | 50/40 µm | 2000 µm² |

Stage A: DC + AC + noise of N1, N2 (both noise definitions, noise split, M1/M2/M3/M4/MC operating points and margins,
gain, fL, fH, Zin, total power, OTA1 area and input capacitance).
Stage B: full signoff of the best valid case (gain 38–42 dB, fL 0.09–0.11 Hz, fH 225–275 Hz, CMRR60 > 85 dB,
Zin10 > 100 MΩ, P < 4 µW with VDDD counted once, main PM ≥ 55°, DRL stable, CM transient no clipping,
noise < 3 µVrms by both methods, design C < 1 nF).
Constraints: new cells/scripts/ADE state only; keep raw Spectre CSV / noise summary / DC OP; no other parameter
changes, no extra W/L scan, no chopper/PSS, no Monte Carlo. Nominal PASS → stop; otherwise keep the best and stop.
Script: `ece203_r5nn.il` (jobs `ece203_r5nn_a`, `ece203_r5nn_b`, `ece203_r5nn_ade`).
