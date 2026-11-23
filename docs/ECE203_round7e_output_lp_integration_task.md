# ECE203 R7E — 实际 R7D 双 Chopper 系统的差分输出 RC 低通（LP-only 单变量实验）

**状态：TASK ONLY / NOT RUN。** 本任务书只完成**输出差分低通接入及其验证**。本轮不能修复 R7B 的 CMFB 67.4fF 输入栅电容差模边沿误差，也不能同时优化 MOS CD、OTA、CMFB、Bias、Pseudo-R 或任何时钟器件。R7D 已验收，最新基线 `Project/ece203_r7d_tb_bias_a0`。任何 R7E 仿真必须由 Claude/Cadence 执行并用真实 Spectre 数据回传；本任务仅为执行指令。

## 0. 权威资料、当前节点和数值

- 必读 `AGENTS.md`、`CLAUDE.md`、`docs/automation_playbook.json`、`docs/ECE203_CHOPPER_HANDOFF_AFTER_R7C_2026-11-22.md`（后者要与较新的 R7D 结果并用）；`docs/ECE203_round7d_mos_bias_mirror_results.md`、`docs/ece203_data/round7d/r7d_stageB_summary.csv`、`r7d_stageC_summary.csv`。
- 代码 `ece203_r7d.il`（`r7dSpecs("a0")`）和 `ece203_r6d.il` 的 `r6dCdDevs`；比较 R4 老系统的 `r4Specs()`/`r4LP`，`ece203_r4.il` 用了 **RLP = 31.8MΩ / CLP=20pF** 的 RC 低通，外置于 OTA feedback。
- 真实 R7D 网表 `docs/ece203_data/round7d/raw/stageB/B_bias_a0_netlist.scs`：
  - `XCD` NMOS source follower 输出到 `bufp/bufn`；现有 `CLBP (bufp 0) clb=10pF`、`CLBN (bufn 0) clb=10pF`；
  - `fp/fn` 是原反馈取样点，`CFN/CFP` 与 `XPRN/XPRP` 均接于 **fp/fn** 和 OTA summing nodes，不能改。
  - `XA/XC/XD/XCI/XCO/XCD/XPRN/XPRP`、`IREF+MP0/MP1/MP2` 及独立 VDD/VDDD 1.8V 供电保持原状；允许的理想输入包括 VREF、VCAS、Clock、100nA IREF。
- **R7D 静态 A 相**：`fL=0.095645 Hz`（相对于100Hz的−3dB），`Hpre100=93.5934`、`Hbuf100=78.8449`、`fH,buf≈7849Hz`、CMFB PM84.55°、DRL PM90.25°、功耗2.309µW。**2kHz chopped / 60ms**：`Hpre100=90.981`、`Hbuf100=76.601`（37.68dB）、100Hz input DM=1mV、DM edge31.59mV、CM均值0.899524V、P=2.314µW、H3≈−85.7dBc。
- **先验预计**（不是仿真）：空载一阶低通 `R=31.8MΩ, C=20pF` => `f_p≈250.24Hz`，`|H_LP(100Hz)|≈0.9285`（−0.64dB），故 100Hz **后滤波** chopped 幅度 `≈76.601×0.9285≈71.1 V/V = 37.04dB`，**低于课程 38dB 最低要求**。这是已知的系统增益余量问题，不得为让本轮“PASS”而偷偷改 CD 或声称全课程指标通过。下一轮才做 CD/增益修正。
- 定义两个高频截止读数，**避免口径混乱**：`fH_flat` = 相对10Hz（近似通带平台）的 -3dB；`fH_100ref` = 相对100Hz `|Hout(100)|` 再下降3dB。理想一阶250Hz LP 的后者理论上约 **287Hz**，因此不能简单拿 `fH_100ref` 与 225–275Hz 目标直接比较；课程指标应优先用与此前 R5N-F 一致的 **平台/通带峰值参照**，并注明测量定义。R4曾使用 `r4LP` 但这不是 R7E 完整物理验证。

## 1. 只加一个被动 LP，绝不碰反馈与 CD

新派生 **`Project/ece203_r7e_tb_lp_a0`**（已有任意历史 cell 绝不重绘）。复制 `r7dSpecs("a0")` 的**完整元件列表**，唯一新增 4 个对称被动元件（相对 R7D 的唯一结构变化）：

```text
Existing: XCD output BUFP -> bufp  , BUFN -> bufn
Existing: CLBP bufp -> gnd! 10pF ; CLBN bufn -> gnd! 10pF (both stay, do NOT relocate)

NEW: RLP_P  bufp -> outp     31.8e6 Ω
     CLP_P  outp -> gnd!     20e-12 F
     RLP_N  bufn -> outn     31.8e6 Ω
     CLP_N  outn -> gnd!     20e-12 F

The new final differential output = V(outp)-V(outn).
Old feedback pickoff ALWAYS fp/fn; NO connection of outp/outn back to Cfb/pseudoR.
```

