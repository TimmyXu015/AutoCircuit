# ECE203 Round 4 — ECG 完整输入网络 × 主 OTA × DRL：限额综合冲刺（Chopper 最后加分）

**用户授权（2026-11-16）：** 本轮破例允许一个“刷牙洗脸期间”的较大自主工程任务。**不是**继续逐个独立器件，而是把 **(1) 三个电极/人体与输入耦合网络、(2) 已验证单级电容反馈主 OTA、(3) DRL 共模抑制支路**整合为**一个真实系统**，测试指标，允许**限额的小优化**；**主系统有结果后**才考虑一项理想 Chopper 加分探索。

阅读：`CLAUDE.md`、`AGENTS.md`、`docs/automation_playbook.json`、`docs/ECE203_round1_task.md`、`docs/ECE203_round1_results.md`、`docs/ECE203_round3a_length_results.md`、`docs/ECE203_round3b_pseudoresistor_results.md`、`docs/ECE203_round3c_ota_compare_results.md`、`docs/ECE203_round3d_ideal_chopper_ceiling_microtest.md`；检查是否已有 Round3D 结果（若已完成应阅读，不重复），并复用 `ece203_ideal_ecg` / `ece203_lp_out`、Round3C C OTA、Round3B pseudo-R。**Round 1 旧三级 INA 已弃用；严禁悄悄切回 A1/A2/A3。**

## 不可降低的作业硬指标（仅最终全部真实、整机测试后才算 PASS）

| 项目 | 目标 |
|---|---|
| 100Hz（或中频）差模闭环增益 | 40±2 dB（38–42dB） |
| 低频与高频 −3dB | 0.1Hz±10%；250Hz±10% |
| 总差模输入参考噪声 0.1–250Hz | **<3 µVrms** |
| 60Hz CMRR（DRL ON） | **>85dB**，还须报告 OFF |
| 输入端 `|Zin(10Hz)|` | >100 MΩ，**注明测量端口** |
| 全电路总功率 | <4µW @1.8V（<2.22µA，主 OTA、DRL、所有偏置和 VREF 一并算） |
| 设计总电容 | <1nF（不包含课程外部电极 3×50nF 与人体200pF，但包含设计 RC/补偿/DRL 电容） |
| 其他 | DRL loop PM、前向 NEF、系统输出是否越轨/失真；最终 mismatch MC 次数 >10 |

**只允许**一个至多 1.8V VDD 电源及一个**恰好 100nA**理想电流参考；输入/人体干扰激励源是 testbench 来源，必须明确注明。前期用于结构验证的**理想 VREF=0.9V、VCAS=1.05V、理想 DRL 增益源**只能标为 *diagnostic / 非源数量合规*，不得用其结果冒充最终满足源数量、功耗或真实 DRL Noise 的测试。真实 VREF 可尝试 VDD 分压，真实 VCAS/偏置需从 1×100nA 基准生成/镜像；如预算或时间不允许，列出缺口，不准静默用独立理想源。

### 已验证、不得虚构的新旧基线
- 单级 **S2**：两侧 `Cc=50pF`, `Cfb=0.5pF`, Rfb 理想3.1831TΩ；VDD1.8V、VREF0.9V。
- **Round3C C 主 OTA**：NMOS 输入10µ/8µ+PMOS镜像+单侧NMOS cascode，VCAS1.05V；增益 **94.22× / 39.48dB**、fL0.095Hz（使用**理想 Rfb**）、fH8.81kHz（**无输出 LP 和人体网络时**）、输入噪声 **16.1µVrms**、功耗 **0.510µW**；**M2 sat margin 仅47mV**。绝不把这些数值当成加载后整机指标。
- **Round3B 真实 pseudo-R**：`pfet33x` 3µ/2µ、零偏置微分电阻4.09TΩ，接进去 S2 后 fL0.0569Hz（当时 OTA 为**不带 cascode 的 L8u 5T**，因此不可直接推断新整机截止）。**gmin=iabstol=1e-18, reltol=1e-6**；报告过真实阱-衬底寄生未建模的限制。
- **Round1 理想完整 ECG** 已有 3 电极人体建模及理想 DRL（`ece203_ideal_ecg`）；可复用和对照电极拓扑，但**旧理想系统是三 OTA INA**，只借用人体/DRL网络，**不要复用其 A1/A2/A3 前向拓扑**。

