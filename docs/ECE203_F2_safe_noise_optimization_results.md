# ECE203 F2S — safer full-band noise margin by bounded sizing (results, 2026-11-25)

- **Task:** [ECE203_F2_safe_noise_optimization_task.md](ECE203_F2_safe_noise_optimization_task.md).
- **Plan:** [ece203_data/f2_safe_noise/f2s_plan.md](ece203_data/f2_safe_noise/f2s_plan.md), registered before any F2S run.
- **Data:** [ece203_data/f2_safe_noise/](ece203_data/f2_safe_noise/).
- **Scope:** TT / 27 °C, instructor fixture, dcc = 0. Nothing was written to or simulated in any `203ECG*` library. No chopper, no topology change, no PVT, no 1 µA rerun.

## Winner: **P2S60**

| Item | Winner |
|---|---|
| Mirror M3/M4 (pfetx) | **W 12 µm / L 63 µm** (was 8/42) |
| Cc | **60 pF** per side (was 50) |
| Cf | **0.6 pF** per side (was 0.5) |
| Pseudo-R | **W 4.8 µm**, L 2 µm (was 4.0/2) |
| Unchanged | everything else |

| Item | F2 (baseline) | **Winner P2S60** | Target / gate |
|---|---|---|---|
| **M1 = √∫S_out (1 mHz–100 kHz) / Gpost(10 Hz)** | 2.982 µV | **2.609 µV** (−12.5 %) | ≤ 2.6, ≤ 2.7 acceptable |
| M1 / Gpost(100 Hz), guard | 3.213 µV (FAIL) | **2.811 µV** | < 3 |
| M3, 0.1–250 Hz, post-electrode pointwise | 2.875 µV | **2.494 µV** | ≤ 2.6 (secondary) |
| M2, Spectre native, V0-referred, 0.1–250 Hz | 4.316 µV | 3.744 µV | reported only |
| M2 / M3, full band (out-of-band de-embedding) | 47.2 / 31.0 µV | **81.7 / 53.8 µV** (worse, see diagnosis) | reported only |
| Gpost 10 / 60 / 100 Hz | 39.871 / 39.631 / 39.224 dB | 39.872 / 39.632 / 39.225 dB | 38–42 |
| fL / fH | 0.1004 / 248.16 Hz | 0.0995 / 248.20 Hz | 0.09–0.11 / 225–275 |
| CMRR60, DRL on (course definition, dcc = 0) | 86.33 dB | **86.73 dB** | > 85 (pref. ≥ 87–88: not reached) |
| Worst Zin @10 Hz (inn, v/i(VPN)); inp side | 162.5 MΩ; 3.86 GΩ | **135.2 MΩ**; 3.76 GΩ | > 100 (pref. ≥ 120) |
| Total power 1.8 V · I(VDD) (includes DRL) | 3.175 µW | 3.175 µW | < 4 |
| Designed capacitance | 143.5 pF | 163.7 pF | < 1 nF |
| Main-loop PM / GM | 73.0° / 19.4 dB | **65.1°** / 21.8 dB | ≥ 60° (guard) |
| DRL-loop PM | 90.1° | 90.1° | ≥ 60° |
| Smallest saturation margin \|VDS\| − VDSAT | M4 0.076 V | M4 0.074 V, M2 0.116 V | — |
| OTA1 area Σ W·L | 4848 µm² | 5688 µm² (mirror 2 × 756) | — |
| Input-device Cgg (M1) / mirror-node Cgg (M3) | 7.53 pF / 1.91 pF | 7.53 / 4.28 pF | — |
| NEF, 0.1–250 Hz, M1, I_fwd 1.46 µA | 8.00 | 6.94 | — |

**Mismatch MC of the winner** (N = 100, seed 12345, the same sample for DM / CM-off / CM-on / noise / stb):
- Valid 100/100, joint pass **100/100** (pilot N = 20: 20/20).
- Worst M1/G10 is **2.643 µV** (σ 0.012). Worst M1/G100 is 2.847 µV, so 100/100 also pass under the 100 Hz reference.
- CMRR_on min 85.58 dB, mean 86.72 dB.
- Zin_N min 135.1 MΩ. Power max 3.47 µW. fL 0.0918–0.1060 Hz. PM_main min 64.7°.
- Replays of samples 7 and 63 reproduce the main run (|ΔDC| 5.6e-10 V, AC ≤ 9e-6, noise ≤ 6e-6 relative).
- F2 for comparison: 94/100, worst noise 3.012 µV, CMRR min 85.16 dB.