- 必须是相等参数的两个单端 RC（差分对称），**不是** `outp` 对 `outn` 的单个电容，也不是在原 10pF 输出电容上直接叠加 20pF；原 10pF 位于 **RC 前端 buf 节点**，新增 20pF 位于 **RC 后端 out 节点**。
- `otaR`/`otaC` analogLib 的**理想线性无源元件**可以作为本轮系统级 LP 验证，但不能宣称 31.8MΩ 已用真实 PDK 可布局电阻实现；独立标出其器件可制造性/噪声/寄生为 **NOT VERIFIED**。若后续要求全片上 PDK 无源器件，再单独实验 PDK 高阻层电阻或有源等效，不能在 R7E 偷换实现。
- 本轮不得为满足增益、fH、功耗更改 `XCD` MOS sizing 或原 `CLBP/CLBN`。**不启动之前讨论过的 Explore/Final Library 批量改名**；先保留现有 Project 历史与 SKILL 依赖。后续整理另开任务。

## 2. Stage A — 静态 A 相 DC/AC：纯 LP 传输验证

**只读 R7D 旧 cell C0 vs R7E LP-a0 C1**。先做 netlist audit：
- C0 与 C1 的 subckt、bias/IREF、CLBP/CLBN、feedback XPRN/XPRP、TG 时钟、刺激、供电全一致；diff 恰好为两个 R + 两个 C 和由新元件带来的必要参数定义。**不允许额外的寄生电容/理想 buffer/VCVS**。
- 测 `Vdc(bufp,bufn,outp,outn)`、`Hpre=(fp-fn)/(ep-en)`、`Hbuf=(bufp-bufn)/(ep-en)`、`Hout=(outp-outn)/(ep-en)`；`H_LP=Hout/Hbuf`（complex），`fH_flat` 与 `fH_100ref`（用曲线 1Hz–100kHz，推荐 1mHz–100kHz 50pts/dec；低端保留 `fL`），输出幅值/相位 1、10、60、100、250、500、1000、2000 Hz；检查 `H_LP(100)` 是否≈0.9285，`fH_flat`是否在 **225–275Hz**，100Hz phase ≈−21.8°（需扣除前级复相位）。
- C0/R7D 只读基线：`Hpre`、`Hbuf`、`fL`、CMFB/DRL PM、CMRR、Zin 和电源功耗。接入**纯无源**LP 后，`Hpre/Hbuf`、`(op+on)/2`、偏置、CMFB/DRL、静态功耗原则上变化很小；出现明显变化则停止诊断。
- **Stage A 主 PASS**（针对高阻、尚未加下游负载的 outp/outn）：R7E `fH_flat=225–275Hz`，`fL=0.09–0.11Hz`，`|H_LP(100Hz)|=0.90–0.95`，Hout/Hbuf phase 符合一阶负相位，100Hz Hpre/Hbuf 对 R7D 偏差 ≤2%，op/on CM 距 0.9V ≤1mV，CMFB+DRL PM ≥60°，不增加>2%的功耗，输入 Zin≥100MΩ，CMRR60≥85dB；输出 DC outp/outn 应各随对应 bufp/bufn（DC 差异由数值精度决定）。
- **务必记录** `Hout100`（预计仅≈73.2 static、约37.3dB；精确以实测为准）。此项低于38dB应标记 **SYSTEM GAIN PENDING**，**不是 LP Stage A 的失败**。

## 3. Stage B — 输出负载敏感度微实验（重要，非增益优化）

**根本现实问题：** LP 的 31.8MΩ 串联电阻意味着新节点 `outp/outn` 对负载阻抗、杂散电容高度敏感；不能把原来的 **10pF 在 bufp/bufn** 误认为新 `outp/outn` 的真实负载。

- 若 Stage A 通过，则可用另一个**全新测试台** `ece203_r7e_tb_lp_load10p`，保持 a0 所有元件再各加 `COUTP 10pF (outp-gnd!)` 与 `COUTN 10pF (outn-gnd!)`，总计 6 个本轮新无源实例（这 10p 是**额外测量负载**，不会替换/移走旧 CLBP/CLBN）。
- **只做静态 A 相 DC/AC**，不必跑 60ms full transient。在无下游负载时 `f_p≈250Hz`，额外每侧10pF时 `f_p≈1/[2π·31.8MΩ·30pF]≈167Hz`。记录 `fH_flat`、`Hout100`、相位、output impedance/下游加载风险。若确实被拉至 ~167Hz，结论必须写 **“LP-a0 空载 PASS，但有 10pF 后端负载时不满足 fH 目标，需要 R7E 后续接口方案”**，而不是通过修改 R/C 或移走旧 CLB 隐藏问题。
- 额外 10p 每侧只是一个敏感度示例，不宣称用户最终 ADC/仪器确有该负载。若决定以10p为正式输出负载，需**另开**负载匹配/输出 buffer 或改 R/C 的受控任务；不能把空载方案描述为已具备 10p 输出驱动。
- 对称两侧核查可避免因负载不等产生新共模转差模；不做负载不匹配扫参。

