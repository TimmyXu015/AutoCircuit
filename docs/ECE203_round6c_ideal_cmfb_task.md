# ECE203 Round 6C-I — Ideal CMFB in a Real MOS System

**状态：任务书已冻结；尚未执行本轮 Spectre 仿真。**  
**目标：**用 R6B 已验证的真实 MOS 全差分 OTA、真实 TG Chopper、DRL、电极/反馈平台，仅把 CMFB 控制器替换为理想连续时间线性结构，在**同一外围电路**上完成公平 A/B 实验。该轮证明架构是否可行、是否有实际改善；不声称新 CMFB 可直接流片。

## 0. 先阅读并记录基线

必须阅读：
- `docs/ECE203_round6a_drl_cmfb_coupled_results.md`
- `docs/ECE203_round6b_real_mos_chopper_results.md`
- `ece203_r6a.il`、`ece203_r6b.il`
- `CLAUDE.md`、`docs/automation_playbook.json`（如有）

参考 R6A/R6B 的 `ece203_r6b_fd_tg_tb`、`ece203_r6a_fd_ota` 和真实 DD-pair CMFB。R6B 旧 CMFB 静态共模约 0.8789 V，2 kHz TG 工作时可产生共模毛刺与 200 Hz 分量；这些是**历史线索**，本轮比较必须在相同新测试条件下重测，不能直接拿旧表数值代替 A/B。

在结果报告写清实际复现实验的 Git commit SHA、PDK/model corner、温度、Spectre 版本（可取得时）、运行入口、全部关键仿真选项。

## 1. 冻结外围电路；CMFB 是唯一实验变量

- VDD 1.8 V、VREF 0.9 V。
- 复用 R6B 的真实 MOS FD OTA1、两组真实 TG Chopper、2 kHz 理想时钟、真实 DRL OTA、人体/电极模型、反馈及负载。
- **不增加 OTA2**。不改变 OTA1 晶体管尺寸、Chopper MOS、偏置、电极、反馈网络和负载。
- R6A/R6B 当前仍有**理想偏置、理想时钟、理想 Rfb**；必须如实标注。
- 全新 `ece203_r6c_*` schematic、testbench、SKILL 和 ADE state；不得覆盖既有 R4/R5/R6A/R6B cell、ADE 或数据。

旧组：真实 MOS DD-pair CMFB；新组：下述理想线性 CMFB。对照时其它条件完全一致。

## 2. 待验证的理想 CMFB 电路

**检测器：**
```
vsense = (VOP + VON)/2
e = vsense - VREF
```
用高输入阻抗、对 OTA 输出不施加额外负载的理想受控源实现。探测节点和物理执行节点要明确区分。

**误差放大器：**
```
VCMFB(s) = VB + [A0/(1+s/wp)] * (vsense(s) - VREF(s))
```
- 连续时间、有限 DC 增益 A0、有限极点 wp/带宽；不得采用无限瞬时增益。
- 实现与 Spectre 兼容，可用受控源 + RC/限幅器，或受支持的行为模型；记录完整实现和所有参数。
- VCMFB 目标由真实 PMOS M3/M4 Gate 接收；保证输出控制的**电源轨限幅**合理（0–1.8 V），避免直接钳位 VOP/VON。
- 初始 `VB` 可参考 R6A 的 VCMFB≈1.325 V，但必须记录并明确它只是控制器偏置，不是隐藏的自动闭环校准。
- 核实极性：Vout,cm 上升 → VCMFB 上升 → PMOS 上拉电流下降 → Vout,cm 下降。
- 如果单极点控制器不能稳定，允许**一次**有根因支持的极性/补偿修正，并保留失败数据；不得靠任意大规模扫描掩盖设计缺陷。
- 理想控制器并不意味着零功耗的物理实现。所有功耗对比仅针对现有 MOS 系统，不得把理想控制器的功耗当成 0 来宣称优势。

## 3. Stage A：Chopper 静止直通——证明闭环能运行

使用 R6B 静止 A 相（TG 直通），分别跑旧/新 CMFB：

1. **DC**：VOP、VON、Vout,cm、VCMFB、PMOS VSD/VDSAT、关键器件工作区。新 CMFB 目标 `Vout,cm=0.900±0.001 V`，控制节点不撞电源轨。
2. **AC**：100 Hz 差模增益相对 R6B 静态基线约 94.56 V/V，变化不超过 5%；核实 CMFB 不破坏差模信号。
3. **STB**：在 CMFB 断环点测正确 return ratio、UGF、PM≥55°；DRL 在 CMFB 闭合下保持稳定。记录主要极点、零点及测量/估计方法。
4. **输出共模扰动**：两侧各注入相等小电流（初始 1 nA/side），AC 或 transient 测闭环抑制、恢复和差模串扰。另检查反馈极性与无持续振荡。

