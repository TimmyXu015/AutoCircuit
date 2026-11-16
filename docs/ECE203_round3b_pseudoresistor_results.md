# ECE203 Round 3B 结果：课堂 MOS–bipolar pseudo-resistor 小实验

日期 2026-11-16 · 任务书 [ECE203_round3b_pseudoresistor_microtest.md](ECE203_round3b_pseudoresistor_microtest.md) · 数据 [ece203_data/pseudoresistor/](ece203_data/pseudoresistor/)（`pr_iv.csv`、`pr_s2_compare.csv`、`pr_summary.png`）

## 器件与接法（依据课件，不是猜的）
- **课件依据：** Lec8–10 第 30 页（PDF 第 15 页）是一只 PMOS，栅极、n 阱（bulk）和 V0 侧的 p+ 接在一起，另一个 p+ 是 Vf 端。第 32 页建议用厚氧器件。
- **PDK 器件：** cmrf7sf 里有 `pfet33x`（3.3 V 厚氧，4 端 D G S B）。CDF 默认 W 500n、L 400n。
- **新 cell `Project/ece203_ss_pr_cell`：** 两个端口 A（Vf，普通 p+）和 B（V0，栅极 + n 阱 + p+）。网表为 `MP (B B A B) pfet33 l=prl w=prw`，W/L 是设计变量。
- **没有建模的寄生：** n 阱到衬底的二极管不在这只 4 端 MOS 模型里，阱到衬底的泄漏和电容都没有被仿真。

## Stage A：独立 I–V（B 固定 0.9 V，A = 0.9 V + vd，每点 DC op + 1 mHz AC）
| 尺寸 / 仿真精度 | r(−5 mV) | **r(0)** | r(+5 mV) | r(±50 mV) | 判断 |
|---|---|---|---|---|---|
| W1u L2u，Spectre 默认 | 0.32 TΩ | 0.035 TΩ | 0.035 TΩ | 0.33 / 0.034 TΩ | **不可信**：g ≈ 3e-12 S 或 2.9e-11 S，与 gmin 同量级；器件 id 只占总电流约 1% |
| W1u L2u，gmin = iabstol = 1e-18，reltol 1e-6 | 11.5 TΩ | **9.69 TΩ** | 7.44 TΩ | 205 / 1.31 TΩ | 可信：I_A = I_B = 器件 id（KCL 闭合） |
| **W3u L2u（唯一一次调整）**，同上收紧精度 | 4.84 TΩ | **4.09 TΩ** | 3.13 TΩ | 86 / 0.54 TΩ | 可信，比目标 3.18 TΩ 高 29% |

- r 是增量电阻 1/g_ac，取 1 mHz AC 下 Re(I_A) 的倒数。±5 mV 时电流只有约 0.5–1.4 fA。
- 调整依据：亚阈值电流大致和 W/L 成正比，W×3 后 r(0) 实测降了 2.37 倍（Vth 也随 W 变化，−0.693 → −0.704 V）。
- 正反方向不对称：A 低于 B 时电阻升高，A 高于 B 时电阻降低。在 ±50 mV 内没有看到二极管式的急剧导通。
- **数值精度结论：** 在 Spectre 默认 gmin（1e-12 S）下，这个器件的 fA 级电流完全被淹没，测不出 TΩ。必须把 gmin 和 iabstol 降到 1e-18。实测把这两项降到 1e-18 后（reltol 1e-6），I_A = I_B = 器件 id，KCL 闭合。

## Stage B：S2 单级对照（W3u pseudo-R，5T 的 L = 8 µm，Cc 50 p、Cfb 0.5 p、CL 0；仅 DC op + AC）
新 cell `Project/ece203_ss_pr_tb` 用两只 pseudo-R 替换理想 Rfb：
- `XPN (n o)`：A 接 OTA 的 INN，B 接 OUT。
- `XPP (p vref)`：A 接 OTA 的 INP，B 接 VREF。
- 阱/栅端（B）放在低阻节点上。

理想参照：用 `ece203_ss_lscan_tb`（L = 8u，Rfb 3.1831 TΩ），在同一个 job、同样的收紧精度下运行。

| 情况 | \|Hdm\| 10 Hz | 100 Hz | dB | 0.1 Hz | fL | fH | DC o / n / p (V) | pseudo-R 端电压 / 电流 |
|---|---|---|---|---|---|---|---|---|
| 理想 Rfb，收紧精度 | 73.13 | 73.13 | 37.28 | 58.96 | **0.0738 Hz** | 11.39 kHz | 0.90149 / 0.90149 / 0.9 | — |
| **pseudo-R，收紧精度** | 72.70 | 72.70 | 37.23 | 63.23 | **0.0569 Hz** | 11.37 kHz | 0.90149 / 0.90149 / 0.9 | 0 V / 0 A（两只） |
| pseudo-R，Spectre 默认精度（仅作数值证据） | 34.01 | 71.38 | 37.07 | 0.38 | 18.9 Hz | 11.41 kHz | 同上 | 20 nV / −5e-21 A |

- 收紧精度下没有求解失败，DC 偏置正常。两只 pseudo-R 两端都是 0 V，因为没有直流电流流过。
- 带内增益比理想低 0.6%（72.70 对 73.13）。fL 和理想的比值是 0.77，与 3.18/4.09 = 0.78 一致。
- **用默认精度仿真会给出完全错误的高通（fL 18.9 Hz）。** 在 ADE 里手动运行时，必须使用收紧选项（state 里已经设好）。
- 理想 Rfb 下 fL 也只有 0.074 Hz，不是 0.1 Hz。这是有限 A0（280）造成的，见 Round 3A。

## 结论
在 ±50 mV 范围内，pfet33x 单管 MOS–bipolar pseudo-R 可以在收紧仿真精度下给出可信的 TΩ 级电阻：W3u/L2u 时零偏置为 4.09 TΩ，比目标 3.18 TΩ 高 29%。用它替换 S2 里的理想 Rfb 后，带内增益基本不变（72.7），fL 为 0.057 Hz（目标 0.1 Hz ± 10%）。没有 PVT/失配，也没有阱到衬底泄漏的建模，不能说已经满足最终指标。

## Cadence 里新建的东西（旧 cell 没有改动）
- cell：`ece203_ss_pr_cell`、`ece203_ss_pr_iv_tb`、`ece203_ss_pr_tb`。
- ADE L state `pr_w3u`：在两个 tb 中各一份，内容为 dc op + ac，已写入 gmin = iabstol = 1e-18、reltol = 1e-6（`asiSetSimOptionVal` 回读确认）。
- job：`ece203_ss_pr_a`、`ece203_ss_pr_a2`、`ece203_ss_pr_b`、`ece203_ss_pr_ade`。

## 等待用户 + GPT 决定
pseudo-R 的尺寸是否要往 3.18 TΩ 微调（或改 L、改成串联），以及 OTA 增益问题（L = 8u 时为 37.3 dB）接下来怎么处理。本轮已经停止。
