# ECE203 Round 3D 结果：1 MHz 理想时钟 / 理想开关 Chopper 短窗实验

日期 2026-11-16 · 任务书 [ECE203_round3d_ideal_chopper_ceiling_microtest.md](ECE203_round3d_ideal_chopper_ceiling_microtest.md) · 数据 [ece203_data/chopper/](ece203_data/chopper/)（`chop_summary.csv`、`*_tran_0p1us.csv`、`chop_step.png`）

**结论：**
- **理想逻辑通过：** 1 MHz 理想时钟 + 理想开关的调制/解调逻辑在 S2 单级上验证通过，理想 VCVS 短窗阶跃增益为 99.89。
- **真实 C 未通过：** 冻结的 Round 3C 局部 cascode OTA 在 1 MHz 下无法正常处理信号。短窗阶跃增益约 12，同窗口不斩波为 94.1；输出平均值偏移 −115 mV，纹波 0.34 V pp。原因是带宽：C 的闭环 fH 为 8.8 kHz，每半周期只有 0.5 µs，OTA 输出来不及建立。
- **噪声未做：** 按任务书，没有做 PSS/PNoise。**Chopper 的噪声改善上限仍未测出。**
- **只是 1 MHz 的结论：** 这个失败**不能说明 chopper 原理行不通**，只说明当前这个 OTA 跟不上 1 MHz。

## 架构（cell：`Project/ece203_ss_chop_ideal_tb`、`Project/ece203_ss_chop_c_tb`）
- **S2 网络不变：** 每侧 Cc 50 p、Cfb 0.5 p、理想 Rfb 3.1831 T，VREF 0.9 V，CL 0。仿真精度 gmin = iabstol = 1e-18、reltol 1e-6。
- **时钟：** 两个理想 vpulse（0/1.8 V，周期 1 µs，边沿 1 ns）。**两相不交叠**，每个边沿有 10 ns 死区，期间所有开关断开。
- **开关：** analogLib `switch`，网表里是 Spectre `relay`。vt1 = 0.8 V（断开），vt2 = 1.0 V（闭合）；rc = 1 Ω，ro = 1e20 Ω。ro 必须远大于 Rfb，否则断开的开关会和 Rfb 并联。开关的热噪声没有研究。
- **输入调制（包住整个 OTA）：** 第 1 相 p→INP、n→INN；第 2 相 n→INP、p→INN。
- **输出解调：** 第 1 相 o ← oa；第 2 相 o ← `2·VREF − oa`。后者由理想 VCVS 反相器 EINV 生成（增益 −1，以 VREF 为参考）。**EINV 是非物理、无噪声的辅助块**，单端输出用被动开关无法免费实现正负号翻转。
- **反馈：** Cfb‖Rfb 从解调后的 o 接回，所以两相都是负反馈。
- **OTA：** 理想版是 VCVS（aol 1e5，无带宽限制）；真实版是冻结的 `ece203_ss_ota_cmp_c_ota`（Round 3C C 版，理想 VCAS 1.05 V，ib3 50 nA）。
- **激励和测量：** 在 Cc 前加差分 1 mV 阶跃，时刻 50 µs，tran 共 200 µs（200 个时钟周期，maxstep 5 ns）。阶跃增益 = [o 在 190–200 µs 的平均 − 40–50 µs 的平均] / 1 mV。这**只是短窗功能检查，不是 10 Hz 稳态 ECG 增益**。

## 结果（第 2 次运行，使用不交叠时钟）
| 情况 | 短窗阶跃增益 | 阶跃前 o 平均 | o 纹波 pp（最后 10 µs） | OTA 输出 oa 范围 | OTA 输入差 pp | 判断 |
|---|---|---|---|---|---|---|
| 理想 VCVS + 1 MHz chopper | **99.89** | 0.9009 V | 1.8 mV | 0.8 / 1.0 V（两相交替），死区时为 0 | 10 µV | 调制/解调和负反馈正确，增益约等于 Cc/Cfb |
| 真实 C + 1 MHz chopper | **11.98** | 0.787 V（偏移 −115 mV） | **339 mV** | 0.73–1.08 V，每半周期都没有建立 | 3.35 mV（虚地不成立） | **失败：带宽不够** |
| 真实 C 不斩波（时钟冻结，同一个 tb） | 94.13 | 0.9023 V | 16 µV | 0.996 V | 0.17 µV | 与 Round 3C 静态结果（94.22）一致 |

- 真实 C 斩波时，阶跃那一刻 o 的平均值跳了约 +19 mV，之后在窗口内持续下漂，没有稳定。
- DC OP（t = 0 时处于第 1 相）三组都正常：o = n ≈ 0.9 V，I_VDD = 283 nA。

**唯一一次修正（第 1 次运行 → 第 2 次运行）：** 第 1 次两相时钟的边沿重合。切换瞬间所有开关都处于半导通状态，有两个后果：
- OTA 两个输入端被同时接到 p 和 n 的中点，理想 VCVS 输出被瞬间拉到 0 V 附近。
- p 和 n 通过低阻的过渡态开关被短接，每个边沿都会分掉一部分信号电荷。

所以阶跃之后 o 先跳 +72 mV，然后逐周期衰减，200 µs 时只剩约 0（理想情况的阶跃增益为 −0.016）。第 2 次改为不交叠时钟后就正确了。第 1 次的数据保存在 `chop_summary_run1_overlapping_clock.csv` 和实验本 `_raw/.../run1_overlapping_clock/`。

## 没有做的事（遵守任务书）
- **噪声：** 没有做 PSS/PNoise，因为真实 C 在 1 MHz 下没有有效的信号工作。**噪声：未验证。** 没有用普通 noise 乘一个系数去“推算”降噪效果。
- **频率：** 没有回退到更低时钟频率，也没有做频率扫描。
- **电路：** 没有用 MOS 开关，没有改 OTA、VCAS 或偏置，也没有加 ripple 抑制。

## 等待用户 + GPT 决定
可以考虑的方向（都需要你们批准）：
- 用这台已验证的理想 chopper 测试台，把时钟降到明显低于 C 的带宽（例如几 kHz）再试一次，然后才谈 PSS/PNoise。
- 或者先提高 OTA 的带宽。

Round 4 的任务书已经出现在仓库里，但本轮没有启动。

## Cadence
- cell：`ece203_ss_chop_ideal_tb`、`ece203_ss_chop_c_tb`。设计变量 `chen` 控制是否斩波（0 = 不斩波），`vst`/`tst` 控制阶跃幅度和时刻。
- ADE state：`chop_1MHz_step`，包含 tran 200 µs 和收紧仿真选项。ADE 的 tran 无法通过 API 设置 maxstep，手动运行时请在 Analyses → tran → Options 里把 maxstep 设为 5n，否则 1 µs 时钟的边沿可能被跨过。
- job：`ece203_ss_chop`、`ece203_ss_chop_ade`、`ece203_ss_chop_probe`。
