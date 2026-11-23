# ECE203 / AutoCircuit：Chopper BioAmp 研究线交接（截至 R7C）

> **新会话入口 / 权威交接文档（2026-11-22，美国西海岸时间；GitHub 提交显示 2026-11-23 UTC）。**
> 当前最新已核实实验结果提交：`5026821d60d873c2a1fe23db856bf4a3672b86b5`；本文是根据实际代码、R7A/R7B/R7C 仿真报告、CSV、netlist audit 和运行日志整理的**已验证事实 + 待验证计划**。开始新工作前先检查仓库是否有更新。
> **立即阅读次序：本文 → `docs/ECE203_round7c_mos_pseudoresistor_results.md` → `docs/ECE203_round7b_cmfb_gatecap_results.md` → `docs/ECE203_round7a_real_mos_cmfb_results.md` → 相关 `.il` → `AGENTS.md` / `CLAUDE.md` / `docs/automation_playbook.json`。**
> 注意 `docs/ECE203_HANDOFF.md` 是 11/15 **Round-1 历史阶段**文件，其中“不做 chopper/CMFB”限制已被用户后来的 R6/R7 决策取代；**不要把它误认作当前研究任务命令**。其课程规格/安全限制仍可作参考。

## A. 用户真实目标和合作方式（先读）

1. 用户在 UCSD ECE203 中开发 ECG biomedical analog front-end，使用 IBM cmrf7sf PDK、Cadence Virtuoso/Spectre，并有独立的模拟/ADC 自学项目。用户使用中文，偏好**小型、边界清楚、有限次数的真实仿真实验**，每轮给 Claude/执行 Agent 一份可以复现的任务书、最后再由 GPT 审查；不希望无止境盲目尺寸优化。
2. 同时保留两条路线：
   - **R5N-F F2：课程保险基线，非斩波**，标称指标已通过。**不可改动或冒险替换。**
   - **R7C：独立进阶研究线，真实 MOS 双 Chopper + 全差分 OTA + MOS CMFB + 真实 DRL + MOS CD + MOS pseudo-R。** 目标是尽可能接近晶体管级、再优化、再研究噪声与 mismatch。
3. 用户明确允许**理想外部输入/基准**：1.8 V 电源、VREF 0.9 V、VCAS 1.1 V、外部 Clock（VPULSE / 2 kHz 两相非交叠）及参考电流；**不要求**现在造振荡器、时钟逻辑或带隙。所有关键有源模拟功能模块尽量用真实 PDK MOS。电容、片上必要 RC 无源网络与人体/电极模型可以是无源元件；但不可让理想 VCVS 偷代 MOS CMFB/OTA、把理想 TΩ 电阻称作真实 pseudo-R。
4. **R7B 已确认的 CMFB 输入栅电容导致的差模切换误差暂时不管，不要擅自重开。** 当前先补齐剩余实际功能模块，之后统一优化。
5. 用户称**11 月 24 日交 Preliminary Report、12 月 4 日交 Final**（2026）。不要让 Chopper 实验危及课程主线的 R5N-F 交付。精确提交时刻以课程 Canvas 为准。
6. 实验用 GitHub 仓库 `TimmyXu015/AutoCircuit`，在 UCSD iENG6 执行。新 Agent 若没有 Cadence 主机控制能力，**不要伪装已跑仿真**：只能写完整任务书交 Claude 执行，结果回来再验收。

## B. 一眼看懂当前电路

```text
 ECG electrodes + body -> Cc 50 pF/side -> summing nodes p,n
                                         |              |
                                    input MOS TG chopper XCI
                                         |
                                real FD OTA XA (R6A)
                                         | OP, ON
                    real MOS CMFB XC <---+---> output MOS TG chopper XCO
                   (R7A candidate a2)                 |
                                                      fp, fn (feedback pickoff)
                                                         |
                      MOS pseudo-R XPRN/XPRP + Cfb ----+---> real MOS CD XCD
                      (R7C 4u/2u; cross feedback)             |
                                                          bufp,bufn (CL=10pF/side)

 Body common-mode -> sensed via high-Z network -> real DRL OTA XD -> right-leg electrode

 Allow IDEAL: VREF, VCAS, reference current, clock VPULSE, supply.
 Not yet integrated: unified MOS bias distribution, deliberate ~250 Hz final LP.
```

