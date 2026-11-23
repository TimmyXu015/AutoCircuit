# ECE203 R8 — 实际 R7F MOS Chopper 的 1/f Noise：先验证周期噪声方法，再做同硬件 ON/OFF 对照

**状态：TASK ONLY / NOT RUN。** 本轮是项目核心研究，不是增加设计模块，也不是优化 MOS。目标是用 **IBM cmrf7sf 的真实 MOS 器件噪声**回答：在完全相同的 R7F 电路上，2 kHz Chopper ON 相比静态 Phase-A OFF，ECG 输入参考噪声是否降低？降低多少？剩下的 flicker/thermal/被折叠噪声各来自哪里？**不准将开关造成的确定性毛刺/高频残差误当随机噪声。** 如果真实周期噪声分析无法收敛或边带不收敛，诚实交付 **BLOCKED / NOT VERIFIED**，不得宣布 chopper noise PASS。

## 0. 权威资料、背景及范围

先读 `AGENTS.md`、`CLAUDE.md`、`docs/automation_playbook.json`、`docs/ECE203_CHOPPER_HANDOFF_AFTER_R7C_2026-11-22.md`，以及以下**实际仿真源**：
- `docs/ECE203_round7f_gain_and_loaded_lp_results.md`、`docs/ece203_data/round7f/r7f_stageC_summary.csv`、`r7f_static_summary.csv`、`r7f_plan.md`、`ece203_r7f.il`，**当前冻结候选 `Project/ece203_r7f_tb_gain_g0_load10p`**。
- `docs/ECE203_round3e_ideal_chopper_noise_results.md`、`ece203_ss_chop_noise.il`（旧理想 1MHz Chopper 已做 PSS/PNoise；不是此真实 MOS 2kHz 的噪声结果）。
- `docs/ECE203_round5_architecture_noise_demod_results.md`、`ece203_r5.il`：4kHz **理想开关**测试台 PNoise maxsideband 30→50 时 input de-embed 从 **11.76→14.25µVrms（+21%）**，说明**必须做边带收敛**；其 PNoise 默认 noisetype 曾无法独立确认。
- `docs/ECE203_round6b_real_mos_chopper_results.md`、`ece203_r6b.il`：真实 MOS TG 的一次 PSS 20 periods 不收敛；另一次 tstab10ms + maxperiods100 在边沿时间步缩到极小而卡住，**没有成功 PNoise**。不要假设这版 R7F 已天然克服该困难。
- `docs/ECE203_round5nf_final_noise_results.md`、`docs/ece203_data/round5nf/raw/F2_noise.csv`、`r5nf_noise_split.csv`：**R5N-F F2 非斩波课程保险设计**，2.880µVrms 逐点 de-embed / 2.930µVrms 应用型，且输入对/PMOS 镜像 flicker 共约 85.5% 噪声功率；其 OTA 尺寸与 R7F FD OTA 完全不同。只能作为**独立工程对照**，不能用它替代**同一 MOS OTA 的 ON/OFF**因果对照。
- 旧 `docs/ECE203_HANDOFF.md` 的“不要做 chopper”属于旧 Round-1 阶段限制，不覆盖当前 R8 授权；其课程噪声规格 **0.1–250Hz 输入 RMS <3µVrms** 仍适用。

**R7F 标称事实（不是 R8 噪声结果）**：2kHz（tch=500µs）、100Hz 1mV signal、额外 COUT 10pF/侧、RLP=4.0MΩ/侧、CLP=148pF/侧、Cc=60pF/侧、Cfb=0.5pF/侧、CLB=10pF/侧、真实 TG/FD OTA/MOS CMFB a2/DRL/CD/pseudoR/PMOS bias IREF100nA。2kHz 60ms transient `Hout100=83.2466=38.41dB`，输出 >1kHz **确定性**残差 141.7µV RMS（绝不是随机 noise RMS）；静态相位 A 的 `fL≈0.0946Hz` / loaded `fH≈234.6Hz`；P≈2.311µW；设计电容439pF。R7F 比较时最终输出为 **`outp-outn`** 而非 `bufp-bufn` 或 `fp-fn`。

