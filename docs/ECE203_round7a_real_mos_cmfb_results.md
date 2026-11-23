# ECE203 R7A 结果：真实 MOS 连续时间 CMFB（线性度优先）

**判定：三个阶段都通过（Baseline PASS / Candidate A PASS，第 2 轮修正后的 a2 / Integrated PASS）。候选 B 没有运行（NOT RUN，不需要）。**

| 阶段 | 结果 |
|---|---|
| **1. 基线复现** | **PASS**：旧 DD-pair 与理想 CMFB 的静态数值与 R6C / R6D 逐位一致 |
| **2. 独立检测器** | a0 **FAIL**（直流零点 +74 mV）→ a1 **FAIL**（−1.51 mV，差 0.5 mV）→ a2 **PASS**（7 项门槛全过）。两轮修正都只改了 MD 的宽度；线性度从 a0 起就满足要求 |
| **3. 系统集成**（BUFFERED 10 pF，只替换 CMFB） | **PASS**：静态和 2 kHz/60 ms 斩波瞬态的全部登记门槛都通过 |
| 候选 B | **NOT RUN**：A 已经通过 |

**代价（不在门槛内，但必须说明）：**
- 斩波边沿处差模误差变大约 3.3 倍：最大 32 mV，理想控制器为 9.6 mV。fp−fn 拟合残差约 4 倍（3589 vs 912 µV RMS），100 Hz 增益因此低 1.9%。
- CMFB 环路 10 Hz 增益 276，理想 1052，旧 DD 722。
- 控制器电流 331.5 nA，旧 DD 103 nA；系统总功耗 1.994 µW。

**本轮没有宣称任何噪声改善。**

日期 2026-11-22 · 任务书 [ECE203_round7a_real_mos_cmfb_task.md](ECE203_round7a_real_mos_cmfb_task.md) · 事先登记的设计说明和门槛 [round7a/r7a_plan.md](ece203_data/round7a/r7a_plan.md)（commit `7f29c7a`，在运行任何候选之前提交） · 脚本 `ece203_r7a.il` · 数据 [ece203_data/round7a/](ece203_data/round7a/) · 图 `r7a_stage2.png`、`r7a_stage3.png`

## 0. 复现信息

| 项目 | 内容 |
|---|---|
| 代码 commit | 基线 + a0：`7f29c7a`；a1：`d9af5fc`；a2：`a6b6981`；系统搭建 / 静态 / 瞬态 / ADE：`f8b0032`（`raw/r7a_run_commits.txt`） |
| PDK / 工艺角 / 温度 | IBM cmrf7sf，`allModels.scs` section `tt`；27 °C |
| 工具 | Virtuoso IC-618，Spectre 15.1.0；ieng6-ece-10，OCEAN 批处理（`run.sh`，正常 git pull） |
| 选项 | reltol 1e-5，vabstol 1e-6，iabstol 1e-17，gmin 1e-18（与 R6B/R6C/R6D 相同） |
| Tran | 60 ms，maxstep 0.5 µs，**cmin 1e-17 F**（R6D-R 方案 C；spectre.out 回显 `cmin = 10 aF`、`reltol = 10e-06`、`gmin = 1 aS`）。只保存所需节点，psf 写在 `/tmp/lix015_r7a`，用 watchdog 监控（240 s 无进展就停）；实际耗时 70.7 s，没有卡住 |
| 运行入口 | `run.sh ece203_r7a_base` → `AC_R7A_CAND=a0/a1/a2 run.sh ece203_r7a_build_det`、`ece203_r7a_det` → `AC_R7A_CAND=a2 run.sh ece203_r7a_build_sys`、`_sys_a`、`_sys_b`、`_ade` |

## 1. 设计：候选 A，线性化的 DD-pair 加二极管 PMOS

推导和完整连接表见 `r7a_plan.md`。要点如下。