**交叉反馈连接不可“修正”**：
- 旧 `RFN (fp n)` / `RFP (fn p)` 为理想 `3.1831 TΩ`。
- R7C 换成 `XPRN (n fp) ece203_ss_pr_cell`、`XPRP (p fn) ece203_ss_pr_cell`。
- 伪电阻子电路 `MP (B B A B) pfet33`（Virtuoso 符号 `pfet33x`）：**A 接高阻求和节点 n/p，B 接低阻解调后输出 fp/fn，B 也连 Gate + N-well + 另一侧 p+**。
- `CFN (fp n)` 和 `CFP (fn p)` 的 0.5 pF 反馈电容均保留。不要改拓扑或方向。

## C. 已完成什么：真实测量、对照和限制

### C1. 课程正式基线：R5N-F（非 Chopper）

- **`Project/ece203_r5nf_tb_f2`，ADE state `r5nf_final_f2`；`docs/ECE203_round5nf_final_noise_results.md`。**
- IBM `tt` 27 °C；真实 MOS OTA、DRL、偏置及 pseudo-R；指标：**39.22 dB**, fL **0.1005 Hz**, fH **247.5 Hz**, 输入噪声 **2.880 µVrms**（逐点 de-embed）／**2.930 µVrms**（应用型），CMRR60 **89.85 dB**, Zin(10 Hz) 最差 **163 MΩ**, 主环 PM **73.0°**, DRL PM **90.1°**, 功耗 **3.175 µW**，标称全部 PASS；噪声余量只有约 2–4%，PVT/MC 未验证。
- 面积代价：M1/M2 **50µ/40µ**，M3/M4 **8µ/42µ**；OTA1 面积 W×L 总估约 **4848 µm²**。R5N-F 噪声源拆分数据 `docs/ece203_data/round5nf/raw/r5nf_noise_split.csv`：**输入对 flicker 46.9% + PMOS 镜像 flicker 38.6% = 85.5% 的总噪声功率**；小尺寸原始非斩波基线噪声约 **16.58 µVrms**。用户未来要通过 Chopper 验证这些 1/f 主导项实际被转移/抑制后剩下什么，是否值得用开关复杂度换晶体管面积。
- **R5N-F 和 R7C OTA 拓扑、尺寸与偏置不同**；不能直接拿 2.88 µV 与尚未测量的 R7C 数值宣称 Chopper 性能提升，先做相同 R7C OTA 的 Chopper ON/OFF。

### C2. R6B–R6D-R：真实 TG Chopper、FD OTA、DRL、MOS CD

- `ece203_r6a_fd_ota`（真实 FD OTA）、`ece203_r6b_tgchop`（每个 8 个 MOS TG，双 chopper 共 16 MOS）、真实 DRL `ece203_r4_drl_ota`、`ece203_r6d_cd`（NMOS source follower + NMOS sink）。
- 2 kHz chopper，半周期 250 µs；时钟来自 VPULSE 非交叠相位，理想参考驱动开关。R6D-R 发现 Spectre 在第一切换处会卡死；**`tran cmin=1e-17 F`**（仅数值辅助）恢复 60ms 5 用例。不要在新仿真无意删除此设置。保留 `VSPS sinephase=0`。
- R6D 在 10pF 负载上 CD 很有效地隔离了前级加载（Hpre 只降约 0.001%），但 CD 增益约 **0.842**，将 output CM 降至约 **0.543 V**；不是 rail-to-rail 缓冲器。实际 R7C 带 Chopper 的 **Hbuf=76.48 ≈37.67 dB**，尚低于课程最终增益目标 **38–42 dB**。
- 详情 `docs/ECE203_round6b_real_mos_chopper_results.md`、`docs/ECE203_round6d_chopper_tran_recovery_results.md`。

### C3. R7A：真实 MOS CMFB，完整斩波信号链