本轮唯一操作变量：**`chen=0`（静态 Phase A：pa=1,pb=0）vs `chen=1`（2kHz TG）**；用**同一个**已验收 R7F cell 的新 noise-only 仿真 state / wrapper，不改变任何 MOS W/L、R/C、pseudoR、CMFB、DRL、bias、load、DC 输入条件、Clock 边沿时序/相位。理想 Clock/VREF/VCAS/100nA IREF 按用户授权保留，时钟抖动和非理想 driver 的随机噪声并不包含在此模型中。旧 cell、ADE、数据完全只读。**禁止修改 PDK 模型/人为叠加校准 VN noisy VCVS 来替代真实 MOS 噪声**。

## 1. 实验公约：正确的噪声定义与公平的输入传递

- 噪声测试将外部100Hz刺激置零 `vd=0`，`adm=0`、`vcmin=0`（按原系统参数实际语义核查），保持原外部电极/人体/偏置和 **COUTP/N 10pF**；但**一定要给现有差分输入驱动设置正确的 AC/PAC 小信号激励**，不能因为 `vd=0` 将 PAC 幅值也设为0。
- 先审查 `r6bSSpecs` 的 `VSPS/VSNS` 和 `VSP/VSN`；`vsin` 以前出现 `sinephase` sticky CDF 与 `pacmag` 符号错误：负端不能用负 `pacmag`，应使用**正幅度 + 180° PAC 相位**。必要时**只在新 R8 testbench**显式配置 PAC/AC probe（DC=0，noise=0），不能改动历史 R7F cell/旧脚本。PAC 100Hz transfer 的分母必须是**实际从电极 `ep-en` 读到的差分 PAC 零边带幅度**；同时保存 input source netlist 和 `VSPS sinephase=0`。
- 观察端严格是**差分输出** `V(outp)-V(outn)`。普通 Spectre `noise` 的 p/n 选择应正确设置（不要把地到单端输出当 differential）；periodic `pnoise` 也要确认 `p=outp, n=outn` 和它的具体采样/连续时间含义。**区分输出端噪声密度 V/√Hz 与 V²/Hz**，积分的是一边 PSD 之和，而不是把幅度密度直接积分。
- 统一频段 **0.1–250Hz**、建议每十倍频 >=20 points；保存检查点 `f=0.1,1,10,100,250Hz`（250Hz 位于扫频终点，插值按实际频点注明）。用 **同一条件**的信号传递 H(f) 计算两种等效输入噪声：
  1. **应用型** `Vn,in,app = sqrt( ∫_0.1^250 Sout(f) df ) / |Hdm(100Hz)|`（ON 用 0-sideband PAC；OFF 用静态 AC）。
  2. **逐点 de-embed** `Vn,in,deemb = sqrt( ∫_0.1^250 Sout(f) / |Hdm(f)|² df )`。在 HP 0.1Hz 附近，低频 gain 很关键，**不能用定值 H100 冒充逐点**。PNoise 有 folding，输入等效只是用零边带 ECG signal gain 规范化的系统指标，不等于 “所有物理噪声都来自输入端”。
- PAC 100Hz 及附近 `|Hout|` 必须与 R7F **有驱动**100Hz transient 的 83.25 V/V 同量级，建议 ±10% 内（偏离先查设置与偏置/非线性，不可强行归一化）；Off 100Hz 使用同一 R7F unloaded? **不可以**——必须保留 COUT10pF/侧，按 **同一** 10p loaded bench 静态 AC 量 H100。两者的输出 LP cutoff 若 PSS/PAC 未计算，应保持静态值、不要把它宣称为 ON 的周期 fH。
- **唯一有效的 Chopper 1/f 抑制证据**：相同器件 + 同一加载条件的 OFF ordinary noise 与 ON **收敛的** PSS/PNoise，报告两种归一化方法和按物理来源拆分；输出 spur、DM residual、H3、整流 DC 漂移须单独列在 deterministic 表，不并入 Vn,rms。

