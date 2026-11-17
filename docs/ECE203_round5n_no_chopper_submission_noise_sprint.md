# ECE203 Round 5N — 单端 BioAmp 无 Chopper 交付冲刺 + 噪声下限实验（READY / NOT RUN）

**日期：2026-11-16。当前状态：准备完毕，尚未启动 Cadence。** 用户今日优先级是先守住可交付的成熟单端路线，然后再考虑 R6 全差分/Chopper。**只允许一个 Claude Agent 工作**。本任务执行前须用户另行明确启动，不要自动展开双 Agent、R6C、CMFB+DRL 联动、RRL、Chopper、AZ、CDS 或新架构。

## 任务目的（按优先级）

1. **交付底线**：以 Round 5 Stage E 真实整机 `Project/ece203_r5_ecg_cs_rbpr_tb` / ADE `r5_final_cs` 为真实基线，在**不换拓扑**前提下修复 fL，保存一个可靠、可复现、适合交付的单端无 Chopper 版本。噪声不达标不得谎称全 SPEC PASS。
2. **探索噪声下限**：使用教授 ECE203 的低噪声思路，特别针对 OTA1 NMOS 输入对和 PMOS 镜像的 flicker noise，有限面积/偏置优化，记录 Noise–Area–Power–Bandwidth 的真实代价。目标尽量接近/低于 3 µVrms，但超出约束时如实止损。
3. **绝不污染原始成果**：R3/R4/R5/R6A/R6B 原 cells、现有 ADE states、所有脚本数据均保持不变。通过新前级变体、新 testbench、新输出目录运行。独立 frozen submission baseline 与 aggressive noise candidate 都保存。

## 已验收事实 — 不必重新研究

资料：`docs/ECE203_round5_architecture_noise_demod_results.md`、`docs/ece203_data/round5/stageE/`，脚本 `ece203_r5.il` / `ece203_r4.il` / `ece203_ss_pr.il`。

**R5 最终是真实整机，非 isolated S2**：3 电极/人体、实际 DRL OTA、两条 1pF CM sense cap、真实源自一个 100 nA 参考的偏置、VREF/VCAS 分压、真实 pseudo-R、单端 OTA1 C（局部 cascode）+ PMOS CS OTA2（Miller 0.5pF），输出 31.8MΩ/20pF LP，反馈取样在 LP 之前。OTA1：NMOS M1/M2 10µ/8µ，PMOS M3/M4 2µ/4µ，单侧 MC 10µ/4µ；保留其余器件。Pseudo-R：`ece203_ss_pr_cell` 的 `pfet33x`，`prw=3µ`, `prl=2µ`（CDF W/L 为 design vars，运行时核实真已生效）。

| 指标 | 目标 | 已测 R5 无 Chopper |
|---|---|---|
| `|Hdm(100 Hz)|` | 38–42 dB | 91.91× / 39.27 dB |
| fL | 0.09–0.11 Hz | 0.0773 Hz — FAIL |
| fH | 225–275 Hz | 249.1 Hz |
| CMRR60 (1% Cc mismatch, DRL ON) | >85 dB | 95.42 dB |
| `|Zin(10 Hz)|` (最差一端) | >100 MΩ | 159 MΩ |
| Power @1.8 V | <4 µW | 1.408 µW |
| Noise, 0.1–250 Hz ECG input referred | <3 µVrms | 16.58 µVrms (逐点 de-embed); 17.15 µVrms (输出应用型) |
| Capacitance | <1 nF | 143.5 pF |
| main/DRL PM | ≥55° main | 87.6° / 90.1° |

噪声分解 R5：OTA1 NMOS input flicker 12.43 µVrms；PMOS mirror flicker 10.93 µVrms；input thermal 1.06、mirror thermal 1.30、Rfb 1.02 µVrms；OTA2 折算输入约 0.03 µVrms，先不碰 OTA2。必须使用**噪声功率相加**，不能将 RMS 简单相加。对面积缩放 `v_fn ~ 1/sqrt(WL)` 只能作为预测，不是 Spectre 结果。增加输入 W/L 也会增加 Cin、改变闭环噪声增益和器件工作点，不能假定无限放大会达到 3 µV。

## 实验设计：先打分，再挖下限

