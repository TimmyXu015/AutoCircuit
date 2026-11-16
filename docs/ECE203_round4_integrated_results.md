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

## C — 少量调整、真实偏置、最终指标

**本轮用掉的调整次数（都在任务书限额内）：**
- 输出 LP 的 RC 替代：1 次，见 A3。
- VCAS：3 个点，含基线，见 C1。
- DRL 参数/补偿：1 次，见 C2。
- 系统配置：1 个基线 + 2 个候选，见 `r4_system_cases.csv`。

**C1 VCAS（`stageC/r4_C1_vcas.csv`；理想 Rfb、LP 31.8 MΩ / 20 pF、DRL 关）：**

| VCAS | \|H\| @100 Hz | M2 Vds / 余量 | MC Vds / 余量 | 最小余量 |
|---|---|---|---|---|
| 1.05 V（基线） | 71.71 | 0.147 / 0.047 V | 0.245 / 0.144 V | 0.047 V |
| **1.10 V（选定）** | 71.71 | 0.190 / 0.090 V | 0.202 / 0.102 V | **0.090 V** |
| 1.15 V | 71.70 | 0.233 / 0.133 V | 0.159 / 0.059 V | 0.059 V |

改 VCAS 不影响增益（增益主要受 LP 负载限制），但 M2 余量几乎翻倍。另一个效果：在真实 DRL 下，CMRR 从 82.8 dB 升到 90.0 dB，原因是主 OTA 自身的共模抑制改善了。

**C2：唯一一次 DRL 改动（`stageC/r4_C2_drlcomp.csv`）。** 两只 10 GΩ CM 感测电阻各并联 1 pF（Ccm）。依据：stb 显示第二极点约 200–300 Hz，判断来自 5 GΩ × DRL OTA 输入电容；Ccm 引入约 16 Hz 的零点。

| | 改动前 | 改动后 |
|---|---|---|
| DRL PM / UGF | 24.3° / 696 Hz | **90.3° / 1.98 kHz** |
| 60 Hz 环路增益 | 28.2 | 32.4 |
| CMRR@60 Hz（Cc 1%） | 90.0 dB | 91.3 dB |
| Zin@10 Hz P / N | 9.36 GΩ / 170 MΩ | 7.06 GΩ / 168 MΩ |
| 人体干扰下 o 的范围 | 0.900–0.906 V | 0.900–0.907 V |

**C3：真实偏置的最终系统（`Project/ece203_r4_ecg_rbpr_tb`，`stageC/r4_C3_final_*.csv`）。**
- **源：** 只有 VDD 1.8 V 和**一个理想 100 nA 参考**。
- **偏置：** 100 nA 参考接 PMOS 二极管 4u/4u，再用 2u/4u 镜像出约 53 nA，分别送给主 OTA 和 DRL OTA 的 IBIAS。
- **VREF：** VDD 用 90 MΩ / 90 MΩ 分压，加 20 pF 去耦，实测 0.900 V。
- **VCAS：** 70 MΩ / 110 MΩ 分压，实测 1.100 V。
- 分压电阻是理想电阻；在片上要实现约 100 MΩ 的电阻，面积会很大。
- **其余配置：** pseudo-R（Round 3B，W3u/L2u）、真实 DRL OTA 加 Ccm 1 pF、LP 31.8 MΩ / 20 pF。
- **对照：** 同配置的理想 Rfb 版本，见 `C3_rb_dm`。
- **结果：**
  - 增益 72.2（37.17 dB），fL 0.073 Hz（理想 Rfb 版为 0.0946 Hz），fH 121 Hz。
  - CMRR 91.35 dB（Cc 1%）/ 92.51 dB（匹配）。DRL PM 90.1°。人体电压 37.4 mV。
  - 噪声（逐点 de-embed）16.57 µV，约 99% 来自主 OTA 的 flicker 噪声；pseudo-R、电极、分压电阻的贡献都 <0.05%。
  - 总电流 724.8 nA，即 **1.30 µW**。
  - 主 OTA M2 余量 0.090 V，DRL OTA 0.293 V。

**C4：失配 Monte Carlo，N = 12（`r4_mc12_table.csv`）。**
- **条件：** 冻结的最终配置。PDK 的 statistics/mismatch 块，OCEAN `monteCarlo ?analysisVariation 'mismatch`，DM 和 CM 两次运行都用 seed 12345。
- **取值方式：** 本机的 OCEAN 没有 `monteOutputFile`，`iterVsValue` 返回 nil，所以改为直接打开 psf 中的 `ac` 族数据，sweep 为 iteration。
- **结果（12 个样本全部保留）：**

