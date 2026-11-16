# ECE203 Round 3C 结果：B / P / C 三种 OTA 在同一 S2 测试台的对照

日期 2026-11-16 · 任务书 [ECE203_round3c_ota_pmos_cascode_microcompare.md](ECE203_round3c_ota_pmos_cascode_microcompare.md) · 数据 [ece203_data/ota_compare/](ece203_data/ota_compare/)（`bpc_summary.csv`、NoiseSummary、`bpc_gain_noise.png`）

**测试台（三组完全相同）：** S2，每侧 Cc 50 p / Cfb 0.5 p / **理想** Rfb 3.1831 T，CL 0，VDD 1.8 V，VREF 0.9 V，差分 AC ±0.5 V，ib3 50 nA。仿真精度 gmin = iabstol = 1e-18、reltol 1e-6。每组跑 DC op + AC（1 mHz–100 kHz，每十倍频 20 点）+ 噪声（同一频点网格，积分 0.1–250 Hz）。实际 A0 用独立开环 tb 测（DC 跟随器，1 TΩ / 1 F，取 10 Hz）。每组都只跑一次，没有做修正。

**变体（网表已核对）：**
- **B**：NMOS 输入 5T，M1/M2 10u/8u，PMOS 镜像 2u/4u，NMOS 尾管 8u/4u + 参考管 2u/4u。（与 Round 3A 的 L = 8u 版相同。）
- **P**：PMOS 输入 5T。M1/M2 为 `pfet` 10u/8u，bulk 接 VDD，输入面积与 B 相同（80 µm²/管）。NMOS 镜像 2u/4u，PMOS 尾管 8u/4u 和参考管 2u/4u 接 VDD，IBIAS 从参考管抽 50 nA 到地。INP 在二极管侧；闭环 DC 正常、带内相位约 0°，说明是负反馈。
- **C**：在 B 的基础上，于 M2 漏极（x）和 OUT 之间串一只 NMOS cascode MC 10u/4u，栅极接理想 VCAS = 1.05 V。这个偏置只用于诊断，不符合源数量要求。**C 已经不是严格的 5T。**

| | B（NMOS 5T） | P（PMOS 输入 5T） | C（B + 局部 cascode） |
|---|---|---|---|
| \|Hdm\| 10 / 100 Hz | 73.13 / 73.13 | 61.06 / 61.06 | **94.22 / 94.22** |
| dB @100 Hz（≥38 dB？） | 37.28（否） | 35.71（否） | **39.48（是）** |
| fL / fH | 0.074 Hz / 11.4 kHz | 0.062 Hz / 9.36 kHz | 0.095 Hz / 8.81 kHz |
| 实际 A0（开环 AC） | 280.6 (49.0 dB) | 161.0 (44.1 dB) | **1627 (64.2 dB)** |
| 100·A0/(A0+101) | 73.5 | 61.5 | 94.2 |
| I_VDD / 功耗 | 283.1 nA / 0.510 µW | **236.5 nA** / 0.426 µW | 283.1 nA / 0.510 µW |
| DC：o / n / p (V) | 0.9015 / 0.9015 / 0.9 | 0.8964 / 0.8964 / 0.9 | 0.9023 / 0.9023 / 0.9 |
| 最小 sat margin（不含 MREF） | 0.291 V (M2) | 0.235 V (M3) | **0.047 V (M2)**；MC 0.145 V |
| 输入管 gm / gm/Id / region | 2.69 µS / 23.1 / 3 | 1.76 µS / 19.5 / 2 | 2.69 µS / 23.1 / 3 |
| gds：输出 NMOS / 输出 PMOS (nS) | M2 8.03 / M4 1.59 | M4(N) 10.5 / M2(P) 0.99 | M2 13.8，MC 15.8 / M4 1.59 |
| 输出噪声 rms 0.1–250 Hz | 1.206 mV | 2.551 mV | 1.521 mV |
| **应用型输入噪声** = out_rms / \|Hdm(100 Hz)\| | **16.5 µV** | 41.8 µV | **16.1 µV** |
| **逐点 de-embed 型** = √∫(out/\|Hdm(f)\|)² | **16.8 µV** | 42.2 µV | **16.6 µV** |
| 噪声：输入对 flicker / 镜像 flicker / cascode / 白噪声(id) | 57.3% / 41.4% / — / 1.0% | **1.1% / 98.6%** / — / 0.3% | 56.4% / 42.2% / 0.00% / 1.1% |
| 上述分量折算到输入（µV） | 12.5 / 10.6 / — / 1.7 | **4.3 / 41.5** / — / 2.3 | 12.1 / 10.5 / 0.06 / 1.7 |

