# ECE203 Round 5 — 输出级 / 双级增益 OTA 架构 × 分级 Flicker Noise × Chopper 解调位置（自主长实验）

**授权上下文（2026-11-16）：** 用户上课，预计 2–3 小时无法使用 PC，明确授权 Claude 自主完成**一次较大的架构实验**：尝试 **CD (common-drain / source follower) buffer**、**现有 C OTA + CS (common-source) 第二电压增益级**（即“两级增益 / 双 CS 思路”），必要时比较 **CS→CD** 复合输出结构；测定 Noise 的**来源、绝对输入参考贡献**，以及 Chopper **解调在 OTA2 前 vs 后**的真实差异。用户希望把**真实 MOS Chopper 的完整实现留到项目最后**，本轮只做 **理想开关、真实放大级**的架构性对比。**无需用户逐步骤确认**，每段先存结果，遭遇 blocker 也交付。不能因任务长而无限 debug。

## 0. 先读证据、锁定研究问题

**必读：** `CLAUDE.md`, `AGENTS.md`, `docs/automation_playbook.json`, `docs/ECE203_round4_integrated_results.md`, `docs/ECE203_round3e_ideal_chopper_noise_results.md`, `docs/ECE203_round3c_ota_compare_results.md`, `docs/ECE203_round3b_pseudoresistor_results.md`, `ece203_r4.il`, `ece203_ss_chop.il`, `ece203_ss_chop_noise.il`, `ac.il`。对照 Round4 原始 CSV，不要凭记忆改端口或参考节点。

**已知冻结基线**：
- Round4 最终系统：独立主 C OTA（NMOS diff-pair + PMOS mirror + single-side cascode，VCAS 1.10 V），真实 DRL 5T + 每个 CM sense 的 1pF，pseudo-R W3u/L2u，2x Cc50p/2x Cfb0.5p，输出 LP=31.8MΩ/20p，VREF 0.9 V，VDD1.8 V，一个理想100nA参考供实际偏置；3 electrodes+body 如 Round4。GAIN@100=**37.17dB**，fL=**0.073Hz**，fH=**121Hz**，逐点 input noise**16.57µVrms**，CMRR60**91.35dB**，DRL PM**90.1°**，I_total**724.8nA**（P=1.30µW），设计电容**143pF**，输入最低 |Zin|=168MΩ。
- **隔离 LP 的证据**：Round4 A2 OTA 输出 `o` 未接 LP，H100≈94.2×、fH≈8.79kHz。31.8MΩ/20p LP 接入后，H100≈71.7×、fH≈117Hz（R4 最终121Hz）。故 **Output loading** 是主要非噪声 blocker；但新级 DC bias/headroom、闭环极点/相位和增益仍需实际测。
- Round3E **1MHz** 无限速理想 OTA 带实测噪声谱：PNoise OFF15.85→ON2.01µV，是理想上限，不是物理 OTA。
- Round4 StageD **真实 C OTA + 理想开关4kHz** 单级前向链（**非整机**）：无斩波应用型 noise16.2µV；斩波后应用型5.58µV、逐频率10.6µV，稳态大纹波**约0.41Vpp**。不要把这组数直接嫁接到新整机。
- 课程硬指标：Gain 38–42dB、fL 0.09–0.11Hz、fH225–275Hz、0.1–250Hz 差分输入参考噪声<3µVrms、CMRR@60Hz>85dB、Zin10Hz>100MΩ、全芯片功耗<4µW、设计电容<1nF、VDD≤1.8V + 仅一个理想100nA参考，DRL PM/NEF/失配需要正确报告。**本轮固定 pseudo-R，所以允许 fL 暂时 FAIL，不要偷改高通来掩盖输出级效果。**