| 指标 | 均值 ± σ | 范围 |
|---|---|---|
| 增益 @100 Hz | 37.15 ± 0.07 dB | 37.03–37.26 dB |
| fL | 0.0734 ± 0.0032 Hz | 0.0673–0.0788 Hz |
| fH | 120.8 ± 2.3 Hz | 116.7–124.5 Hz |
| CMRR@60 Hz | 92.5 ± 0.35 dB | 91.7–93.0 dB |

**电容台账：**
- 设计电容：2×Cc（100 pF）+ 2×Cfb（1 pF）+ CLP（20 pF）+ 2×Ccm（2 pF）+ VREF 去耦（20 pF）= **143 pF < 1 nF**。
- 未计入预算的外部元件：3×50 nF 电极，200 pF 人体。

**NEF：** 公式 NEF = Vni·√(2·Itot / (π·UT·4kT·BW))。取 Vni = 16.57 µV，BW = fH − fL = 121 Hz，T = 300 K：
- Itot = 724.8 nA（整个系统）时为 **49.4**。
- 只算主 OTA 的 283 nA 时为 30.8。

### 最终指标表（详见 `r4_spec_matrix.csv`）

| 指标 | 目标 | 最终系统（C3） | 判断 |
|---|---|---|---|
| 增益 @100 Hz | 40 ± 2 dB | 37.17 dB | **SPEC FAIL** |
| fL | 0.1 Hz ± 10% | 0.073 Hz（理想 Rfb 0.095） | **SPEC FAIL**（pseudo-R） |
| fH | 250 Hz ± 10% | 121 Hz | **SPEC FAIL** |
| 输入噪声 0.1–250 Hz | <3 µVrms | 16.6 µVrms | **SPEC FAIL** |
| CMRR@60 Hz（DRL 开 / 关） | >85 dB | 91.4 / 53.9 dB | **PASS**（开） |
| 0.1 µA 人体干扰 | 不削顶 | 开：人体 37 mV，不削顶；关：削顶 | PASS（开） |
| Zin@10 Hz（放大器输入端） | >100 MΩ | P 7.06 GΩ / N 168 MΩ | PASS |
| 总功耗 | <4 µW | 1.30 µW | PASS |
| 设计电容 | <1 nF | 143 pF | PASS |
| 源数量 | VDD + 一个 100 nA | 满足（C3）；A/B 阶段用的是理想 VREF/VCAS/IB | PASS（C3） |
| DRL PM | 报告 | 90.1° | SIM PASS |
| 失配 MC | N > 10 | N = 12 | 已完成 |

以上全部为 Spectre 仿真结果（tt，27 °C），没有 PVT。

## D — Chopper 加分项：真实 C OTA + 理想开关，单一频率 4 kHz（`stageD/r4_D_chopper.csv`）

- **测试台：** `Project/ece203_r4_chop_c_tb`。沿用 Round 3D 的理想 chopper 结构（relay 开关、10 ns 不交叠死区、理想 EINV 反相器作非物理辅助、反馈从解调后接回），S2 网络用理想 Rfb。OTA 是**真实 `ece203_r4_ota`**（C 版，VCAS 1.10 V，理想偏置）。这里只测前向单级，**不含电极、DRL 和 LP**。Round 3E 的 1 MHz 理想实验没有重复。
- **为什么选 4 kHz（只选这一个，不扫频）：**
  - 是 250 Hz 带宽上限的 16 倍。
  - 高于 C 实测噪声谱的 1/f 拐点，约 2.9 kHz（来自 Round 3E 的拟合）。
  - 半周期 125 µs，约等于 C 闭环时间常数（fH 8.8 kHz，τ ≈ 18 µs）的 7 倍。
- **信号检查（1 mV 阶跃，20 ms 瞬态）：**
  - 不斩波：阶跃增益 93.4。
  - 4 kHz 斩波：阶跃增益 97.5，比值 1.044，在 10% 以内，所以接着做了噪声测试。
  - 但斩波后有两处异常：
    - 瞬态 o 的平均值比 VREF 低 224 mV。从 PSS 周期稳态看，这主要是 τ = 1.6 s 的启动过程没走完，稳态平均值只低 25 mV。
    - **纹波很大：** 稳态下 0.41 V pp，o 在 0.69–1.11 V 之间。OTA 输入差 4 mV pp，说明每次翻相后都在重新建立。
  - 没有打到电源轨，但纹波要靠后面的 250 Hz LP 滤掉（这一点本节没有测）。
- **PSS（fund 4 kHz，harms 30）+ PAC + PNoise（maxsideband 30，真实晶体管噪声），一次就成功，没有修正：**

