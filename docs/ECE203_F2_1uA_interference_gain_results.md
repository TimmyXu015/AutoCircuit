# ECE203 F2 — 1 µA 60 Hz body-interference gain test in the instructor ECG_tb (results, 2026-11-25)

Task: [ECE203_F2_1uA_interference_gain_task.md](ECE203_F2_1uA_interference_gain_task.md). Plan (registered before results): [ece203_data/f2_1ua_gain/f2i_plan.md](ece203_data/f2_1ua_gain/f2i_plan.md). It has three updates, each recorded before the results it affects:
- update 1: extend to 10 s;
- update 2: output format;
- update 3: linear drift term in the fit.

Script: `ece203_f2i.il`; jobs `ece203_f2i_{probe,build,ac,tran}`. Data: [ece203_data/f2_1ua_gain/](ece203_data/f2_1ua_gain/).

**DUT:** the frozen early non-chopped F2:
- `Project/ece203_r5nf_tb_f2`, OTA `ece203_r5nf_ota_f2`;
- `r5nOver(4e-6)` on `r4Vars`: prw 4u, real DRL with rdr 1 MΩ, LP 31.8 MΩ / 20 pF, cm2 0.5 pF;
- TT / 27 °C; options gmin 1e-18, reltol 1e-6.

**Testbench:** an isolated copy of the instructor `ECG_tb/ECG_tb` in `Project/ece203_f2_1ua_prof_tb`.
- The original is read-only. Nothing was written to any `203ECG*` library.
- V0 vsin is 1 mV peak (net1 → net013). The R1–R3 200 Ω loop has C0 200 pF on body net5. I2 is a 60 Hz isin, 0 → net5. The electrodes are 2 kΩ + (1 MΩ ‖ 50 nF).
- vRight → F2 inp and vLeft → F2 inn. This is the same polarity as the user's `ECG_tb_DRL`, which was only read.
- Gpost = |out| / |vRight − vLeft| (post-electrode). Gsrc = |out| / |V0|.

**Netlist audit — [f2i_netlist_audit.txt](ece203_data/f2_1ua_gain/f2i_netlist_audit.txt): PASS.**
- The instructor elements R1–R9, C0–C3, V0 and I2 match the schematic dump.
- The 36 DUT elements and the subckts match the archived F2 netlist, minus its fixture and with the nets renamed.
- Every transient netlist differs from the AC netlist only in the stimulus variables.

## Results (window 9–10 s; amplitudes are peak values)

| Case | Interference (60 Hz) | ECG | Gsrc / Gpost 10 Hz [dB] | Δ vs T0 [dB] | 38–42 dB | out DC [V] (drift) | out 60 Hz residual | out min..max [V] | H2/H3 | DRL / clipping | Settled | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Test 1 AC (archived fixture) | 0 | AC | 39.215 @100 Hz (Hsrc) | — | — | 0.8998 (DC OP) | — | — | — | — | — | **PASS** (reproduces 39.22) |
| Test 1 AC (instructor copy) | 0 | AC | Hpost 39.871 / 39.630 / 39.224 @10/60/100 Hz | 0 vs archived | in | 0.8998 | — | — | — | — | — | **PASS** |
| T0 | 0 | 1 mV, 10 Hz | 36.343 / 39.873 | 0 | in | 0.9346 (+0.04 mV/s) | 0.16 µV | 0.869..1.000 | −56 dBc | linear | yes | **PASS** |
| T100n | 100 nA | 1 mV, 10 Hz | 36.341 / 39.871 | −0.002 | in | 0.9372 (≈0) | 6.59 mV | 0.865..1.007 | −52 dBc | linear; drlr 0.84..0.96 | yes | **PASS** |
| T1u | 1 µA | 1 mV, 10 Hz | 35.828 / 39.358 | −0.515 | in | 0.8190 (**−64 mV/s**) | **514 mV** | 0.318..1.610 | **−33 dBc** | **drlr −0.70..2.43**; body / inputs −1.69..3.41; oa to 1.799 | **no** | **FAIL** (gain in band, output not usable) |
| I100n | 100 nA | 0 | — | — | — | 0.9046 | 6.58 mV | 0.897..0.910 | — | linear | yes | reference |
| I1u | 1 µA | 0 | — | — | — | 0.7939 (−64 mV/s) | 514 mV | 0.354..1.523 | — | DRL saturated as T1u | no | reference |
| T0_dcc1 (stress label) | 0 | 1 mV, 10 Hz | 36.345 / 39.875 | +0.002 | in | 0.9346 | 0.16 µV | 0.869..1.000 | −56 dBc | linear | yes | PASS |
| T1u_dcc1 (stress label) | 1 µA | 1 mV, 10 Hz | 35.834 / 39.364 | −0.511 (vs T0_dcc1) | in | 0.7806 (−64 mV/s) | 537 mV | 0.265..1.591 | −33 dBc | as T1u | no | FAIL |
| T1u at 3 s (first pass) | 1 µA | 1 mV, 10 Hz | 7.03 / 10.55 | −29.3 | out | 1.779 (pinned near VDD) | 39 mV | 1.252..1.799 | −17 dBc | oa1 to 2 mV, out to 1.799 | no | (superseded by 10 s) |