**要回答三个用户问题**：
1. **放大器怎么加第二级？** 是只要低输出阻抗 CD，还是值得花功耗增加真正第二级 CS 增益及其补偿？`OTA1` 先保持原封不动。
2. **OTA2 自身 Flicker Noise 与其系统贡献是两回事。** 实测 OTA2 的器件1/f /热噪声以及归算至 ECG 原始差模输入的噪声；禁止只说“两个级都16µV所以要把解调往后”或“前级闭环100×所以无需管二级”。
3. **解调位置：** 调制在 OTA1 前保持一致，比较解调 `D1` = OTA1 后/OTA2 前与 `D2` = OTA2 后。究竟减少多少输入参考随机噪声、增加多少 ripple/settling/loop instability？是否值得更高成本？

## 全局边界、资源、工作流

- **只加新东西**：`ece203_r5.il` + `batch/ece203_r5_*.il` + `Project/ece203_r5_*` cells + `run.sh ece203_r5_*` jobs + 新 ADE states。**严禁覆写/重建 Round3/4 的 cell、脚本、仿真结果或用户 Virtuoso GUI/进程**。允许 `ac.il` 注册新脚本/job；不要破坏旧 jobs。不要误把旧 Round4 的 COTA 复制变成普通 3 OTA INA；**绝不切回旧 Round1 架构**。
- 先通过 **isolated S2 前向链（理想 Rfb）**低成本隔离 output loading / OTA2 本体，再把至多 **1–2 个有希望的配置**移植到**Round4 最终真实偏置+真实 DRL+电极+pseudo-R整机**；记录每一步差异。不要一次把所有改动混起来。
- **优先级**：A 理想 buffer 因果对照 → B CD / CS 实现及稳定性 → C 噪声归因 → D 解调前后对比 → E 1 个最佳结构整机复核；时间/配额不够时停在已完成阶段，交付分阶段结果，**绝不为了 D 耽误 C**。
- 时限：用户预留2–3小时。按 **工作预算约150分钟主动工作** 规划，若工具运行超过预算，就提交截至当时数据并停止；进度可在30分钟/阶段 checkpoint 提交。**建议 Spectre case 总数 ≤25 个（不算小于等于两个轻量重试），PSS/PNoise 最多 3 个新 case**；不自动扫频/自动 sizing/通宵重跑，不做全 PVT、不做大规模 Monte Carlo、不设计完整真实 MOS Chopper。
- ieng6 quota 前先检查（之前仅剩约520MB）；每个 phase 保存 compact CSV/短日志/必要 PNG。删除**仅本轮**可重建 psf/cache，保留旧 Round4 的东西和用户文件；不可碰其他人进程。日志/错误、AC/Noise CSV 保存阶段后提交 GitHub。源码与数字可公开，**严禁提交 IBM PDK 模型、license、原始机密网表或个人资料**。
- **SSH/MATLAB防卡死**：所有 MATLAB `system('ssh ...')` 要使用 `-o BatchMode=yes -o ConnectTimeout=15 -n`，让远端命令 stdin 关闭；远程每项 bounded `timeout` 并检查 exit code；不能给 `grep` 空匹配表达式/无文件导致读stdin，必要时给 `/dev/null`；不要将超长脚本直接塞 MATLAB 命令，先 git push/pull + run.sh；不杀用户 GUI。长作业分批执行，失败就取错误日志。
- 物理判断：**CD 是 common drain/source follower，CG 是 common gate，不能混淆；CS 是 common source 有电压增益但不自动提供低输出阻抗**。**C OTA + 一个 CS 是 two-gain-stage**；若再加 CD 是两级增益加第三级输出缓冲，必须这样如实命名，不能偷叫“二级”。
- 所有电路关键输出 `Vout, VOTA1, VOTA2`、反馈采样点、LP 前后、DC reference、开关相位都要画**实际接线小图**；特别注明主反馈应来自**第二级/缓冲后、RC LP 前的节点**（作为默认对照，外部LP保持在主反馈外），这样比较时不引入混淆的外部RC相移。反相 CS 会改变符号，必须核实真正**负反馈**，而不只是 `dc` 迭代收敛。

