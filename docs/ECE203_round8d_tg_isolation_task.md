# ECE203 R8D — 高通 fL=0.338 Hz 根因隔离：输入 XCI / 输出 XCO TG 的受控理想化 2×2 对照

**STATUS: TASK ONLY / NOT RUN.** 这轮给 Claude 在 Cadence 执行；本文件只是已提交的实验任务书，尚无 R8D Spectre 结果。目标是在 R8B/R8C 真 MOS 已验收的基础上，区分 **真实 TG 非理想性** 与 **即使理想开关也存在的周期闭环效应**，并在需要时判断 XCI 输入换向与 XCO 输出解调的相对贡献。R7F/R8/R8B/R8C 历史 cell、ADE、data 全部只读。

## 0. 必读资料 / 实测锚点

- `docs/ECE203_round8c_periodic_highpass_rootcause_results.md`、`docs/ece203_data/round8c/r8c_fl_summary.csv`、`r8c_node_transfer.csv`、`r8c_netlist_audit_B.txt`、`r8c_plan.md`、`ece203_r8c.il`；
- `docs/ECE203_round8b_pss_fixture_isolation_results.md`、`ece203_r8b.il`、`ece203_r8_noise.il`；
- `ece203_r6b.il`（真实 4-TG 全差分 chopper 模块的 10-pin 定义、端口映射和 4 相 complementary clock）、`docs/ECE203_round6b_real_mos_chopper_results.md`（TG Ron@0.9V 约1.68kΩ；0.9V/1.05V 实测跨度约1.4k–2.14kΩ）、`ece203_ss_chop.il`（已有 `chSw()` 实现 `analogLib/switch` 的 CDF/symbol）；并读 `AGENTS.md`、`CLAUDE.md`、`docs/automation_playbook.json`。
- 冻结基线：`Project/ece203_r8b_tb_noeoc_chp` 的真实两组 `XCI` / `XCO` 都是 `Project/ece203_r6b_tgchop`，6 个 MOS 子电路、线性 LP、MOS pseudoR 等完全不变；`EOC` 和 `CHP` 已移除，**绝不加回**。
- R8C 在相同物理 MOS 电路上证实 **OFF fL=0.094296 Hz**，2kHz 运行时 **ON fL=0.338068 Hz**，H100 OFF=85.666、ON=83.251 V/V；PAC maxsideband1与3结果完全相同，100Hz PAC 与真实 chopped transient 吻合。
- R8C 将 `XPRP/XPRN` 替换为 3.128TΩ 理想 R，得到 `Q_LIN=3.604` 与原 MOS pseudoR `Q_MOS=3.585`：**pseudo-R 的非线性不是必要原因**。此次 R8D 回到**真实 MOS pseudoR**，不继续使用 R8C 线性替身。
- 数值：Spectre 15.1 / IBM cmrf7sf tt / 27°C，`gmin=1e-18, iabstol=1e-17, reltol=1e-5, cmin=1e-17`，clock `tch=500µs`、rise/fall=1ns、非重叠 dead time 原样保持。R8B PSS a1（`fund=2k,harms=40,maxacfreq=200k,moderate,tstab=5ms,maxperiods=40,itres=1e-4`）已在真实 TG 上 3 iteration converged。
- **唯一允许的诊断物理自变量**是 input `XCI` / output `XCO` 的 TG 主体从 MOS → 理想等效开关。其它真实 OTA、MOS CMFB、DRL、CD、PMOS bias、MOS pseudoR、Cc60p/Cfb0.5p、LP4M/148p、COUT10p/side、电极网络、clock完全冻结。绝不修改旧 `r6bTgDevs()` / `r6bClocks()`。

## 1. 理想 TG surrogate：首先确保是真正“相同逻辑的开关”