**Paired subtraction** (mixed − interference-only, 10 Hz, 9–10 s; [f2i_pairs.csv](ece203_data/f2_1ua_gain/f2i_pairs.csv)):

| Pair | Gpost [dB] | Residual after subtraction (60 / 20 / 30 Hz) |
|---|---|---|
| T100n − I100n | 39.871 | 8 µV / 161 µV / 49 µV (the 20/30 Hz terms equal the native T0 H2/H3) |
| T1u − I1u | 39.359 | 192 µV / **1.40 mV** / **0.54 mV** |
| T1u_dcc1 − I1u_dcc1 | 39.365 | similar to T1u − I1u |

Subtraction does not prove linearity: in the 1 µA pair, 20 and 30 Hz products remain.

**Test 4, same frequency** (ECG 1 mV at 60 Hz + 1 µA at 60 Hz, 9–10 s, complex 60 Hz phasors; [f2i_samefreq.csv](ece203_data/f2_1ua_gain/f2i_samefreq.csv)):

| Case | Apparent mixed \|out60\|/\|vpost60\| (not a gain) | Paired subtraction Gpost | vs S0 | Settled |
|---|---|---|---|---|
| S0 (no interference) | 39.633 dB (= AC 39.630) | — | 0 | yes |
| Si (interference only) | out60 514 mV, vpost60 3.9 µV | — | — | no |
| S1u phase 0° | 58.11 dB | 29.94 dB | −9.69 dB | no (−64 mV/s) |
| S1u phase 90° | 58.12 dB | 32.76 dB | −6.87 dB | no |
| S1u phase 180° | 57.35 dB | 29.95 dB | −9.68 dB | no |
| S1u phase 270° | 57.35 dB | 32.77 dB | −6.86 dB | no |

The mixed ratio is dominated by the interference, so it is not the differential gain. Under 1 µA the 60 Hz signal response from paired subtraction is 6.9–9.7 dB below S0 and depends on phase, so superposition does not hold.

Figures:
- [fig_f2i_waveforms.png](ece203_data/f2_1ua_gain/fig_f2i_waveforms.png): last 0.3 s of out, oa1, oa, drlr, body, electrode CM and DRL current.
- [fig_f2i_out_trend.png](ece203_data/f2_1ua_gain/fig_f2i_out_trend.png): out over the whole 10 s at 1 ms.
- [fig_f2i_gain.png](ece203_data/f2_1ua_gain/fig_f2i_gain.png): mixed-run 10 Hz gain against the 38–42 dB band.
- [fig_f2i_samefreq.png](ece203_data/f2_1ua_gain/fig_f2i_samefreq.png): Test 4.

## 中文小结

- **Test 1 通过。** 原 F2 夹具在 100 Hz 处为 39.215 dB，复现了 39.22 dB。把同一个 F2 接到教授的 ECG_tb 上，Hpost 与原夹具完全一致：10 Hz 39.87 dB，60 Hz 39.63 dB，100 Hz 39.22 dB。源端增益多了 body 分压 2/3（post/src = 0.666）。
- **100 nA 通过。** 10 Hz 增益 39.871 dB，比无干扰只低 0.002 dB。输出中 60 Hz 残留为 6.6 mV 峰值，约为 ECG 输出 65.6 mV 的 1/10（线性 AC 预测 5.9 mV）。没有削波，H2/H3 为 −52 dBc，DRL 驱动电流峰值 100 nA，10 s 时已稳定。
- **1 µA 时，只看 10 Hz 基波增益数字，仍在 38–42 dB 带内**（39.36 dB，下降 0.51 dB）。**但输出不可用，按任务规则不算干净通过。**
  - DRL 输出 drlr 摆到 −0.70…2.43 V，超出电源轨约 0.7 V。
  - body、电极共模和放大器输入一起摆到 −1.69…3.41 V。
  - 输出中 60 Hz 残留为 514 mV 峰值，约为 ECG 的 8 倍，而线性 AC 预测只有 59 mV。
  - H2/H3 为 −33 dBc，oa 碰到 1.80 V。
  - 输出直流在 10 s 时仍以约 −64 mV/s 漂移，没有稳定。前约 2 s 内输出贴在 1.80 V（3 s 首轮测得的增益只有 10.5 dB）。
  - 配对相减后仍剩 1.4 mV 的 20 Hz 和 0.54 mV 的 30 Hz 互调成分。
