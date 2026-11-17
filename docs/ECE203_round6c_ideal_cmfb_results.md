# ECE203 Round 6C-I 结果：真实 MOS 系统中的理想 CMFB（A/B 对照）

**判定：ARCHITECTURE PASS / VALUE PASS（理想控制器上限，不是晶体管级 CMFB）**

- **ARCHITECTURE PASS：** 真实 FD OTA + 真实 DRL + 2 kHz 真实 TG chopper 下，理想线性 CMFB 通过真实 PMOS 负载 M3/M4 稳定控制输出共模：Vout,cm 平均 0.90015 V，VCMFB 1.3250–1.3634 V，没有撞电源轨。100 Hz 差模增益 93.51（旧 CMFB 93.23），20–40 ms 与 40–60 ms 两个窗口一致，没有漂移。
- **VALUE PASS：** 同条件 A/B 中有多项可量化改善：
  - 输出共模 DC 误差：−21.1 mV → +0.06 mV；
  - 差模引起的共模 200 Hz 分量：3.52 mV → 0.0047 mV（斩波下）；
  - TG 边沿后共模恢复到 1 mV：≤ 11 µs → ≤ 0.11 µs。
- **变差的一项：** TG 边沿处输出共模的正向尖峰由 22.5 mV 增大到 48.4 mV，VCMFB 跟着跳 39.6 mV。
- **适用范围：** 新组用的是理想受控源，只说明控制路线和性能上限。不代表晶体管级实现、零噪声、零功耗或流片合格。

日期 2026-11-16 · 任务书 [ECE203_round6c_ideal_cmfb_task.md](ECE203_round6c_ideal_cmfb_task.md) · 脚本 `ece203_r6c.il`（任务 ece203_r6c_a / b / c / ade）· 数据 [ece203_data/round6c/](ece203_data/round6c/) · 图 `r6c_stageA.png`、`r6c_stageBC.png`

## 0. 复现信息

| 项目 | 内容 |
|---|---|
| 代码 commit | Stage A 第一次运行：`d002d45`；Stage B、C 和 Stage A 重跑：`d3c8a0b`；报告与数据：`3cc3e8e`（之后的 r6cBuild 只在缺少 R6A/R6B cell 时才建，不影响结果） |
| PDK / corner / 温度 | IBM cmrf7sf，`allModels.scs` section `tt`；temp 27 °C（tnom 25） |
| 工具 | Virtuoso IC-618，Spectre sub-version 15.1.0.803.isr18；ieng6-ece-10，OCEAN 批处理 |
| Spectre 选项 | reltol 1e-5，vabstol 1e-6，iabstol 1e-17，gmin 1e-18（与 R6B 系统测试台相同） |
| DC / AC / STB | dc saveOppoint；ac 1 mHz–100 kHz，20 点/十倍频；stb 1 mHz–100 MHz，20 点/十倍频，探针 `/IPRC`（CMFB）和 `/IPRD`（DRL） |
| Tran | 共模阶跃：6 ms，maxstep 0.2 µs；Stage B：60 ms，maxstep 2 µs；Stage C：60 ms，maxstep 0.5 µs；只保存所需节点 |
| 运行入口 | `~/AutoCircuit/run.sh ece203_r6c_a` → `ece203_r6c_b` → `ece203_r6c_c` → `ece203_r6c_ade`（GUI） |

## 1. 实验设置：CMFB 是唯一变量

- **两个测试台用同一份元件列表生成**，即 R6B 系统 `ece203_r6b_fd_tg_tb` 的列表：
  - `Project/ece203_r6c_tb_old`：原样的 R6B 系统，带真实 DD-pair CMFB（XC）；
  - `Project/ece203_r6c_tb_ideal`：删去 XC，在同一节点 `vcf` 上接理想控制器。
- **网表 diff**（`raw/r6c_netlist_diff_B.txt`、`_C.txt`）确认两份网表只差：
  - 删去 `ece203_r6a_cmfb` 子电路和 XC；
  - 新增 7 个控制器元件；
  - 其余差异是文件头和 psf 路径。
- **冻结部分：** VDD 1.8 V，VREF 0.9 V；R6A FD OTA1（尺寸不变）；两组真实 TG（8 管，N 1u/0.18u，P 2u/0.18u）；R4 DRL OTA；人体/电极；Cc 50 pF；Cfb 0.5 pF；负载。没有加 OTA2。
- **理想部分（照实标注）：**
  - 偏置 VREF / VCAS / IB / IBD 是理想源；
  - 两相时钟是理想脉冲源（死区约 10 ns）；
  - Rfb 是理想电阻；
  - 新组的 CMFB 是理想元件；
  - 无失配，只做了 tt、27 °C。