## A — GOLDEN：先用“理想单位 buffer”隔离加载损失（重要、低成本、应最先成功）

**A0**：读取 Round4 frozen baseline，不耗算力重复；记录 H100/ fH/noise/增益 LP前后、原 DC o~0.902V。

**A1**：在 **复制的独立 S2 TB**（有 C OTA / 输入电容 / 反馈 / LP）放一个**理想高输入阻抗、零 offset、单位增益、低输出阻抗 VCVS**，在 `OTA1-output -> BUF -> feedback-sense -> (31.8M/20p LP) -> final-out`，反馈仍经 `Cfb||Rfb` 接到正确输入。理想 BUF 的增益1不是额外的 gain stage，不含噪声、没有附加供电负担，**标为 diagnostic**。控制：相同 S2 不接 LP vs 接 LP无 BUF vs 接 LP有 BUF。若因 VCVS 地/共模定义不对导致偏移，修正理想模型零直流移位（不可暗中改变第一级增益）。
**测** OP、H10/H60/H100、fL/fH（频扫低端<0.01Hz，高端>1kHz）、各节点 AC/输出纹波（无时钟应近零）。预估 **有机会 H100 ~87×/38.8dB、fH~250Hz**，只是预测，测不到按实测解释。此项直接判定仅靠输出低阻能否修复 Gain/fH，不能拿理想 BUF 当作课程最终合规。
**加一个 AC 小测试**：定义 `Zout` 开/闭环、注入位置、返回节点，至少读 10Hz/100Hz/250Hz，区分 OTA 内部高开环Rout与最终反馈输出阻抗，不可混为一谈。

## B — 真实晶体管输出级：至少 CD vs 一种 CS 二级放大

**B1 CD，优先**：固定 Round4 C OTA 电路/尺寸/VCAS不动，只增加一个**真实 MOS source follower (common-drain)** + 低电流 bias（由 R4 reference mirror 分支而来，最初可以用标明 diagnostic 的理想偏置）。建议先估计 NMOS/PMOS follower 的工作电平位移：当前 OTA 输出约0.902V，Source Follower 输出会有 **±Vgs** 的电平差，而非自动0.9V！真正闭环反馈取样要放在 buffer 后/LP前，设计一个**真实可偏置的 0.9V buffer 输出**，不能靠偷偷加理想 level-shifter宣称晶体管 PASS。
  - 优先选一个可实现的极性；允许**最多一次** NMOS ↔ PMOS 替换/源电流修正以满足头间距，不允许反复试空想方案。若现有OTA不能把内部电压摆至 follower gate 所需电平，明确标 **DC HEADROOM BLOCKED** 并保留理想-buffer证明，后续转 CS。
  - 测 transistor OP（VDS/VGS/VDSAT、最小margin）、IOUT、IBUF、Vin/out电压、A_v(buffer)10/100Hz、Rout闭环、LP两端的H100/fH、功耗、电容。(g_m) 越大 Rout 越小但耗电越高；如果只是估算Rout，要与注入仿真对照。
  - 晶体管 buffer 不可借用无噪声VCVS作为最后一级；对新bias的理想性须标诊断/最终来源。