- **补充说明：**
  - NoiseSummary 的总功率与独立积分完全一致（B 1.454e-6 V²，P 6.507e-6 V²，C 2.315e-6 V²）。
  - 理想 Rfb 的噪声在三组中都 ≤0.34%。
  - 带内两种输入参考定义相差 <3%。
  - Spectre 以 VINP 单端为参考的输入噪声，与 de-embed 值一致。
- **P 的电流偏低：** 总电流 236.5 nA，比 B 少 16%。PMOS 尾管/参考管镜像的实际电流比不同，tail 约 186 nA。按任务书，只有 OP 失败才允许修正，所以没有改。
- **C 的余量问题：** M2 的 Vds 只有 0.147 V。由于 margin 按 max(Vdsat, 0.1 V) 计算，余量只剩 0.047 V（仍在 region 3）。M1 的 Vds 为 0.814 V、M2 为 0.147 V，明显失配，系统失调 +0.8 mV。闭环和开环都工作正常，所以**不算失败**，按规则也没有做偏置修正。

## 两个核心问题的数据回答
1. **PMOS 输入的 1/f 噪声是否较低？** 输入对本身：是。同样 80 µm² 的面积，PMOS 输入对的 flicker 折算到输入只有 4.3 µV，B 的 NMOS 输入对是 12.5 µV。但 P 的总噪声更差（42 µV），因为 98.6% 来自新的 NMOS 镜像 M3/M4（2u/4u，面积很小）。同时 P 的 A0 降到 161，因为 NMOS 镜像的 gds 为 10.5 nS；电流也低了 16%。
2. **单侧 NMOS cascode 能否低成本提高增益？** 能。A0 从 281 升到 1627，S2 增益达到 94.2（39.48 dB，过 38 dB）。电流和噪声与 B 基本相同（应用型输入噪声 16.1 µV），cascode 本身的噪声约为 0%。代价有三点：需要额外的 VCAS 偏置（本轮用的是理想源）；M2 余量只剩 0.047 V；fH 从 11.4 kHz 降到 8.8 kHz。

## Cadence 里新建的东西（旧 cell 没有改动）
- OTA：`ece203_ss_ota_cmp_b_ota`、`ece203_ss_ota_cmp_p_ota`、`ece203_ss_ota_cmp_c_ota`（C 多一个 VCAS 引脚）。
- 测试台：各变体的 `ece203_ss_ota_cmp_{b,p,c}_tb`（S2）和 `ece203_ss_ota_cmp_{b,p,c}_ol`（开环 A0）。
- ADE state `cmp_s2`：每个 `_tb` 一份，内容为 dc op + ac + noise，仿真选项为 gmin/iabstol = 1e-18、reltol = 1e-6。
- job：`ece203_ss_ota_cmp`、`ece203_ss_ota_cmp_ade`。

## 等待用户 + GPT 决定
保留哪条路线：C（单侧 cascode，需要解决 VCAS 来源和 M2 余量），P 加更大的 NMOS 镜像，还是其他方向。另外还有 chopper 是否引入。所有变体的噪声都在 16 µV 以上，远高于 3 µVrms 的指标。本轮已经停止。