### 理想 CMFB 控制器（`r6c_controller_params.csv`）

```
检测   ESA/ESB  vcvs 0.5 + 0.5        csen = (op + on)/2        探测节点，零输入电流、零电容
误差   EEA      vcvs a0 = 1           cea1 = a0·(csen − vrc)    vrc = 旧 CMFB 用的同一个 VREF 节点
极点   RPC/CPC  1 kΩ / 5.3052 pF      cea2 = cea1/(1 + s/ωp)，  fp = 30.0 MHz
偏置   VBC+EAD  vb = 1.325 V          csum = vb + cea2
限幅   ELM      vcvs 1，min 0 / max 1.8 V   vcf = clip(csum)，只限控制量，不钳位 op/on
执行   vcf → IPRC（stb 断环点）→ RCF 1 Ω → vg = PMOS M3/M4 栅（与旧组完全相同）
```

- **传递函数：** VCMFB(s) = 1.325 V + [1/(1 + s/(2π·30 MHz))]·(Vout,cm − VREF)。
- **vb：** 1.325 V 取自 R6A 的 VCMFB 1.325 V，是固定的控制器偏置，没有做闭环校准。DC 误差 = (所需 vg − vb)/a0，实测 +0.06 mV。
- **极性核对：** Vout,cm ↑ → csen ↑ → VCMFB ↑ → PMOS 上拉电流 ↓ → Vout,cm ↓。共模阶跃中 VCMFB 和 e_out 同号同幅（+0.561 mV / +0.561 mV），stb 在中频的相位为 −180°。
- **为什么 a0 = 1（仿真前就定好）：**
  - 环路中频增益主要来自 OTA 本身：vg → Vout,cm 约 1050 V/V。
  - a0 决定的是 UGF。仿真前用 R6B 旧环路增益曲线估算：a0 = 1、fp = 30 MHz 时，UGF 约 0.7 MHz，PM 在 63–83° 之间。
  - 实测 UGF 546 kHz、PM 87.8°。任务书允许的一次补偿修正没有使用。

## 2. Stage A：TG 静止在 A 相（直通）

| 指标 | 旧：DD-pair CMFB | 新：理想 CMFB | 门槛 / 状态 |
|---|---|---|---|
| VOP = VON | 0.878907 V | 0.900059 V | 新组 0.900 ± 0.001 V：**PASS** |
| VCMFB（vg） | 1.32522 V | 1.32506 V | 不撞轨：**PASS** |
| PMOS M3/M4：VSD / VDSAT / 余量 | 0.921 / 0.089 / 0.821 V | 0.900 / 0.089 / 0.800 V | 饱和 |
| OTA 最紧器件余量 | MC2 0.078 V | M1 0.092 V（MC 0.099 V） | 所有器件在饱和或亚阈值饱和区 |
| 100 Hz 差模增益 | 94.558 | 94.533（−0.03%） | 变化 < 5%：**PASS** |
| CMRR @60 Hz（Cc 失配 1%，DRL 开） | 108.59 dB | 108.62 dB | 不变 |
| CMFB 环路：10 Hz 增益 / UGF / PM | 722 / 350 kHz / 74.0° | 1052 / 546 kHz / **87.8°** | PM ≥ 55°：**PASS** |
| CMFB 主极点（10 Hz 平台的 −3 dB 点） | 501 Hz | 562 Hz | |
| UGF 处超出单极点的相移 | 16.2° | 2.3°（其中控制器极点约 1.0°） | |
| 增益裕度（相位到 0° 处） | 32.6 dB @ 4.5 MHz | 33.1 dB @ 35 MHz | |
| DRL 环路：UGF / PM / LG60 | 1984 Hz / 90.3° / 32.4 | 1984 Hz / 90.2° / 32.4 | DRL 稳定：**PASS** |
| 每侧 1 nA 输出共模电流引起的 e_out（AC，1 Hz / 1 kHz / 100 kHz） | 0.819 / 0.819 / 0.809 mV | 0.559 / 0.559 / 0.551 mV | 抑制提高约 1.46 倍 |
| 同一扰动引起的差模串扰 vod（1 Hz） | 142 pV | 72 pV | 可忽略 |
| 1 nA 阶跃：e_out / VCMFB / t90 / 过冲 | 0.818 / 0.562 mV / 1.36 µs / 0.03% | 0.561 / 0.561 mV / 1.34 µs / 0% | 无持续振荡（末 1 ms 峰峰值 < 0.1 µV）：**PASS** |
| I(VDD) / I(VDDD) | 385.6 / 283.1 nA | 283.1 / 283.1 nA | 见下方功耗说明 |