**Noise convergence:** 50 vs 100 points per decade differ by 0.01 % (M1 2.6094 vs 2.6090 µV).

**Transient check** (10 s, instructor fixture, window 9–10 s, F2I extraction):

| Case | Gpost | out 60 Hz | DC drift | Notes |
|---|---|---|---|---|
| ECG 1 mV 10 Hz, no interference | 39.873 dB | — | settled | H2/H3 −56 dBc |
| ECG + 100 nA 60 Hz | 39.871 dB | 6.30 mV pk (F2: 6.59) | settled (−0.7 µV) | no clipping; drlr 0.84–0.96 V; H2/H3 −52 dBc |
| Paired subtraction (with − without interference) | 39.871 dB | 8 µV residual | — | — |

## Stage A — scouts and combinations (all audited; [f2s_compare.txt](ece203_data/f2_safe_noise/f2s_compare.txt), [fig_f2s_cases.png](ece203_data/f2_safe_noise/fig_f2s_cases.png))

| Case | M1/M2 · M3/M4 · MT (µm) | M1/G10 | M1/G100 | Input pair / mirror group (µV) | CMRR_on | PM main | Zin_N | P |
|---|---|---|---|---|---|---|---|---|
| B0 = F2 rebuilt | 50/40 · 8/42 · 32/4 | 2.982 | 3.213 | 2.199 / 1.908 | 86.33 | 73.0 | 162.5 M | 3.175 |
| N1 | 55/44 · base · base | 2.941 | 3.168 | 2.094 / 1.961 | 85.78 | 73.0 | 163.3 M | 3.175 |
| N2 | 60/48 · base · base | 2.927 | 3.153 | 2.017 / 2.018 | **85.22** | 73.0 | 164.1 M | 3.175 |
| P1 | base · 10/52.5 · base | 2.780 | 2.995 | 2.199 / 1.568 | 86.33 | 69.6 | 162.5 M | 3.175 |
| **P2** | base · **12/63** · base | 2.666 | 2.872 | 2.199 / 1.347 | 86.33 | 66.2 | 162.5 M | 3.175 |
| T1 | base · base · 36/4 | 2.976 | 3.208 | 2.151 / 1.915 | 85.64 | 72.7 | 162.7 M | 3.482 |
| T2 | base · base · 40/4 | 3.012 | 3.250 | 2.109 / 1.923 | **85.07** | 73.2 | 163.1 M | 3.790 |
| C1 = N1 + P2 | 55/44 · 12/63 · 32/4 | 2.601 | 2.802 | 2.094 / 1.385 | 85.78 | 66.3 | 163.3 M | 3.175 |
| C2 = N2 + P2 | 60/48 · 12/63 · 32/4 | 2.563 | 2.761 | 2.017 / 1.425 | **85.22** | 66.4 | 164.1 M | 3.175 |

**Mirror area (P) is the only lever without a side cost.** It cuts mirror noise ~1/√area (1.91 → 1.35 µV). CMRR, Zin, power and gain are unchanged; only main-loop PM drops (73 → 66°).

**Input-pair area (N) gives back most of its own gain:**
- Its own noise falls 2.20 → 2.02 µV.
- But mirror noise rises 1.91 → 2.02 µV: input Cgg goes 7.5 → 10.9 pF, which raises the capacitive noise gain (Cc + Cf + Cgg)/Cc.
- CMRR_on falls about 0.55 dB per step (85.78, 85.22). Against F2's observed MC spread (minimum 1.2 dB below nominal), C1/C2 would leave no CMRR margin.

**Tail current (T) does not help:**
- Input-pair noise falls, but mirror noise and power rise.
- CMRR falls to 85.07 dB, and M4 headroom drops to 0.056 / 0.038 V.
- T0 (less current) was not run, because the T trend showed no noise benefit worth trading.