## 2. Stage A — 静态 TG Phase-A，真实 MOS ordinary Noise：先拿可靠的 OFF 锚点

使用 `ece203_r7f_tb_gain_g0_load10p` 的**全新 noise 仿真任务**，`chen=0`, `pa=1`, `pb=0`，`vd=0`，`dcc=0`，主信号源独立 AC差模（1V differential 已校准或等价）；保持独立 VDD/VDDD；旧 R7F 不重绘。仿真 `dc/ac/noise` 0.1–250 Hz（AC 可扩至 1mHz–100kHz 作为 H(f)），确认真实 PDK模型、偏置和静态温度 tt27°C。
- 保存 `Hoff(f)`（尤其 f=0.1/1/10/60/100/250）、差分 `Soff(f)` 输出 PSD、上述两种 `Vn,in`、input/output noise checkpoint、NoiseSummary overall + 0.1–1/1–10/10–100/100–250 分带，最好能按 **XA.M1/M2 flicker、XA.M3/M4 flicker、这些器件 thermal、XC CMFB、XD DRL、XCD CD、XCI/XCO TG channel noise、XPRN/XPRP pseudo-R、RLP_P/N 电阻热噪声及 PMOS bias** 等分组。器件具体谱的 1/f/thermal 名称以 Spectre summary/model 实际结果为准；不可将无记录来源自动归零。电阻是 ideal analogLib 但自带 thermal noise（若 noiseless 选项为默认，则须核对）。
- 噪声数值双验证：OCEAN SKILL 积分与读取 CSV 后 Python `trapz(S_V(f))` 的 RMS 差异 <=2%（若存在插值/频点精度差异先解释）；如果能得到 Spectre integrated noise summary 与上述逐点 de-embed 相比，也要报出来。
- PASS Stage A：独立AC差模激励传递非零且 H100 在合理范围（参考 R7F 静态 loaded Hout100=86.06），NoiseSummary/PSD 有效、端口确认为 outp−outn、数值/积分自洽，真实 PMOS/NMOS flicker 与 thermal 噪声确实参与。**不要求静态 OFF <3µVrms**，若未达标正好是对照基线的科学价值。
- 使用 Stage A 噪声分组预测 R8 最需关注的是 OTA input pair / PMOS load flicker 还是其它源，**但不要未经 ON PNoise 就宣称“斩波会下降 X 倍”**。

## 3. Stage B — 最小真实 TG PSS/PAC feasibility gate（可能失败，先低成本）