**Stage A 门槛：全部通过。** 没有用理想电压源把输出固定在 0.9 V。

**极点和零点（方法：从 stb 返回比曲线读取，估算值）：**

- **主极点（约 500–560 Hz）：** 来自 OTA 输出的共模电阻和电容，两组相同。
- **高频部分：**
  - 新组在 UGF 处的超额相移，扣除控制器 30 MHz 极点（约 1.0°）后只剩约 1.3°，相当于 OTA 自身一个约 24 MHz 的等效寄生极点。
  - 旧组的 16.2° 主要来自旧 CMFB 自身的内部节点（二极管 MD 等），不是 OTA 本身。
- **低频部分（< 0.01 Hz）：** 1 mHz 处环路增益下降（129 / 189）并出现相位超前，来自 TΩ 级的反馈路径，两组相同。

**功耗说明：**

- 旧 I(VDD) 里有 DD-pair CMFB 的 102.5 nA。新组的理想控制器没有物理功耗，所以 283.1 nA 只是 OTA 加偏置的电流。
- I(VDD) 为 283.1 nA，恰好与 DRL 的 I(VDDD) 283.1 nA 相等，是巧合。
- **不能据此说理想 CMFB 省电。**

## 3. Stage B：Chopper 关闭（TG 静止 A 相），100 Hz、1 mV 差分正弦

分析方法：两个窗口（20–40 ms、40–60 ms）各 4 个整周期，重采样到 1 µs 后做最小二乘正弦拟合（含直流和线性漂移项，100 Hz 与 200 Hz 两个谐波）。两个窗口的结果一致到 5 位有效数字，表中给出 40–60 ms 窗口的值。

| 指标 | 旧 | 新 | 新/旧 |
|---|---|---|---|
| 100 Hz 差模增益 | 94.113 | 94.089 | 1.000 |
| VOP / VON 范围 | 0.825–0.919 V | 0.853–0.947 V | 摆幅相同（vod 峰峰值 0.1882 V） |
| 输出共模平均 − 0.9 V | **−24.58 mV** | **+0.059 mV** | — |
| 输出共模 200 Hz 分量 | **3.589 mV** | **0.0001 mV** | 3 × 10⁻⁵ |
| 输出共模峰峰值 | 7.19 mV | 0.0002 mV | |
| VCMFB 峰峰值 / 200 Hz 分量 | 0.0071 / 0.0036 mV | 0.0002 / 0.0001 mV | |
| vod 拟合残差（RMS） | 1.09 µV | 0.80 µV | 0.73 |
| 削顶 | 无 | 无 | |

- **共模失真来自旧检测器，不是 OTA 本身：** 旧组的 VCMFB 几乎不动（7 µV），实际输出共模却以 200 Hz 摆动 3.6 mV，平均值还比静态再低 3.5 mV。旧 DD-pair 检测器在 ±47 mV 差模摆幅下的非线性（偶次项）把差模"读"成了共模，环路就把真实输出共模推偏了。
  - 理想线性检测器在相同的 OTA 和摆幅下，200 Hz 分量只有 0.1 µV。两组环路增益同量级（722 / 1052），如果失真来自 OTA 本身，两组都会被压低同样的倍数。所以 R6B 斩波下的约 3.5 mV 共模 200 Hz 分量，是旧 CMFB 检测器的非线性造成的。
  - 这次没有加做低幅对照点：新组已经处在仿真分辨率附近，没有必要。
- **余量（估算）：** 假设只有 MC 的 VDS 承担输出摆动，摆到最低点时，旧组 MC2 余量约 0.078 − 0.054 = 0.024 V，新组约 0.099 − 0.047 = 0.052 V。这是按 DC 工作点线性外推的，没有逐点提取工作点。

## 4. Stage C：2 kHz 真实 TG chopper，60 ms，100 Hz、1 mV 差分输入

