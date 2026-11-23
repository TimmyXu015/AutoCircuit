# ECE203 R8C — 真 MOS Chopper 的周期高通截止 0.34 Hz：先排除 PAC 口径，再隔离 pseudo-R 动态效应

**状态：TASK / NOT RUN。** R8B 刚通过真实 TG 2 kHz PSS/PAC/PNoise；本轮唯一目的：**解释为什么 Chopper ON 的侧带0 PAC 高通角频率约0.34 Hz，而同一系统 OFF 静态 AC 约0.095 Hz。** 不在本轮调 MOS W/L、Clock/fch、Cc/Cfb、LP、OTA/CMFB/DRL/CD 或追求 noise <3µV。只有诊断用新 cell 可以临时以线性高阻替代真实 pseudo-R；原已验收 MOS pseudo-R 电路始终只读。

## 0. 已有证据（不是 R8C 结果）

必读：
- `docs/ECE203_round8b_pss_fixture_isolation_results.md`、`docs/ece203_data/round8b/r8b_pac.csv`、`r8b_pss_check.csv`、`r8b_plan.md`、`raw/gateB/B_pss_a1_convergence_lines.txt`、`raw/gateC/B_pac_netlist.scs`；
- `ece203_r8b.il`、`ece203_r8_noise.il`、`ece203_r7f.il`、`ece203_r6b.il`、`docs/ECE203_round7f_gain_and_loaded_lp_results.md`、`docs/ECE203_round7c_mos_pseudoresistor_results.md`。
- `AGENTS.md`、`CLAUDE.md`、`docs/automation_playbook.json`。旧 R6A 的历史任务不是本轮权威；不要重新造已解决的 `EOC+CHP` 假性慢状态。

真实 R8B 物理链：`Project/ece203_r8b_tb_noeoc_chp`（R7F G0 loaded 仅删**无效 EOC + CHP**），IBM cmrf7sf **tt、27°C**，`tch=500µs`/2kHz、真实双TG `XCI/XCO`，`CFP/CFN=0.5pF`、`CCP/CCN=60pF`、`CLP_P/N=148pF, RLP_P/N=4MΩ`、`COUTP/N=10pF`、真实 MOS pseudo-R `XPRP(p,fn)`、`XPRN(n,fp)`。电极/人体模型和偏置均不变；参考/Clock 许可理想。

**R8B 实测：**
- Phase-A OFF ordinary AC：`|H(0.1Hz)|=67.727`, `|H(100Hz)|=85.666`, highpass `fL,OFF≈0.095Hz`（平台约93 V/V）。
- Chopper ON 2kHz, PSS=500µs **3 shooting iterations converged**, 侧带0 PAC：`|H(0.1)|=25.573`, `|H(1)|=85.752`, `|H(10)|=90.359`, `|H(100)|=83.251`（与 60ms 1mV signal transient 83.247 符合0.006%），平台峰90.364V/V@8.9Hz，`fL,ON≈0.34Hz`（按通带平台 −3dB），`fH≈234.5Hz`。
- Noise 用相同硬件 ON/OFF 证明减噪，但ON 3.141µVrms 应用型 / 3.994µVrms 逐点型（S90），两者仍不达 <3µV；低频逐点型变差与 ON PAC fL 偏移有关。**本轮不重复 PNoise，也不改噪声电路**。
- 已知疑点：2kHz XCI/XCO 开关内部 MOS 非理想性及 parasitic switched conductance，或真正 `pfet33` pseudo-R 在零输入时 p/n ±~2.8mV 周期纹波下的**时变小信号导纳/整流**。当前没有证据认定哪一者是主要原因。
- 重要：500µs 周期的 PSS-PAC 完全可以计算比一个周期慢很多的 0.1Hz **小信号线性响应**；但它反映的是 periodic operating point 的小信号导数，和 60ms 零稳态大信号不能机械混为一谈。**不要为了“验证0.1Hz”启动数十秒/几分钟原始 tran**。

## Stage A — 无器件修改：检查 PAC 低频定义和内部路径

**A0：复算现有 R8B 数据，零成本先做。** 用 R8B PAC 原始完整 `r8b_pac.csv` 加 OFF AC，明确：
- 统一 `fL_flat` 为相对于 **5–10 Hz 通带平台**的幅度 `1/sqrt(2)` 点，且在低频段插值；不是相对于100Hz信号输出的 −3dB、不是 `fH`、不是单点 `H(0.1)`。
- 画 OFF/ON 幅相 / ON-to-OFF gain ratio 随频率，重点0.05–3Hz与10/100Hz；核查输出位置确实 `outp-outn`，PAC`harmonic=0` 且输入归一化为读取 `ep-en` 的侧带0，clock PAC=0。
- 先复算约0.095与0.34；若既有数据无法支持，不运行任何新实验，STOP反馈数据/算法问题。