The legal fallback P1s (9/47.25) was not needed: every requested W/L was realised exactly. The PDK CDF has no W/L limits, and the model files have no geometry bins or asserts, so no extrapolation flag applies. The layout penalty is area: the mirror grows from 2 × 336 to 2 × 756 µm².

## Stage B — Cc/Cf rescue on P2 (P2 alone stays above the 2.6 µV target)

| Case | Cc / Cf / prw | M1/G10 | M1/G100 | CMRR_on | Zin_N | PM main | fL |
|---|---|---|---|---|---|---|---|
| **P2S60** | 60p / 0.6p / 4.8u | **2.609** | 2.811 | 86.73 | **135.2 M** | 65.1 | 0.0995 |
| P2S70 | 70p / 0.7p / 5.6u | 2.569 | 2.767 | 87.03 | 115.7 M (below the 120 M preference) | 64.1 | 0.0989 |

- Larger Cc lowers the noise gain set by Cgg and raises CMRR slightly. Zin falls about 1/Cc.
- The prw ∝ Cf scaling kept fL centred, so no prw correction was needed.
- **P2S60 was chosen:** it keeps Zin ≥ 120 MΩ and more PM. P2S70 is 0.04 µV quieter but violates the Zin preference.
- **Budget:** 11 nominal configurations used (Stage A 9 + Stage B 2, limit 16). No Miller change.

## Full-band M2/M3 got worse — diagnosis, not hidden

- The pointwise full-band numbers rise from 47 → 82 µV (M2) and 31 → 54 µV (M3) as soon as the mirror is enlarged (P1 64/42, P2 84/55).
- The bigger mirror moves the mirror-node pole down. This shows as PM 73 → 66° and as a different roll-off of the closed-loop signal gain near 10–100 kHz: |Hpost(100 kHz)| 0.078 → 0.054.
- Output noise there rises: 11 → 14 nV/√Hz at 100 kHz.
- Pointwise de-embedding divides by that smaller gain, so the 250 Hz–100 kHz slice dominates these two numbers. It accounts for 81.5 of the 81.7 µV.
- In-band (0.1–250 Hz) both methods improve (M2 4.316 → 3.744, M3 2.875 → 2.494).
- Whether the course means a pointwise full-band input-referred number is the open question from F2V; it remains unresolved here.

## Hand-drawing recipe

**OTA1:** copy `ece203_r5nf_ota_f2` and change only M3 and M4 (pfetx): **w = 12u, l = 63u**, nf 1, m 1. Ad/as/pd/ps are filled by the PDK CDF (0.54 µm · W, 2 · (W + 0.54 µm)). Unchanged:
- M1/M2 nfetx 50u/40u;
- MC 10u/4u, MT 32u/4u, MREF 2u/4u.

**System:** the F2 system on the instructor ECG_tb, with only these design variables changed:
- **cc = 60p** (CCN/CCP), **cfb = 0.6p** (CFN/CFP), **prw = 4.8u** (XPN/XPP pseudo-R; prl stays 2u).

Unchanged:
- cm2 0.5p, LP 31.8 MΩ / 20 pF;
- DRL (rdr 1 MΩ), bias (IREF 100 nA + MP0/MP1/MP2), OTA2;
- dcc 0.

**Already built here (Project):**
- OTA `ece203_f2s_ota_p2`;
- system `ece203_f2s_tb_p2`;
- **ADE L state `f2s_winner_p2_cc60p`**:
  - tt, gmin/iabstol 1e-18, reltol 1e-6;
  - dc + ac 1m–100k 50/dec, noise 1m–100k from /out with input /V0, stb probe /IPRB;
  - outputs `Gpost_10Hz`, `Gpost_100Hz`, `M1_noise_G10`, `M1_noise_G100`, `M2_native_V0ref_1m_100k`, `P_total`, `loopGain_main`;
  - the Calculator expressions are the ones in the F2V manual section.

**Audit:**
- The ADE netlist of that cell with these variables (`WIN_dm_netlist.scs`) equals the simulated candidate netlist. The only differences are the stimulus mode expressions, which equal the plain values at fvm = 0.
- All 9 sizing netlists PASS [f2s_netlist_audit.txt](ece203_data/f2_safe_noise/f2s_netlist_audit.txt): only the intended devices' w/l/ad/as/pd/ps differ, and realised W/L equal the requested values.

