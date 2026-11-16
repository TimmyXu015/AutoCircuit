# ECE203 Round 5 结果：输出级 / 双级 OTA × 分级噪声 × Chopper 解调位置

日期 2026-11-16 · 任务书 [ECE203_round5_ota_stage_noise_chopper_placement_bigrun.md](ECE203_round5_ota_stage_noise_chopper_placement_bigrun.md) · 数据 [ece203_data/round5/](ece203_data/round5/) · 脚本 `ece203_r5.il`

证据等级标记：**[Spectre]** 为实际 Spectre 运行结果；**[Approx]** 为由 Spectre 数据做的近似计算；**[Ideal-diag]** 为理想诊断块；**[BLOCKED]** / **[NOT RUN]** 按字面含义。全部为 tt，27 °C。

## 隔离 S2 测试台（A–D 共用一套接线，`Project/ece203_r5_s2_<stage>_<slot>`）

```
VINP ─Cc─ p ─(Cfb‖Rfb)─ VREF                 输入 commutator（ck1：p→ia, n→ib_；ck2：交换）
VINN ─Cc─ n ─(Cfb‖Rfb)─ fb ◄─────────────┐
p,n ─[S1/S2]─ ia, ib_ ─► OTA1 (XA = ece203_r4_ota，冻结 C OTA，VCAS 1.10) ─► oa1
oa1 ─[槽 1：直通 或 D1 解调：oa1 / 2·vr1−oa1]─► d1 ─► OTA2（none / 理想 ×1 / CD / CS + CM2）─► oa2
oa2 ─[槽 2：直通 或 D2 解调：oa2 / 2·VREF−oa2]─► d2 ─IPRB─► fb ──RLP 31.8 MΩ──► out ──CLP 20 pF──┤
                                                                  （反馈取样点 fb 在 OTA2 / 解调之后、LP 之前）
```

- **CS 的极性：** CS 级是反相的，所以 CS 方案中 OTA1 的 INP 接 ib_、INN 接 ia，以保证整体仍是负反馈。已经用 stb 核实：低频环路增益相位 +135°（1 mHz 处在高通区，接近 +180° 的负反馈约定），带内 H 的相位与非反相方案一致（100 Hz 处约 −22°）。
- **偏置：** OTA2 的偏置管栅极接 OTA1 的 IBIAS 节点，镜像出约 53.6 nA。
- **理想源（诊断用，与 Round 4 A/B 相同）：** VREF、VCAS、IB 50 nA、VR1；VR1 只给槽 1 的反相器用。
- **独立电表：** VDD2 只给 OTA2 供电，用来单独测 OTA2 电流。
- **不斩波时：** chen = 0，时钟冻结在第 1 相，两个槽都是直通，所以静态和斩波用的是完全相同的电路。
- **仿真精度：** gmin = iabstol = 1e-18，reltol 1e-6。

## A — 理想单位 buffer 的负载对照 [Spectre + Ideal-diag]（`stageA/r5_stageA.csv`）

| 情况 | H100（out） | dB | fL | fH | fb 处 H100 | 主环路 UGF / PM | 闭环 Zout@fb 10 / 100 / 250 Hz |
|---|---|---|---|---|---|---|---|
| 不接 LP（在 fb 测） | — | — | — | — | 94.22（fH 8.82 kHz） | 8.30 kHz / 93.4° | 35.4 / **29.1** / 21.3 MΩ |
| 接 LP，无 buffer（相当于 R4 前向链） | 71.75 | 37.12 | 0.095 Hz | **117 Hz** | 77.27 | 315 Hz / 142°（LP 负载改变了环路） | 同上 |
| 接 LP + **理想 ×1 buffer** | **87.49** | **38.84** | 0.095 Hz | **249.8 Hz** | 94.22 | 311 kHz / 89.4° | **0.058 Ω** |

- **结论：** Round 4 的增益和 fH 问题**完全是输出阻抗问题**。理想 buffer 把闭环 Zout 从 29 MΩ 降到约 0 Ω 后，fH 正好由 LP 自身决定（250 Hz），100 Hz 增益 = 94.22 × |1/(1 + j·100/250)| = 87.5，与实测吻合。理想 buffer 本身不计入合规，只用于确定瓶颈。
- **Zout 的区分：** OTA1 开环输出阻抗很高（约 1/(gds4 + 级联项)，量级为数百 MΩ）。上表的 Zout 是**闭环**值，即开环值 ÷ (1 + T)，T 为环路增益（10 Hz 时 T = 16.2）。不要把两者混为一谈。
- **噪声：** 有无理想 buffer，逐点 de-embed 型都是 16.68 µV；应用型分别为 20.2 µV（无 buffer，被增益偏低放大）和 17.1 µV。

## B — 真实输出级：CD 对比 C OTA + CS 第二增益级 [Spectre]（`stageB/r5_stageB.csv`）

- **B1 CD：** NMOS 源随器 MSF 4u/1u（D 接 VDD2，G 接 oa1，S 接 oa2，bulk 接地），偏置管 MSB 2u/4u（镜像）。
- **B2 CS（真正的两级增益）：** PMOS 共源 MCS 4u/2u（S 接 VDD2，G 接 oa1，D 接 oa2），负载 MCL 2u/4u（镜像），Miller 电容 CM2 = 0.5 pF 接在 oa1 和 oa2 之间。OTA1 的输入已交换。
- **其余冻结：** OTA1 的尺寸、VCAS、Cc / Cfb / Rfb、LP 都不变。

