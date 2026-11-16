# ECE203 Round 3B — 课堂 MOS–Bipolar Pseudo-Resistor：一个小实验

**2026-11-16 用户选择：** 暂停 OTA 增益优化，先实现课堂所讲的“假电阻”，替换单级电容反馈 BioAmp 的理想 Rfb，验证真实的 0.1 Hz 高通。**只做器件独立小测 + 一次 S2 闭环对照；不得扩大实验。**

## 读完再动手
- `CLAUDE.md`、`docs/automation_playbook.json`、`docs/ECE203_round3_single_stage_results.md`、`docs/ECE203_round3a_length_results.md`；沿用已经验证的 SKILL/OCEAN + `run.sh` 流程，保护已有 cell/原理图/ADE/仿真数据和用户 Virtuoso 会话。
- 教授 **Lec8–10 BioAmp** 的 MOS-bipolar pseudo-resistor 段落（Lecture 9，2026-10-12 字幕可参考）：单器件 PMOS 与寄生 PNP 的两个方向导电；教授建议检查 **thick-oxide I/O MOS**，有需要时用较长 L/串联。**不要从口头描述猜引脚**：按课件原图核对 gate/drain/bulk/source 连接，并检查 IBM PDK 的真实可用器件、bulk/well 限制及额定电压。若 PDK 不支持，明确报告 blocker，不能用理想电阻伪装成实现成功。

## Stage A：先把两端口器件测明白（必要门槛）
1. 新建独立 `Project/ece203_ss_pr_cell` 两端口 pseudo-R + `Project/ece203_ss_pr_iv_tb`，最简单的课堂实现即可；**最多一个基础尺寸 + 一个有根据的轻微调整**，别扫描几十组参数；不要 Cascode、Buffer、第二级、chopper、开关电容。
2. 两端施加共模约 **0.9 V**、差模小电压；实测 **I–V（−50 到 +50 mV，包含 −10/−5/0/+5/+10 mV）**，记录每个点的电流与增量电导 `g=dI/dV`、局部 `r_d=1/g`，尤其是零偏置与 ±5 mV。若数值受 Spectre gmin、泄漏或求解精度支配，记录证据，**不要**宣称测得 TΩ。
3. 目标量级：在实际偏置附近 `Rfb ≈ 3.183 TΩ`（因为 `Cfb=0.5 pF`、理想 `fL=0.1 Hz`）。仅报告达到与否、正反方向差异和敏感性；暂不要求满足所有 PVT/失配规格。提醒约 5 mV / 3.18 TΩ 对应电流仅 ~1.6 fA，极易被泄漏与数值误差影响。

## Stage B：只在 Stage A 可信时做一次替换
1. 新建独立 `Project/ece203_ss_pr_tb`，从已验证单级 S2 复制接法，**不要覆盖旧 cell**。选 **Round 3A 的 L=8 µm 普通 5T OTA**作为冻结起点（非 Cascode）；其余保持 `Cc=50 pF`/侧、`Cfb=0.5 pF`/侧、VDD=1.8 V、VREF=0.9 V、CL=0、相同差模源与偏置。两只理想 `Rfb=3.1831 TΩ` 分别替换为两个**相同真实 pseudo-R**：反馈到 OTA 输出的一条、正输入到 VREF 的一条；注意器件正反方向和 DC/AC 偏置。
2. 同一个新测试环境里对照 **理想 Rfb vs 真实 pseudo-R**，仅 DC OP + AC：记录输出/两个 OTA 输入节点 DC、`|Hdm(10/100Hz)|`、`fL`、实际两只 pseudo-R 的 DC 端电压与电流、是否存在求解或偏置失败。不要调整其它参数来掩盖差别。若 Stage A 不可信就不做 Stage B。
3. **禁止** Noise、STB、tran、PVT/MC、面积/匹配海扫、OTA 增益/尺寸优化、DRL 和 250 Hz LP。不要添加理想并联大阻值来“帮 pseudo-R 工作”并声称已替代；如求解必须使用额外导通路径，清楚标注这只是数值调试而非真实器件性能。

## 快速交付与停止
- 一张表 `docs/ece203_data/pseudoresistor/pr_iv.csv`（器件 I–V/局部电阻），一张表 `pr_s2_compare.csv`（若 Stage B 执行），简短中文总结 `docs/ECE203_round3b_pseudoresistor_results.md`。不需要大量图片或复杂测试矩阵。
- 新 job 与 cell 独立，复用 playbook；注意 ieng6 quota，绝不动旧课程设计、模型或用户 GUI。公开 GitHub **不上传任何机密 IBM PDK/模型、私有 netlist、许可文件**。
- 完成即停止，等待用户与 GPT 决定后续。结果若未达 0.1 Hz 也应正常交付。**本轮目标是识别物理 pseudo-R 的真实行为和困难，而不是强迫通过所有项目指标。**