**A1：新 R8C job，直接使用只读 R8B cell 与相同收敛 PSS（可复用已归档的 converged PSS 前提是 cell/netlist SHA 匹配且文件存在，否则按同一 a1 配置重跑一次 PSS），新增密一点的 0.025–5 Hz PAC（≥40点/dec）及 5–250Hz 稀疏验证。**
- 测 `H0(outp−outn)/(ep−en)`、`H0(fp−fn)`、`H0(bufp−bufn)`、`H0(p−n)` 以定位低频衰减在哪一级出现；**前级载波节点** `ia−ibx`、`op−on` 的主信号在2kHz谐波，不可仅凭侧带0近零来宣称电路不工作。如需这两处，请额外记录 `harmonic ±1` 的带内调制幅相并明确归一化方式；不强制。
- 建议在同一零输入PSS上用相同激励、`maxsideband=1` vs `3` 比较侧带0 `H(0.1,0.3,1,10,100)`，排除 PAC 边带设置造成的读取偏差；若当前 Spectre 15.1 的 PAC语义不支持该比较，记录 help/实际网表而非猜测。**这是数值一致性检查，不是物理变量实验**。
- Stage A PASS：复现 R8B ON `H100≈83.25`（±2%）、`fL_flat≈0.34Hz`（±0.04Hz），PSS log 明确 converged，PAC不同`maxsideband`/重新分析的主侧带0结果差 ≤2%，所有节点/传输定义、端口及相位正确。若 A FAIL，STOP并定位分析设置/读数，不进入 Stage B。若复现，才允许研究物理归因。

## Stage B — 单变量诊断：MOS pseudo-R → 线性等效高阻（不能当最终设计）

新建**唯一新的诊断 cell** `Project/ece203_r8c_tb_linear_pr`：严格复制 `r8bSpecs()` 的实例列表，只删除两只 **`XPRP`、`XPRN`**，添加两只 **analogLib 理想线性电阻**：
```text
  REMOVE  XPRP (p fn) ece203_ss_pr_cell
  REMOVE  XPRN (n fp) ece203_ss_pr_cell
  ADD     RPRP (p fn) 3.128 TΩ
  ADD     RPRN (n fp) 3.128 TΩ
```
初始3.128TΩ来自 R7C MOS pseudo-R 近0.9V偏置小信号导通估计。此值**是预设诊断参数，不是R7F新实测**；它未必精确匹配 R8B 两只非线性 pseudo-R 的全频传输。禁止修改其它元件或重新引入 EOC/CHP。两只对称相同，不改 `XCI/XCO`、不改 `cc/cfb`、不改 Clock、电极、加载或 bias。做网表 diff，允许差异仅上述4个实例（且PSS/AC statements与参数按同条件）。

**B0 — OFF Phase-A DC/AC**：
- 目标是证明线性 surrogate 在静态近似与 R8B 一致，至少 `fL_flat` 落在 0.07–0.15 Hz 且 H(100) 在 R8B ±5%，DC CM偏差≤1mV、功耗变化≤2%；
- 如静态偏差明显，允许**一次**由实际 OFF fL 比例推导的 RPR 同倍率修正（先登记新值/理由/一份新cell，保留初始诊断结果），但若仍不满足近似等效，**STOP**，不要用一个完全不同的静态高通来解释 ON差异。
- **Stage B 不运行普通 Noise**（理想电阻的热噪声不同，且本任务只研究信号传递）；也不比较这只理想R与R8B的噪声优劣。