## 全局安全/效率限制

- 新增独立 `Project/ece203_r4_*` cell，独立脚本与 `run.sh ece203_r4_*` job；保留旧 cells/ADE、旧脚本、用户手开的 Virtuoso/其他 Spectre 进程和 Windows lab notebook，**不得杀进程、不覆盖既有结果、不得上传机密 IBM PDK 模型、license、netlist/个人信息**。检查 ieng6 quota 并避免多套网表在同一个 cell 上并行写。
- 先把能跑的 baseline 结果保存，再每次只改一个参数；每条工作流**最多一次合理修线/偏置补救**。如果走不通，记录 blocker 并跳过依赖它的后续项目，**不能陷入无限 debug**。**每一项都标记 SIM PASS / SPEC FAIL / NOT RUN / BLOCKED**，不能把网表可跑混成 specs 全过。
- 最多 **1 个系统基线 + 2 个优化候选配置**（并不是每个指标都跑 2 次；不得组合海扫、自动遗传优化、多尺寸迭代）；主 OTA 只允许 **VCAS 的至多 3 点有理由调整（含原 1.05V）**来增加 M2 headroom，且调后必须重测增益。DRL 参数只允许 **一个** R0/gain/compensation 改动；输出 LP 只允许 **一个** RC 比例替代。若三个地方同时需要改，优先记录失败项而不是继续叠加变量。
- **优先级：真实三合一 DC+AC+DRL ON/OFF > 低通/假电阻与噪声 > 源数量/偏置合规 > MC > Chopper bonus。** 不要因为后面 bonus 卡住而丢掉前面已完成结果。

## A — 最先构建“真正三合一”完整信号路径

1. 新 `ece203_r4_ecg_tb` / 必要模块 cell：
   - **人体** body to ground：**200pF** 并联 `0.1µA @60Hz` 的干扰电流测试源；
   - **三个电极**（VINP、VINN、right leg）**每个** `2kΩ 串联 (1MΩ || 50nF)`。每个电极按旧 `ece203_ideal_ecg` 的实际端口/节点复制；不能把串联/并联位置接反，也不能偷偷绕过 electrode model；
   - 感测两个**耦合电容之前**的电极节点做平均共模（先沿用旧 `Rcm=10GΩ` 两路，或功能等效高阻网络），不得把正负两个电极直接短路；输入保留匹配两支 `Cc50p/Cfb0.5p` 及同一主 OTA 输入正负极性；
   - 主 OTA 使用 **Round3C C 单侧 cascode**，在此复制到独立 top cell，输出 DC ≈0.9V，保留可比较的理想 VCAS/reference 边界；
   - 先做**理想 Rfb** 校验系统，第二个对照版本才换 **Round3B 两只真实 pseudo-R**（端子接向参见 Round3B）；不能把 pseudo-R 结果误当成理想线性电阻。收紧 Spectre 精度，复核 DC/KCL。
2. **250 Hz 输出 LP** 是完整系统必需，开始沿用 `RLP=3.18MΩ, CLP=200pF`，务必放在**OTA 反馈取样点之后、外部输出之前**；前向最终输出在 LP 后。先检查 loading（在 LP 前/后读 AC、输出工作点）；若增益/截止因 OTA 高输出阻抗而崩溃，仅允许一次**同时间常数、减小电容并提高 R**的替代（如31.8MΩ/20pF，报告理想电阻在真实芯片的实现性以及输出阻抗/热噪声影响）。**不许自行插入二级 buffer**，也不许以无负载的 OTA gain 宣称 40dB 已满足。
3. 做基础 **DC OP + AC**：系统 `VDD` 电流、各 OTA、输入/输出 node、电极 body DC、所有级 headroom；`Hdm` 10/60/100Hz、fL/fH（幅度与中频的 −3dB）, 两种 Rfb 版本比较；输出 LP 前/后加载对比。对 `fL` 测量区间请覆盖至少 `0.01–1 Hz`，`fH` 至少 `100–1000 Hz`。在输入端（不包含外部电极器件）测 `Zin@10Hz`，同时给完整电极体外测 `Zin` 作为诊断，防止源端口误读。
4. 每个版本做 **0.1–250Hz Noise**（能测则报告）并核对输出 PSD 积分/输入折算与噪声贡献。请用真正最终输出/正确差模输入的 transfer 进行去嵌入，明确 `out_rms / midband_gain` 与逐点型差异；`<3µV` 是*全系统*目标，**不可单纯把 Round3C 16.1µV 复制作为整机结果**。没有完整真实 DRL 时暂标“前向链测试”。