**门槛：Stage A 不通过，停止，不跑后续 Stage。** 不得使用理想电压源直接把两路输出固定在 0.9 V。

## 4. Stage B：关闭 Chopper，测差模 → 共模非线性

旧/新 CMFB 在完全相同条件下输入 100 Hz、1 mV 差分正弦；必要时加一个低幅对照点，但不要大范围幅度扫描。

对比：
- 输出共模 DC 偏差（目标 0.9 V）；
- 共模波形 200 Hz 分量（说明测量窗口及 FFT/正弦拟合方法）；
- VOP/VON 差模摆幅与增益；
- VCMFB 波形、摆幅、Headroom；
- 有无非线性削顶。

历史 R6B 在斩波条件下观察到约 3.5 mV 的 200 Hz 分量；本阶段的**无斩波同条件 A/B**用于分辨 CMFB 检测非线性与 OTA 本征非线性，不能直接推定新 CMFB 一定消除全部 200 Hz。

## 5. Stage C：启用原 R6B 真实 TG Chopper

仅在 Stage A/B 成功后启用 2 kHz 两相 TG；真实 MOS、其余理想化外围维持冻结。旧/新 CMFB 均跑 60 ms transient，使用相同 100 Hz、1 mV 差分输入。

量测：
- 100 Hz 差模增益（参考 R6B 旧基线约 93.23 V/V），新电路不得劣化超过 5%；
- 输出共模平均值、200 Hz 分量、稳态峰峰值；
- TG 翻转边沿共模毛刺和恢复时间；
- VCMFB 与 VOP/VON 波形、电源轨/饱和检查；
- 20–40 ms 和 40–60 ms 统计量是否一致，确认无明显漂移。

本轮**不跑 PSS/PAC/PNoise、Monte Carlo/PVT**；R6B 的 PSS 曾未收敛，不要把不收敛结果当成证据。

## 6. 严格比较与判定

- **ARCHITECTURE PASS**：真实 OTA + DRL + 2 kHz TG 下，新理想 CMFB 稳定控制输出共模，保持差模信号且没有饱和/持续漂移。
- **VALUE PASS**：在同条件 A/B 中，DC 误差、差模相关共模失真或动态纹波至少一项有明确可量化的改善。
- 可分别标记 `ARCHITECTURE PASS / VALUE NOT YET PROVEN`、`FAIL`。
- 理想元件只能证明潜在性能上限和控制路线；不得据此宣称晶体管级实现、零噪声、零功耗或硅片合格。
- 限制约 6–8 组主要仿真案例；遇到根本问题先报告并停止，不要自主扩展成 R6D/OTA2/RRL/SC-CMFB。

## 7. GitHub 可复现交付（必需）

- **任务书**：本文件 `docs/ECE203_round6c_ideal_cmfb_task.md`。
- **源代码**：`ece203_r6c.il`（如使用 Verilog-A 或额外 models，全部随 repo 提交，或说明模型许可证限制及依赖）。
- **报告**：`docs/ECE203_round6c_ideal_cmfb_results.md`，首段先给两个 PASS/FAIL 判定。
- **数据**：`docs/ece203_data/round6c/`，含 summary CSV、原始 DC/AC/STB/tran 数据、频谱/图、必要的 log、控制器参数表和关键工作点。
- **复现**：报告列出从干净环境执行的任务名/命令顺序、环境/库/PDK 依赖、输入参数、输出目录、预期测试数量、实际 commit SHA 和结果核对方法；不要把本地 `~/AutoCircuit_results/` 当作唯一证据。
- 如果完整 PSF、网表或日志过大/受 PDK 许可限制，记录原因与校验信息，并至少保存所有用于结论的可再计算 CSV 与生成脚本；不要提交未经允许的 PDK 模型。
- 结果与源代码作为同一 Git 版本体系的提交交付；保存失败/中止原因，禁止伪造 PASS 或覆盖旧结果。

**执行终点：**独立证实理想 CMFB 通过真实 MOS 负载控制输出共模，有可复查的 A/B 数据与 GitHub 记录。完成后 STOP，不进入真实 CMFB 器件设计。
