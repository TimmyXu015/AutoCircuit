# ECE203 Round 2A — A1/A2 noise diagnosis and W/L sweep: results (2026-11-15)

> Work order: [ECE203_round2_noise_scan.md](ECE203_round2_noise_scan.md). Every number comes from Spectre runs on
> ieng6 (jobs below, raw CSVs in [`ece203_data/round2a/`](ece203_data/round2a/)). Round-1 cells were not modified.
> Topology unchanged. This is a characterisation round — **no point meets the noise aspiration**.

## What was run

| Job (`~/AutoCircuit/run.sh <job>`) | What | Status |
|---|---|---|
| `ece203_noise_probe` | builds the new cells, baseline run, probes `noiseSummary` | OK |
| `ece203_noise_scan` | Stage 1 breakdown + Stage 2 12-point grid + Stage 3 mirror area x2/x4 + combo + convergence | OK (15 points, all ran) |
| `ece203_noise_rebias` | bounded VCP/VCN rebias of the points whose saturation margin went negative | OK (4 points) |

New cells in library `Project` (Round-1 cells untouched):

- `ece203_a12n_ota` — same devices/nets as `ece203_a12_ota`, but **M1/M2 W/L = design variables `w12in`/`l12in`** and **M7/M8 W/L = `w78in`/`l78in`** (defaults 20u/1u and 1u/10u = Round-1 sizes). Explore in ADE by changing these variables.
- `ece203_a12n_cl_tb` — same as `ece203_hp_real_tb` (OTA + `ece203_hp_fb`, IPRB for stb, CL 5 pF, VIN acm=1).
- `ece203_a12n_ol_tb` — same as `ece203_a12_ol_tb` (1 TOhm / 1 F DC follower; rl12 = 1e15 or 1 MOhm to vcm).

Setup (all points): ib12 = 100 nA ideal sink, VDD 1.8 V, vref 0.9 V, cc/cf/rp = 100 p/4 p/398 G (ideal R), CL 5 pF.
Fixed bias VCP/VCN = 0.70/0.75 V unless `bias = rebiased`. Only VIN has AC magnitude (netlist checked: VREF, VCP, VCN, VDD, IB all `mag=0`).
Noise: `analysis('noise ?start "1m" ?stop "100k" ?dec "20" ?p "/o" ?n "/gnd!" ?iprobe "/VIN")`.