- `ece203_r7a_cmfb_a2`：真实 **7-MOS 连续时间差分差分对**，输入 NMOS 0.5µ/40µ、尾管 10µ/8µ、二极管 PMOS MD 2.932µ/4µ，总控制器电流 **331.5 nA**，取代理想 VCVS CMFB；R7A 新系统 `Project/ece203_r7a_tb_buf_a2`。
- DC 输出共模误差 ≈**−0.08 mV**；2 kHz/60ms 共模均值误差 **−0.06 mV**；200Hz 共模失真 **3.94 µV**（旧真实 DD 对约 **3.52 mV**）；CMFB PM **84.46°**、DRL PM **90.25°**，总功耗 **1.999 µW**，R7A 所有预登记 gate PASS。
- 代价：100Hz Hpre 91.73 vs ideal CMFB 93.50；差模边沿误差约 **31.97 mV** vs 9.58 mV，残差 RMS **3.589 mV** vs 0.912 mV。这是开关切换确定性误差，**不是随机噪声功率**。
- 报告 `docs/ECE203_round7a_real_mos_cmfb_results.md`；数据 `docs/ece203_data/round7a/`。

### C4. R7B：CMFB Gate C 归因实验证据很强（已冻结）

- MOS 输入管 (C_{gg}=109.6\,\mathrm{fF})，考虑尾节点跟随后的**有效输入负载约 67.4 fF/侧**（独立 AC 导纳、预先登记），相对于理想 CMFB VCVS 输入为零的附加负载。
- 在理想 CMFB 测试台 `op/on` 各加 **67.4fF**，差模最大边沿误差变 **32.49mV**（R7A 31.97），残差 **3.593mV**（R7A 3.589），100Hz 增益 91.730（R7A 91.733）；归因比例 edge **1.023**、residual **1.001**、gain **1.002**；差值波形高度重合。C0 未加电容与 R6D-R 旧波形 SHA 逐位一致；两倍电容 C2 单调更差。
- 结论是**输入栅电容已足以解释差模劣化（strong support，非完美物理证明）**；不代表 MOS CMFB 本身已被优化。用户明确暂不修它。
- 报告 `docs/ECE203_round7b_cmfb_gatecap_results.md`；预注册 `docs/ece203_data/round7b/r7b_cap_plan.md`。

### C5. **最新 R7C：真实 MOS pseudo-resistor 整合——验收 PASS**

**首要原始依据：`docs/ECE203_round7c_mos_pseudoresistor_results.md`、`docs/ece203_data/round7c/r7c_stageB_summary.csv`、`r7c_stageC_summary.csv`、`r7c_netlist_audit.txt`、`ece203_r7c.il`。结果提交 `5026821d60d8`。**

- MOS cell `Project/ece203_ss_pr_cell` 复用 R3B，经实际网表确认厚氧 `pfet33`（Virtuoso `pfet33x`），W **4µm**、L **2µm**；`RFN/RFP` **完全消失**、`XPRN/XPRP` **各一只真实 PMOS**、`CFN/CFP` 与其它模块完全不变；网表 audit **PASS**。新整机 `Project/ece203_r7c_tb_pr_w4`，ADE state **`r7c_pr_w4_phaseA`**。
- **Stage A：PASS。** 0mV 偏差下增量电阻 (1/g\approx3.128\,\mathrm{T\Omega})；±50 mV 下严重非线性且电流明显不对称，真实测得；不应误当固定 3.18TΩ。
- **Stage B：PASS（TG 静止 A 相的 DC/AC/STB）。** `fL=0.095627 Hz`（理想 Rfb 对照 `0.094303 Hz`；同一 −3dB vs 100Hz 增益尺子），**不是周期 Chopper 的 PAC fL**。Hpre100 **93.57769** vs **94.53109**（−1.01%），Hbuf100 **78.83765**，共模 0.8999181 V，CMFB PM **84.505°**，DRL PM **90.253°**，CMRR60 **108.42 dB**，Zin10Hz **658.0 MΩ**，功耗 **1.994 µW**。没有调整 W。
- **Stage C：PASS（真实 TG 2kHz，100Hz/1mV DM，60ms）。** Hpre **90.8306** vs 91.7333（−0.98%），Hbuf **76.4803**，差模边沿误差 **31.45mV** vs 31.97mV，差模残差 RMS **3.520mV** vs 3.589mV，op/on CM 平均 0.899940V、200Hz CM **3.87 µV**、CM+ spike **8.46mV**，功耗 **~1.998 µW**。两个20ms窗口一致；原 R7A trace 作只读基线复用。
- **Pseudo-R 新增小非线性：** 100Hz H3 从 −106.2 dBc → **−85.7 dBc**（仍很低）。反馈端电压每侧约 **−48mV..+47mV**，真实器件在该幅度下非线性很强，但100Hz电流主要走0.5pF反馈电容，所以整机谐波影响很小。
- **慢时间尺度风险：** 非对称 pseudo-R 整流可能使 OTA summing node 共模缓慢漂移；60ms 时域的拟合趋势约 **−0.18mV/s**。用单器件 DC I–V 准静态外推，在本测试 ±47mV/侧时，可能最终形成约 **−22mV** 的 DC 平衡移位、估计时间尺度**几分钟**。**这两个是分析外推，不是长时间仿真所得稳态；不能当作已验证的最终偏置或确定的实际长期失调。** OTA 最弱饱和余量当前约 **0.092V**，应在后续考虑偏置移位的头间余量。
- 一次数值检查 `iabstol=1e-17 → 1e-18`：60ms 主要量结果稳定。R7C 的 **Stage A/B/C gate 均 PASS**，但**周期 fL（PSS/PAC）、1Hz大信号失真、长期漂移、PVT/MC、噪声都 NOT RUN**。不要将 “R7C PASS” 误读为 “整个 ECG final signoff PASS”。
- netlist and exact readouts `docs/ece203_data/round7c/raw/stageB/` & `raw/stageC/`（完整 compressed tran csv + SHA + Spectre logs）。实验脚本只新增 `ece203_r7c.il` 和 R7C bench，旧数据未更改。