| 指标（40–60 ms；20–40 ms 窗口一致） | 旧 | 新 | 判定 |
|---|---|---|---|
| 100 Hz 差模增益 | 93.227（复现 R6B 的 93.23） | **93.506**（+0.30%） | 不劣化超过 5%：**PASS** |
| 增益：20–40 ms / 40–60 ms | 93.2273 / 93.2273 | 93.5063 / 93.5064 | 无漂移 |
| 输出共模平均 − 0.9 V | −24.47 mV | **+0.148 mV** | 改善 |
| 输出共模 200 Hz 分量 | 3.518 mV | **0.0047 mV** | 约 1/740 |
| 输出共模漂移 | 0.10 mV/s | 0.002 mV/s | |
| 输出共模峰峰值（含边沿尖峰） | 29.6 mV | 43.6 mV | 变差（尖峰决定） |
| TG 边沿正向尖峰（80 个边沿中的最大值） | 22.5 mV | **48.4 mV** | **变差，约 2.2 倍** |
| TG 边沿负向尖峰 | −3.7 mV | −4.5 mV | |
| 边沿后恢复到 1 mV 以内（最大值） | 11.0 µs | **0.11 µs** | 改善 |
| 边沿后恢复到 0.1 mV 以内（最大值） | ≥ 40 µs（到窗口末端仍未进入） | **0.74 µs** | 改善 |
| VCMFB 范围 | 1.3249–1.3262 V | 1.3250–1.3634 V（边沿瞬间） | 不撞轨 |
| VOP / VON 范围 | 0.825–0.943 V | 0.853–0.994 V | 不削顶 |
| vod 拟合残差（RMS / 峰峰值） | 1406 µV / 19.8 mV | 916 µV / 13.0 mV | 0.65 倍 |

**边沿的测量方法：**

- 以每个边沿前 [−20, −1] µs 的均值和边沿后 [40, 60] µs 的均值连一条直线作为基线，用来扣掉 100 Hz 和 200 Hz 的慢变化。
- 在 [−50 ns, +40 µs] 内取最大正、负偏差。
- 恢复时间取"偏差最后一次超过阈值"的时刻。
- 每个窗口 79–80 个边沿。

**解读：**

1. **慢恢复的拖尾只出现在旧组（图 `r6c_stageBC.png` (d)）。**
   - 在差模峰值附近的边沿（例如 42.5 ms），旧组输出共模出现约 +1.6 mV、时间常数约 20 µs 的拖尾。这正是 R6B 测到的 FD OTA 差模翻转建立时间常数（约 20 µs）。
   - 原因是差模在翻转建立的过程中，被非线性检测器转换成了共模。
   - 理想检测器没有这一项，0.74 µs 内就回到 0.1 mV 以内。
2. **尖峰变大：现象是测量结果，原因是假设，没有单独验证。**
   - 尖峰出现在约 10 ns 的死区内：两组 XCO 的 TG 都关断，op/on 处于悬空状态，时钟馈通的电荷直接落在 op/on 上。
   - 旧组 op/on 上挂着 DD-pair 输入管 MA1/MB1（4u/2u）的栅电容，能吸收一部分电荷；理想检测器的输入电容为 0，所以同样的电荷产生更大的电压。
   - 理想控制器带宽 30 MHz，会在几 ns 内跟着把 VCMFB 拉高约 38 mV。但这个方向是减小 PMOS 电流，起的是抑制作用，不是尖峰变大的原因。
   - 死区内 fp/fn 与 op/on 断开，vod 在尖峰期间不受影响。
   - **这个电容解释没有单独仿真验证。** 可行的验证是在理想组 op/on 上各加一个与旧检测器输入电容等效的电容，本轮没有做。
3. **vod 残差下降 35%，原因未验证。** 一个可能的原因是新组输出共模高出约 24 mV，负摆时 MC 的余量更大（见 Stage B 的估算），差模翻转时建立得更好。

## 5. 运行量、失败与修正（全部保留）

- **主要用例：6 个**（A 旧/新、B 旧/新、C 旧/新）。另外：
  - 1 次探针任务：读取 analogLib vcvs 的 CDF 参数名（maxm/minm）和 Spectre 版本；
  - Stage A 在修正后的 cell 上重跑一次，`r6c_stageA.csv` 以及 stb、阶跃 CSV 与第一次逐位相同。