**Metrics** (all from amplitude densities, integrated as power):
- `rms 0.1-250` = sqrt(∫ v_in(f)² df, 0.1–250 Hz), v_in = Spectre input-referred density (`getData("in" ?result "noise")`). Primary score.
- `rms in 1m-100k` = same over 1 mHz–100 kHz (includes the high-pass's low-frequency noise amplification — large).
- `out rms 1m-100k / H` = sqrt(∫ v_out² df, 1 mHz–100 kHz) / |H(100 Hz)| (instructor-style, uses the measured |H|).
- `x sqrt2` = sqrt(2)·rms 0.1-250: **estimate** for two uncorrelated matched A1/A2 paths, NOT a full-chain simulation.
- Integration: OCEAN `integ()` (trapezoid, linear Hz) on 20 points/decade. Convergence: 50 points/decade changes rms 0.1-250 by 0.10 % (baseline 13.327→13.313 uV) and 0.10 % (best combo 5.438→5.433 uV); see `ece203_ns_convergence.csv`.

Baseline reproduction with the new cells: rms 0.1-250 = 13.33 uV, |H(100)| 24.948, fL 0.09999 Hz, fH 4.485 kHz, PM 90.07 deg, Zin 159.4 MOhm, I 668 nA — identical to Round 1 (all digits).

## Stage 1 — where the noise comes from (baseline W20/L1)

`noiseSummary('integrated ?result 'noise ?from 0.1 ?to 250 ?output port)` works in batch OCEAN and lists every
noise source (device, param, output-referred V²). Check: the device rows sum to 0.999997 of Spectre's
"Total Summarized Noise" (1.04181e-7 V² at the output); "Total Input Referred Noise" 1.77612e-10 V² = (13.33 uV)².
Params: `fn` = flicker, `id` = channel thermal, `rn` = resistor thermal; `XA.Mx.rgate/rsext/...` = PDK parasitic resistors.

| group | devices | share of 0.1–250 Hz output noise power | of which flicker |
|---|---|---|---|
| NMOS mirror | M7, M8 (nfetx 1u/10u) | **64.06 %** (M8 32.00, M7 31.73) | 99.5 % |
| input pair | M1, M2 (pfetx 20u/1u) | **35.42 %** (M2 17.61, M1 17.59) | 99.4 % |
| feedback Rp | XFB/RP (ideal 398 GOhm) | 0.50 % | thermal |
| NMOS cascode | M5, M6 | 0.01 % | |
| PMOS cascode | M3, M4 | 0.01 % | |
| tail / reference | M0, MREF | 0.00 % (common-mode, cancels) | |
| PDK parasitic R | rgate etc. | 0.00 % | |

Share of the spot noise PSD by frequency (baseline):

| f | input pair | mirror M7/M8 | Rp |
|---|---|---|---|
| 0.1 Hz | 60.8 % | 35.9 % | 3.3 % |
| 1 Hz | 44.9 % | 54.7 % | 0.4 % |
| 10 Hz | 28.4 % | 71.5 % | 0.1 % |
| 100 Hz | 16.6 % | 83.4 % | — |
| 250 Hz | 13.8 % | 86.1 % | — |
| 1 kHz | 13.5 % | 86.5 % | — |

Over 1 mHz–100 kHz: mirror 68.1 %, input pair 31.3 %, Rp 0.6 %.
Input-referred amplitude slopes (baseline, log-log between spot points): −0.57 (0.1–1 Hz), −0.53, −0.51, −0.48, −0.45 (250 Hz–1 kHz):
≈ −0.5 = 1/f in power, i.e. flicker-dominated in band; white floor ≈ 60–70 nV/√Hz only above ~10 kHz.
The input-pair share falling with frequency means the PMOS and NMOS flicker spectra have different slopes in this PDK (data, not modelled here).

## Stage 2 + 3 — all points

`stage`: S2grid = 12-point M1/M2 grid; S3mirror = M7/M8 area x2 (1.41u/14.1u) and x4 (2u/20u) at fixed W/L ratio 0.1 and baseline M1/M2;
S3combo = best grid point + mirror x4 (labelled combination, not part of the pure W/L study).
`rebiased` rows come from the bounded scan (VCP 0.45–0.80, VCN 0.65–0.85, step 0.05; criterion: all devices region 2/3, |Vout−0.9| < 20 mV, max of the smallest margin); the fixed-bias rows of the same geometry stay in the table.
`min margin` = min over M0..M8 of |Vds| − max(|Vdsat|, 0.1 V) — negative means a device has < 0.1 V across it. **Spectre still reports region 3 (subthreshold) there**, so `run_status = ok` does not mean "healthy": look at margin and A0. Every point including the baseline (57 mV) is flagged `margin<0.1V` in the CSV.

| tag | stage | W/L (um) | M7/M8 W/L | bias | VCP/VCN | status | rms 0.1-250 (uV) | x sqrt2 (uV) | rms in 1m-100k (uV) | out rms 1m-100k / H (uV) | in-pair % | mirror % | I(VDD) (nA) | gm/Id M1 | min margin (mV) / worst | A0 | A0 w/ 1M | H(100) | fL (Hz) | fH (kHz) | PM (deg) | Zin10 (MOhm) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| w20_l1 | S2grid | 20/1 | 1/10 | fixed | 0.7/0.75 | ok | **13.33** | 18.85 | 38.6 | 16.22 | 35.4 | 64.1 | 668.3 | 22.9 | 57 / M2 | 14191 | 6.48 | 24.948 | 0.1000 | 4.49 | 90.1 | 159.4 |
| w40_l1 | S2grid | 40/1 | 1/10 | fixed | 0.7/0.75 | ok | **11.43** | 16.16 | 31.9 | 14.30 | 21.7 | 77.6 | 668.6 | 24.3 | 28 / M2 | 12165 | 6.84 | 24.941 | 0.1000 | 4.74 | 90.1 | 159.5 |
| w80_l1 | S2grid | 80/1 | 1/10 | fixed | 0.7/0.75 | ok | **10.26** | 14.51 | 27.9 | 13.10 | 12.2 | 86.9 | 668.8 | 25.6 | -0 / M2 | 8385 | 7.19 | 24.916 | 0.0999 | 4.98 | 90.1 | 159.6 |
| w160_l1 | S2grid | 160/1 | 1/10 | fixed | 0.7/0.75 | ok | **9.70** | 13.71 | 25.8 | 12.51 | 6.3 | 92.2 | 669.1 | 26.9 | -26 / M2 | 3761 | 7.40 | 24.820 | 0.0995 | 5.13 | 90.3 | 160.2 |
| w20_l2 | S2grid | 20/2 | 1/10 | fixed | 0.7/0.75 | ok | **12.73** | 18.00 | 36.2 | 15.96 | 21.1 | 78.3 | 668.1 | 21.6 | 57 / M5 | 19591 | 6.11 | 24.960 | 0.1000 | 4.23 | 90.0 | 159.4 |
| w40_l2 | S2grid | 40/2 | 1/10 | fixed | 0.7/0.75 | ok | **11.36** | 16.06 | 31.3 | 14.48 | 12.1 | 87.2 | 668.4 | 22.9 | 55 / M2 | 18124 | 6.48 | 24.958 | 0.1000 | 4.48 | 90.0 | 159.4 |
| w80_l2 | S2grid | 80/2 | 1/10 | fixed | 0.7/0.75 | ok | **10.43** | 14.76 | 28.1 | 13.45 | 6.6 | 92.6 | 668.6 | 24.2 | 26 / M2 | 14784 | 6.84 | 24.949 | 0.1000 | 4.73 | 90.0 | 159.4 |
| w160_l2 | S2grid | 160/2 | 1/10 | fixed | 0.7/0.75 | ok | **9.80** | 13.86 | 26.0 | 12.73 | 3.5 | 95.5 | 668.9 | 25.6 | -2 / M2 | 9359 | 7.18 | 24.922 | 0.0999 | 4.96 | 90.1 | 159.6 |
| w20_l4 | S2grid | 20/4 | 1/10 | fixed | 0.7/0.75 | ok | **12.89** | 18.24 | 36.6 | 16.47 | 11.6 | 87.8 | 667.8 | 20.1 | 57 / M5 | 23523 | 5.68 | 24.964 | 0.1000 | 3.93 | 90.0 | 159.3 |
| w40_l4 | S2grid | 40/4 | 1/10 | fixed | 0.7/0.75 | ok | **11.66** | 16.49 | 32.2 | 15.05 | 6.5 | 92.8 | 668.1 | 21.6 | 57 / M5 | 23191 | 6.11 | 24.965 | 0.1000 | 4.22 | 90.0 | 159.3 |
| w80_l4 | S2grid | 80/4 | 1/10 | fixed | 0.7/0.75 | ok | **10.85** | 15.34 | 29.3 | 14.06 | 3.6 | 95.7 | 668.4 | 22.9 | 55 / M2 | 21073 | 6.48 | 24.962 | 0.1000 | 4.47 | 90.0 | 159.3 |
| w160_l4 | S2grid | 160/4 | 1/10 | fixed | 0.7/0.75 | ok | **10.23** | 14.47 | 27.2 | 13.30 | 1.9 | 97.2 | 668.6 | 24.2 | 25 / M2 | 16608 | 6.84 | 24.952 | 0.1000 | 4.71 | 90.0 | 159.4 |
| w20_l1_m78x2 | S3mirror | 20/1 | 1.41/14.1 | fixed | 0.7/0.75 | ok | **11.07** | 15.65 | 36.3 | 13.48 | 51.8 | 47.4 | 668.3 | 22.9 | 57 / M2 | 15247 | 6.48 | 24.951 | 0.1000 | 4.49 | 90.0 | 159.4 |
| w20_l1_m78x4 | S3mirror | 20/1 | 2/20 | fixed | 0.7/0.75 | ok | **9.71** | 13.74 | 35.1 | 11.85 | 68.0 | 31.1 | 668.3 | 22.9 | 57 / M2 | 16171 | 6.48 | 24.954 | 0.1000 | 4.49 | 90.0 | 159.4 |
| w160_l1_m78x4 | S3combo | 160/1 | 2/20 | fixed | 0.7/0.75 | ok | **5.44** | 7.69 | 21.7 | 7.75 | 20.2 | 75.0 | 669.1 | 26.9 | -26 / M2 | 3871 | 7.40 | 24.825 | 0.0996 | 5.14 | 90.2 | 160.2 |
| w80_l1_rb | S2grid | 80/1 | 1/10 | rebiased | 0.65/0.7 | ok | **9.87** | 13.96 | 27.3 | 12.64 | 13.2 | 85.9 | 668.9 | 25.6 | 31 / M4 | 11649 | 7.25 | 24.938 | 0.1000 | 5.02 | 90.1 | 159.5 |
| w160_l1_rb | S2grid | 160/1 | 1/10 | rebiased | 0.65/0.75 | ok | **9.42** | 13.32 | 25.2 | 12.19 | 6.6 | 92.3 | 669.1 | 26.9 | 23 / M2 | 9988 | 7.60 | 24.926 | 0.0999 | 5.26 | 90.0 | 159.6 |
| w160_l2_rb | S2grid | 160/2 | 1/10 | rebiased | 0.65/0.65 | ok | **8.99** | 12.72 | 25.0 | 11.80 | 4.1 | 94.7 | 668.9 | 25.6 | 31 / M4 | 13457 | 7.24 | 24.943 | 0.1000 | 5.00 | 90.0 | 159.4 |
| w160_l1_m78x4_rb | S3combo | 160/1 | 2/20 | rebiased | 0.65/0.75 | ok | **5.28** | 7.47 | 21.3 | 7.57 | 21.4 | 75.3 | 669.1 | 26.9 | 23 / M2 | 10781 | 7.60 | 24.931 | 0.0999 | 5.26 | 89.9 | 159.5 |

Spot input noise (V/rtHz):
| tag | 0.1 Hz | 1 Hz | 10 Hz | 100 Hz | 250 Hz | 1 kHz |
|---|---|---|---|---|---|---|
| w20_l1 | 1.8e-05 | 4.87e-06 | 1.43e-06 | 4.45e-07 | 2.86e-07 | 1.54e-07 |
| w40_l1 | 1.42e-05 | 4.07e-06 | 1.25e-06 | 4.04e-07 | 2.62e-07 | 1.42e-07 |
| w80_l1 | 1.2e-05 | 3.59e-06 | 1.14e-06 | 3.77e-07 | 2.46e-07 | 1.34e-07 |
| w160_l1 | 1.1e-05 | 3.35e-06 | 1.09e-06 | 3.63e-07 | 2.37e-07 | 1.29e-07 |
| w20_l2 | 1.57e-05 | 4.52e-06 | 1.4e-06 | 4.53e-07 | 2.95e-07 | 1.62e-07 |
| w40_l2 | 1.32e-05 | 3.96e-06 | 1.27e-06 | 4.18e-07 | 2.73e-07 | 1.5e-07 |
| w80_l2 | 1.17e-05 | 3.6e-06 | 1.17e-06 | 3.92e-07 | 2.56e-07 | 1.41e-07 |
| w160_l2 | 1.08e-05 | 3.36e-06 | 1.11e-06 | 3.72e-07 | 2.43e-07 | 1.33e-07 |
| w20_l4 | 1.48e-05 | 4.49e-06 | 1.44e-06 | 4.77e-07 | 3.13e-07 | 1.75e-07 |
| w40_l4 | 1.29e-05 | 4.02e-06 | 1.31e-06 | 4.39e-07 | 2.88e-07 | 1.6e-07 |
| w80_l4 | 1.18e-05 | 3.72e-06 | 1.23e-06 | 4.12e-07 | 2.71e-07 | 1.5e-07 |
| w160_l4 | 1.1e-05 | 3.5e-06 | 1.16e-06 | 3.91e-07 | 2.56e-07 | 1.41e-07 |
| w20_l1_m78x2 | 1.63e-05 | 4.15e-06 | 1.15e-06 | 3.42e-07 | 2.19e-07 | 1.21e-07 |
| w20_l1_m78x4 | 1.53e-05 | 3.74e-06 | 9.72e-07 | 2.75e-07 | 1.75e-07 | 1e-07 |
| w160_l1_m78x4 | 7.26e-06 | 1.92e-06 | 5.85e-07 | 1.92e-07 | 1.29e-07 | 7.82e-08 |
| w80_l1_rb | 1.17e-05 | 3.45e-06 | 1.1e-06 | 3.61e-07 | 2.35e-07 | 1.28e-07 |
| w160_l1_rb | 1.07e-05 | 3.25e-06 | 1.06e-06 | 3.53e-07 | 2.31e-07 | 1.26e-07 |
| w160_l2_rb | 9.99e-06 | 3.09e-06 | 1.01e-06 | 3.4e-07 | 2.23e-07 | 1.23e-07 |
| w160_l1_m78x4_rb | 7.07e-06 | 1.86e-06 | 5.67e-07 | 1.87e-07 | 1.25e-07 | 7.6e-08 |


## Best candidates and trade-offs

| candidate | rms 0.1-250 | vs baseline | cost |
|---|---|---|---|
| `w160_l1_m78x4_rb` (M1/M2 160u/1u, M7/M8 2u/20u, VCP 0.65 / VCN 0.75) | **5.28 uV** | −60 % | margin 23 mV (M2); input-pair gate area 8x, mirror area 4x; A0 10781; still 75 % mirror-limited |
| `w160_l1_m78x4` (same, fixed bias) | 5.44 uV | −59 % | margin −26 mV, A0 3871 (M2 squeezed) |
| `w160_l2_rb` (M1/M2 160u/2u, VCP 0.65 / VCN 0.65) | 8.99 uV | −33 % | 16x input area; margin 31 mV |
| `w20_l1_m78x4` (mirror only) | 9.72 uV | −27 % | mirror area 4x, no headroom change (margin 57 mV) |
| `w160_l1` (fixed bias) | 9.70 uV | −27 % | margin −26 mV, A0 3761 |

Current is unchanged everywhere (667.8–669.1 nA). PM stays 90 deg (dominant pole), fH rises with W and falls with L (3.93 kHz at W20/L4 … 5.26 kHz at W160/L1), |H(100)| stays 24.82–24.97,
Zin(10 Hz) 159.3–160.2 MOhm, fL 0.0995–0.1000 Hz. A0 with 1 MOhm load stays collapsed (5.7–7.6) — the A1→A3 loading issue is unchanged.

## Answers (Chinese, for the user)

1. **哪些器件主导噪声？** NMOS 电流镜 M7/M8 的闪烁噪声（基线 64 %），其次是输入对 M1/M2 的闪烁噪声（35 %）。0.1–250 Hz 里 >99 % 是 flicker（`fn`）；Rp 0.5 %，共源共栅管和尾管/参考都 <0.02 %。频率越高电流镜占比越大（0.1 Hz 时 36 %，250 Hz 时 86 %）。
2. **W 和 L 怎么影响 flicker / thermal？** 同样电流下加大 W：输入对的面积和 gm/Id 都上升（22.9 → 26.9 /V，已接近亚阈值上限），输入对自己的占比从 35 % 降到 6 %；但因为 gm1 只涨了约 17 %，电流镜折算到输入的噪声几乎不降，于是总噪声只从 13.3 降到 9.7 µV。加大 L（W 不变）：输入对面积变大，但 gm/Id 下降（22.9 → 20.1），电流镜的折算噪声反而变大，总噪声几乎不变（W20：13.3 / 12.7 / 12.9 µV）。同样面积下"宽"比"长"好（160 µm²：W160/L1 9.70 µV，W40/L4 11.66 µV）。热噪声在带内 <0.5 %，只在 ~10 kHz 以上可见（约 60–70 nV/√Hz）。
3. **电流不变能改善多少？** 只改输入对：13.3 → 9.7 µV（固定偏置）或 9.0 µV（W160/L2 重偏置），约 −27 % 到 −33 %。只把电流镜面积 ×4：9.7 µV。两者都做：5.4 µV（固定偏置）/ 5.3 µV（重偏置），约 −60 %。电流变化 <0.2 %。
4. **哪些改动影响增益、PM、余量、输入阻抗？** 余量受影响最大：W 越大，M1/M2 的 |Vgs| 越小（0.337 → 0.255 V），tail 降低，M1/M2 的 |Vds| 从 0.159 降到 0.076 V（W160/L1），开环 A0 从 14191 掉到 3760，闭环 |H| 从 24.95 掉到 24.82；把 VCP 降到 0.65 V 能拉回约 23–31 mV 余量，A0 恢复到 ~1e4。PM 一直是 90°；fH 随 W 变大（4.49 → 5.26 kHz）；Zin(10 Hz) 基本不变（159–160 MΩ），因为 Cc = 100 pF 远大于输入管栅电容。带 1 MΩ 负载的开环增益仍然塌掉（5.7–7.6），级间负载问题没变。
5. **不改架构能做到每路 ≤1–1.5 µV 吗？** 在这次试过的尺寸范围内不能：最好是 5.3 µV，离 1.5 µV 还差约 3.5 倍（功率差约 12 倍），而且剩下的噪声里电流镜仍占 75 %。继续靠面积要把电流镜和输入对都再放大一个数量级左右，余量和面积都会成问题。是否需要改结构（例如电流镜改为更低 gm 或加退化、调整电流分配、或其他架构）需要你和 GPT 决定；本轮没有做任何结构改动。

## Open items / not done

- Stage 3 "extend input pair to W 320 / L 8" was **not** run: input-pair flicker is not dominant (rule in the work order).
- Further mirror options (larger area than x4, lower W/L, degeneration) were **not** run: outside the approved x2/x4 area sweep.
- No per-device input capacitance extraction; Zin and |H| show Cin is negligible next to Cc = 100 pF.
- A1→A3 loading (A0 with 1 MOhm ≈ 5.7–7.6) unresolved, as in Round 1.
- Monte Carlo / mismatch, full-chain noise: not in this round.

## Files

`docs/ece203_data/round2a/`: `ece203_ns_sweep.csv` (fixed-bias grid + S3), `ece203_ns_rebias.csv` (rebiased rows), `ece203_noise_breakdown.csv`
(long format: tag, kind, freq, group, device, param, V2_out, pct — integrated 0.1–250 Hz for every point, baseline spot at 0.1/1/10/100/250/1000 Hz,
baseline 1 mHz–100 kHz), `ece203_noise_breakdown_rebias.csv`, `ece203_ns_convergence.csv`, `w20_l1_summary_0p1_250.txt` (raw noiseSummary),
`<tag>_noise.csv` (f, in, out density), `<tag>_op.csv` (per-device OP). Code: `ece203_noise_scan.il`, plots `matlab/ece203_noise_plot.m`.