| 情况 | PAC \|H\| @100 Hz | 输出 rms 0.1–250 Hz | 应用型输入噪声 | 逐点 de-embed 型 | 输入噪声谱 @1 Hz / 100 Hz |
|---|---|---|---|---|---|
| 不斩波（同一测试台） | 94.22 | 1.527 mV | 16.2 µV | 16.7 µV | 6.15 µV/√Hz / 545 nV/√Hz |
| **4 kHz 斩波** | 93.09 | 0.520 mV | **5.58 µV** | **10.6 µV** | 3.17 µV/√Hz / 162 nV/√Hz |

- **解读：**
  - RMS 改善：应用型 2.9 倍，逐点型 1.6 倍。斩波后仍**高于 3 µV**，所以 **SPEC FAIL**。
  - 两种定义差别很大。原因是斩波后低频（<1 Hz）残余噪声很高：1 Hz 处 3.17 µV/√Hz，Round 3E 理想模型中只有 0.36 µV/√Hz。
  - 推测这部分残余与 OTA 每半周期的建立误差、0.41 V 的大纹波，以及未被斩波的支路有关，**没有进一步验证**（不在本轮限额内）。
  - 证据等级：Spectre 真实晶体管 PSS + PNoise。noisetype 用的是 Spectre 默认值。理想开关和理想反相器属于非物理元件。
- **状态：** BONUS 已运行，噪声改善有限且有条件。真实开关、时钟、电荷注入和纹波抑制都没有做。

## Cadence 与复现

- **新 cell（library Project，旧 cell 没有改动）：**
  - OTA：`ece203_r4_ota`、`ece203_r4_drl_ota`。
  - 测试台：`ece203_r4_ecg_tb`（理想偏置，理想 Rfb）、`ece203_r4_ecg_pr_tb`（理想偏置，pseudo-R）、`ece203_r4_ecg_rb_tb`（真实偏置，理想 Rfb）、`ece203_r4_ecg_rbpr_tb`（**最终系统**）、`ece203_r4_chop_c_tb`。
- **ADE L state（都已设 gmin = iabstol = 1e-18、reltol 1e-6）：**
  - `ece203_r4_ecg_rbpr_tb`：`r4_final`（dc + ac + noise + DRL stb + 50 ms 干扰 tran）。
  - `ece203_r4_ecg_rb_tb`：`r4_final_idealRfb`。
  - `ece203_r4_ecg_tb`：`r4_A1_baseline_drloff` 和 `r4_C2_idealbias_realDRL`。
  - ADE 的 tran 无法通过 API 设置 maxstep，手动运行时请设为 20 µs。
- **job（`~/AutoCircuit/run.sh <job>`）：** `ece203_r4_a`、`ece203_r4_b`、`ece203_r4_c1`、`ece203_r4_c2`、`ece203_r4_c3`、`ece203_r4_c4`（MC）、`ece203_r4_c4read`（读取 MC 数据，不重新仿真）、`ece203_r4_d`、`ece203_r4_dpss`、`ece203_r4_ade`（GUI 方式）。
- **数据：** `docs/ece203_data/round4/`，含 `r4_spec_matrix.csv`、`r4_system_cases.csv`、`r4_drl_60hz.csv`、`r4_mc12_table.csv`、`r4_summary.png`，以及 `stageA` 到 `stageD` 各阶段的原始数据。

## 最终三行总结

1. **已经 PASS 的（真实晶体管 OTA 和 DRL，加真实偏置，仅用 VDD + 一个 100 nA 参考）：**
   - CMRR@60 Hz 为 91.4 dB（Cc 1% 失配；MC12 范围 91.7–93.0 dB）。
   - DRL 开启时 0.1 µA 人体干扰不削顶，DRL PM 90°。
   - Zin@10 Hz 大于 168 MΩ，功耗 1.30 µW，设计电容 143 pF。
2. **最严重的剩余问题：**
   - 单级 OTA 的闭环输出阻抗太高，驱动不了无源 250 Hz LP。增益只有 37.2 dB，fH 只有 121 Hz。
   - 主 OTA 的 flicker 噪声 16.6 µV，远高于 3 µV；4 kHz 斩波后为 5.6 / 10.6 µV，仍不达标。
   - pseudo-R 下 fL 为 0.073 Hz，偏低。
3. **下一个最小的单点实验：** 只解决 LP 负载这一个问题，在 OTA 和 LP 之间比较两种做法：（a）把 LP 放进反馈网络，在 Cfb 上并 Rfb 形成主极点；（b）用低 Zout 的输出级或 buffer。两者都需要你们 + GPT 批准。之后再单独研究噪声，包括 4 kHz 斩波后低频残余噪声的来源。