**B1 — 同一线性 surrogate 的 ON PSS + PAC**：
- `chen=1`, 零输入，与 R8B a1 一致 `pss fund=2k,harms=40,maxacfreq=200k,moderate,tstab=5ms,maxperiods=40,cmin=1e-17,itres=1e-4`，同一相位/电源/温度；PSS有收敛证据才接 PAC；若一次不收敛，允许一次**有记录**、仅更新数值 solver setting 的 retry（绝不更改电路），再失败 BLOCKED。
- PAC 0.025–5Hz >=40点/dec +5–250Hz，输出 same H(outp−outn)/H(fp−fn)/H(p−n)；测 `fL,ON(linearR)` 和 `fL,OFF(linearR)`，核心看**比例** `Q_R=fL_ON/fL_OFF` vs 真实 pseudoR `Q_MOS≈0.34/0.095≈3.6`，100Hz H、H plateau、phase 和 PSS p/n,fn/fp pseudoR两端纹波与电流（如果能正确获得）一并记录。
- 事前解释判据（都只是**diagnostic evidence**，不是物理证明）：
  - 若 `Q_R <=1.4`，而 Q_MOS≈3.6：pseudoR 的非线性/周期导纳是**主要嫌疑**，应下轮做 MOS pseudo-R I–V/小信号电导随信号幅度研究；
  - 若 `Q_R >=2.7`：即使换成线性高阻，Chopper 仍明显抬升 fL，重点怀疑 TG 及其它周期性开关耦合；下轮才设计只替换**输入**TG的受控实验；
  - 若1.4<`Q_R`<2.7：两机制可能都有贡献，需后续隔离，不能单独归因。
- 检查 PSS p/n 与 MOS 原版对照（在零输入时实际p/n仍有2kHz纹波），若线性替换使工作点/纹波显著不同，则明确“surrogate 不能保留非线性真实工作状态”，因果结论降级。**本轮不调整 fL、没有新电路可作为正式替代**。

## C. 交付/停止/后续建议

- 交付 `ece203_r8c.il` + `batch/ece203_r8c_*.il`、新 diagnostic cell，独立运行 state；旧 R7F/R8/R8B/R5N-F 只读。**不要把诊断线性R cell 当作正式 MOS 完整系统**，不要批量重命名已有 Cadence cell。
- **Pre-run**：先提交 `docs/ece203_data/round8c/r8c_plan.md`（具体 gate、Netlist diff、实验预算和失败停止条件）、脚本与图表分析代码到 GitHub，**后运行**。R8B PAC基线只读取不覆盖。
- 输出 `docs/ECE203_round8c_periodic_highpass_rootcause_results.md`、`docs/ece203_data/round8c/`：R8B复算对照/新R8C宽频PAC曲线、静态对照、surrogate的PSS/PAC、PSS真实收敛日志/netlist、节点分频转移表、p/n开关纹波、解释力/不确定性、R8C verdict PASS/FAIL/BLOCKED。图至少一张 OFF vs ON 的 fL 曲线和各节点比值，若执行B再有 MOS vs linear pseudo-R Q 柱状或表。
- **成本限制**：最多一份 R8B baseline PSS 重建（若已有 converged PSF不在，重建一次）；最多2次线性pseudoR PSS（含数值retry）；不运行 60ms full tran、不跑 PNoise、不做频率/MOS尺寸扫，不修改 R8B固定 LP 和增益。
- 只将有效 `cmin=1e-17F` 当作 simulator 数值参数，不能算成真实开关电容。所有失效都保留 Spectre log，只有显式 PSS convergence 才可解释PAC。用 `/tmp` 与 watchdog，别杀用户其它 Virtuoso/Spectre，公开仓库禁止上传 IBM PDK 模型内容/凭据；按既有 results notebook 规范交付。
- 如果 A复算或PAC数值一致性失败，**STOP 不进入 B**。若 B OFF无法近似匹配，**STOP**。若 B PSS不收敛，**BLOCKED**。若成功，只报告**问题机制的证据等级**，不宣布课程 fL/Noise 规格PASS。留给用户选择后续针对性真实MOS改进。

## 交给 Claude 的启动指令

> 执行 `docs/ECE203_round8c_periodic_highpass_rootcause_task.md`。R8B 的真实MOS Chopper PSS/PNoise已成功，本轮只调查为什么运行中 sideband-0 PAC `fL≈0.34Hz` 而OFF静态 `≈0.095Hz`。Stage A 使用只读R8B先复算fL，再在相同零输入PSS上增强0.025–5Hz PAC、检查边带0定义/内部 fp/fn、p/n、outp/outn 的低频传输，必须验证数值一致性。Stage B另建全新诊断cell，只把 XPRP/XPRN 两只MOS pseudoR用同端点 3.128TΩ 线性高阻代替，其余真实MOS TG/OTA/CMFB/DRL/LP/Clock/负载不动；先OFF DC/AC匹配，后ON PSS/PAC测 fL 比例来区分pseudoR非线性与TG时变导纳。严格网表diff、先pre-run plan commit、真实Spectre证据、有限重试，失败停；不跑PNoise/60ms，不优化MOS，不覆盖R8B或旧cell。完毕全部CSV/plots/log/report提交GitHub，交GPT验收。
