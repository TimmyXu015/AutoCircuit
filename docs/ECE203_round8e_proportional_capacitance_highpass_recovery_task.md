# ECE203 R8E — 课程收尾：同比放大 Cc/Cfb，尝试补偿运行中 0.338 Hz 高通偏移

**状态：TASK ONLY / NOT RUN。** 任务书由 GPT 编写并提交 GitHub，供 Claude 在 UCSD Cadence/Spectre15.1 运行；没有任何 R8E 测量结果。课程阶段停止无限追究 periodic chopping 根因，转向**保留真实 MOS TG 与真实 MOS pseudo-R、尝试在现有电容预算内恢复 fL_ON≈0.1Hz**。本轮不改 OTA W/L、偏置电流、TG/clock、CMFB/DRL/CD、RLP/CLP、COUT、pseudo-R。**必须同时检验增益、fH、Zin、静态稳定性与真实 PNoise，不因 fL “变好”就宣布整机 PASS。**

## 0. 冻结基线与课程规格（先读实际文件，不能靠项目口头总结）

- `docs/ECE203_round8d_tg_isolation_results.md`、`docs/ECE203_round8c_periodic_highpass_rootcause_results.md`、`docs/ECE203_round8b_pss_fixture_isolation_results.md`、`docs/ECE203_round7f_gain_and_loaded_lp_results.md`、`docs/ECE203_round7f_gain_and_loaded_lp_task.md`；
- `ece203_r8b.il`、`ece203_r8_noise.il`、`ece203_r8c.il`、`ece203_r7f.il`、`ece203_r7c.il`、`ece203_r7e.il`、`docs/automation_playbook.json`、`AGENTS.md`、`CLAUDE.md`。
- **母版：** `Project/ece203_r8b_tb_noeoc_chp` (`r8bSpecs()`), 真实 `XCI/XCO` MOS chopper、真实 `XPRP/XPRN` MOS pseudoR；零增益辅助支路 `EOC` + 1MF `CHP` 已删除，**不要加回来**。
- PDK IBM cmrf7sf tt/27°C、VDD 1.8V、2kHz `tch=500µs`、10ns dead-time、1ns edges、`cmin=1e-17` 数值选项、`gmin=1e-18`, `iabstol=1e-17`, `reltol=1e-5`；`Cc=60pF/side`, `Cfb=0.5pF/side`, `CLB=10pF/side`, `CLP=148pF/side`, `RLP=4MΩ/side`, 输出负载 COUT=10pF/side（stress load）。
- **基线已实测**：`fL_OFF=0.094296Hz`，`fL_ON=0.338068Hz`（2kHz真实TG，PAC sb0）；`H_ON(100Hz)=83.2514V/V=38.41dB`（课程38–42dB、余量只有+0.41dB），`fH_ON≈234.5Hz`、`fH_OFF≈234.6Hz`，`Zin_OFF(10Hz)=556MΩ`，`CMRR60_OFF=110.47dB`、`CMFB_PM_OFF≈84.55°`、`DRL_PM_OFF≈90.25°`、`P≈2.31µW`，设计电容`439pF`，PNoise S90 ON 0.1–250Hz **app=3.141µVrms, deembed=3.994µVrms**；ON fL 与 Noise 的两种口径均未达要求。
- **课程/项目验收门槛**：100Hz Chopper ON gain **38–42dB**；运行中 `fL_ON=0.09–0.11Hz`（同时报告 OFF，不用 OFF 假称 ON PASS）；`fH_ON=225–275Hz`（10pF/side 负载），`CMRR60≥85dB`、`Zin(10Hz)>100MΩ`、`CMFB/DRL PM≥60°`、`P<4µW`、**设计电容总量<1nF**、`0.1–250Hz` input-ref noise **<3µVrms**（app/deembedded 都独立报告，绝不偷换口径）。有静态和周期不同定义的指标必须分别列出，未经验证不能写 PASS。
- **R8D 机制约束**：双理想 TG 后 fL_ON 仍0.3356Hz；R8C换线性pseudo-R后0.3409Hz，说明原MOS TG寄生或pseudoR非线性均非偏移的必要原因；`Gsw`仅是待证实的**近似等效模型**，不是确认的漏电通道或真实MOS寄生。

