# ECE203 Round 5N-F：最终噪声收敛（M3/M4 L）实验结果

日期 2026-11-16 · 脚本 `ece203_r5nf.il`（任务：ece203_r5nf_a / b / ade；ece203_r5nf_a3 已准备但未运行）· 任务书 [ECE203_round5nf_final_noise_task.md](ECE203_round5nf_final_noise_task.md)
· 数据 [ece203_data/round5nf/](ece203_data/round5nf/)（`r5nf_final_noise.csv`、`r5nf_noise_check.csv`、`r5nf_final_noise.png`、原始数据 `raw/`）
· 全部结果为真实 PDK 整机的 Spectre 仿真，tt、27 °C；没有 chopper、PSS、MC、PVT。

## **NOMINAL PASS — PVT/MC PENDING**

推荐设计 **F2**：M1/M2 50/40 µm，M3/M4 8/42 µm。噪声 2.880 µV（逐点 de-embed）/ 2.930 µV（输出 RMS / |H100|），两种算法都 < 2.95 µV；其余全部标称规格 PASS；M4 饱和余量 75.6 mV（> 50 mV）。

- 原理图：`Project/ece203_r5nf_tb_f2`（OTA1 = `Project/ece203_r5nf_ota_f2`）
- ADE state：`r5nf_final_f2`
- 只完成了标称（tt、27 °C）验收；PVT 和 Monte Carlo 尚未运行。

## 设置

- **基准：** R5N-N N2（`ece203_r5nn_tb_n2`）：M1/M2 50/40 µm，M3/M4 8/36 µm，MC 10/4，MT 32/4（尾电流 ×4），MREF 2/4，pseudo-R prw 4 µm，CS OTA2，真实 DRL 与偏置，LP 31.8 MΩ / 20 pF。
- **唯一改动：** M3/M4 的 L：F1 = 40 µm，F2 = 42 µm（W 8 µm）。网表确认 `M3/M4 pfet l=40u/42u w=8u`，`M1/M2 nfet l=40u w=50u`，OTA2 器件不变，prw=4e-06。
- **F3（8/44 µm）没有运行：** 任务书只在 F1/F2 都未达标时才允许 F3，而 F1、F2 都已达标。
- **N2 数据：** 直接引用 R5N-N 的结果，没有重跑。
- **新建 cell：** `Project/ece203_r5nf_ota_{f1,f2}`、`ece203_r5nf_tb_{f1,f2}`。旧的 R5N / R5N-L / R5N-N cell、ADE state 和数据都没有改动。
- **功耗：** VDDD 是串在 vddd→vdd 之间的 0 V 电流表，I(VDD) 已包含 DRL 支路；总功耗 = I(VDD) × 1.8 V，没有重复加 I(VDDD)。

## Stage A：N2 / F1 / F2 对照（0.1–250 Hz，折算到 ECG 输入）

| | **N2（8/36）** | **F1（8/40）** | **F2（8/42）** |
|---|---|---|---|
| 噪声，逐点 de-embed | 2.994 µV | 2.913 µV | **2.880 µV** |
| 噪声，输出 RMS / \|H100\| | 3.045 µV | 2.964 µV | **2.930 µV** |
| 两种都 < 3 µV / < 2.95 µV | 否 / 否 | 是 / 否 | **是 / 是** |
| 输入对 1/f | 1.97（43.5%） | 1.97（45.9%） | 1.97（46.9%） |
| 镜像 1/f | 1.97（43.6%） | 1.84（40.2%） | 1.79（38.6%） |
| 输入对 / 镜像热噪声 | 0.78 / 0.49 | 0.78 / 0.48 | 0.78 / 0.48 |
| 输入 PSD @ 0.1 / 1 / 10 / 100 / 250 Hz（nV/√Hz） | 4064 / 1068 / 305 / 107 / 81 | 3880 / 1031 / 298 / 105 / 81 | 3802 / 1015 / 296 / 105 / 81 |
| \|H100\|（dB） | 91.48（39.23） | 91.41（39.22） | 91.36（39.22） |
| fL / fH | 0.1006 / 248.2 Hz | 0.1006 / 247.8 Hz | 0.1005 / 247.5 Hz |
| Zin @10 Hz，P / N 端 | 3859 / 162 MΩ | 3857 / 162 MΩ | 3856 / 163 MΩ |
| M1 VDS / 余量 | 0.603 / 0.503 V | 0.584 / 0.484 | 0.574 / 0.474 |
| M2 VDS / 余量 | 0.186 / 0.0863 V | 0.186 / 0.0863 | 0.186 / 0.0863 |
| M3 VSG / gm/Id / 余量 | 0.742 V / 5.62 / 0.474 V | 0.762 / 5.32 / 0.479 | 0.771 / 5.19 / 0.482 |
| **M4 VSD / \|VDSAT\| / 余量** | 0.365 / 0.268 / **96.6 mV** | 0.365 / 0.283 / **82.5 mV** | 0.365 / 0.290 / **75.6 mV** |
| MC / MT / MREF 余量 | 0.694 / 0.355 / 0.212 V | 同左 | 同左 |
| OTA1 最紧器件 | M2 86.3 mV | M4 82.5 mV | M4 75.6 mV |
| OTA2 最小余量 | 0.800 V | 0.800 | 0.800 |
| I(VDD)（其中 I(VDDD)）→ 总功耗 | 1764 nA（249）→ 3.175 µW | 同左 | 同左 |
| DC 工作点 | 有效 | 有效 | 有效 |