历史的 `chSw(name,a,b,ck)` 采用 `analogLib/switch`：`vt1=0.8V,vt2=1.0V,ro=1e20Ω,rc=1Ω`。**本轮新理想 TG 使用同一 symbol/CDF、相同阈值与 Roff，但 RC 初值预先定为 1.68kΩ**，来自 R6B 真实 TG 在 Vcm≈0.9V 的单位测试（不用旧 1Ω 以免把更低 Ron 当成诊断结论）。名称以防碰撞可用 `ece203_r8d_ideal_tg`，保持与 MOS chopper 的 10 pins 一致：`INP INN OUTP OUTN CKA CKAB CKB CKBB VDD GND`，unused CKAB/CKBB/VDD/GND pins 按正常 Cadence 规则处理，不能引入浮置有源方程或新电容。**必须先用 Cadence 读取/确认真正 analogLib switch 的 CDF/端口，不能根据猜测自动新建非法 cell。**

在此新 cell 中恰好放 **4** 条无寄生理想双端开关；不要加理想 OTA、VCVS 反相器或任何新的去耦器件：
- A 相：`INP↔OUTP` 由 CKA 控，`INN↔OUTN` 由 CKA 控；
- B 相：`INP↔OUTN` 由 CKB 控，`INN↔OUTP` 由 CKB 控。
- CKA/CKB 是原 0/1.8V 四时钟中的两个，互补 CKAB/CKBB 与之精确镜像；理想开关不显式使用互补端并**不改变开关的 A/B 时序**。此 surrogate **没有 MOS gate-drain overlap、junction capacitance、charge injection、leakage、nonlinear Ron**，是诊断理想化，不是 manufacturable MOS 实现。下游 OTA/CD、反馈完全留真实。

### Stage A：surrogate 的便宜预检（必须先过）

- 新理想 TG 独立 unit bench（不覆盖 `ece203_r6b_tg_tb`）：在 Vcm 0.9V、两相静态时验证导通路径、关断路径、交叉方向、0.1/1mV 信号换向，导通等效电阻≈1.68kΩ，关断远大于3.128TΩ；再用真实 2kHz clock 跑 **小于等于2ms** smoke（仅理想 TG module），确保 A/B 相+1/-1、10ns dead time、无重叠导通或人工 short、波形无异常。
- 阈值固定 0.8/1.0V，不更改 clock。若 surrogate 不支持 PSS 或错误端口无法得到正确结果：Stage A FAIL，STOP，不要擅自换一个不等价开关模型。
- 预先明确：匹配 0.9V Ron 是有限意义上的静态近似；实 MOS Ron 与开关态随 Vcm/摆幅变化。在电路接近 3TΩ 反馈、1.68kΩ 开关通态的工况下，预期 Ron 不是唯一极点来源；但比较只可称为 **“TG MOS 非理想性整体贡献”**，不能直接称为纯 overlap C 的精确因果测量。

## 2. 正交电路矩阵（按成本最小的顺序）

必须建立**全新 R8D-only** testbench cells，父版是 `r8bSpecs()`（**真实 MOS pseudo-R**）。新开关 `ideal_tg` master 的 pins + nets必须与 `r6bTgInst` 一模一样。只替换指定实例的 master，不更改完整反馈/电极/其他元件。**所有 OFF/ON 小信号实验都用同一 cell、同一参数、同一端口定义**。

| Case | XCI input chopper | XCO output chopper | 作用 / 顺序 |
|---|---|---|---|
| **MM** | real MOS | real MOS | R8C / R8B 只读 baseline，fL_OFF=.0943，fL_ON=.3381 |
| **II** | ideal | ideal | **优先第一个**：判断理想开关是否仍出现异常 |
| **IM** | ideal | real MOS | 只有 II 证明需要分组归因时运行 |
| **MI** | real MOS | ideal | 同上；对照 IM |

建议新 cells：`Project/ece203_r8d_tb_ii`、`Project/ece203_r8d_tb_im`、`Project/ece203_r8d_tb_mi`，另有新 master `Project/ece203_r8d_ideal_tg`；不要覆盖 `Project/ece203_r8b_tb_noeoc_chp`、`Project/ece203_r8c_tb_linear_pr`。