| | **B1 CD** | **B2 CS + Miller 0.5 pF** |
|---|---|---|
| H10 / H60 / H100（out） | 92.0 / 89.5 / **85.47（38.64 dB）** | 99.8 / 97.1 / **92.75（39.35 dB）** |
| fL / fH | 0.093 Hz / **249.5 Hz** | **0.100 Hz** / **249.2 Hz** |
| fb 处 H100 | 92.05 | 99.88（fH_fb 8.47 kHz） |
| OTA1 输出 oa1：DC / 对 vd 的增益 | **1.313 V** / 107.8 | **1.438 V** / 1.43 |
| OTA2 输出 DC（= fb） | 0.9019 V | 0.8982 V |
| 主环路 UGF / PM / LG@10 Hz / LG@1 mHz | 181 kHz / **73.4°** / 11.5 / 822 | 8.08 kHz / **87.4°** / **700.8** / 121 300 |
| 闭环 Zout@fb（100 Hz） | 47.1 kΩ | 77.3 kΩ |
| OTA2 电流 | 53.6 nA | 53.6 nA |
| OTA1 最小余量 | M2 0.092 V | M2 0.094 V，M4 0.262 V |
| OTA2 器件 OP | MSF Vgs 0.411 V（体效应后 Vth 0.567 V），Vds 0.898 V；MSB Vds 0.902 V（region 3） | MCS Vsg 0.362 V，Vsd 0.902 V；MCL Vds 0.898 V（region 3） |
| 噪声：应用型 / 逐点型 | 17.13 / 16.69 µV | 17.07 / 16.69 µV |

- **CD 的电平位移：** 源随器的 Vgs 约 0.41 V，把 OTA1 输出推高到 1.31 V。OTA1 的 PMOS 镜像（M4，Vds 0.49 V）和 cascode 仍有余量，所以 **DC 可实现，没有出现 headroom 阻塞**。由于反馈从源随器之后取，fb 自动回到 0.90 V。PMOS 源随器会把 oa1 拉到约 0.45 V，低于 cascode 下限，所以没有采用。
- **CS 的补偿：** 0.5 pF Miller 下 PM 已是 87.4°，**不需要改值**（原本允许改一次）。CS 让环路增益提高约 43 倍（10 Hz 时从 16 升到 701），fL 因此回到 0.100 Hz（理想 Rfb）。
- **两种方案都消除了 LP 负载问题：** fH 约 249 Hz，增益落在 38–42 dB 以内。只是前向链候选，**还没有在整机上验证**。
- **B3（CS → CD）：** 没有触发条件，CS 的闭环 Zout 已经很低。**[NOT RUN]**

## C — 分级噪声归因：OTA2 对整机的影响到底有多大 [Spectre + Approx]（`r5_noise_stage_contributions.csv`）

**方法：**
- 每个候选在 0.1–250 Hz 内做 **15 个对数子频带**的 Spectre NoiseSummary，按实例前缀分组，然后逐带除以 \|Hdm,out(f_center)\|²（ac 结果插值）再加总。
- **验证：** 子频带合计 16.67 µV，与普通 noise 的逐点 de-embed 结果 16.69 µV 一致。
- 不是把各级的 RMS 直接相加，也不是简单除以 100。

| 0.1–250 Hz，**折算到 ECG 差模输入**（µVrms） | 单级 C（R4 参照） | +理想 BUF | +CD | +CS |
|---|---|---|---|---|
| OTA1 输入管 NMOS flicker | 12.4 | 12.4 | 12.4 | 12.4 |
| OTA1 输入管热噪声 | 1.06 | 1.06 | 1.06 | 1.06 |
| OTA1 镜像 PMOS flicker | 10.9 | 10.9 | 10.9 | 10.9 |
| OTA1 镜像热噪声 | 1.29 | 1.30 | 1.30 | 1.30 |
| OTA1 其他（cascode、尾管、参考管） | 0.053 | 0.053 | 0.064 | 0.048 |
| **OTA2 flicker** | — | 0（理想） | **0.042** | **0.028** |
| **OTA2 热噪声** | — | — | 0.0008 | 0.0015 |
| Rfb 热噪声 | 1.02 | 1.02 | 1.02 | 1.02 |
| 合计（子频带去嵌入） | 16.68 | 16.66 | 16.67 | 16.67 |

- **OTA2 自身噪声（折算到 OTA2 自己的输入）[Approx，教学参考]：**
  - CD：约 **4.5 µVrms**，和 OTA1 同一量级。计算方法是用环内 DM 传递 \|out/oa1\|（约 0.79）做近似。
  - CS：约 0.03 µVrms。CS 级自身的 gm 增益已经把它的噪声压得很低。
- **系统权重：** 尽管 CD 自身噪声约 4.5 µV，但它前面有 OTA1 约 108 倍的增益（oa1/vd），**折算到 ECG 输入只剩 0.042 µV**，占整机功率的约 0.0006%。NoiseSummary 中 X2 各器件的输出功率合计约 1e-11 V²，整机约 2.5e-6 V²。
- **判定（按任务书规则）：** OTA2 折算到 ECG 输入的 1/f 噪声 ≪ 0.5 µV。所以**把解调从 OTA2 之前挪到之后，可节省的噪声最多只有约 0.04 µV**，相对 16.7 µV 可以忽略。这只是候选判定，D 节会用波形和 PNoise 直接检验。
- **整机噪声来源：** 约 98.5% 来自 **OTA1 的 flicker**，其中输入对约 12.4 µV、镜像约 10.9 µV。chopper 必须包住 OTA1，镜像管也在被斩波的回路里。