（余量 = |VDS| − max(|VDSAT|, 0.1 V)。M4 的 VSD 由输出直流电平固定在 0.365 V，L 增大只抬高 |VDSAT|，所以余量随 L 单调下降。）

## 噪声算法与原始数据验证

三种独立方式得到的数一致（`r5nf_noise_check.csv`）：

| | SKILL 逐点 de-embed | Spectre "Total Input Referred Noise" | 由 `*_noise.csv` 重新积分 | SKILL 输出 RMS / \|H100\| | Spectre "Total Summarized Noise" / \|H100\| | 由 `*_noise.csv` 输出 PSD 重新积分 / \|H100\| |
|---|---|---|---|---|---|---|
| N2 | 2.9940 | 2.9940 | 2.9907 | 3.0455 | 3.0455 | 3.0421 |
| F1 | 2.9128 | 2.9128 | 2.9095 | 2.9635 | 2.9635 | 2.9602 |
| F2 | **2.8798** | 2.8798 | 2.8766 | **2.9304** | 2.9304 | 2.9271 |

单位 µVrms。|H100| 由 `*_ac.csv` 插值得到（F2 为 91.363）。重新积分用 161 点 CSV 的对数插值，比 Spectre 自身积分低约 0.1%。

## Stage B：F2 完整验收

| 指标 | 目标 | F2 结果 | 状态 |
|---|---|---|---|
| 噪声，逐点 de-embed | < 3 µVrms | 2.880 µV | PASS |
| 噪声，输出 RMS / \|H100\| | < 3 µVrms | 2.930 µV | PASS |
| 增益 | 38–42 dB | 91.36（39.22 dB）；DRL 验收台 Adm60 95.77 | PASS |
| fL / fH | 0.09–0.11 Hz / 225–275 Hz | 0.1005 Hz / 247.5 Hz | PASS |
| CMRR @60 Hz（Cc 失配 1%） | > 85 dB | 89.85 dB（DRL 开）；DRL 关 59.37 dB | PASS |
| Zin @10 Hz（最差端） | > 100 MΩ | 163 MΩ（N 端，DRL 开）；P 端 3.85 GΩ | PASS |
| 总功耗 | < 4 µW | 1764 nA → 3.175 µW（VDDD 249 nA 已含在内） | PASS |
| 主环路 PM | ≥ 55° | 73.0°（UGF 29.0 kHz，LG10 396，LG100 134） | PASS |
| DRL 环路 | 稳定 | PM 90.1°，UGF 2.0 kHz | PASS |
| 共模干扰瞬态（0.1 µA，60 Hz，DRL 开） | 不削顶 | OTA 输出 0.8924–0.9026 V，DRL 0.837–0.961 V，body 78.5 mV pp | PASS |
| M1/M2/M3/M4/MC 工作区 | 有效；M4 余量 ≥ 50 mV | 全部饱和；最紧 M4 75.6 mV、M2 86.3 mV | PASS |
| 设计电容 | < 1 nF | 143.5 pF（电容参数与 N2 相同；OTA1 栅电容 M1/M2 各 7.5 pF 不计入） | PASS |

- DRL 关闭（只作对照）时输出削到电源轨（0.50–1.80 V），N 端 Zin 90 MΩ，与之前各轮相同。
- 相比 N2，主环路 10 Hz 环路增益从 589 降到 396（M3 二极管负载的 gm 变小），PM 从 73.9° 降到 73.0°。

## 剩余余量（F2，标称）

| 项目 | 余量 |
|---|---|
| 噪声 | 逐点 0.120 µV（4.0%），输出 RMS 法 0.070 µV（2.3%） |
| M4 / M2 饱和余量 | 75.6 mV / 86.3 mV |
| CMRR | 4.85 dB |
| Zin | 63 MΩ |
| 功耗 | 0.825 µW |
| 主环路 PM | 18° |

噪声余量只有 2–4%，PVT/MC 下是否保持没有验证。

## 原始数据

- 仓库 `docs/ece203_data/round5nf/raw/`：
  - Stage A：`r5nf_cases.csv`（全部列）、`r5nf_noise_split.csv`、`F{1,2}_ac.csv`、`F{1,2}_noise.csv`、`F{1,2}_noisesummary_0p1_250.txt`、`F{1,2}_ns_b00–14.txt`、`F{1,2}_dcop.csv`、`F{1,2}_ota1_dcop.csv`、`F{1,2}_x2_dcop.csv`。
  - Stage B：`r5nf_signoff_mainstb.csv`、`r5nf_signoff_drl.csv`、`B_F2_mainstb_stb.csv`、`B_F2_real_dcc1_stb.csv`、`B_F2_{off,real}_dcc1_dm_ac.csv`、`B_F2_{off,real}_dcc1_{dm,cm,int}_dcop.csv`、`B_F2_{off,real}_dcc1_tran_tran.csv`。
- 完整原始包（含网表、日志）：实验记录本 `_raw\2026-11-16_ece203_round5nf_final_noise\r5nf_raw.tgz`；服务器 `~/AutoCircuit_results/ece203_r5nf/`。
- 表、验证和图：`docs/ece203_data/round5nf/r5nf_tables.py`（从仓库根目录运行；N2 列引用 `docs/ece203_data/round5nn/raw/`）。
- 仿真次数：Stage A 2 个配置（DC + AC + noise）；Stage B 1 次主环路 stb + 2 个 DRL 验收（off / real，各含 AC、stb、瞬态）。
