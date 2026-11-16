# ECE203 Round 4 结果：ECG 完整输入网络 × 单级 C OTA × DRL（整合实验）

日期 2026-11-16 · 任务书 [ECE203_round4_ecg_integrated_bigrun.md](ECE203_round4_ecg_integrated_bigrun.md) · 数据 [ece203_data/round4/](ece203_data/round4/) · 脚本 `ece203_r4.il`

> 本报告分阶段写入。每个阶段完成后单独提交。

## A — 完整信号链（DRL 关，只测前向链）

**系统（`Project/ece203_r4_ecg_tb`，理想 Rfb；`ece203_r4_ecg_pr_tb`，两只 Round 3B pseudo-R）：**
- **人体：** 200 pF 对地，另有 0.1 µA@60 Hz 交流电流源（Stage A 设为 0）。
- **电极：** 三个电极，每个为 2 kΩ 串（1 MΩ ‖ 50 nF）。
- **ECG 源：** VSP/VSN 位于人体和电极之间（差模 ±0.5 V；共模测试用 vcmin）。
- **放大器：** 0 V 探针 VPP/VPN 位于电极和放大器输入（inp/inn）之间，后接 Cc 50 p、Cfb 0.5 p、Rfb 3.18 T 或 pseudo-R。主 OTA `ece203_r4_ota` 是 Round 3C C 的复制，采用**理想 VCAS 1.05 V 和理想 VREF 0.9 V（诊断用，不符合源数量要求）**，ib3 50 nA 为理想源。
- **输出 LP：** 接在 OTA 反馈取样点 o 之后：o → RLP → out，CLP 对地。
- **CM 感测：** 在耦合电容之前，inp/inn 各经 10 GΩ 接到 cm。
- **DRL：** 理想 EDRL 和真实 DRL OTA（`ece203_r4_drl_ota`，即 B 5T）两条路径都在电路里，用 rdi / rdr 选择。DRL 关时两者都是 1e15 Ω。
- **仿真精度：** gmin = iabstol = 1e-18，reltol 1e-6。

**结果（`stageA/r4_stageA.csv`；增益定义为 V(out) / (V(ep) − V(en))，即电极源处的差模）：**

| 情况 | \|H\| 10 / 60 / 100 Hz（out） | dB @100 | fL / fH（out） | \|H\| @100 Hz 在 o 点（LP 前） | 状态 |
|---|---|---|---|---|---|
| A1 理想 Rfb + LP 3.18 MΩ / 200 pF | 84.9 / 30.6 / **18.9** | **25.6** | 0.094 Hz / **20.6 Hz** | 20.4 | SIM PASS / **SPEC FAIL**（LP 负载） |
| A2 理想 Rfb，去掉 LP（负载参照） | —（out 悬空） | — | o：— / 8.79 kHz | **94.2** | 参照 |
| A3 理想 Rfb + LP 31.8 MΩ / 20 pF（**唯一一次 RC 替代**） | 93.9 / 83.9 / 71.7 | **37.1** | 0.095 Hz / **117 Hz** | 77.2 | SIM PASS / **SPEC FAIL**（fH、增益） |
| A4 pseudo-R + LP 3.18 MΩ / 200 pF | 84.3 / 30.5 / 18.9 | 25.5 | **0.073 Hz** / 20.7 Hz | 20.4 | SIM PASS / SPEC FAIL |

- **架构瓶颈：输出 LP 负载。** 单级 OTA 的闭环输出阻抗太高，A0 = 1627 时 β ≈ 1/101，加 LP 后 o 点自身被拉低：100 Hz 时从 94 降到 20。同一时间常数下把 R 提高 10 倍、C 降 10 倍后，情况改善，但 fH 仍只有 117 Hz（目标 250 ± 10%）。按规则 RC 只替换一次，**不再调整**，也**没有加 buffer**。
- **低频截止：** fL 在理想 Rfb 下为 0.094 Hz（PASS），pseudo-R 下为 0.073 Hz（−27%，FAIL）。
- **Zin@10 Hz（DM 激励，在放大器输入端，不含电极）：** P 端 10.7 GΩ，N 端 0.120 GΩ；去掉 LP 时 N 端为 0.092 GΩ。N 端较低是因为 Cc 接到反馈驱动的节点 n：DM 激励下 n 跟随 p 的正半边，CCN 两端承受约 2 倍电压。从 VSP 源端看（含电极）为 7.7 GΩ。
- **噪声 0.1–250 Hz（以 out 为输出，差分输入参考）：**
  - 逐点 de-embed 型：理想 Rfb 16.63 µV，pseudo-R 16.60 µV。
  - 应用型（out_rms / \|H(100 Hz)\|）：68 µV，被 LP 负载导致的低增益放大了。
  - NoiseSummary：M1/M4/M3/M2 的 flicker 各约 23–27%，Rfb 0.46%，电极 RE 0.08%。
  - **SPEC FAIL**（目标 <3 µV）。
- **工作点：** DC 正常：o = n = 0.9023 V，cm = body = 0.9011 V（DRL 关时人体经 1e15 Ω 定 DC）。主 OTA 电流 283 nA，DRL OTA 283 nA（DRL 关时也在耗电）。主 OTA M2 余量仍然只有 **0.047 V**。
