# ECE203 R7A — 真实 MOS 连续时间 CMFB：线性度优先的受限验证

任务性质：**研究分支；不得改变或覆盖已通过的 R5N-F、R6A–R6D-R 电路及数据。**
目标：以 **真实 MOS 连续时间 CMFB** 替换 R6D-R 中的理想线性 CMFB；其余真实 FD OTA、双真实 TG Chopper、DRL、MOS CD 保持不变。理想 VPULSE、VREF、VCAS、参考电流和理想 Rfb 允许保留。本任务**不涉及** MOS 参考源、数字时钟发生器、pseudo-R 接入、noise、PSS/PNoise、Monte Carlo、PVT 或新增第二级。

## 0. 必须先阅读并核对的基线
- `docs/ECE203_round6a_drl_cmfb_coupled_results.md`：真实 DD-pair CMFB（`ece203_r6a_cmfb`），DC 共模 0.8789 V；CMFB PM 73.5°，DRL PM 90.3°。
- `docs/ECE203_round6b_real_mos_chopper_results.md`：两组真实 CMOS TG，2 kHz/4 kHz 斩波；原 DD 检测器在 100 Hz 差模摆动下产生约 3.52 mV 的 200 Hz 共模分量。
- `docs/ECE203_round6c_ideal_cmfb_results.md`：同一真实 MOS 被控对象换为理想线性 CMFB 后，输出共模约 0.90015 V、200 Hz 共模约 4.7 µV，CMFB PM 87.8°；**理想上限，不是 MOS 指标**。
- `docs/ECE203_round6d_mos_cd_buffer_results.md`、`docs/ECE203_round6d_chopper_tran_recovery_results.md`：已有真正的 4 管 NMOS CD、10 pF 负载隔离、60 ms 斩波瞬态；其余部分必须冻结。
- 代码源：`ece203_r6a.il`、`ece203_r6b.il`、`ece203_r6c.il`、`ece203_r6d.il`、`ece203_r6dr.il`。阅读 `AGENTS.md`、`CLAUDE.md`、`docs/automation_playbook.json`。
- **独立检查**现有网表电源接法：早期 R6A/R6D 的 `VDD`、`VDDD` 看起来是分别对地的独立 1.8 V 源；R5N-F 才用串联 0 V 电流表。不能套用 R5N-F 的计数方式，也不能未经核对就重复计数。输出报告注明网表根据与计算方式。

## 1. 设计问题（需分开解决）
旧 DD-pair 用两个 50 nA NMOS 差分对（`MA1/MA2`、`MB1/MB2`）比较 `OP/ON` 与 `VREF`，共模误差经二极管 PMOS `MD` 变成 `VCMFB`，去驱动真实 FD OTA 的 PMOS 负载栅。
- **DC 偏差**：旧 `MD` 与主 OTA M3/M4 的电流镜比例/工作点不匹配，`Vout,cm≈0.8789 V`；仅改善这点不等于改善线性。
- **差模串入共模**：`Vop=Vcm+Vd/2`、`Von=Vcm−Vd/2`；在大差模摆幅下，DD-pair 的非线性即使对称也存在偶次项。R6C 已通过 A/B 证实这不是主 OTA 单独导致的。
- **不能**只靠提高 CMFB 环路增益、调电阻分压、钳输出或理想 VCVS 隐藏检测器非线性。新控制器输出 `vg` 必须由真实 MOS 产生（参考/偏置输入可理想）。

## 2. 拟议 MOS 方案及停机门
执行前给出**简短的晶体管级候选拓扑说明**：输入 `OP/ON/VREF`、MOS 共模检测、误差放大/转换、`vg` 输出、偏置、反馈符号，尤其说明为何相对旧 DD-pair 扩大差模线性范围。初始建议：保留真实 MOS 连续时间 DD 架构，但**提高输入对线性范围**（例如强反型/适当源极退化）；源极退化若使用电阻，应落实为实际 MOS 退化器件，不得把理想高阻元件当成最终解决方案。可提出另一种更合理、完全由 MOS 组成的连续时间 sensing topology，但必须写清物理机制和尺寸，不能直接套入理想平均器。如果仅有尺寸校准无法满足线性要求，诚实报告失败；**不要循环无界优化**。