**先 Stage B（II only），再按结果决定 Stage C：**
- 每一个 candidate 先静态 `chen=0` Phase-A DC+AC 1mHz–100kHz，测 `op/on, p/n, fp/fn, vg, ib/pref, buf/out, I(VDD/VDDD), |Hout100|, fL_flat`。OFF 近似等效 Gate：原 MM fL=.0943 的 ±15%，Hout100=85.67 的 ±5%，关键节点偏置差≤2mV，CMFB供电电流/总功耗差≤5%，无浮置/削顶。若失败 **STOP**，不可拿严重不等效 surrogate 的 ON fL 来归因。
- Stage B II OFF 通过→运行 2kHz `chen=1,vd=0,adm=0,dcc=0,pacd=0` PSS a1；与 R8B 相同参数（尤其 cmin），PSS **必须明确 converged**；之后用 readpss 跑 `pacd=1` sideband0 `0.01–250Hz`、40/dec，归一化 by actual `V(ep)−V(en)` sideband0。输出 `outp−outn`、`fp−fn`、`p−n`、`bufp−bufn`，100Hz校准、5–10Hz plateau、fL_flat。Saves在 PSS/PAC 两段必须**完全相同**，避免 R8C 因多save terminal currents 造成 readpss equation-size mismatch 和重复PSS。
- II 的 `Q=fL_ON/fL_OFF` 是主判据。预登记分类：
  - **II fL_ON 在0.08–0.13Hz且 Q≤1.4**：恢复到原目标附近，真实 MOS TG 非理想性**必要**；执行 Stage C IM+MI 区分来源。
  - **II Q≥2.7**（即使全部理想化仍存在大半偏移）：说明**MOS TG 特有寄生不是必要条件**，优先考虑周期换向的采样/死区/系统小信号电荷传输及传递定义；原则上 STOP，不需浪费两份额外 TG 替换实验；给出下一轮围绕 periodic switching itself 的机制方案。
  - **1.4<Q<2.7**：两类机制可能都有贡献，允许 Stage C 做剩余单 TG cases，分析交互项。
  - **II 失败**：假设未验证，先检查 surrogate 行为、PSS solver 的真实错误；允许同 cell 一次有证据、提前登记的数值设置重试（PSS-only，保留原失败日志），仍失败 STOP，不能借机修改器件去制造 PASS。
- 任何 case 的 **100Hz PAC增益**若较真实 MM 83.251 V/V 偏离 >10% 或 p/n、fp/fn PSS DC/peak-to-peak 差 >30%，须标记**surrogate altered operation / attribution downgraded**，即使 fL 看起来漂亮也不能把它称为成功修复；可以报告数据，但不得做强机制推断。

### Stage C（only if gated）：两份单 TG 替换

- 新建 IM 和 MI，各自 OFF gate→PSS converged→PAC，使用**与 II 完全相同设置**，不换其它电路值；如一份不通过或PSS无法收敛，标该分支 NOT VERIFIED，**不要把其它分支结果自动归因该开关**。每份最多1次数值 retry，且 R8D 总的额外 retry 数≤2。
- 汇总 `fL_OFF, fL_ON, Q, H100_ON, Hplateau, p/n_pp, fp/fn_pp, clock-edge DM spur` (仅有相同PSS waveform方法可比时；不是 random noise)。
- 用 **2×2 factorial** 的描述性分析计算与报告：XCI idealization 主效应、XCO idealization 主效应、相互作用（以 `fL_ON` 或 `Q` 为 response 的差分比较），不要仅凭 “IM 比 MI 更低”宣称纯电容主因。
- 如果某一组理想化明显恢复低频性能，下一轮才针对该物理 TG 的关断寄生、时钟耦合和 Ron 进行小而受控的 MOS 参数研究；**不可在本轮顺手更改 MOS W/L**。

## 3. 理论模型可选，但**要标“假设”**

R8C 曾作数量级估算：如果把 `Q_MOS=3.585` 的偏移**完全**当作反馈求和节点附加线性导纳，则 `ΔG=(Q−1)/3.128TΩ≈0.83pS`，`R_eq≈1.2TΩ`；在2kHz 单电容交换的**极简理想模型**下 `C_eq=ΔG/fch≈0.4fF`。它可能只是 switched-capacitor effects 的一个等效标度，**未被任何仿真直接测定**；更不能在不知道真实闭环离散时间动态时用它拟合“实际 MOS overlap capacitor”。若 R8D 测出了 Q 可复现，可将各 case的 `ΔG_model`列成供后续 MATLAB sensitivity modeling 的待证实 proxy 参数。