**B2 C OTA + CS 第二电压增益级（真正 two-stage；“双 CS”思路）**：第一级继续使用冻结的 C OTA，不改输入对/单侧 cascode；OTA1输出驱动一个真实MOS **CS** 二级（器件及负载支路用同PDK；一版有根据的几何与偏置）。**禁止默认 CS 就有强驱动**：同时测第二级 Rout、Miller effect、环路增益、PM、UGF、输出负载极点；若 Rout仍高，则比较已知理想缓冲上限，不要以额外A0掩饰 loading。CS 级是**反相**，在电容反馈S2中必须核实闭环极性。若二级不稳定，允许**一套物理可解释的 Miller Cc 补偿 + 最多一次修改其数值（2种总计）**，每次都测 STB 环路PM（建议目标≥55°）与 Gain/fH。说明 Miller 零点/额外极点，不允许“没有测稳定性就把 gain 报成PASS”。必须确保所有 MOS 偏置电流可计入 source budget。
  - **B3 可选且有触发条件**：只有B2增益/开环A0改善但仍受Rout拖累，且 B1 CD 的 DC 实现已验证、资源还够，才尝试 **C OTA → CS → CD**（两级电压增益 + 一个输出缓冲，三有源功能级）；不得尝试“两只新CS+一只CD”无限叠级。否则B3明确 `NOT RUN (no justified trigger/time)`。
  - 每个B case与A1 ideal-buffer **同样 LP 31.8M/20p**、同样反馈采样点，输出量分别在 `OTA1`、`OTA2/buf`、`out`；主电压增益 38–42dB，fH225–275Hz，DRL尚未接全时只记 **forward-chain candidate**, 不宣称系统PASS。
- 除有明确理由，不随意修改主OTA输入管尺寸、VCAS、pseudoR、Cc/Cfb、DRL，保证两级比较可解释。最多 **两个完整真实输出结构**进入下阶段，若两者都BLOCKED，保存结果并停止重型测量。

## C — **首要研究目标：OTA2 的 Flicker Noise 到底伤害整机多少？**

对每个 B 中 **DC+负反馈稳定** 的候选（含现有单级 R4 参照），在相同 `0.1–250Hz`、相同反馈/电极/输出和归算端口条件下：
1. Spectre普通 `noise` 输出 PSD（给绝对 (V/√{Hz}) 在 0.1/1/10/100/250Hz）、积分 **输出RMS**、`outRMS / |Hdm(100Hz)|` 的应用型输入参考，以及 `sqrt(integral(Sout(f)/|Hdm(f)|² df))` 的**逐频率去嵌入输入参考 RMS**。两种不可混写；若增益变化很大，先给准确deembed。出 `NoiseSummary` 的 source-wise **V²**，由实例前缀把贡献分为 **OTA1 input NMOS、OTA1 mirror PMOS、OTA1其他、OTA2的全部 MOS（1/f 和 thermal 分开）、其他 DRL/bias/电阻**。
2. **禁止只比较 OTA1 / OTA2 各自单独测得的 input noise**：主结论要给 OTA2 **按完整系统输入折算**的量 (V_{n2,eq,in})，可以从独立 source contribution (S_{out,n2}) 经 (|H_{dm,tot}|²) 去嵌入积分，**不得简单除以主电路的闭环100×，也不要直接把两段 noise RMS 相加**。若本机 NoiseSummary 只给频带积分功率，不够支持逐频去嵌入，标明仅 approximate / 写清增益定义；尽量用按源 PSD 或唯一增加的噪声测试源分离OTA2贡献。可只做 stage-wise over-the-band power, 但必须有明确证据等级。
3. 记录 **OTA2 的 (1/f) 贡献本身**（flicker `fn`）与 white/thermal 分开：至少 1Hz/10Hz, integrated 0.1–250Hz，OTA2 flicker占整机 PSD 和功率的多少；记录该级单独 input-referred noise 作为教学辅助，但解释其**系统权重**。
4. **裁决规则**：若 OTA2 原始输入噪声跟OTA1同大但整机折算贡献 (<0.5µV)，则其被 chopper 包围的潜在改善极小；如果 `OTA2-referred-to-ECG` 的 (1/f) 大到接近/超过 ~1µV（或成为整机高占比），后移解调器有价值。但**这只是候选判定；真正结论要等 D 的波形与PNoise**。公平比较电极、源、反馈和 DRL 噪声；假如C无法拆来源也要如实记录 `NOT RESOLVED`。

## D — **解调位置前移/后移：真正对照实验，不做真实MOS Chopper**