- **dcc = 1 %（单独标注的压力用例）** 与 dcc = 0 基本相同：增益差在 0.01 dB 以内，1 µA 下同样饱和。
- **同频测试（Test 4）。** 混合比值为 57–58 dB，由干扰主导，不是增益。配对相减得到的 60 Hz 信号响应只有 29.9–32.8 dB，比 S0 低 6.9–9.7 dB，并随相位变化，说明 1 µA 下叠加原理不成立。
- **供你推理的事实，未下结论。**
  - DC OP 下 DRL OTA 尾电流为 249 nA（XD.MT），而 1 µA 用例中 RDRR 上的电流峰值为 0.998 µA。
  - 100 nA 用例的 drlr 只摆动 ±62 mV。
  - 1 µA 用例中 VDD 平均功耗从 3.18 µW 变为 1.36 µW（不含 DRL 的 VDDD）。
- **回答主问题：** 这个早期 F2 在 1 µA 下，10 Hz 基波增益数字仍在带内，但输出被饱和的 60 Hz 主导、有失真且未稳定，**不能算保持了可用的中频 ECG 增益**。100 nA（规格值）下干净通过。

## Commands

Server: ieng6-ece-10. Jobs run from `/home/linux/ieng6/ECE203_FA26_001/lix015`.

```
~/AutoCircuit/run.sh ece203_f2i_probe   # read-only dump of the libraries and schematics
~/AutoCircuit/run.sh ece203_f2i_build   # copy ECG_tb -> Project/ece203_f2_1ua_prof_tb, place frozen F2 (refuses 203ECG*)
~/AutoCircuit/run.sh ece203_f2i_ac      # Test 1: A_ref_f2fixture_dm, A_prof_dm, A_prof_int
AC_F2I_CASES=T0 ~/AutoCircuit/run.sh ece203_f2i_tran                 # 3 s first pass (T0 I1u T1u I100n T100n)
AC_F2I_STOP=10 AC_F2I_CASES=<case> ~/AutoCircuit/run.sh ece203_f2i_tran   # 10 s extension; cases T0 I1u T1u I100n T100n
                                                                          # T0_dcc1 T1u_dcc1 I1u_dcc1 S0 Si S1u_p0 S1u_p90 S1u_p180 S1u_p270
```

The transient uses maxstep 50 µs with a watchdog (`tools/f2i_watchdog.sh`). The T1u 10 s run takes 459 k steps and about 5 min.

Analysis, run locally on the raw folder:
```
F2I_RAW=<raw> python3 f2i_analysis.py
python3 f2i_audit.py <raw>
F2I_RAW=<raw> python3 f2i_figs.py 10
```

Raw files are in the notebook, `_raw\2026-11-25_ece203_f2_1ua_interference\`:
- full traces: the last 2 s at 100 µs plus a 1 ms whole-run trend, with sha256 sums in `raw/kv/`;
- netlists, `spectre.out` and job logs.

The partial I1u 3 s full-resolution CSV, from a run I killed myself, was moved aside and not used.

## Limitations

- **1 µA is ten times the 100 nA spec.** This is a stress test, not a spec gate.
- **Corners:** TT / 27 °C only. No MC, PVT, chopper or redesign was run (out of scope).
- **No pad or ESD clamps.** The model has no input or body clamp devices. At 1 µA the body and inputs exceed the rails, limited only by the device junctions and the source impedances. Real pads would change the clamp levels.
- **Settling.** The registered single extension went to 10 s. All 1 µA cases are still unsettled (DC −64 mV/s); their 10 Hz numbers come from a drifting state. They were not run longer.
- **Fit method.** Least-squares fit of DC + linear + k·f0 on a 20 µs resample of a 100 µs grid. The harmonics of strongly distorted 1 µA waveforms are fit estimates. The min/max values are exact Spectre extrema.
- **Power.** P counts only the VDD supply; the DRL VDDD supply is excluded.