## B — DRL：先验证极性，再尝试真实 DRL OTA

1. **DRL-OFF**：右腿驱动断开但不要丢掉 electrode/body 结构，可采用高阻隔离方式；先取 60 Hz 电极共模/信号路径输出，避免因理想 DC float 扭曲。注意 `0.1µA` 的体干扰可能导致 OFF 物理系统的 **非线性饱和**；大信号被动 AC 放大倍数不代表实际不饱和幅度。
2. **先理想 DRL**：利用旧 `ece203_ideal_ecg` 的**输入电容之前**高阻平均CM sense，并围绕 VREF 反相驱动，通过 **R0 初始1MΩ + 右腿电极**作用于 body。检查干扰输入极性、反馈 loop sign 和 ON/OFF body CM / 实际最终输出。建立真实动态反馈环时测 `stb` loop UGF / PM，不能拿纯记忆less VCVS 的 PM 冒充真实 DRL PM。可以用有限带宽的一极理想 DRL 作诊断，需标注假设。
3. **真实 DRL OTA 尝试（此次正式授权）**：优先克隆已经可运行的简单单级 OTA（可以直接选择 Round3C 的 B 5T 或其他经过验证、容易产生正确反相的 OTA）作为 DRL driver；允许 1 个直流偏置/极性修正。选择和解释 DC 工作点、驱动幅度/共模范围、所需源阻抗、60Hz 动态负载；如电流不足或输入偏置不对，记录真实 blocker，不可悄悄退回理想 VCVS 却宣称“真实 DRL 已通过”。
4. **必须分离两种不同测试**：
   - **CMRR@60Hz**：在定义好的输入电极/身体公共模态上施加小信号 `vcm`，在**同一电气条件**下测最终输出 `Acm` 与差模 `Adm`，公式 `20log10(|Adm/Acm|)`。要同时报 **DRL OFF vs ON**，并说明输入参考节点、增益定义、是否使用失配（如 (Cc) 一侧1%误差；理想完全匹配时不要报告无穷大假 CMRR）。
   - **0.1µA@60Hz 人体电流干扰抑制**：另独立测 `Vbody`、电极CM、最终输出在 OFF/ON 的幅度，以及输出/轨余量；这**不是**直接等价于 CMRR。
   - DRL 真实反馈的 loop gain & phase margin（STB 如可能；用可解释的断环注入位置，若不可信标为 unresolved）、输入阻抗是否被 CM sense/DRL 闭环破坏。
5. 主 OTA 0.047V M2 headroom 非常脆弱；在 DRL OFF/ON / 输入变化下检查 clipping 可能。不要因为理想 DRL 高增益“使共模归零”就跳过真实输出摆幅。
6. DRL 电流、参考支路、任何输出安全电阻都计入实际总功耗和条件说明，外部 R0/electrode 不是“已经经过人体安全认证”的声明。

## C — 总结优化、实际偏置、系统指标复核（只动少量 knobs）