### A. 恢复/冻结基线 + 修 fL（优先执行，先产出结果）

- 新建 `ece203_r5n_*` cell、`ece203_r5n.il` 和独立 `~/AutoCircuit_results/ece203_r5n` 结果目录；注册 `ece203_r5n_*` run.sh job。**新 TB 从 R5 Stage E `r5SpecsE("cs")` 拷贝/转换实例映射构建，不能调用会重写旧 cell 的 `r4Build()`、`r5BuildOta2()`、`r6Build()` 等。** 必须明确核对 XA 与 X2 实例、DC/符号/反馈极性/偏置均指向预期器件。
- 先复现 R5 Golden 的关键值（优先 AC fL/H、H100、noise、DC）。若和原始差异明显，先停、定位新 TB 接线，不能用错误起点优化。
- 保持 OTA、Cc=50pF、Cfb=0.5pF、输出 LP、DRL/偏置不变。仅扫描两个 pseudo-R 实例共同 W，建议 `prw = 3.5 / 4.0 / 4.5 µm`，L=2µm；各点 AC 求 fL 和 H100、DC/headroom。因为 `prw` 是 cell 的变量，务必检查 Spectre 实际实例 W/L，不能只改变变量名却让物理器件不变。目标 fL 落在 0.09–0.11Hz。若三点均失败，最多追加 1 点、选择最接近的合法点；不能乱改 Cc/Cfb 或反馈拓扑。
- **先冻结一个 `r5n_submission_baseline` 版本**（含确切 prw、schematic、ADE state、CSV/plot、真实 noise FAIL）。即使后续噪声实验不成功，这个成果也必须保留，不能被后续参数探索覆写。

### B. OTA1 噪声定向优化（有限用例，避免指数爆炸）

固定阶段 A 最佳 pseudo-R 和 R5 完整的 CS+DRL 系统，只改变 OTA1 的 NMOS M1/M2、PMOS M3/M4 尺寸。基线输入 `10/8 µm`、镜像 `2/4 µm`。先使用 W、L 等比例缩放保持 W/L 不变（工艺/模型/尺寸合法性必须检查）；如果寄生或 headroom 使此方法退化，可以记录原因，不得暗中换成全新拓扑。

**优先顺序**（`4×` 指两个同类器件各自 WL 面积乘 4，即每只 W 和 L 各乘 2；`16×` 即 W 和 L 各乘 4，不是仅 W×16）：

| Case | 输入 NMOS 面积 | 镜像 PMOS 面积 | 目的 |
|---|---:|---:|---|
| B0 | 1× | 1× | A 的 submission baseline |
| B1 | 4× | 1× | 输入管单独贡献 |
| B2 | 1× | 4× | 电流镜单独贡献 |
| B3 | 4× | 4× | 联合缩放 |
| B4 | 16× | 4× | 判定输入管极限 |
| B5 | 4× | 16× | 判定镜像极限 |
| B6 | 16× | 16× | 联合激进缩放 |

- **各 Case 先 DC + 快速 AC gate**：验证每支 NMOS/PMOS 饱和裕量、MOS Vgs/Vds/Ids、增益/fL/fH、总电流以及是否有明显的新 Cin 反馈/加载问题。无效点标 `INVALID` 并跳过 noise。不允许用本来已失效的放大器伪装出低噪声。
- 有效点运行 **普通静态 Spectre noise**（不是 PNoise，既无 Chopper 也无 clock）0.1–250 Hz，采用与 R5 一致的 ECG 输入定义、同一 output & transfer function，保留 **逐频点除以 |Hdm(f)|² 再积分** 与 `Vout_rms / |Hdm(100)|` 两种计算，明确不可混同。至少输出 0.1/1/10/100/250 Hz PSD。
- B0、B3、B6 必须做主要噪声贡献分组；B1/B2/B4/B5 可只做汇总噪声，节约时间。重点判断两类 flicker 是否降下来、新的 dominant source 是什么。不能用器件面积公式代替仿真报告。
- 记录晶体管总 W×L 面积估算、相对原始 OTA1 增加量（不冒充真实版图面积）、输入 Cin / 输入高阻节点 capacitance（可由 OP/cap model 验证）、总系统 143.5pF 基线和改变后的预算；不能只比输入噪声。
- 若 B6 仍离 3µV 很远且面积/输入电容代价不合理，允许在保持拓扑下 **最多 2 个小幅偏置电流试点**（如基于 gm/Id 和 headroom 的有限调节）；必须保留真实 100 nA 参考、DRL、全系统功耗记录，不能把整机偷换成理想 50nA reference testbench。禁止大面积智能优化搜索、随机多轮 sweep。可根据 B1–B6 提前停止无效方向。
- 探索结果即使未达 3 µV，也须保留 **在其它核心 specs 均达标、原有功耗预算下的最低噪声候选**，同时保留面积更合理的候选作对照。