## 中文结论

- **推荐的稳妥方案是 P2S60。**
  - 改动：PMOS 镜像 M3/M4 由 8/42 改为 **12/63 µm**；Cc/Cf 由 50p/0.5p 改为 **60p/0.6p**；pseudo-R 宽 4u 改为 **4.8u**。
  - 其他都不变：输入对 50/40、尾管 32/4、DRL、偏置、OTA2、LP。
- **噪声：** 课程全带 M1/G10 从 2.982 降到 **2.609 µV（−12.5 %）**；M1/G100 从 3.213 降到 **2.811 µV**，两种增益口径都 < 3 µV。0.1–250 Hz 逐点折算为 2.494 µV。
- **代价：** 主环路相位裕度 73° 降到 65°；inn 端输入阻抗 162 降到 135 MΩ；OTA1 面积 +17 %；电容 +20 pF。功耗不变（3.175 µW）。CMRR 略升，到 86.73 dB。
- **MC（N = 100）：** 全部指标联合 **100/100**。最差噪声 2.643 µV，G100 口径最差 2.847 µV；CMRR 最低 85.58 dB；功耗最高 3.47 µW。F2 原来是 94/100。
- **各方向的经验：**
  - 加大输入对：输入对噪声下降，但输入栅电容变大，抬高了镜像噪声，而且 CMRR 每档约降 0.55 dB，不划算。
  - 加大尾电流：没用。
  - 加大镜像面积：唯一没有副作用的方向。
- **未解决的问题：** 逐点折算的全带数字反而变大（M3 31 → 54 µV），原因是镜像极点下移，使 10–100 kHz 的增益滚降变快。这个口径是否算数，仍需你或教授确认；0.1–250 Hz 内两种方法都改善了。
- **已经建好、可直接对照手画：**
  - Project 里的 `ece203_f2s_tb_p2`，以及 ADE state `f2s_winner_p2_cc60p`；
  - 网表审计 PASS；
  - 10 s 瞬态在 100 nA 干扰下无削波、已稳定。
- **仍可作为后备：** 原 F2 没有改动。

## Commands

**Server (`~/AutoCircuit`):**
```
AC_F2S_CASES="B0 N1 N2 P1 P2 T1 T2" run.sh ece203_f2s_build      # then "C1 C2"
F2V_BASE=~/AutoCircuit_results/ece203_f2s/<case>_netlist.scs tools/f2v_run.sh s_<case> nominal 50
F2V_BASE=.../P2_netlist.scs F2V_SET="cc=60e-12 cfb=0.6e-12 prw=4.8e-6" tools/f2v_run.sh s_P2S60 nominal 50   (P2S70: 70p/0.7p/5.6u)
run.sh ece203_f2s_winner_ac ; AC_F2I_CASES="T0 T100n I100n" AC_F2I_STOP=10 run.sh ece203_f2s_tran ; run.sh ece203_f2s_ade
(F2V_BASE / F2V_SET as above) tools/f2v_run.sh w_mc20 mc 20 12345 1 50 ; w_mc100 mc 100 12345 1 50 ; w_rp7 / w_rp63 (firstrun 7 / 63, numruns 1)
```

**Local (`docs/ece203_data/f2_safe_noise/`):**
```
f2s_audit.py ; f2s_compare.py ; ../f2_final_scout/f2v_mc.py <x_w_mc100> w100 <x_w_rp7> <x_w_rp63> ; f2s_figs.py
(tran) F2I_RAW=<raw> ../f2_1ua_gain/f2i_analysis.py
```

Raw files are in the notebook folder `_raw\2026-11-25_ece203_f2_safe_noise\`.

## Limitations

- **Corners:** TT / 27 °C only; no PVT.
- **MC scope:** MOS mismatch only; ideal R/C not randomised; one seed.
- **Not run:** the optional fixed ±1 % Cc nominal sensitivity and the second-seed MC.
- **Model:** the large mirror (12 × 63 µm) relies on an unbinned single BSIM3 model. No geometry warning was raised, but long-channel flicker scaling is model-trusted.
- **Course compliance:** a 100 % course pass is not claimed while the full-band M2/M3 interpretation is unresolved.
