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

## B — DRL：关闭 / 理想（诊断用）/ 真实 DRL OTA

**条件：** 测试台 `ece203_r4_ecg_tb`，理想 Rfb，LP 采用 Stage A 选定的 31.8 MΩ / 20 pF。CM 感测为 2 × 10 GΩ，R0 1 MΩ，右腿电极与其他电极相同。
- **理想 DRL：** EDRL 为 VCVS，adrl = 100，以 VREF 为参考反相驱动。这是**诊断用的理想块**。
- **真实 DRL：** `ece203_r4_drl_ota` 为 B 5T（NMOS 输入 10u/8u），**开环反相接法**：INP 接 VREF，INN 接 cm，OUT 经 R0 接右腿电极。ib 50 nA 为理想源，VREF 为理想源。
- **CMRR 和人体干扰分开测：**
  - **CMRR@60 Hz：** 在电极和人体之间加 1 V 共模（vcmin），Acm = \|V(out)\| / 1 V；Adm = \|V(out)\| / \|V(ep) − V(en)\|，两者在**同一电气条件**下测。主要结果用 Cc 1% 失配（dcc = 0.01），匹配情况作参考。
  - **人体干扰：** 0.1 µA@60 Hz 注入人体（AC），读人体、电极共模和输出的幅度。另外用 isin 跑 50 ms 瞬态，读最后一个周期的削顶情况。

| DRL | CMRR@60 Hz（Cc 1% / 匹配） | 人体 \|Vbody\| @0.1 µA | 电极 CM | \|out\| 60 Hz | 瞬态 o 范围 | DRL 环路 UGF / PM | 状态 |
|---|---|---|---|---|---|---|---|
| OFF | **53.9 / 54.4 dB** | 1.32 V | 1.32 V | 0.227 V | **1.017–1.80 V（打到 VDD 削顶）** | — | SPEC FAIL，物理饱和 |
| 理想（诊断用，adrl 100） | 87.5 / 88.0 dB | 2.07 mV | 2.07 mV | 0.36 mV | 0.9020–0.9027 V | 1.52 kHz / **29.5°** | 诊断：CMRR 过，PM 偏低 |
| **真实 DRL OTA** | **82.8 / 83.3 dB** | 38.7 mV | 38.7 mV | 6.6 mV | 0.897–0.914 V（不削顶） | 696 Hz / **24.3°** | SIM PASS / **SPEC FAIL**（CMRR −2.2 dB，PM 低） |

- 真实 DRL OTA 的瞬态输出范围为 0.836–0.963 V，DC 为 0.9015 V，最小 margin 0.291 V（M2）。电流 283 nA。
- **匹配情况的 CMRR 也只有约 54 dB（DRL 关）。** 单级 C OTA 本身的共模抑制有限，输入共模会经两边 Cc 直接到 OTA 输入。所以 Cc 1% 失配几乎不改变结果；DRL 主要是在降低共模本身。
- **Zin@10 Hz（DM，放大器输入端）：** DRL 打开后 P 端 9.36 GΩ，N 端 0.170 GΩ，都 >100 MΩ。CM 感测和 DRL 闭环没有把 Zin 拉低到 100 MΩ 以下。
- **真实 DRL 环路（stb，probe 在右腿电极前）：** 低频环路增益 280.6，60 Hz 处 28.2，UGF 696 Hz，PM 24.3°。主极点约 7 Hz，来自 DRL OTA 约 100 MΩ 的输出阻抗；第二极点约 200–300 Hz，判断来自 CM 感测的 5 GΩ 和 DRL OTA 输入电容。理想 DRL 在 60 Hz 处环路增益 47.9，PM 29.5°。
- **DRL 关时人体电压摆幅 2.6 V pp**，主 OTA 输出直接削顶，这时的 AC 线性增益不代表真实情况。