分三步，严格 gate：
1. **Baseline/静态复现**：只读原 cell；复现静态旧 DD、理想 CMFB 的 `Vcm/H100/stb` 基线。用新 `Project/ece203_r7a_*` cell 与新脚本，不重建老 cell。
2. **独立传输/大信号检测器测试**：对固定共模约 0.9 V 的 `OP=0.9+Vd/2, ON=0.9−Vd/2`，扫描 `Vd={-0.20,-0.10,-0.05,0,+0.05,+0.10,+0.20} V`，还要扫描少量 `Vcm` 误差（如 0.88/0.90/0.92 V）。记录检测器关键节点、电流、`vg`、饱和余量、控制器对差模的偶次敏感度和 `dvg/dVcm` 极性。**先解决 DC 零点与线性，之后才加斩波**。可测试一个 DC 校准的旧 DD-pair 作为隔离对照，但不能误称它为线性化架构。允许最多 **两种明确不同的 MOS 方案**、每种最多 **两轮针对性偏置/尺寸修正**；保留全部结果和理由。
3. **系统集成**：在 R6D-R 的 `BUFFERED 10 pF` 及可选 REF 测试台仅替换 CMFB，`XCI/XCO` 真 TG、主 OTA、真实 DRL、CD、时钟、负载完全不动。先 TG 停在 A 相，测 DC/AC/CMFB STB/DRL STB，再进行 2 kHz、60 ms 真实 TG tran。数值设置优先沿用 R6D-R 已验证的 `tran cmin=1e-17 F`，记录全部 tolerance 和 Spectre 回显。查验 `VSPS sinephase=0` 防止 Virtuoso CDF 沿用旧相位。

## 3. 验收标准（先登记，不得事后更改）
- MOS CMFB 确有可追踪的 PDK NMOS/PMOS 实例；**没有理想 VCVS/受控电流源充当共模控制器**；`VREF/VCAS/IB/VPULSE` 理想源允许。输出共模来自真实反馈，不得硬夹 `op/on`。
- TG 静止、DC：`(op+on)/2` 接近 0.900 V，目标 **误差 <=1 mV**；`vg` 不撞轨；主 OTA 和 CMFB 关键管在可用工作区，列出最小 VDS/VDSAT 余量。
- TG 静止、`stb`：CMFB PM **>=60°**，DRL PM **>=60°**（测两个闭环）；DC/AC、100 Hz 前级增益对理想 CMFB 基线变化 **<=5%**。
- 2 kHz TG tran（20–40 ms 和 40–60 ms 两个窗口）：完成完整 60 ms；不持续振荡、不漂移、无削顶，输出共模平均偏差 **<=1 mV**；100 Hz 差模增益变化 **<=5%**；**200 Hz 输出共模分量 <=0.20 mV（目标，比旧 3.52 mV 至少小约 17 倍）**。它是务实工程目标，不要求立即达到理想控制器 4.7 µV。输出边沿尖峰、恢复时间和 `vg` 波形必须测量、不能只报告均值。
- 记录新增 CMFB 的静态电流、总功耗（每一路供电都按实际网表测量），与旧 CMFB 的约 102.5 nA 增量对照；目标控制器自身电流 <=0.5 µA（偏离须说明）。
- **若任何 gate 失败，明确标记 NOT PASS 并停止在该阶段**；不要为了 PASS 无限延伸，也不要换用户未授权的大拓扑/引入 SC-CMFB、RRL、OTA2、额外时钟。这轮**不宣称噪声改善**。

## 4. 运行与证据纪律
- 所有新脚本用 `ece203_r7a*.il` 和 `batch/ece203_r7a_*.il`，新 cells `ece203_r7a_*`。不得覆盖历史 `R5N-F`、`R6*` 仿真、ADE state、数据或 Github 结果。
- 每个案例记录 netlist 元件/模型/偏置核对、dcop、STB/AC、Spectre log、结果 CSV、分析脚本与关键波形图（含 200 Hz harmonic 的提取方法）。用至少两个相邻 20 ms 窗口对照，**不能拿单个截图代替定量**。
- 服务器 home 配额最后记录仅剩约 12 MB。必要时使用 `/tmp` 独立目录存 PSF 与临时 Git clone，`AC_SKIP_GIT_PULL=1` 固定脚本版本，记录实际 commit；清理仅本轮生成的缓存，不触碰用户别的进程或旧数据。给每个 Spectre 长 tran 设 watchdog/有限运行时间，失败保存日志后停止。
- **预期提交**：`docs/ECE203_round7a_real_mos_cmfb_results.md`、新脚本、`docs/ece203_data/round7a/` 下的数据和图、必要日志。明确列出 baseline / candidate / integrated 的 PASS/FAIL/NOT RUN，commit 回同一 GitHub 仓库。
- 若用户/教授的交付截止迫近：先保证可复现的微型实验和简短结果，不要牺牲 R5N-F 正式主线交付。

## 5. 立即执行的第一步
先根据 R6A 的真实 `r6CmfbDevs` 及 R6C 对照报告，设计**至少一种明确的真实 MOS 线性化方案**，画/输出器件连线清单和偏置假设，然后进入第 2 节的 standalone DC sweep。**只有独立检测器的线性和 DC 行为可接受才进入 full 60 ms。**