### C. 交付验收（仅最佳 1–2 个 + frozen baseline）

对最终最多两套候选重跑真实整机关键指标，输出 **PASS / FAIL / NOT MEASURED**：
1. AC DM H10/60/100、fL/fH；真实 Cc mismatch 1% 时 60 Hz CMRR DRL ON，必要时 OFF 作对照。
2. `|Zin(10Hz)|` 最差端、真实总电源 I/P（含 DRL/OTA2/bias）、电容预算与敏感工作区/headroom（原 R5 M2 裕量 0.094V，不能被忽略）。
3. 两个反馈环路独立 STB：主环路 PM≥55°，DRL PM；真实人体 0.1µA@60Hz 干扰下检查输出削顶，避免仅 AC 的高 CMRR 掩盖越轨。
4. 0.1–250 Hz Noise（两个定义）+ 噪声分解：尤其如果降到 ≤3µV，独立复核积分方法、噪声源与反馈传递函数。
5. 可复现 ADE states：`r5n_submission_baseline` 和 `r5n_low_noise_best`；各自原 cell/config/尺寸/数据可追溯，未测项目如实标注。若仅部分完成，应至少保留 A 的 baseline。

## 严格预算和停机

- 粗筛总数 **不超过 14 个配置点**（A：原始复现 + 3–4 个 pseudo-R；B：最多 7 个面积点，含 baseline；偏置：最多 2 个），最终 signoff 限 2 套。每配置允许 DC/AC/常规 noise；主/DRL stb、60Hz 大信号 tran 只在最终 signoff 做。**不运行 PSS/PAC/PNoise/MC/PVT，不做 Chopper。**
- 出现收敛错误最多一次数值设置修复，保持低频 pseudo-R 的 `gmin`/精度有物理意义；不可把数值 gmin 电导当成真实 pseudo-R。只保存必要节点，避免 R6B 磁盘配额问题；前后先检查 quota，保留用户原文件和运行中的进程。
- 不得将理论约 `1/sqrt(WL)` 当作 PDK 的准确电噪声缩放律；特别注意输入栅电容增加可能提升 OTA input-referred noise gain，反向抵消 flicker 改进。
- 仍失败时按时间优先：**交付 baseline > 证明噪声极限趋势 > 完整自动优化**。保存当前阶段并 STOP，无需用户再多回答问题。
- 公开 GitHub：只提交脚本、任务/结果报告、处理后的 CSV/图；不得提交 IBM PDK、敏感路径/密钥、作业最终文字答案或未经授权的专有网表。Windows lab notebook 按 `docs/automation_playbook.json` 记 log.md/PNG / _raw，不删除已有实验。

## 交付物

- `ece203_r5n.il` + `batch/ece203_r5n_*.il` + 任务注册，独立新 cells 与 ADE states。
- `docs/ECE203_round5n_no_chopper_results.md`。
- `docs/ece203_data/round5n/r5n_prw_scan.csv`、`r5n_noise_tradeoff.csv`、`r5n_final_spec_matrix.csv`、至少一张噪声-面积/增益约束图和对应 Spectre DC/AC/noise/STB 简要证据。
- 最后回答三件事：
  1. **Submission baseline 是否把 fL 拉到 0.1Hz 且守住原来所有 PASS 指标？**
  2. **在实际 PDK 全系统里不使用 Chopper，噪声从 16.58µVrms 最多降到多少？代价多少面积/电容/功耗？**
  3. **有没有在全部必要规格下达到 3µVrms？若否，最强剩余噪声瓶颈是什么？**

**任务书 READY，等待用户明确启动。完成后 STOP；不要自动接着执行 Round 6C。**