## 1. 本轮只试两档比例，预登记预测（不是结论）

固定 `Cc/Cfb=120`，两侧严格同比缩放；只改变设计变量 `cc`、`cfb`，Cadence真实网表必须证明对应 `CCP/CCN` 和 `CFP/CFN` 都生效。**仍使用真实 MOS pseudoR**，该cell不得从 R8C线性版本继承。

| case | cell name | 比例 k | Cc 每侧 | Cfb 每侧 | 预估总设计电容（不含COUT/电极） | 粗略 fL_ON 模型 |
|---|---|---:|---:|---:|---:|---:|
| G0 原版只读 | `ece203_r8b_tb_noeoc_chp` | 1 | 60p | 0.5p | 439p | 实测0.3381Hz |
| **A2** | `ece203_r8e_tb_c2` | 2 | 120p | 1.0p | **约560p** | ~0.169Hz |
| **B35** | `ece203_r8e_tb_c35` | 3.5 | 210p | 1.75p | **约741.5p** | ~0.097Hz |

**重要：模型不保证准确**。最简反馈高通 `fL≈G_eff/(2π·Cfb)`，如果 `G_eff=G_MOSpseudoR+G_periodic` 在 Cc/Cfb缩放下近似不变，则 `fL_ON(k)≈0.338/k`。但电容重配会改变环路响应、输入阻抗、时钟扰动、频率响应；也可能改变 `G_periodic`，上表仅是需用PSS/PAC证伪的预测。OFF fL 的粗略预测 A~0.047Hz、B~0.027Hz；OFF 落在课程0.09–0.11之外是已知代价，**不能假装OFF和ON都达标**，本轮采用真实运行时 ON 为主要课程解释，同时报告所有冲突。
- 439pF预算：`2Cc+2Cfb+2CLB+2CLP+2CCM_DRL=439pF`；A增加 `2*(60+0.5)=121pF`→560pF（四舍五入 **560pF**，若Cc/Cfb的标称精确值合计是439则总560）；B增加 `2*(150+1.25)=302.5pF`→**741.5pF**。**使用实际网表作唯一预算来源，谨慎处理总数四舍五入，不能引用上表粗略数当精确面积**。
- **风险重点**：大Cc可能使`Zin10Hz`从556MΩ显著变低、减小反馈因子/稳定性裕量、加重电极衰减；`Cfb`增大可能改噪声增益/环路行为。之前不同阶段余量不是凭空“可用”。
- 不允许在此轮再扫随意的k、把Cc/Cfb拆开优化、调整RLP/MOS/bias 来救一个失败case；两档各自独立报告优劣。

## 2. 执行顺序与严格 Gates

### 预提交及网表审计（必须在任何Spectre前）

- 新 `ece203_r8e.il`、`batch/ece203_r8e_{build,static,pss,pac,pnoise,tran}.il`、`tools/r8e_watchdog.sh`、`docs/ece203_data/round8e/r8e_plan.md`、分析脚本与 CSV 生成程序。**先 Git commit 计划 + 代码，然后才调用 Spectre。** 建议用 `r8bSpecs()` create新cell而非拷贝原cell；exact names和参数生效以真实网表确认。路径隔离 `/tmp/lix015_r8e`、results `~/AutoCircuit_results/ece203_r8e`。
- 每个新cell的 audit：与 R8B原网表对比，零实例增删、零子电路变化、零额外参数变化，**仅`cc`及`cfb`的合法数值变化**；注意 `CCX=cc*dcc`，两组测量`dcc=0`；不动RLP/CLP、输出负载。发生任何意外变更 STOP该cell。
- 冻结 R8B旧cell/源码/PSF/Noise/R7F/R8C/R8D/R5N-F，严禁覆盖；理想TG II/R8C线性pseudoR版本只作为机制对照，不是本轮母版。

### Stage A — 两档 **静态 Phase-A** DC/AC/STB/CMRR/Zin 安全预检