- **Stage B 第 1 次中止：** B_old 跑完后，日志行里 `%d` 格式化浮点行数出错，任务中断。改成 `%.0f` 后重跑。B_old 结果与重跑一致。
- **Stage B 第 2 次无效：** 理想测试台的 `VSPS` 被 Virtuoso 填上了 `sinephase=180`，两路输入同相，vid = 0，所以理想组没有差分信号。
  - 原因：analogLib 的 vsin 没有指定的参数，会沿用本次会话里上一个同类实例的值，这里沿用了前一个测试台 VSNS 的 180°。
  - 修正：给 VSPS 显式写 `sinephase 0`，重建两个测试台，并在每个 Stage 结束时自动 diff 两份网表。
  - 这不是电路修正，CMFB 补偿修正的次数仍为 0。
  - Stage A 用的是另一组 AC 源，vd = 0，不受影响；重跑结果逐位一致可以证明。
- **两次失败的原始文件** 保存在实验记录本 `_raw\2026-11-16_ece203_round6c_ideal_cmfb\r6c_ab.tgz` 中的 `aborted_run1/`、`aborted_run2_vsps_phase/`。
- **旧 cell 被重画：** 本轮运行时，`r6cBuild()` 还会无条件调用 `r6bBuildTg()` 和 `r6Build()`，用同一份未修改的代码重画了 `ece203_r6b_tgchop`、`ece203_r6a_fd_ota`、`ece203_r6a_cmfb`、`ece203_r6a_tb`（R6B 当时也是这样做的）。
  - 内容相同的证据：旧组完全复现了 R6B 的 S0 结果（增益 94.5581，CMRR 108.593 dB，CMFB PM 74.0368°，I_VDD 385.6 nA），Stage C 增益也复现了 93.23。
  - 此后代码已改为只在这些 cell 不存在时才建。
- **清理：** 只删除了本轮 Stage B/C 可重建的 tran psf 目录（服务器配额只剩约 16 MB）。用户自己的 Virtuoso / spectre 进程没有动。
- **没有运行：** PSS、PAC、PNoise、Monte Carlo、PVT；也没有做真实 CMFB 器件设计。

## 6. 数据与复现

- **`docs/ece203_data/round6c/`：**
  - `r6c_ab_summary.csv`：A/B 对照总表；
  - `r6c_stageA_summary.csv`：Stage A 的工作点、环路和扰动指标；
  - `r6c_tran_summary.csv`：Stage B/C 每个窗口的指标；
  - `r6c_controller_params.csv`：控制器参数；
  - `r6c_analysis.py`、`r6c_plots.py`：分析和画图脚本；
  - `r6c_stageA.png`、`r6c_stageBC.png`。
- **`raw/`：**
  - Stage A：`A_{old,ideal}_{dm,cm,dz}_ac.csv`、`_dm_dcop.csv`、`_stb_{cmfb,drl}.csv`、`_step_tran.csv`、`r6c_stageA.csv`；
  - Stage B/C：`B_*_tran.csv.gz`、`C_*_tran.csv.gz`（完整分辨率，gzip 压缩；解压前的 SHA-256 见 `r6c_tran_sha256.txt`），以及 `r6c_stageB.csv`、`r6c_stageC.csv`；
  - 网表 diff、`r6c_run_lines.txt`（三个任务日志中的全部结果行）。
- **没有提交到仓库的内容：** 完整网表（含 PDK 模型路径）、psf 和完整日志。它们在实验记录本 `_raw\2026-11-16_ece203_round6c_ideal_cmfb\` 中。
- **复现步骤：**
  1. 前提：cds.lib 包含 Project 库和 cmrf7sf PDK，并且已有 `ece203_r4_drl_ota`（R4）。R6A/R6B 的 cell 如果不存在，`r6cBuild()` 会自动生成。
  2. 依次运行 `run.sh ece203_r6c_a`、`ece203_r6c_b`、`ece203_r6c_c`（各约 3 / 4 / 10 分钟），结果写入 `~/AutoCircuit_results/ece203_r6c/`。
  3. 把 CSV 拷到 `raw/`，在 `docs/ece203_data/round6c/` 下运行 `python3 r6c_analysis.py raw && python3 r6c_plots.py raw`。
  4. 核对方法：`r6c_ab_summary.csv` 与本报告表格一致；Stage A 两次运行的 CSV 逐位相同；旧组复现 R6B（94.5581 / 108.593 dB / 74.04° / 93.23）。
- **Cadence：**
  - 新 cell：`Project/ece203_r6c_tb_old`、`ece203_r6c_tb_ideal`；
  - ADE state：`r6c_old_cmfb_phaseA`、`r6c_ideal_cmfb_phaseA`（dc / ac / CMFB stb，TG 静止 A 相；设 `chen = 1`、`vd = 1m` 即可做斩波 tran）。

**本轮到此停止，不进入真实 CMFB 器件设计。**