**重要：2kHz 周期是 500µs；为了让 PSS 基波确实为 2kHz，`vd=0`，不要在周期解中注入 100Hz 输入正弦，避免被迫求 100Hz superperiod。** `chen=1, pa=1, pb=0, tch=500us`，所有 MOS 状态同 R7F，输出仍 outp/outn＋COUT10p。
- 单独新 job 跑**只有 PSS**的验证（后续 PAC 需要时再跑），不要第一步就请求昂贵的 PNoise。使用 MMSIM 15.1 / Spectre 的真实分析语法，先本机核实 `pss` 支持的 shooting/HB, `harms`、`tstab`、`maxperiods`、容差和 phase conventions；起始参考历史 `r6bSysPss()`，其 2kHz `harms=40` 失败，`cmin=1e-17` 是后来 R6D-R 成功瞬态的数值关键。**保留 log/网表和实际 tstab**；不要直接复用 R6B 已经失败的无 cmin 默认方法。
- 先验证**零输入、Chopper ON 的普通 tran**（若无可比零输入 trace，最多一条 10–20ms smoke，以 R7F 60ms 原数据的收敛经验为依据），检查 `op/on, fp/fn, p/n, bufp/bufn, outp/outn, vg, pref/ib, clock` DC 和两个相位无削顶，反复周期窗口中的平均/漂移与关键节点变化。**慢 pseudo-R 可能存在分钟尺度的整流漂移或伪稳态**，即使 60ms 平均稳定，也不能替 PSS convergence。
- 首次 PSS 目标有明确 stop：例如 `fund=2kHz`、`harms=40`、moderate、tstab依据已有短时波形，`maxperiods<=40`，启用 per-run watchdog 与运行时/空间上限（参考仓库 watchdog）；若 PSS 报未收敛、edge minstep 卡住、periodic endpoint/模型工作点可疑，**保留失败并只允许一次有明确数值原因的修复**（如收紧/放宽适当 tolerances、tstab、PSS shooting option、gear2only/cmin 的相容配置；**禁止修改电路、clock rise/fall、Vt、MOS、pseudoR 或将真实 TG 换理想 relay 来制造收敛**）。第二次仍不行，**STOP：R8 periodic noise BLOCKED；不生成任何 ON PNoise 数值**。
- Stage B PASS 必须提供 **Spectre 明确的 PSS converged status**、真实 2kHz fundamental、PSS TD 周期端点闭合/时间波形与物理工作区/无削顶证据、时钟和驱动的 zero-signal netlist 审核，以及已验证数值容差；不能用“pss_td 文件存在”“PSF 里有 wave”冒充收敛。pseudoR 长期 offset 风险在报告中明标。
- Stage B 成功后跑零边带 **PAC** 0.1–250Hz（可附 1–100kHz用于分辨，但周期系统 100kHz data 必须能解释），验证真实小信号 ECG gain：`HPAC0=(outp−outn)_harmonic0/(ep−en)_harmonic0`，100Hz约 R7F chopped transient 83.25 V/V（允许初始 ±10%），且 `Hoff100` 从 Stage A 独立获得。**PAC Source 必须有被确认的 PAC 幅度/相位，Clock的 PAC=0**。若 PAC 不可信，Stage B仍 **FAIL**，不进入 PNoise。

## 4. Stage C — 真实 MOS PNoise 与边带收敛（不是“有结果就PASS”）

Stage A/B 通过才做。**Spectre 执行前核实当前版本** periodic noise 的 sampling / `timeaverage` 类型和 `pnoise` differential output 语义：`/outp` 对 `/outn`，`sweeptype=relative, relharmnum=0`，`0.1–250Hz`，`maxsideband` 正确出现在最终 netlist。旧 R3E/R5 中传的 `?noisetype "timeaverage"` 在网表里可能因默认值被省略，**必须从 Spectre 实际帮助/日志或数值协议确认语义；不能凭推测称其为 sampled 或 timeaverage**。
- 边带预算先快后全：**S10 pilot**（例如 1/10/100Hz 密度与总 RMS），随后 **S30 → S60** 两套完整 0.1–250Hz；若 S30→S60 仍变化明显、且算力允许，**最后最多追加 S90**。所有这些是**同一物理电路的 PNoise numerical-convergence cases**，不是几个噪声设计候选。每档保留 `pnoise` netlist、PSF log、完整谱、输出/input 两种积分、source summary；必要时每档 restart PSS 亦须真实记录。
- **积分收敛门槛**：最后两个已完成高档（优先 S60/S90，最低 S30/S60）输入等效**应用型和逐点型 RMS**差异 <=5%，且 1/10/100Hz 的 noise density 各差 <=10%；若不满足，标记 **SIDEBAND NOT CONVERGED**、可以报告值和随边带变化的曲线，但**不得**写“R8 已测出真实噪声为 X µV”或“达到 <3µV”。最多四个档（10/30/60/90），不做无限增加。
- 若 maxsideband=90 仍不收敛，停止并报告可能的 TG 开关边沿1ns、高频折叠、OTA 带宽/模型及计算资源边界；**不要用 30 档的数值充当最终定值**。可用解析理想折叠模型帮助解释（标为 Approx），但不能冒充真实 MOS PNoise。
- PNoise 成功时输出完整 **ON spectrum** at 0.1/1/10/100/250Hz、输出带内 RMS、两类等效输入 RMS、对比 OFF 同一结果的 *RMS ratio* 和 *power ratio*，以及 **`ON <3µVrms?`** 的课程噪声 gate（若 2.95–3.05µV 附近，考虑足够精度/定义，不能取整凑 PASS）。分组源清楚区分：
   - OTA XA input pair & PMOS load 的 **flicker** 是否显著减少、折叠 thermal 是否反而占主导；
   - MOS TG XCI/XCO 的开关 channel noise 与边带贡献；
   - MOS CMFB XC、MOS DRL XD、CD XCD、pseudoR（真实非线性）、Bias mirrors MP0/1/2、RLP_P/N（linear passive thermal）与其它；
   - 若旧 Spectre 的 `noiseSummary(?result 'pnoise)` 能提供源明细，输出 **全频带与4个子带**，正确逐带按各自 PAC gain de-embed（不要把某个器件的输出噪声占比当作输入折算电压）。**如果 Spectre 该版本拿不到源分组，则报告 SPLIT NOT AVAILABLE**，不要用关闭模型噪声、重建MOS、不受控多次仿真凑结论。
