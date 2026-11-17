# ECE203 R6D-R — Chopper 瞬态数值收敛恢复（只救 Stage B）

> **授权范围：**用户同意额外一次**受限排障**，不更改 CD / OTA / CMFB / DRL / Chopper 架构，也不修改旧实验原始数据。本文件为 R6D 失败后的续跑任务，不替换最初 R6D 任务书。执行后停止并提交证据。

## 0. 前置事实与必读

先读并遵守：
- `docs/ECE203_round6d_mos_cd_buffer_results.md`（包含失败日志、已完成 Stage A）
- `docs/ECE203_round6d_mos_cd_buffer_task.md`
- `ece203_r6d.il`、`ece203_r6c.il`、`run.sh`、现有 batch 入口
- `docs/ece203_data/round6d/raw/stageB_attempt2_gear2only/B_ref_spectre_out_excerpt.txt`

已经证实：
1. R6D Stage A 静态 DC/AC/STB **全部 PASS**，不要重复大规模重新设计。10 pF 下 DIRECT 带宽 423 Hz，BUFFERED 8.13 kHz，CD 局部增益 0.8425，buf CM 0.5427 V，CMFB/DRL PM 正常。
2. R6D Stage B 原先 **默认 trapezoidal** 的 REF 与 DIRECT 1pF 能完成 60 ms；BUFFERED 1pF 在第一个 TG 翻转 `t≈250 µs` 时间步缩至几十～几百 attoseconds。报告有 `Found trapezoidal ringing on node XA.MT.s1` 提示。
3. 改成 `gear2only` 后连 REF 也在 250 µs 时间步塌缩，所以**不能再把 gear2only 当作修复**。先还原默认积分法。
4. 当前原有选项 `iabstol=1e-17 A, gmin=1e-18 S, cmin=0` 较严格；新诊断须一次只改一个数值参数，并检查结果是否受影响。
5. Home quota 曾只剩约 12 MB。不能因为空间问题误判为 Spectre 失败。

**失败不是电路不可行的证据；但收敛成功也不保证波形物理正确。**

## 1. 保证可执行与数据安全

- 使用新的 R6D-R job（例如 `ece203_r6dr_probe`、`ece203_r6dr_full`）和独立输出目录 `/tmp/<user>_r6dr/`；不用覆盖 R6A/R6B/R6C/R6D 的 cells、ADE、脚本或 raw。
- 复用 R6D 的 BUFFERED/DIRECT/REF schematic。保持 MOS W/L、偏置、负载、理想 CMFB 参数、脉冲时钟与 10 ns deadtime **一字不变**。
- 在运行前检查 home quota / `du -sh ~/AutoCircuit ~/AutoCircuit/.git`。当前 `run.sh` 启动会自动 `git pull -q`；**不得让重复 pull 或历史大 CSV 数据把 home 填满**。若已经包含当前任务代码，可为诊断 job 引入受控的 skip-pull 开关（例如 `AC_SKIP_GIT_PULL=1`），准确记录所用 commit；不要盲目声称 sparse checkout 可以压缩既有 `.git` 历史，也不要删除已提交原始数据、项目源码或用户其它进程/文件。必要时把可重建 PSF 放 /tmp，保存每轮精简日志。
- 仅中止**本任务启动的** Spectre/Virtuoso 子进程。每轮诊断设置合理运行守护：监控 250 µs 后仿真时间是否前进，若数分钟仍持续 attosecond 步长且无时间推进，终止该用例、保存 spectre.out 和日志，不无限空转。
- 对 PDK 模型、器件 CDF、B/C 输入相位完全不做修改；确认 `VSPS sinephase=0` 保留。
- 不把完整专有 PDK 模型提交 GitHub。

## 2. 最小可解释诊断（只跑到 1 ms）

**固定：**2 kHz TG，`vd=1 mV`、`fin=100 Hz`，原 R6D BUFFERED 1pF，`maxstep=0.5 µs`，先设置 `stop=1 ms` 确保覆盖多次 TG 边沿。只改变以下一个数值选项，先成功过第一个 250 µs 边沿。

A. **恢复 trapezoidal / 默认方法**，不使用 `gear2only`；保留其它选项。该基准应如实记录之前卡住的现象，若仍卡住不要长时间等待。

B. **首选救援：只将瞬态求解中的 `iabstol` 从 `1e-17 A` 放宽到 `1e-15 A`**，trapezoidal 不变，其余容差、模型、信号不变；通过 Spectre 实际日志核实选项生效。若失败，在 A/B 对照上标注失败位置/警告。