## D. 当前最重要的欠缺 / 不要误判

| 项目 | 状态 | 下一步意义 |
|---|---|---|
| XCI/XCO TG、FD OTA、CMFB、DRL、CD、pseudoR | **真实 MOS，已单项与集成 TT 仿真** | 冻结，除非新 gate 明确失败 |
| 外部 Clock/VPULSE、VREF、VCAS、输入参考电流 | **用户授权理想输入** | 暂不设计 oscillator/BGR |
| 电流分配 | **R7C 仍用两套理想 50nA 电流源到本地 MOS MREF** | **下一步 R7D：一个理想电流基准 + 真实 MOS bias mirror network** |
| 250 Hz 低通 | **尚未加入 R7 信号输出** | R7E 加输出低通与负载/增益协同；不要把 7.4kHz 前级 fH 当成完整 ECG fH |
| Chopper 差模 switch edge | **32mV 量级，物理来源已归因栅电容** | 用户明确暂时冻结，系统级整合后再评估 |
| CD gain/common-mode | `Acd≈0.842`; buffer CM `~0.543V` | 最终 38–42dB 总增益、输出摆幅/headroom 需单独处理 |
| MOS pseudoR 整流长期偏移 | **只看到 60ms 斜率；−22mV 为外推** | 最小必要时只做 DC shifted-headroom / 1Hz 慢信号测试，不要预先大改 |
| Noise / 1/f 归因 | **R7C 尚无可靠 Chopper ON 周期噪声结果** | 之后做 PSS/PNoise 或证据充分的替代方法 |
| Monte Carlo / PVT | **R7C 尚未运行** | 最后验证 CMFB 精细调零、pseudoR 的 process/temperature 敏感度 |
| 课程所有指标与 NEF/layout | **未完整证明** | 不得宣称课程完整最终 PASS |

## E. 建议下一轮执行顺序（原则：先完成架构、再有限优化、再 Noise/MC）

### R7D — 统一真实 MOS bias distribution（推荐下一轮）

**唯一目标：** 在 R7C `ece203_r7c_tb_pr_w4` 的完整真实 MOS Chopper 系统内，把原来两支**理想 50nA**偏置供给路径统一为**一个允许的理想参考电流 + 真正的 MOS 电流镜**，复用 R4/R5 中已验证的 `MP0/MP1/MP2` PMOS mirror 思想（参 `ece203_r4.il` 的 `r4SpecsRB(pr)`），并视 R7C 的负载需求合理配置镜像比。