- A2、B35均使用 `chen=0,pa=1,pb=0`、同tt27°C / 1.8V、输出10p/side，运行与 R7F 同口径 `dc+ac+stb`：fL_OFF（预计变小，不硬要求0.09–0.11）、fH_OFF（225–275Hz）、`H100_OFF`/中频平台增益（38–42dB，或如果因OFF/ON有已知差异，至少对波形可能性判断）、`Zin10Hz>=100MΩ`、CMRR60≥85dB、PM(CMFB/DRL)≥60°、输出CM偏差≤1mV、P<4µW、minOTA margin≥50mV、无floating/clipping；真实设计电容<1000pF（排除3×50nF电极等外部模型与COUT stress，以R7F同口径）。
- **硬停止条件**：若 netlist审计失败、Zin<100M、PM<60°、CMRR<85dB、P≥4µW、设计C≥1000pF 或严重偏置/削顶，**此候选 STOP，不进入ON**。A2失败不影响B35在相同理由尚可成立时的独立静态检查；若两者均失败，本轮STOP。对于静态OFF的fL下降是设计预期，不能因此禁止ON PAC，也不能写OFF PASS。
- 若静态H100_OFF未在38–42dB，而功耗/环路/阻抗等全部健康：记录为 **static gain caution**；可以做 **一次 ON PAC** 来确认实际工作增益，再按真实ON结果决定是否继续。避免用静态结果武断否掉实际ON可用性。

### Stage B — 只对通过静态硬门槛的候选做真实 2kHz MOS TG PSS + PAC

- 逐个依照 **A2然后B35** 测；相同源/clock、零差模输入，`fund=2k,harms=40,maxacfreq=200k,errpreset=moderate,tstab=5ms,maxperiods=40,cmin=1e-17,itres=1e-4`，PSS存文件供下一步PAC复用。PSS与PAC的 `save` 必须一致，避免R8C旧问题；分别验证Spectre **explicit achieved steady-state**、period closure/CM/no clipping，不允许从CSV表格`status=ok`推断收敛。
- PAC `pacd=1`，输入差模正PAC/180° 反PAC，Clock PAC=0，真实测 `|V(ep)-V(en)|=2V`；`relative,relharmnum=0`,0.01–1000Hz,40points/dec，度量 `H=(outp-outn)_0/(ep-en)_0`，统计`fL_flat`（5–10Hz 平台、−3dB）和`fH_flat`（同一平台、上侧−3dB，不可拿100Hz参考），H100和相位、各节点`p-n`、`fp-fn`、`bufp-bufn`；固定实际COUT 10p/side。
- **主要 course gates**：ON fL **0.09–0.11Hz**, fH **225–275Hz**, 100Hz增益 **38–42dB**；另外比较 H(0.1/1/10/100/250Hz) vs R8B。若 A2 fL≈0.17，这属于模型预期的“scout非达标”，继续预登记的B35，不得标完整PASS；若B35 fL未合适也不新增其它k，报告结果供下一轮决定。
- ON 100Hz H<38dB或>42dB、fH严重越界、PSS不收敛或偏置异常 → 标此候选FAIL/blocked，不跑该候选PNoise/60ms tran。若PSS失败，允许该候选**一次**先写清真实日志证据和数值原因的setting-only retry，不得改物理电路或时钟；仍失败 STOP该候选。
- 额外敏感项：计算ON vs OFF Zin定义（如果Spectre PSS/PAC能可靠读取输入端电流），但不得虚构已经具备周期输入Zin结论。若实测周期 Zin<100M，候选FAIL，即使静态Zin PASS。

### Stage C — 仅最有前景（通过ON fL/fH/gain）的单个真实 MOS 候选进入 PNoise

- 选择B35优先；若A2或B35没有全部通过ON频响/增益 **不要**为拿一个漂亮噪声数字而跑PNoise，把本轮作为“补偿假设失败/部分成立”报告。若两者都过：择增益余量/输入阻抗/电容量更健康者，不必都跑。
- 与 R8B R8B Stage D **完全同定义**：continuous-time 真实MOS`outp/outn`, PNoise timeaverage, `relative,relharmnum 0`, 0.1–250Hz, 20/dec, sideband ladder `S30→S60→S90`；如S60→S90超过RMS5%或1/10/100Hz density10%，允许最后**一个**S120检验，仍不过则**NOT CONVERGED**,不宣称规格达标。保留noiseSummary按XA输入对1/f与热噪声、PMOS负载1/f与热、XCI/XCO、XCD、pseudoR、RLP等分项。
- 分别输出 **application`sqrt∫Sout df / |Hon(100)|`** 与 **pointwise-deembedded `sqrt∫Sout/|Hon(f)|² df`** 的0.1–250Hz µVrms，原 R8B app 3.141/deemb3.994µV；目标 **<3µVrms**，两类指标各自判PASS/FAIL，任何一类失败不可写“两个都PASS”。PNoise数值截断持续单调上升时要声明残余误差与规格边缘风险。输出时钟确定性残差绝不能当随机Noise。