C. **若 B 仍失败：撤回 B 的容差变化；只加极小 `cmin≈1e-17 F`**（选项/合法写法以本 Spectre 版本为准）。先核实是否生效，观察每一个步长和过零时刻，并评估该数值附加电容是否可能扭曲快沿毛刺/内部节点波形。不要同时改变 `iabstol`、`cmin`、`gmin` 和时钟边沿。

上面两种救援方式是相互独立的控制变量测试，**不授权更多参数随机搜索**。若两者都无法让 BUFFERED 1pF 越过前两个 TG 边沿，记录证据后 STOP，不能私自改电路。

建议在诊断时顺手用 Spectre `diagnose`、`+diagnose` 或支持的收敛诊断选项记录“正在重复迭代的节点/器件”，但要先核实当前版本语法；记录 `XA.MT.s1` 的日志原文而非推断真因。

## 3. 短程复核及完整 Stage B

若 B 或 C 能稳定推进到 1 ms：
- 用**同一种已验证数值设置**分别跑 REF、DIRECT 1pF、BUFFERED 1pF 的短程实验，并和已经完成的旧默认法 REF/DIRECT 1pF 结果比较。记录 250 µs 边沿波形、`op/on`、`fp/fn`、`bufp/bufn`、`vg` 和主要电流；若在重要指标或开关毛刺上出现显著数值敏感性，暂缓宣称物理通过。
- 通过短程一致性验证才运行完整 60 ms 的原 Stage B：REF、DIRECT 1pF、BUFFERED 1pF、DIRECT 10pF、BUFFERED 10pF。保留 20–40 ms 与 40–60 ms 两窗，记录差模增益、缓冲局部增益、输出 CM、开关峰值/恢复时间、DC/AC 工作区对照和功耗。重点是 **同样的 10pF 负载 DIRECT vs BUFFERED**。
- 如完整长程仍出现新的步长塌缩，记录停止处与原始日志，不无限自动补偿、改尺寸或重写 Chopper。
- 使用原 `r6d_analysis.py` 的既有指标定义，必要时扩展脚本以包含所有成功用例，不覆盖原 `r6d_stageB_summary.csv`。新增分析脚本和所有实际使用的求解设置均提交 GitHub。

## 4. 严格验收

分别报告：
- **NUMERICALLY RECOVERED / NOT RECOVERED**：能否稳定跑完 BUFFERED 1pF 与 10pF 的两相 TG 实际 MOS transient。
- **INTEGRATION PASS / NOT PROVEN**：真实 CD 接入且完整时域下工作点、振幅、增益、CMFB/DRL 无漂移/不正常振荡。静态 STB 不能替代 2 kHz 时变环路动态验证。
- **BUFFER VALUE PASS / NOT PROVEN**：10pF DIRECT 与 BUFFERED 同负载、同设置下，是否有可复查的波形/建立/失真/负载隔离证据。

**数值求解设置变化后，严禁直接比较“新 BUFFERED”与“旧容差 DIRECT”来证明价值**；两组必须使用相同设置。静态已观测的高带宽可保留为辅助证据，不能冒充斩波稳定证据。功耗 R6 需把**独立** 1.8 V 供电的 I(VDD) 与 I(VDDD) 相加，并明确理想 CMFB 功耗未计。

## 5. GitHub 交付与 Stop

- 续跑任务书：`docs/ECE203_round6d_chopper_tran_recovery_task.md`（本文件）。
- 新脚本/入口：优先 `ece203_r6dr.il` 与 `batch/ece203_r6dr_*.il`，不要覆盖 R6D 历史失败记录。
- 报告：`docs/ECE203_round6d_chopper_tran_recovery_results.md`，首段给明确结论与失败/成功边界。
- 数据：`docs/ece203_data/round6dr/`，包含数值设置对照、运行/中止日志、最小诊断波形、成功的完整 60ms waveform（可 gzip）、CSV、分析脚本和校验值。服务器空间有限时优先只提交精确复算所需数据与日志，不要塞无必要的 PSF。
- 记录实际代码和数据 Git SHA、Spectre 参数、PDK、corner、温度、重现命令。
- 无论跑通或达到上述诊断 STOP 条件，都 **STOP**；不主动进入真实 MOS CMFB、第二级 CS 或新优化轮次。