- 保留 `XA/XC/XD/XCD/XCI/XCO/XPRN/XPRP` **全部尺寸不变**；VREF/VCAS/Clock 继续理想；`Cc/Cfb`、R7B 的 67.4fF 问题也保持不动。**禁止这轮顺便造 LP、改 CMFB、调 TG 或 noise**。
- 任务书先写真实 netlist 分析：R7C 的 VDD/VDDD 是**两只独立对地 1.8V**，测总功耗应相加（与 R5N-F 的串联0V电流表不同）；新 Bias 若合并供电要记录所有支路并重算。必须确认 `IB/IBD` 与 `ib/ibd` 的方向、参考二极管/MREF、不允许暗藏另一路理想偏置。
- 仅做小矩阵：C0 旧 R7C read-only vs 新 MOS bias；TG 静止 DC/AC/CMFB+DRL STB → 2kHz/60ms tran。实测工作点、CM 0.9、Hpre/Hbuf、斩波边沿、功耗、PM、头间裕量、input-node趋势；记录失败而非无界调参。尽量总功耗 <4µW（理想参考和clock还未完全计，需标注）。
- 若从旧 R4 单 100nA 参考移植，引入额外偏置镜像开销，应显式量化。**这只是推荐的下一轮，先拿用户授权的 R7D 任务书再执行**。

### R7E — 输出 LP + 系统全链路调谐

- 加一个有明确接法、真实无源 R/C 的约 250Hz output LP（**位于反馈取样 fp/fn 之后、避免直接损坏主反馈**）；保留真实 MOS CD 或按有限对照分析其输出增益/驱动能力。**尚不能默认 LP 后同时获得 38–42dB 和 225–275Hz**；现在 Chopper Hbuf≈37.67dB。
- 关注 CD 导致的 common-mode 0.543V，输出是否需要恢复到 VREF（由教授要求决定）；输入 Zin/CMRR/环路/带宽/功耗一起量，最多允许针对失败项的有限修正。
- 如后续对 MOS pseudoR 的长期整流风险需要把关，先做**最小 DC headroom shift 测试**，或 1Hz 大信号长时域专项；若失败，再与用户讨论是否用 back-to-back 对称 pseudoR（这属于拓扑变化，不能自动实施）。
- 做完整 TB 与指标矩阵，保证用于噪声研究的 stable/no clipping baseline。

### R8 — 研究 Chopper 是否真正抑制 1/f

- 先做 **PSS/PNoise 最小可行性测试**。R6B 曾有 PSS/PAC 数值/许可证或收敛风险，不能假定完整 PNoise 已经跑通；采用符合 Spectre 实际功能的周期噪声分析。不能拿关掉开关后的普通 `noise` 冒充运行中的 Chopper 噪声。
- 实验 1：**同一套 R7 MOS OTA、偏置、负载、反馈**，TG 仅静止 A 相 vs 同步 2kHz ON，输入等效噪声 PSD (0.1/1/10/100/250Hz) + 0.1–250Hz 总积分。对**输入对/PMOS镜像的 flicker、thermal、CMFB、DRL、CD、TG 开关、伪电阻**做 source split，并评估开关边带 alias/folding 和 clock-related random noise。
- 实验 2：在可比较功耗/面积下与 R5N-F 大器件单端正式基线对比，但不能把不同 OTA 拓扑/功耗差异归功于 Chopper。
- 将开关毛刺、纹波、同步解调残余、整流偏移（**确定性误差**）与随机 RMS 噪声区分；对 long-term 非稳态要避免直接用 PSS 定常假设而不核查。

### R9 — Monte Carlo / PVT 与工程价值判定

- 先做 10–20 mismatch 样本的快速冒烟，再按需要扩样，测 CMFB 对 MD 宽度校准的敏感度、共模/offset/增益/无削顶、pseudo-R 参数分散、功耗/余量。完整周期 PNoise 乘以大量 MC 成本高，先分阶段。
- PVT 至少检查工艺和温度对 pseudoR TΩ 等效阻值、fL、OTA/CMFB偏置、DRL稳定的影响。
- 最终基于 **总集成噪声、1/f 占比、面积、功耗、THD/offset、复杂度与稳健性**回答用户最初研究问题：Chopper 值不值得替代 R5N-F 的巨大 MOS 面积优化？

## F. 硬性工程纪律（新 Agent 必读）