本轮不是 MATLAB 优化阶段，只先建立真正可信的模型归因数据。用户长期目标是 MATLAB modeling→simulation comparison→Pareto-optimal Noise-Power-Area trade-off；这些假设参数需清晰标记证据等级。

## 4. 报告、预算、纪律

- 代码 `ece203_r8d.il`，新 `batch/ece203_r8d_*.il`，`tools/r8d_watchdog.sh` 与 `docs/ece203_data/round8d/r8d_analysis.py`、`r8d_netlist_audit.py`。
- 在**任何 R8D Spectre 前**提交 GitHub `docs/ece203_data/round8d/r8d_plan.md` + 可重复的代码、预先定义的 Gates/branch criteria；中途不得“事后”改变II->IM/MI进入条件，所有偏差和solver retry按时间顺序记录。
- 交付 `docs/ECE203_round8d_tg_isolation_results.md`：A/B/C PASS/FAIL/NOT RUN、完整 netlist实例差异与子电路 audit、每个 case OFF AC and ON PSS/PAC原始谱及 source/clock config、主要节点的周期 waveform、`r8d_matrix_summary.csv`、图、Spectre converged log、异常/失败记录。旧 R8B/R8C 的 baseline 只读；保存 R8D 真正用到的 Spectre原日志，不得只存截图。
- **成本**：新系统 testbench 最多 II/IM/MI 三份；每份 OFF AC、ON PSS/PAC各一组（优先II）。总PSS初次≤3，再给全轮最多2次有记录的 solver retry。无重复 R8B PSS（旧已验收）。理想 TG unit smoke≤2ms。不跑真实 60ms transient、PNoise、PVT/MC或fch扫描。
- **精度和资料安全**：IBM cmrf7sf tt、27°C；新数据只写 `docs/ece203_data/round8d/`，大PSF放 `/tmp` + watchdog、保留重要可重建数据和SHA；公开GitHub不上传PDK model/凭据，勿清理用户其他工作中的Virtuoso/Spectre。
- R8D任何理想开关版本**不是**可用于交课程/最终Noise验证的物理替代设计。无论 II 结果好坏，**当前真实 MOS电路的 0.338Hz 高通规格问题仍未修复**，R8B noise 3.141/3.994µVrms 亦未因此改变。
- STOP：A ideal switch functionality失败→停；OFF等效失败→停；PSS不收敛且唯一有据重试失败→停；PAC source/sideband不可信→停；按 II Q 决定是否跑 IM/MI。最终只交诊断和最小下一步修复策略，**不自动开启 R8E/WL优化**。

## 给 Claude 直接复制的启动语

> 运行 ECE203 R8D，严格执行 `docs/ECE203_round8d_tg_isolation_task.md`。基线为只读 R8B 真 MOS 设计，R8C 已确认同一高通偏移在非线性 MOS pseudoR 和线性3.128TΩ高阻里都存在。本轮返回**真实 MOS pseudoR**，仅诊断 2kHz XCI 与 XCO TG。先用已知 analogLib/switch、相同 CKA/CKB+10ns dead-time 做一个4条理想开关组成的10pin差分 TG master，rc初值1.68kΩ、ro=1e20Ω、阈值0.8/1.0V；先unit检验。然后建新II（双TG理想）先做OFF DC/AC近似等效、ON PSS明确收敛、sideband0 PAC测 fL和100Hz增益。如果 II 恢复0.1Hz才继续 IM/MI单个TG理想化；若II仍Q≥2.7，则stop并报告周期拓扑本身仍存在的额外高通。所有次序遵守任务书、旧R8B/R8C不动、先预登记提交、保留PSS/PAC Spectre原始日志、网表diff和CSV；不改MOS W/L、Clock或电容、不跑Noise/60ms、不把理想开关当最终设计。