只有 C 已完成且存在**稳定并有信号增益**的 1 个最有希望的多级候选，才进入。采用 Round4 单频 **4kHz** 的 **两相非交叠理想 1Ω/1e20Ω relay switch + ideal EINV** 技术参考；零频 OFF 始终要有 **同样电极/负载/反馈/偏置** 的比较。禁止扫多频/回到 1MHz 或造新的无噪声 VCVS代替真实OTA。理想 EINV、clock及开关**非物理且不计noise**：结果只能是位置可行性实验，**不能当最终真实 Chopper 成绩**。

比较两种实际节点：
- **D1 Early demod:** `Input mod -> real OTA1 -> ideal demod (around VREF) -> real OTA2 (CD or CS) -> feedback pickoff -> passive LP`。OTA2 的器件低频 noise 在解调器**之后**，不会被这对chopper抑制。
- **D2 Late demod:** `Input mod -> real OTA1 -> real OTA2 (CD or CS) -> ideal demod -> feedback pickoff -> passive LP`。OTA2 的低频 noise也有机会被搬离基带。注意 OTA2若是 CS **额外反相一次**，两方案必须校正clock相位/极性并验证负反馈，但不能用无约束的理想有源增益模块掩盖真实 OTA2 电平摆幅/带宽。
- **控制**：(f_{ch}=4kHz)、相同stage器件/偏置/LP/反馈/电极和 signal gain、每个开关元件 `rc,ro,deadtime`，same 1.8V supply; **必要的理想 sign inverter 只为复用此前非物理测试平台**，记录它在两种方案的位置、负载与噪声不被模拟；不可故意从 D2 提供更理想的驱动然后拿它胜出。若理想 EINV位置差使比较不公平，说明并尝试一种统一的等效理想 sign handling，不能够统一就标 `POSITION NOT COMPARABLE`。
- 先每个只跑小 `tran` / 受限 `PSS` waveform（包括 PSS steady-state 而不仅20ms启动），检查 `Vota1/Vota2/Vdemod/Vout, Vcm`：**平均值 DC、P-P ripple、peak/headroom、ECG small signal gain、每相 settling time**。至少 1mV step 或 10/100Hz可复核PSS/PAC gain，禁止以20ms尚未稳定的baseline漂移当作稳态。若 `PSS` 卡在 `Rfb~TΩ` 时间常数，不能靠跑上百万开关周期强行启动，用合理稳态方式或如实停止。
- **噪声闸门**：D1/D2 的 signal gain at 100Hz 对各自 OFF baseline 不得偏离>10%（若闭环增益本就偏移，先对照且解释，不要假定）。DC node不越轨，不能出现严重失稳，再执行两条 `Spectre PSS+PAC+timeaverage PNoise`（若可行总计两个新 Chopper case，最多一次定向修复；静态基线用C noise）；`pnoise maxsideband` 以 Round4 StageD 已跑通的**30边带为初始**，可做**一次单点sideband收敛检查（如改到50）**，别海扫。注意 `noisetype` 的最终网表/日志要核实确实 continuous-time averaged（以前报告仅猜默认值），PAC注入为差模 `pacmag>=0` + 180°，时钟 pacmag=0。
- 只对**同一测量输出**与同一`Hdm(f)`去嵌入：报告 `outRMS, outRMS/|Hdm(100)|, pointwise de-embedded, input PSD@1/10/100Hz, |H100|, ripple_pp, OTA2电流, loop PM`。每种D结果必须标真实 transistors + ideal switches/EINV，并声明是否只是**isolated S2**不是全整机，**不能将未加LP的输出noise 叫作最终ECG out**。
- 如 D1/D2某一条因单端 `EINV`、DC shift、反馈符号或PSS严重越轨而BLOCKED，不允许用理想高速第二级替换真实CD/CS“证明”位置优劣；可保留 C 的 static noise + 解析对照作参考，标 `PARTIAL`。***不做 MOS chopper、auto-zero、Ripple Reduction Loop、1MHz chopper、多级快速尺寸迭代***。用户已经把物理Chopper留到项目末尾。