### Stage D — 只有Stage C得到可接受 noise 结果的一个物理候选，做最终 60ms transient

- 延用R7F的 `2kHz`, 100Hz/1mV true DM, 60ms, maxstep0.5µs（如需更小精度一份必须登记）、提取40–60ms稳定窗，记录 Hout100、H3(100Hz), 2k/4k spur, >1kHz deterministic residual RMS, edge glitch、op/on CM、output CM、`p/n` pseudoR较慢漂移、电源电流/总功耗、headroom；**H3 vs R7F -85.8dBc 和残差142µVrms**要有同定义对照，不能当噪声RMS。
- Stage D若不能达到gain/稳定性等，则课程整机不算PASS，即使PAC/PNoise ok。
- 若Stage C ON app<3但deembed>3，仍可为完成课程报告做**可选的一次**Stage D，但必须标 **Noise definition-dependent / not full signoff**；不能把过程合理化为两个Noise达标。
- 本轮不跑PVT/MC，不做额外MOS尺寸/偏置优化；一切不能验证的physical resistor/cap, clock jitter, ADC负载保留limitations。

## 3. 交付 / 复现 / STOP

- `docs/ECE203_round8e_proportional_capacitance_highpass_recovery_results.md`，`docs/ece203_data/round8e/` 下 plan、`r8e_design_budget.csv`、`r8e_static_gates.csv`、`r8e_pac.csv`、`r8e_pnoise_convergence.csv`（若运行）、netlist audits、原始Spectre.out与PSS convergence、PSS/PAC/PNoise CSV与plots、短时/全时tran raw压缩及SHA；每项明确 PASS/FAIL/BLOCKED/NOT RUN。报告独立列出 **真正ON fL**, **静态OFF fL**、Zin、H100、fH、PM、PNoise两定义和电容预算，不隐瞒OFF高通不能同时为0.1Hz的冲突。
- `docs/ece203_data/round8e/r8e_plan.md`必须在**仿真之前**提交，描述A2/B35两个case、各关口阈值、最多一次setting-only PSS retry/case、PNoise sideband上限120、60ms最多1个候选。所有重试先登记，失败结果保留，遵守 `~/AutoCircuit/run.sh` batch调用、watchdog，禁动旧cell/用户其它进程，禁上传PDK模型和凭据。
- 若实验发现 fL随比例k不按1/k变化，应优先分析 **原先 `Gsw` 是否独立于Cfb/Cc的假设不成立**；绝不靠设置静态器件让算法“证明”其预测。下一轮可只基于R8E的测量决定是否做参数插值或换另一条补偿路线。
- 结束即STOP，向GPT提交commit/报告/原始测量。**禁止自动开展R8F/R9/MATLAB全局优化**。

## Claude 启动短语

> 开始 R8E。严格执行 `docs/ECE203_round8e_proportional_capacitance_highpass_recovery_task.md`。冻结R8B真实 MOS XCI/XCO + MOS pseudoR，母版 `r8bSpecs()`，只改 `cc/cfb` 同比例：A2=120p/1p，B35=210p/1.75p，两侧对称，原R8B全只读。先提交新r8e_plan和代码并网表audit；两个候选各跑静态DC/AC/STB/CMRR/Zin/面积，再对合格者运行真正2kHz PSS/PAC测ON fL、fH、100Hz gain，注意OFF fL预期会低于0.1。只有ON频响增益合格，才选一个候选做PNoise S30/60/90(/120)边带收敛、若有望课程达标再做一次60ms真实TG tran。所有noise应用型/逐点型独立评估，Zin必须>100M，不能夸大未跑结果，严格保留Spectre日志与CSV；失败停，结果commit后等GPT验收。