- 附加科学检查：一页图同时画 OFF/ON **input-ref noise density**（对数频率）以及两者的 output PSD；另一张噪声源贡献图（仅有真实噪声分组时）；一张 S10/S30/S60(/S90) 积分/特征点收敛图。比较 ON noise PSD / noise gain 的 0.1 Hz 端点要警惕 Rfb 的伪电阻偏置和 PAC 的极点口径。
- OFF 与 ON 的增益不完全相同，尤其 H100 86.06 vs chopped约83.25，因此必须明确两种**自己的** H(f) de-embed；不能直接拿输出 RMS 比例当输入抑制倍率。

## 5. 结果解释与严格停止条件

- **禁止** 1) 把 R7F 的 141.7µV deterministic switching residue/H3 当为真正 noise rms；2) 把静态 `noise` 在 `chen=1` 之下运行当 ON; 3) 把 R3E 的 1MHz ideal OTA 的 2.01µV 冒充 R7F 2kHz MOS 噪声；4) 用没有 sideband convergence 的 R5 11.76µV 和 R7F 对比；5) 直接以 R5N-F 2.88µV 对比下结论“Chopper降低X倍”（器件、拓扑、面积不同）。
- Chopper OFF 与 ON 仅比 2kHz 周期 Chopper，**这不是 chopper 频率扫描**；不得擅自提到 4kHz/1MHz 去“追求 PASS”。
- 如果 Stage A PDK ordinary noise 不可验证：Stage A FAIL/STOP。Stage B PSS/PAC 不收敛或许可证不支持：**Stage B BLOCKED/STOP**，只交 OFF 结果＋真实失败日志；可提出下一轮单独获授权的 truncated PNoise/瞬态噪声方法论任务，但**不得在本轮自动切换方法并声称已测 ON**。Stage C sideband 未收敛：C NOT CONVERGED，不做任何未论证的噪声改善签收。
- 只有 **A valid + B valid + C converged** 才能给出“ON/OFF 1/f suppression quantified”的 PASS；噪声 `<3µVrms` 是独立的 COURSE SPEC PASS/FAIL，不因技术分析成功而自动达标。即便 R8 通过，PVT/Monte Carlo、PDK LP resistor物理实现和 pseudo-R 长期偏移**仍未验证**，噪声结果只是 tt 27°C。
- 有结果就马上停，不自动优化 OTA/noise/clock/LP，不自动进入 R9。

## 6. 工件、运行纪律和提交