1. 如有明显 loading、M2 saturation headroom、或 DRL 稳定性不达标，仅做 A/B 中许可的一次改动。对被选配置重测关键 DC/AC/Noise/DRL 指标，记录**before/after**，不要叠加多次调整。
2. **真实偏置/源数量**：优先将 VREF 用 VDD/2 真实分压得到，VCAS 用参考/分压/简单镜像生成，沿用**一个 100nA**理想 reference 的总偏置；**允许一版简单实现，不许设计复杂的 bandgap 或额外调压芯片**。正确计入分压和参考镜像电流、DRL 电流。若不能完成，明确列成“理想参考源依赖 — source budget FAIL/pending”，而非假装合规。
3. **总电容台账**：列出 2×Cc + 2×Cf + output CLP + DRL compensation + 任何 VREF decap/时钟电容；另外列出独立排除在设计预算外的 3×50nF electrodes + body200pF。追踪任何改变输入信号 / feedback 导致的额外电容。
4. **仅当完整真实系统稳定、算力允许时**，以最少 **12 次** Monte Carlo mismatch 对一个**冻结配置**测 **gain、fL、fH、CMRR**，失败/缺模型也记录。**不要扫描 PVT、不要为 MC 自动优化；MC 结果中未满足的样本不可以丢弃。** 若 MC 支持需设置明确的工艺/失配模式，不可假称工艺 MC 等于 mismatch MC。
5. 最后整理 **NEF**（必须展示使用的噪声、电流、有效带宽和计算公式/假设，避免以概念估算冒充符合课程定义），同时列出有无 DRL / Rfb / LP 的噪声差异，指出哪些硬指标已通过、哪些还缺乏实测证据。

## D — Chopper BONUS（只有 A/B/C 关键结果已经保存）

- **若 Round3D 1MHz 理想 clock/switch 已有结果，先阅读，不要再跑重复高成本测试。** 用户之前明确设 **1MHz 为理想极限演示**，不能偷换成宣称“真实 OTA 可以跑1MHz”；冻结 C 的 fH≈8.81kHz，极可能不具备1MHz建立能力。
- 此阶段只允许**一个 bonus 技术观察**：有现成 1MHz ideal-VCVS + ideal-clock 测试可沿用；若要证明真实 OTA 的 Chopper 降噪，**必须选取依据当前实测带宽的一个单一、可解释的 kHz 级理想 clock 频率**并明确它不同于用户的 1MHz“极限测试”（如 fch=1kHz 仅作为有理有据的候选，不是扫描），仍然使用理想无噪声 switches、无噪声 clock，**不能靠完全无噪声 VCVS 的 noise 结果来宣称低噪声达标**。
- 仅当信号解调正确 / 不越轨 / 调制 OTA 能跟上时，最多一次 **PSS/PNoise（或等效可信周期噪声）**尝试；不成功就标 `BONUS BLOCKED / NOISE UNVERIFIED`。绝不从普通 noise/AC 或简单乘因子捏造 chopped noise。注意 PAM/cyclostationary sidebands 的正确选择、外加滤波与 baseline 对照公平。
- **不得**实现晶体管 MOS switch、完整 Harrison、附加第二级、chopper 自动扫频、长于数万个开关周期的“大逃杀”tran。bonus 不是完成主任务的前置条件。

## 可交付结果 / 最后停机标准

**即使某一阶段失败也必须提交主报告** `docs/ECE203_round4_integrated_results.md`，精简四段（A 信号链、B DRL OFF/ON、C limited tune + final spec table、D bonus）：
- **明确每个测量到底是**真实 transistor / ideal-VCVS DRL / ideal VREF/VCAS / pseudo-R / ideal Rfb；不要用一个“整机 PASS”掩盖部分理想块。
- `docs/ece203_data/round4/` 至少 `r4_spec_matrix.csv`、`r4_system_cases.csv`、`r4_drl_60hz.csv`、`r4_summary.png`（能生成就生成，失败可给 raw traces 和 log），附精简 OP/AC/noise/STB/MC 文件（只上传必要的可复核数据）；记录 VDD 电流、功耗、电容预算、margin、case、测试节点、数据单位与实际仿真状态。
- Cadence cells + ADE states + `run.sh` job 清楚可复现；短日志放 Windows `AutoCircuit_Results` 实验目录，repo 公共文件不含机密。
- **最终三行总结**：现在哪些真实指标已经 PASS、最严重剩余 blocker、下一个最小单点实验是什么。**跑完停止，不继续无边界优化。**

**注意：** 本任务由用户授权“终极综合大任务”，可以比 Round3 小实验长，但所有大工作都必须在保存了独立阶段结果后继续；不要把 A–D 做成一个失败就无法交付的单片脚本。