## 4. Stage C — 2kHz Chopper 60ms，验证 RC 降低边沿/纹波与增益代价

只有 Stage A 的空载 LP PASS、无异常 DC/环路/偏置才做。**不改 R7D 或 R7E 各种 MOS 尺寸**。
- 2kHz 真 MOS TG、100Hz 1mV differential ECG input，`60ms`，`maxstep=0.5µs`、`cmin=1e-17F`、`gmin=1e-18`、`iabstol=1e-17`、`reltol=1e-5`，tt 27°C；`VSPS sinephase=0`、相同 VDD/VDDD。复用 R7D C0 已归档、完全相同条件的完整原始 wave；**只对新的 a0 运行一个 full 60ms**（短 smoke 可选）；结果保存原始波形、spectre.out、netlist、job log、hash。
- 分析用 R7A/R7C/R7D 同一 20–40ms 与 40–60ms 100Hz+harmonics、DM edge glitch 与 CM 200Hz 的定义；增加 `outp,outn` 两列及其和差波形：
  - `Hpre`, `Hbuf`, **`Hout`** 各自 100Hz gain/phase、H2/H3、残差 RMS、边沿最大/平均误差、out 共模均值/200Hz spike、2kHz clock spur（window and harmonic definition explicit）、out 对 buf 的幅度/相位比；
  - 100Hz `Hout/Hbuf≈0.9285`（可接受 ±3%，若偏差较大需分析模拟 LP 与切换分量相互作用）；`Hpre/Hbuf` vs C0 误差≤2%，能看到低通后开关尖峰和 2kHz 波纹衰减，但**不预注册必须达到某个未知的 glitch 降幅**；
  - OTA CM ≤1mV error、CMFB/DRL 静态 PM≥60°、无 clipping、功耗 <4µW 且≤C0+2%（RC不耗DC供电，虽可能有加载电流）、没有慢漂移显著恶化；R7C pseudoR 在 60ms 的整流 CM 趋势仍需报告。
  - **保持结果诚实**：静态 LP fH ≠ periodic PSS/PAC fH；运行中 60ms 的 100Hz/2kHz 检查不能独立证明 0.1Hz 或完整频响；噪声尚 NOT RUN。R7D buffered gain 37.68dB，后滤波 100Hz expected≈37.04dB，**后续必须专门增益修正**才能宣称整体达到38–42dB。
- 若 Stage C 失败，停止并明确定位；**不得**偷偷改 31.8M/20p、CD sink/follower 或 Chopper 来挽救结果。仅对数值错误可进行一次有依据的重试并记录原始失败。

## 5. 交付物、纪律和下一步

- 新 `ece203_r7e.il`、`batch/ece203_r7e_*.il`、可选 watchdog，**仅新** `Project/ece203_r7e_tb_lp_a0`、`ece203_r7e_tb_lp_load10p`，如可稳定保存 GUI state 则新 ADE `r7e_lp_phaseA`。不重建 R7D 及以前已验收 cell、ADE。
- `docs/ECE203_round7e_output_lp_results.md`，分栏 LP-only PASS/FAIL、loaded-output limitation、system gain PENDING、周期 PSS/PAC NOT RUN；`docs/ece203_data/round7e/` 数值 CSV、analysis script、netlist diff audit、before/after AC/STB 与真实 tran plot、压缩重要 raw CSV+SHA、Spectre logs。
- 每轮有本地 commit id、耗时/精度、失败记录。遵守 `AGENTS.md` 用户的 Windows lab notebook `LOG.md` / PNG / `_raw` 规范。服务器 quota 小，长 transient PSF 用 `/tmp`、watchdog，不杀用户 Virtuoso/Spectre，绝不删除旧数据。GitHub 禁止私钥/机密 IBM PDK 模型内容。
- 本轮若通过，**停止，不自动开始输出增益修正**。下一实验可叫 **R7F：在 CD Buffer/后级增益增加约12%的纯增益单变量优化**（同时考察 LP 后端10pF 负载实际接口需求），然后再进入 Noise/PSS。
- **不要批量重命名 Cadence 既有 Cell 或变更 Library 名**；工程归档独立安排，不要和 R7E 测试混为一轮。

## 6. 交 Claude 执行的开头指令

> 开始 ECE203 R7E。严格执行 `docs/ECE203_round7e_output_lp_integration_task.md`。基于冻结的 R7D a0，先建立两路 31.8MΩ/20pF 对称输出 RC（bufp/outp，bufn/outn，保留旧 CLBP/CLBN 10pF 和 fp/fn 反馈），跑原理图/netlist audit + 静态 DC/AC/STB，再可选小型10pF输出负载敏感度 AC，最后仅一个完整 60ms 2kHz transient。禁止调整 MOS、偏置、反馈、时钟和旧 Cell；输出后滤波的 100Hz gain 预计不到38dB，应标注 SYSTEM GAIN PENDING，不因其失败而偷改尺寸。完整代码、原始 CSV、Spectre 日志、校验 hash、总结报告提交 GitHub。若有异常按任务书 STOP。