- 新 `ece203_r8_noise.il`、`batch/ece203_r8_*.il`，如果需要新 cloned testbench 仅建立 `Project/ece203_r8_tb_noise_*`（**净表器件与现有 R7F 相同，只允许必要的小信号 AC/PAC probe 修正；完整审计**）；否则**只读原 R7F cell 执行新仿真，不要调用历史 build**。新 ADE noise state 可创建在新 cell 上；旧 R7F `r7f_gain_g0_load10p_phaseA` 不动。
- **先**提交 `docs/ece203_data/round8/r8_plan.md`（预登记 stage gates、频点、sideband、tstab预算、源分类、测试台哈希）及实验代码，**后**运行 Spectre；任何数值修改须记录原失败并单独 commit 说明，避免事后“预登记”。
- 新数据只写 `docs/ece203_data/round8/`，至少 `r8_static_noise.csv`、`r8_pss_attempts.csv`、`r8_pac.csv`、`r8_sideband_convergence.csv`、`r8_noise_summary.csv` 和相应 PNG、脚本、`raw/stageA|B|C` 中真实输入 netlist、Spectre stdout/err、完整 noise spectra、PSS TD/pnoise/noise summary 或明确 NOT RUN。
- 报告：`docs/ECE203_round8_real_mos_chopper_noise_results.md`，开头用 **A/B/C PASS/FAIL/BLOCKED + 证据等级**，并明确 **<3µVrms spec PASS/FAIL/NOT VERIFIED**。给我核查的最小指标：同 MOS 100Hz HOFF/HON、OFF/ON output RMS、OFF/ON application/deembed RMS、低频 PSD、sideband convergence 和 PSS 收敛证据。
- 使用 IBM `cmrf7sf tt`、27°C、Spectre MMSIM15.1 / IC618；长/重 PSF 尽量 `/tmp`，输出聚合 CSV+PNG+log+必要 PSS波形，watchdog、空间上限；不把完整巨量 PSS/PSF 上传 public GitHub。不要杀用户自己的 Virtuoso / spectre 进程，只清理本轮可重建对象。公开仓库**不上传 IBM PDK model 全文、用户名密码或密钥**。保存具体 Git SHA、running time 和 reproducibility commands，Windows 实验记录遵守 `docs/automation_playbook.json`。
- 结果不能证明实际 clock jitter、供应噪声、板级噪声、电极极化，以及任何 sampled ADC 后端噪声。输出 LP 是**理想 analogLib 4MΩ/148pF**，其器件实物实现和热噪声/寄生参数的真实性需分别披露。
- **STOP**：严控 PSS 数值重试（最多1次）、PNoise侧带档（最多4档），不进行器件参数扫。失败结果也完整提交，不隐藏。

## 7. 给 Claude 的启动话术

> 开始 ECE203 R8：先完整阅读 `docs/ECE203_round8_real_mos_chopper_noise_task.md`。目标是在冻结的 `Project/ece203_r7f_tb_gain_g0_load10p`（真实 MOS 双 2kHz Chopper、真实 MOS OTA/CMFB/DRL/CD/bias/pseudoR、4M/148p LP、60p input Cc、out 10p loaded）上研究真实器件 1/f noise。
>
> **先 Stage A**：TG停 A 相 `chen=0`，验证普通真实 MOS `dc/ac/noise` 的 differential output input-referred 0.1–250Hz 噪声及器件分组。**Stage B**：`vd=0` 让 PSS 只有 2kHz 周期，参考 R6B 已失败的真实 TG PSS 和 R6D 的 cmin 方法，最多两次有记录的 PSS 尝试；收敛后跑 0-sideband PAC，核对约83V/V的100Hz信号增益。**Stage C**：PNoise 多档 `maxsideband`（10/30/60/必要时90），直到后两档输入 RMS <5% 变化且特征 PSD <10% 变化才签收，算清 ON/OFF 同一MOS的两种 input-referred RMS、flicker/thermal和folding；未收敛必须 BLOCKED，禁止冒充真实 noise PASS。
>
> 不修改历史任何 cell/源MOS/R/C/clock/bias/负载；先 pre-register & commit 再运行，所有网表审计、PSS收敛日志、PAC/PNoise谱、NoiseSummary、积分检查、图表上传 GitHub。若失败提交可重现失败日志并停，不得自动调整频率或开启 R9。