- **每个实验必须先明确一个因果变量、冻结其余模块和提交 pre-run plan / gates，最多有限轮修正；结果标记 PASS / FAIL / NOT RUN。** 未实测不得宣称仿真通过；仿真条件及模型角必须随数据记。
- **绝不覆盖** R5N-F F2、R6D-R、R7A/B/C cell、ADE state、数据和已有报告。使用 `ece203_r7d_*` 等全新 cell、脚本和 `docs/ece203_data/round7d/`；对照只读。新任务书放 `docs/ECE203_round7d_*.md`。版本 commit 后跑。
- 环境：UCSD `ieng6`，`ECE203_FA26_001`，Virtuoso IC-618、Spectre 15.1，IBM `cmrf7sf tt` at 27°C。运行命令 `~/AutoCircuit/run.sh ece203_<job>`，batch job 在 `batch/<job>.il`；`AC_SKIP_GIT_PULL=1` 用于 pinned clone。详见 `docs/automation_playbook.json`，不要自己发明工具访问方法。
- 瞬态已验证 `maxstep=0.5µs`、`cmin=1e-17 F`、`gmin=1e-18`、`iabstol=1e-17`、`reltol=1e-5`；特殊极小电流可用有理据的精度复核。**`cmin` 是数值 shunt，不是物理电容**。检查每个 Spectre log 和 `VSPS sinephase=0`（Virtuoso CDF sticky 曾出过相位错误）。
- 服务器 home 容量曾紧张，long tran PSF 存 `/tmp` 并启用 per-run watchdog；压缩并校验重要 raw waves。**只清理本轮可重建 PSF，不杀用户自己的 Virtuoso/Spectre 进程，不删历史数据**。
- GitHub 公开仓库不可放密码、私钥、IBM PDK 模型全文或作业答案。Windows 本地实验 notebook `C:\Users\Timmy\AutoCircuit_Results\` 格式和同步方法见 `AGENTS.md` / `docs/automation_playbook.json`；更新索引 `LOG.md`。新会话若没有连接相应外部工具，应交待限制而不是虚构已执行。
- 新 Agent 回复中文、技术解释简洁但精确。优先提交一个 Claude 可直接执行的任务书，Claude 跑完再由 GPT 对照日志/CSV/netlist 验收；避免长篇空想架构。

## G. 新对话“一键启动”指令（可复制整段）

> 我们继续 UCSD ECE203 的 AutoCircuit / Chopper BioAmp 项目。**请先读取 GitHub 仓库 `TimmyXu015/AutoCircuit` 的 `docs/ECE203_CHOPPER_HANDOFF_AFTER_R7C_2026-11-22.md`**，随后核对 R7C 结果 `docs/ECE203_round7c_mos_pseudoresistor_results.md` 和 `ece203_r7c.il`。
>
> **当前 R7C 已通过真实 MOS pseudo-R 替换的全部预定仿真门槛**；暂时冻结 R7B 已定位的 67.4fF CMFB 输入电容问题。真正目标是保留理想 Clock/VREF/VCAS/参考输入，其余模拟有源模块尽量 MOS 化，补齐系统后先有限优化，再开展同 OTA Chopper ON/OFF 的 1/f Noise / PNoise 对照与 Monte Carlo，验证 Chopper 能否替代 R5N-F 的大面积 flicker 优化。
>
> 当前建议下一轮 **R7D：一个理想参考电流 + MOS bias mirrors**；先完成单变量任务书、不要未经同意改动任何旧 cell。也需记住 R7C pseudoR 有**尚未验证**的长期整流偏移，不能将 60ms PASS 当作稳态证明；R5N-F 是单独课程交付保险，不要动。
>
> 请先用**简短**状态表复述读到的确切最新数据与剩余模块，并给出 R7D 的最小实验计划。我确认后再交 Claude/Cadence 执行。不要自动开始无边界全系统调参。

## H. 关键可点击原始资料

- [Repo](https://github.com/TimmyXu015/AutoCircuit)
- [R7C results](ECE203_round7c_mos_pseudoresistor_results.md) · [R7C task](ECE203_round7c_mos_pseudoresistor_integration_task.md) · [R7C data](ece203_data/round7c/)
- [R7B results](ECE203_round7b_cmfb_gatecap_results.md) · [R7A results](ECE203_round7a_real_mos_cmfb_results.md)
- [R6D-R numerical recovery](ECE203_round6d_chopper_tran_recovery_results.md)
- [R5N-F protected sign-off](ECE203_round5nf_final_noise_results.md)
- [Tech runner](../run.sh) · [Repo rules](../AGENTS.md) · [Automation playbook](../docs/automation_playbook.json)