## E — 唯一最佳候选回到真实 ECG（如果 A–D 已经得到足够结果）

- 从 B/C/D 中挑 1 个**由 DC可行+Gain/BW/Noise/PM/功耗判定的最佳** transistor stage，复制进 **Round4最终架构的独立 `r5` TB**：3电极/人体、2x耦合、pseudo-R、真实DRL+两条1p CM compensation、VREF/VCAS/偏置为**仅1.8V VDD+一个100nA ideal reference**，输出LP仍31.8MΩ/20p，**反馈取样在输出缓冲/第二级之后、LP之前**。这部分默认先测 **no-chopper**，避免改变多维度而不知改善来自哪。
- 测同配置 `DRL OFF/ON` 的60Hz CMRR（Cc mismatch 1%）和0.1µA身体干扰**分别**计算；不得拿 R4早期 OFF 53.9 vs R5最终ON做夸大进步的同条件对照。测 DRL stb/PM **以及主OTA新多级反馈STB/PM**（两个不同loop/probe），DC/headroom, 10/100Hz gain, fL/fH, |Zin10Hz|, 0.1–250Hz input noise两种定义，source budget，full VDD current including buffer bias，calculated capacitance ledger。若任一关键 spec failed，如实 `SPEC FAIL`。**不要借此自动动pseudo-R（fL仍~0.073Hz）**；这次只解决 OTA/LP/Noise/Chopper-placement。
- 若预算只够前向链，可把 E 标 `NOT RUN (budget)`，但 C/D 的可比较证据必须完整。**无需重做 Round4 12点 MC 或 PVT**；任何 PDK only TT / 27°C 保留说明。

## 自动停止/交付机制

按优先级完成这些文件：
1. **主报告** `docs/ECE203_round5_architecture_noise_demod_results.md`，章节 A ideal buffer, B CD vs CS(/CS+CD), C OTA2 flicker and input-referred breakdown, D D1 vs D2 placement, E integrated summary，最后 **decision memo**：
   - “只加CD还是要CS?” 由真实增益fH/PM/功耗/噪声数据支持；
   - “OTA2 1/f 是否需要后移解调?” 用 **OTA2 绝对 + ECG 输入参考数值**支持；
   - “D1/D2谁赢?” 同信号增益、输出位置、noise/ripple/headroom和PNoise证据等级；
   - “新架构真实改善多少?” versus R4指标，不得把初级 isolated 与整机混淆。
2. `docs/ece203_data/round5/` 分 `stageA`–`stageE`，至少：`r5_architecture_matrix.csv`、`r5_noise_stage_contributions.csv`、`r5_demod_placement.csv`、`r5_final_spec_matrix.csv`（E未跑则用 NOT RUN）、一张便于用户看的 `r5_overview.png`（可行时），保留有限 DC/AC/noise/loopgain/PSS原始CSV，**每行标方法、原始/解析、pass/fail/blocked、不适用指标**。
3. 代码文件 `ece203_r5.il` + `batch/ece203_r5_*.il`、`ac.il`新 job 注册，GUI ADE state 至少一个最有代表性的有效候选；Windows notebook按现有规范整理 `log.md`、PNG、`LOG.md`，失败也要保留部分实验。
4. **阶段性提交**：A后提交、B后提交、C后提交、D/E完成后提交，必要时阶段C先出部分摘要避免丢成果。多核不并行操作同一 cell/PSF 目录。报告要有 **Actual Spectre-run / Approx math / Ideal diagnostic / BLOCKED / NOT RUN**。
5. 最终末尾三行： **(1) 已证实的最佳结构与增益/噪声 (2) 解调位置证据与未解决项 (3) 下一次最小单点实验**。**完成后 STOP，不自动设计真实 MOS Chopper，不自动开始 Round6**。