- **旧检测器把差模读成共模的原因：** 偶次误差 ≈ (h'''/h')·a·δ²/2，同时正比于平衡点失衡 a 和 1/Vs²（Vs 是输入对的线性范围）。旧对管 4u/2u、约 25 nA，gm/Id ≈ 27，深亚阈值，Vs ≈ 70 mV；而且 a ≈ −21 mV（直流误差）。两样都很差。
- **A 的做法：**
  - 输入对改为 nfetx 0.5u/40u，每管约 83 nA，gm/Id ≈ 8.2，工作在中等反型（region 2）。线性范围扩大约 3.5 倍。
  - 尾管 10u/8u，栅接 IBIAS（复用 OTA 的 MREF），每对 166 nA。
  - 二极管 MD 的宽度设计成：两对平衡时，VCMFB 恰好等于 OTA 负载所需的 vg。
  - 结构仍是"两对 + 二极管"，没有新增理想源，也没有用高阻电阻或 VCVS。
  - 尺寸来自一次单器件特性扫描（`r7a_device_char.csv`，只用来选尺寸，不算候选）。
- **器件（a2，系统 DC 工作点，vcm = 0.9）：**

| 器件 | D G S B | W/L | Id | VGS | VDS | VDSAT | 区域 | 余量* |
|---|---|---|---|---|---|---|---|---|
| MA1 / MB1 | VDD OP/ON ta/tb GND | 0.5u/40u | 83.1 nA | 0.600 | 1.500 | 0.215 | 2（饱和） | 1.285 V |
| MA2 / MB2 | VCMFB VREF ta/tb GND | 0.5u/40u | 82.6 nA | 0.600 | 1.025 | 0.215 | 2 | 0.810 V |
| MTA / MTB | ta/tb IBIAS GND GND | 10u/8u | 165.7 nA | 0.309 | 0.300 | 0.051 | 3（亚阈值） | 0.200 V |
| MD | VCMFB VCMFB VDD VDD | **2.932u**/4u | 165.3 nA | −0.475 | −0.475 | −0.089 | 2 | 0.375 V |

\* 余量 = \|VDS\| − max(\|VDSAT\|, 0.1 V)

- **反馈极性：** Vout,cm ↑ → MA1/MB1 电流 ↑、MA2/MB2 ↓ → MD 电流 ↓ → VCMFB ↑ → PMOS 负载电流 ↓ → Vout,cm ↓，为负反馈。
  - 独立测试中 dvg/dVcm 在 vd ∈ [−0.2, 0.2] V 内都 > 0（最小 0.242）；
  - 系统 stb 的 1 mHz 相位为 −141.9°（与理想基线同一形状，见 §4）。

## 2. Stage 1：基线复现（只仿真原 cell，不重画）

| 测试台 | op/on 共模 | vg | Hdm 100 Hz | CMRR60 | CMFB UGF / PM | DRL PM | I(VDD) / I(VDDD) |
|---|---|---|---|---|---|---|---|
| 旧 DD（`ece203_r6c_tb_old`） | 0.878907 V | 1.32522 V | 94.558 | 108.59 dB | 350 kHz / 74.04° | 90.25° | 385.6 / 283.1 nA（控制器 103.0 nA） |
| 理想 CMFB BUFFERED 10 pF（`ece203_r6d_tb_buf`） | 0.900059 V | **1.32506 V** | 94.533 | 108.62 dB | 535 kHz / 87.85° | 90.25° | 493.4 / 283.1 nA |

- 两组数值与 R6C / R6D 报告逐位一致。
- 理想组的 vg = 1.32506 V 作为 Stage 2 直流零点的目标值。

**电源接法核对（网表）：**
- `VDD (vdd 0) vsource dc=vdd`、`VDDD (vddd 0) vsource dc=vdd`，是两个独立的对地 1.8 V 电源；
- IB 从 vdd 取电，IBD 从 vddd 取电。
- 因此总电流 = I(VDD) + I(VDDD)，不重复计算。这与 R5N-F 的串联 0 V 电流表接法不同。

## 3. Stage 2：独立检测器测试

- **测试台：** `ece203_r7a_det_tb_<v>`
  - OP/ON = vcm ± vd/2；VREF 0.9 V；IB 50 nA 加 MREF 复制管；
  - vg 接两只 M3/M4 复制负载（2u/4u，漏极接 0.9 V）；
  - 控制器单独用电源 VDDC。
- **扫描：** vcm 取 0.88 / 0.899 / 0.90 / 0.901 / 0.92 V，每个 vcm 下 vd 从 −0.2 到 +0.2 V，步长 2 mV；另外在 21 个工作点上存 DC op。
- **定义：**
  - A_ctrl = dvg/dVcm（用 vcm 0.899 / 0.901 两点求，vd = 0）；
  - e(Vd) = [vg(vcm, Vd) − vg(vcm, 0)]/A_ctrl，即等效到检测器输入的共模误差；
  - Vcm0 = 0.9 + (1.32506 − vg(0.9, 0))/A_ctrl。

| 指标（门槛） | 旧 DD（对照） | a0 | a1 | **a2** |
|---|---|---|---|---|
| MD 宽度 | 1u | 2.085u | 2.95u | **2.932u** |
| S1 极性：min dvg/dVcm（> 0） | 0.208 | 0.267 | 0.242 | **0.242 PASS** |
| S2 A_ctrl（0.2–2） | 0.865 | 0.290 | 0.262 | **0.263 PASS** |
| vg(0.9, 0) | 1.34158 V | 1.30349 V | 1.32546 V | **1.32508 V** |
| S3 Vcm0 − 0.9 V（≤ ±1 mV） | −19.10 mV | **+74.44 mV FAIL** | **−1.51 mV FAIL** | **−0.08 mV PASS** |
| S4 e(±0.10 V) @ vcm 0.90（≤ 0.4 mV） | −1.018 mV | −0.0140 | −0.0132 | **−0.0133 mV PASS** |
| e(±0.05 / ±0.20 V) @ 0.90 | −0.304 / −2.344 | | | −0.0035 / −0.044 mV |
| S5 e(±0.10) @ vcm 0.88 / 0.92（≤ 旧值的 1/4） | +4.462 / −8.346 mV | | | **+0.345 / −0.416 mV PASS**（旧值的 1/13 / 1/20） |
| e(±0.20) @ 0.88 / 0.92 | +10.93 / −18.92 mV | | | +1.418 / −1.680 mV |
| 平方律外推：±94 mV 差模下 200 Hz 共模 | 0.46 mV | 0.006 | 0.006 | **0.006 mV** |
| S6 最小余量 / vg 范围（≥ 0 / 0.3–1.6 V） | 0.340 V / 1.326–1.360 | 0.156 V | 0.156 V | **0.156 V（MTA，vcm 0.88、vd −0.2）/ 1.320–1.331 V PASS** |
| S7 控制器电流（≤ 0.5 µA） | 103.1 nA | 331.5 | 331.5 | **331.5 nA PASS** |

- **线性化效果和直流校准无关：**
  - a0 的直流零点偏了 74 mV，但它的 e 曲线已经与 a2 相同（S4/S5 数值几乎一样）。
  - 人为加 ±20 mV 共模失衡时，a2 的 e(±0.1 V) 是旧 DD 的 1/13–1/20（图 `r7a_stage2.png` (b)）。这是任务书要求的"线性化"证据。
  - 反过来，旧 DD 即使把直流校准到 a = 0，在 vcm 0.90 下仍有 −1.02 mV。
- **两轮修正都只改 MD 宽度（直流零点），其余不变：**
  - a0 → a1：尾电流实际是 166 nA，不是设计时的 120 nA，所以 MD 的 VSG 偏大 21.6 mV。按单器件特性的 dVSG/dlnW = 0.0615 V 外推，2.085u → 2.95u。
  - a1 → a2：用 a0、a1 两点实测的 dVSG/dlnW = 0.0633 V 做牛顿修正，2.95u → 2.932u。
  - **A 的两轮修正额度已经用完。**
- **直流零点的稳健性（只做了 tt 标称，未做 PVT/失配）：**
  - A_ctrl 只有 0.26，MD 电流偏 1%，Vcm 约偏 2.7 mV。所以直流零点依赖尺寸校准。
  - 但线性度在 ±20 mV 失衡下仍有余量：平方律外推得到 200 Hz 约 0.19 mV，仍 ≤ 0.2 mV。

## 4. Stage 3：系统集成（`Project/ece203_r7a_tb_buf_a2`）

- **搭建：** 用 R6D BUFFERED 的元件列表，删去理想控制器（ESA/ESB/EEA/RPC/CPC/VBC/EAD/ELM），在同一组网络上接入 XC（`ece203_r7a_cmfb_a2`：OP op、ON on、VREF vrc、VCMFB vcf、VDD vdd、IBIAS ib）。
- **网表 diff**（`raw/netdiff_r6dbuf_vs_r7a_a2.txt`）：结构上只差上述 8 个元件被替换为 1 个子电路和 XC，其余差异只是运行参数（chen/vd/dcc）和分析语句。
  - 双 TG（XCI/XCO）、主 OTA、真实 DRL、CD（XCD）、时钟、10 pF 负载都没有变；
  - `VSPS ... sinephase=0` 在网表中确认。

### 4.1 TG 静止在 A 相

| 指标 | 理想 CMFB 基线 | **MOS CMFB a2** | 门槛 / 判定 |
|---|---|---|---|
| op/on（= fp/fn）共模 | 0.900059 V | **0.899918 V（−0.082 mV）** | ≤ ±1 mV：**PASS** |
| vg | 1.32506 V | 1.32506 V | 不撞轨：**PASS** |
| Hpre 10 / 100 / 1k Hz | 94.543 / 94.533 / — | 94.543 / **94.531** / 93.688 | 100 Hz 变化 −0.002%（≤ 5%）：**PASS** |
| Hbuf 100 Hz / A_CD | 79.64 / 0.8425 | 79.641 / 0.8425 | 不变 |
| CMRR60（Cc 失配 1%） | 108.62 dB | 108.49 dB | |
| CMFB 环路：UGF / PM | 535 kHz / 87.85° | **122 kHz / 84.46°** | PM ≥ 60°：**PASS** |
| CMFB 环路增益 @ 10 Hz / 1 mHz | 1052 / 189 | 276 / 49.7 | 更低（A_ctrl 0.26 vs 1） |
| DRL 环路：UGF / PM / LG60 | 1984 Hz / 90.25° / 32.36 | 1983 Hz / **90.25°** / 32.36 | PM ≥ 60°：**PASS** |
| OTA 最紧余量 / CMFB 最紧余量 | XA.M1 0.092 V / — | XA.M1 0.092 V / XC.MTB 0.200 V | 均在饱和区（含亚阈值饱和） |
| I(VDD) / I(VDDD) | 493.4 / 283.1 nA | 824.8 / 283.1 nA | 控制器 331.5 nA |

### 4.2 2 kHz 真实 TG，60 ms，100 Hz、1 mV 差模输入

- **分析方法：** 与 R6D-R 相同。两个窗口 20–40 ms 和 40–60 ms 各重采样到 1 µs，做最小二乘拟合（直流 + 线性漂移 + 100/200/300 Hz）。
  - 共模 200 Hz 取 op/on 共模拟合中 200 Hz 项的幅度；
  - 边沿尖峰以 [−20, −1] µs 和 [+40, +60] µs 两段均值连线作为基线；
  - 恢复时间取偏差最后一次超过 1 mV 的时刻。
- **一致性核对：** 用同一脚本（`r7a_sys_analysis.py`）重算 R6D-R 的 `F_C_buf_10p` 理想波形，结果与 R6D-R 报告一致（93.5024、4.71 µV、47.79 mV、0.102 µs）。
- 下表两个窗口的数值一致到 4–5 位有效数字，给出 40–60 ms 窗口。

| 指标 | 理想 CMFB（R6D-R） | **MOS CMFB a2** | 门槛 / 判定 |
|---|---|---|---|
| 运行到 | 60 ms | **60 ms**（watchdog 未触发） | **PASS** |
| op/on 共模平均 − 0.9 V | +0.147 mV | **−0.061 mV** | ≤ 1 mV：**PASS** |
| **op/on 共模 200 Hz 分量** | 4.70 µV | **3.94 µV** | ≤ 0.20 mV：**PASS**（旧 DD 3.52 mV 的 1/890） |
| op/on 共模 100 Hz 分量 | 4.32 µV | 0.83 µV | |
| 漂移 / 两窗口差 | −0.002 mV/s / 无 | 0.002 mV/s / 无 | 无漂移、无持续振荡：**PASS** |
| 100 Hz 差模增益 Hpre | 93.5025 | **91.733（−1.89%）** | ≤ 5%：**PASS** |
| Hbuf（送到负载） | 78.762 | 77.240（−1.93%） | |
| op/on 范围 / buf 最低点 | 0.853–0.998 V / 0.503 V | 0.853–0.956 V / 0.503 V | 无削顶：**PASS** |
| TG 边沿 op/on 共模尖峰 +/− | +47.8 / −4.5 mV | **+8.5 / −2.9 mV** | 改善（旧 DD 为 +22.5 mV） |
| 边沿后共模恢复到 1 mV | 0.10 µs | 0.011 µs | |
| vg 范围 / 边沿跳变 | 1.3238–1.3630 V / +37.9 mV | **1.3232–1.3259 V / +0.8, −1.9 mV** | 不撞轨 |
| vg 200 Hz 分量 | 4.1 µV | 0.06 µV | |
| **fp−fn 边沿误差（最大 / 平均）** | 9.6 / 6.2 mV | **32.0 / 20.7 mV** | **变差 3.3 倍**（未登记门槛） |
| fp−fn 拟合残差 RMS | 912 µV | 3589 µV | 变差 3.9 倍 |
| I(VDD) / I(VDDD) / 总功耗 | 493.9 / 283.1 nA / 1.399 µW（理想 CMFB 不计功耗） | 827.2 / 283.2 nA / **1.999 µW** | 控制器增加 0.597 µW |

**解读：**

1. **共模指标全面达标，且优于理想控制器的边沿表现。**
   - 200 Hz 共模分量 3.9 µV，与理想控制器同一量级。独立测试的平方律外推是 6 µV，量级一致。
   - 边沿共模尖峰从 47.8 mV 降到 8.5 mV。这与 R6C 的假设一致：理想检测器输入电容为 0，op/on 上没有东西吸收时钟馈通电荷；新输入管有约 20 µm² 栅面积，提供了这部分电容。
   - 这个电容解释仍然没有单独仿真验证。
2. **代价是斩波边沿的差模误差变大**（图 `r7a_stage3.png` (d)，42.5 ms 处的边沿）。
   - 边沿瞬间 fp−fn 的误差从 −6.7 mV 跳到 −25 mV，之后按相近的时间常数（约 20 µs 量级）恢复。所以增大的是边沿瞬间的初始误差，不是建立速度。
   - 拟合后多出约 +2.3 mV 的平台（理想 +0.55 mV），对应平均增益低 1.9%。
   - **假设（未验证）：** 来自检测器输入管挂在 op/on 上的栅电容。TG 翻转时，fp/fn 和 op/on 之间的电荷分享变大了。
   - 支持这个假设的是一个趋势：输入电容为 0 的理想检测器残差 912 µV；旧 DD（4u/2u，8 µm²）在 R6C 中是 1406 µV；新的 0.5u/40u（20 µm²）是 3589 µV。
   - 可行的验证：在理想测试台的 op/on 上各加一只与 MA1 栅电容相当的电容。本轮没有做。
   - 这项不在登记门槛内，但对增益精度有实际影响。
3. **CMFB 环路增益偏低**（10 Hz 时 276，理想 1052）。原因是 A_ctrl 只有 0.26。
   - 这意味着对 op/on 上外加共模电流扰动的抑制，比理想控制器差约 3.8 倍。
   - 本轮没有做共模电流扰动测试（不在任务范围），这是推算值。

## 5. 运行量、失败与清理

- **主要用例：**
  - Stage 1：2 个基线；
  - Stage 2：旧 DD 对照 1 次，加候选 A 三个版本（a0 初始、a1 和 a2 两轮修正）；
  - Stage 3：1 次静态，1 次 60 ms 瞬态，1 次 ADE 存 state。
- **另外：** 1 次单器件特性扫描（直接调用 Spectre，`tools/char.py`；只用于选尺寸，不是 CMFB 候选）。
- **失败和修正（全部保留）：**
  - a0（S3 FAIL）、a1（S3 FAIL）的 cell、测试台和数据都保留；
  - 第一次拉取 Stage 2 数据时 a0 任务还没跑完，拿到的 op 文件不完整。等任务结束后重新拉取，用的是完整文件；
  - 特性扫描脚本第一次少了 PDK 全局参数（`p5vonly`、`phires`），报错后补上。
- **候选 B（高增益镜像负载 DD 加 MOS 滞后补偿）：** 没有设计，也没有运行。
- **新 cell（Project 库，全部新建）：**
  - `ece203_r7a_cmfb_a0/_a1/_a2`
  - `ece203_r7a_det_tb_old/_a0/_a1/_a2`
  - `ece203_r7a_tb_buf_a2`
  - ADE state：`r7a_a2_buf10p_phaseA`（dc / ac / CMFB stb，TG 静止 A 相；设 `chen = 1`、`vd = 1m` 即可做斩波 tran）
  - 旧 cell（R5N-F、R6A–R6D-R）都没有重画或改动。
- **清理：** 只删除了本轮可重建的 AC/STB/DC psf（`r7aRmPsf`）和 tran psf（/tmp）。用户的进程没有动。home 配额本轮结束时为 3909 / 5120 MB。
- **没有运行：** 噪声、PSS/PNoise、Monte Carlo、PVT、MOS 参考源、时钟发生器、伪电阻接入，也没有新增第二级。

## 6. 数据

`docs/ece203_data/round7a/`：

- **设计与汇总：**
  - `r7a_plan.md`：设计说明和事先登记的门槛；
  - `r7a_device_char.csv`：单器件特性；
  - `r7a_det_summary.csv`：Stage 2 全部指标；
  - `r7a_det_e_{old,a0,a1,a2}.csv`：e(Vd) 曲线；
  - `r7a_stage3_summary.csv`：Stage 3 每个窗口的指标，含理想基线重算。
- **脚本：** `r7a_det_analysis.py`、`r7a_sys_analysis.py`、`r7a_plots.py`、`tools/char.py`、`tools/psfop.py`。
- **图：** `r7a_stage2.png`、`r7a_stage3.png`。
- **`raw/`：**
  - Stage 1：`r7a_baseline.csv`、`B_*`（AC/DC op/stb）；
  - Stage 2：`D_{old,a0,a1,a2}_sw_vcm*.csv`、`D_*_op.csv`；
  - Stage 3（`stage3/`）：`S_a2_*`；`T_a2_buf10p_tran.csv.gz`（完整分辨率，SHA-256 已核对）；`T_a2_buf10p_spectre.out.gz`；`T_a2.csv`；
  - 其他：`netdiff_r6dbuf_vs_r7a_a2.txt`、`watchdog.log`、`r7a_run_lines.txt`、`r7a_run_commits.txt`。
- **没有提交到仓库的内容：** 完整网表（含 PDK 路径）在实验记录本 `_raw\2026-11-22_ece203_round7a_real_mos_cmfb\`。

**本轮到此停止。** 没有进入候选 B、噪声或 PVT。
