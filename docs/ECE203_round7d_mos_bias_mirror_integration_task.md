# ECE203 R7D — 单一理想 IREF + 真实 MOS Bias Mirrors 整合（限定实验任务书）

**状态：TASK / NOT RUN。** 这份任务书用于让 Claude/Cadence Agent 在 UCSD iENG6 上执行。任务书本身**不代表 Spectre 已运行**。上一轮结果 R7C：`docs/ECE203_round7c_mos_pseudoresistor_results.md`，已验收 PASS。这里不改 R7B 已知 CMFB 67.4 fF gate-cap 引发的斩波差模边沿误差。

## 0. 总目标、范围和先读资料

**唯一电路改动**：从 `Project/ece203_r7c_tb_pr_w4` 的系统中去掉**两只理想 50 nA 偏置电流源** `IB (vdd ib)`、`IBD (vddd ibd)`，改为**一只理想参考电流源 IREF + 一组真实 PDK PMOS 电流镜**，为主 OTA、CMFB、CD（共同使用 `ib`）与 DRL（`ibd`）供电。**保留原始内部 NMOS MREF/MT 电流镜**，不能暗中删去或重新尺寸优化。

- 源码：`ece203_r7c.il`，`ece203_r7a.il`（`r7aSysSpecs`）、`ece203_r6a.il`（`r6Specs`、OTA/DRL/CMFB pins）、`ece203_r4.il`（`r4SpecsRB(pr)` 中已成功的 `MP0/MP1/MP2` 镜像）、`ece203_ss_pr.il`。
- 结果基线：`docs/ECE203_round7c_mos_pseudoresistor_results.md`、`docs/ece203_data/round7c/r7c_stageB_summary.csv`、`docs/ece203_data/round7c/r7c_stageC_summary.csv`、`docs/ece203_data/round7c/r7c_netlist_audit.txt`。
- 工作习惯：`docs/ECE203_CHOPPER_HANDOFF_AFTER_R7C_2026-11-22.md`、`AGENTS.md`、`CLAUDE.md`、`docs/automation_playbook.json`。较旧 `docs/ECE203_HANDOFF.md` 是 **Round 1 历史记录**，其中“禁止 Chopper”不适用于已获用户授权的 R7D。
- **始终冻结**真实 FD OTA `XA`、真实 MOS CMFB a2 `XC`、DRL `XD`、双 MOS TG `XCI/XCO`、MOS CD `XCD`、两个 MOS pseudoR `XPRN/XPRP`（W 4 µm/L 2 µm）、电极/人体模型、`Cc/Cfb`、10 pF 每侧 CD 输出负载、反馈网络和 Chopper 驱动波形。
- **继续允许**理想 `VDD=VDDD=1.8 V`、`VREF=0.9 V`、`VCAS=1.1 V`、理想 2 kHz VPULSE/非交叠时钟和**一个** `IREF`。不得造 bandgap、oscillator、时钟 buffer 或额外理想偏置节点。刺激人体电极的外部测试电流源不计入偏置源，但必须在报告区分。
- **不做**输出 LP、CMFB 电容优化、PSS/PNoise、普通 noise、Monte Carlo、PVT、布局。R7C pseudoR 长期整流/1 Hz 问题仍待后续单独调查。

## 1. 真实网表来源与目标连接（先验证再造）

基线真实 netlist `docs/ece203_data/round7c/raw/stageB/B_pr_w4_netlist.scs` 显示：
```spectre
VDD  (vdd  0) vsource dc=vdd
VDDD (vddd 0) vsource dc=vdd
IB   (vdd  ib)  isource dc=ib3       // 50 nA
IBD  (vddd ibd) isource dc=ibd       // 50 nA
XA(... ib ... vdd)   // FD OTA with local NMOS diode MREF at ib
XC(... ib ... vdd)   // MOS CMFB at ib
XCD(... ib vdd)      // MOS CD at ib
XD(... ibd ... vddd) // DRL with local NMOS diode MREF at ibd
```
**两只电压源是各自接地的独立 1.8V 供应，不是 R5N-F 的串联 0V 电流表**。不要在本实验顺便把 `VDDD` 改成 0V meter 或与 `VDD` 短接；那会引入额外实验变量并破坏基线。

借用 `r4SpecsRB(pr)` 的原理（**新 R7D cell 中新增元件，不能调用会重建 R4 cell 的 build**），初始候选固定：
```text
                  VDD = 1.8 V                      VDDD = 1.8 V
                      |                                  |
             PMOS MP0 4µ/4µ                        PMOS MP2 2µ/4µ
           D=G=pref, S=B=vdd                      D=ibd G=pref S=B=vddd
                      |                                  |
         pref --------+------ G(MP1), G(MP2)            ibd --> XD.MREF diode NMOS
                      |
                  IREF 100nA
                 pref -> GND
         
             PMOS MP1 2µ/4µ
             D=ib, G=pref, S=B=vdd
                      |
                      ib --> XA/XC/XCD shared reference MREF & bias gates
```
严格的 `ece203FetSpec` pin 顺序为 **D, G, S, B**：
- `MP0 ("pref","pref","vdd","vdd")`，`MP1 ("ib","pref","vdd","vdd")`，`MP2 ("ibd","pref","vddd","vddd")`，型号优先 `pfetx`，L=4 µm；
- `IREF`：理想 **100 nA** 电流 sink `pref -> gnd!`；它是**唯一参考/偏置电流源**。
- MP0:MP1:MP2 初始尺寸比 **4:2:2**，名义参考 100 nA -> 两路约 50 nA。**不是精确 50 nA 的保证**，MOS 的有限输出电阻会使 MP1/MP2 实际值偏离比例，必须真实测。
- MP2 从 `vddd` 取电、bulk 也接 `vddd`，与 MP1 的源电压均为 1.8 V（在现有理想测试台中）；这是为了保留两路原有供电和电流计量。不能让 MP2 bulk 浮置，也不要把不同电源节点的电流漏计。
- **极性要核查**：原 `IB/IBD` 是从电源节点向 NMOS diode 偏置栅节点**供电**（current source `vdd -> ib` / `vddd -> ibd`）；MP1/MP2 必须在 `ib/ibd` 注入正向电流，不能倒接 PMOS。

若执行前发现源 code/netlist 实际不同，**先报告差异并停止**，不要擅自用一套新架构遮掩。

## 2. Stage A：搭新 cell + 低成本独立 DC / netlist audit（STOP gate）

- 派生 `r7cSpecs()` 的元件列表，删除**恰好**两只 `IB/IBD`，增加 **`IREF`、MP0/MP1/MP2**。其余元件不增删改参。新 cell `Project/ece203_r7d_tb_bias_a0`，脚本 `ece203_r7d.il`，batch 新 `ece203_r7d_{build,a,b,c,ade}`（命名可等价但必须唯一）。新电路与旧 `Project/ece203_r7c_tb_pr_w4` 的网表结构 diff 只应出现 2 source remove + 1 source add + 3 MOS add，及允许的参数/仿真分析声明。
- **不可修改或重建** 旧 R5N-F F2、R6/R7A/B/C、`ece203_ss_pr_cell` 或旧 ADE state；唯一新 cell 名必须 `r7d_*`，避免调用 `r6Build`、`prBuild` 等旧 build。
- 静态 TG A 相、tt 27°C、`VDD=VDDD=1.8V`、100nA IREF、原 2×4u/2u pseudoR。打印 `V(pref),V(ib),V(ibd)`、`IREF`、MP0/MP1/MP2 的 `id, gm, gds, vsg, vsd, vdsat, region` 和饱和余量；再读 XA.MREF/XD.MREF 电流和各个主要器件工作区。
- **KCL check**：IREF 应约 100nA，MP0 电流约 100nA，MP1 和 MP2 分别接近 50nA，`id(MP1)` / `id(MP2)` 与各自 `ib`/ `ibd` 接收电流一致；必须检查 MPx 均确实属于 PMOS 饱和/合适工作区，`pref` 不撞轨，端电压非反常。系统里的 MOS bias 电流没有另一只理想 `IB/IBD` 或隐藏 ideal CCS。
- **首轮门槛**：MP1/MP2 各在 **45–55 nA** 内（相对 50nA ±10%），`IREF` 为唯一直接 bias 源，全部 bias PMOS 可用工作区；`V(ib)`、`V(ibd)` 对旧基线偏差请量化（参考阈值绝对差 <15mV，但真正 gate 为功能工作点/性能）。若初始偏置 FAIL，只允许**一次**根据实际镜像电流和 OP 的校正：可调整 MP1、MP2 的 W（L 不变，明确解释比例）、必要时 MP0 的 W，但不许修改 OTA/CMFB/DRL/CD 内部晶体管。必须**先记录失败与修改原因**再新建 `r7d_tb_bias_a1`，最多两种整合候选 a0 / a1，禁止漫无目的 sweep。
- 若出现实质 DC 开路、钳位、无法收敛，或计量不自洽，标记 FAIL 并停，不做 full transient。

## 3. Stage B：静态 A 相系统 DC/AC/STB + 功耗（必要 gate）

C0 = 只读 R7C `Project/ece203_r7c_tb_pr_w4` 作为旧理想 IB/IBD 基线；C1 = R7D 新 MOS bias cell。**复用 R7C 的测量函数和精度**，不得把原本电路频响的差异算成新设计收益。

- TG 保持 A 相，1% `Cc` mismatch（`dcc=0.01`），DM / CM AC: `1 mHz–100 kHz`，在相同波形定义下比较 `fL`（`|Hpre(100Hz)|` 为参照 −3dB）、Hpre 10/60/100Hz、Hbuf100、CMRR60、Zin10、输出共模、p/n 输入节点 DC、pseudoR DC 电流和电压、CMFB 和 DRL 两个 STB 的 UGF/PM；保存关键 MOS headroom，并特别检查 XA.M1 当前最弱余量约 **0.0917 V**。
- **预先登记 PASS 门槛：** TG-static output op/on CM `|Vcm−0.900| <=1mV`；`fL=0.09–0.11Hz`；Hpre100 / Hbuf100 相对 C0 **|Δ|<=5%**；CMFB PM **>=60°** 且 DRL PM **>=60°**；CMRR60 **>=85dB**（基线 108.42dB），`Zin(10Hz)>100MΩ`（基线 658MΩ）；主 OTA 与 CMFB 有效工作区，最小余量 **>=50mV**，新的 PMOS mirror 自身不能失去有效饱和区。若基线器件存在原有 <50mV 余量，需与 C0 对照并单独标异常，不能谎报通过。
- **功耗**：用实际两只独立电压源从供电端读取的有符号电流计算 (P_{supply}=−[VDD·I(VDD:PLUS)+VDDD·I(VDDD:PLUS)])（根据 Spectre 的电流定义核对，要求总实数为正）。**IREF 是从 pref 到地的 100nA 电流 sink，通过 MP0 从 VDD 获取电流；其耗电已经包含在 VDD 端电流中，不得重复加 100nA×1.8V**。记录 VDD/VDDD 单项/合计、MP0/MP1/MP2 与 IREF、原 C0 的 1.994µW 以及新增加的实际值。目标完整当前理想电源测试台 **P<4.0 µW**（不含物理时钟驱动/BGR 开销，需明确标注），新增约 100nA 参考支路是可能的工程开销，不能说 bias 免费。
- 保存 C0/C1 static **netlist diff + CSV（DC op/AC/STB）+ 关键频响/共模/功耗图**；不能仅以“仿真成功”代替可量化验收。

## 4. Stage C：完整 2kHz Chopper 60ms transient

**只有 Stage A/B 的全部必要 gate PASS 才进入。** Stage C 不再允许尺寸优化。
- 2kHz，`tch=500us`、100Hz / 1mV 输入差模，保留原 VPULSE 相位/非交叠时序和 `VSPS sinephase=0`；`tran=60ms`，`maxstep=0.5µs`、`cmin=1e-17F`、`gmin=1e-18`、`iabstol=1e-17`、`reltol=1e-5`，与 R7C 完全一致；记录 Spectre 输出选项 echo 和 full-time t_end。
- C0 = 已有 R7C 60ms 原波形（只读引用，除非比较条件不一致）；C1 = 新 MOS bias 60ms；如 Stage A 有 a1 修正，最多测试最终 a1，**总新 60ms 大仿真不超过两个**。支持仅在有数值可信度疑问时做一个短 smoke/numerical check，不得借此扩大无界实验。
- 用同一 `r7c_analysis.py` + `r7a_sys_analysis.py` 对两个窗口 **20–40 / 40–60 ms** 报 Hpre/Hbuf、相位、H2/H3、DM edge max/mean、残差 RMS、`op/on` CM 200Hz/边沿尖峰、`vg` 范围、`(p+n)/2` 趋势、pseudo-R 端波形/范围及平均功耗。增加 `pref,ib,ibd` 瞬态和 MP1/MP2/IREF 支路电流，检查 bias 网络纹波、参考源是否进入异常状态。新 mirror PMOS 的偏置对时钟尖峰可能有反作用，不得默认完全等效于 ideal IB。
- **PASS 门槛：** 完整 60ms、无失稳/削顶；`Hpre/Hbuf` 100Hz 相对 C0 **|Δ|<=5%**；`op/on` CM 均值距 0.9V <=1mV、200Hz CM 分量 <=0.20mV；功耗 P<4µW；CMFB+DRL 稳定；若 DM edge 最大误差较 R7C C0（31.45mV）增加 **>15%**、DM残差 RMS 较旧 3.520mV 增加 >30%，或 H3 比 R7C（−85.7dBc）恶化 >10dB，标记**transient performance FAIL**，需解释而不得把改变归于旧 R7B 问题；窗口间趋势和 p/n CM 漂移必须列出、说明后续长期仍 NOT RUN。
- R7C 旧已知的不理想处**不是**新的 R7D 失败理由：CMFB-detector ~67.4fF 致 31mV edge、CD 输出增益 0.842 / common-mode 0.543V、buffered Hbuf=76.48 （~37.67dB 未到课程 38dB）、伪电阻长期整流偏移仍未实测。若这些项与旧 C0 基本一致，分类为“carry-forward risk”。
- **严禁**称静态 AC 的 0.0956Hz 为运行中 Chopper 的 periodic `fL`；PSS/PAC/PNoise/MC 仍 NOT RUN。

## 5. 预期输出、版本与验收总结

- **代码**：`ece203_r7d.il`, `batch/ece203_r7d_*.il`、必要 `tools/r7d_watchdog.sh`/复用 R7C watchdog（不得影响旧任务），新 `Project/ece203_r7d_tb_bias_{a0,a1}`；若成功，`ADE L state r7d_bias_phaseA`（仅新 cell；如果 GUI/ADE 不稳，报告 NOT RUN）。
- **报告**：`docs/ECE203_round7d_mos_bias_mirror_results.md`，包含拓扑及测试台说明、电流镜 device sizing、器件区与饱和余量、netlist diff 证据、Stage A/B/C **PASS/FAIL/NOT RUN**、100Hz/60Hz指标、实测新增电流/总功耗、clock 瞬态影响、所有未验项目和是否进入 R7E。
- **原始证据**：`docs/ece203_data/round7d/`：pre-run plan（写明候选与 gate）、Stage A/B/C 数值 CSV、Spectre log、OP、真实网表、B 的 AC/STB 曲线、C 的全分辨率 gzip CSV & hash、近边沿对比图和对照 summary，代码 commit/运行 commit；遵守 `AGENTS.md` 的 Windows lab notebook `LOG.md`、实验 `log.md` 和 PNG 图片规则。
- home quota 小，使用分离的 `/tmp` PSF 和每个大 tran watchdog，记录最新 Git SHA；只清理本轮可再建的 PSF，**绝不杀用户自己的 Virtuoso/Spectre 进程**。GitHub 是公开仓库：**不要上传私钥、密码、PDK model 内容、原始保密 PDK 文件**；提交引用/instance netlist 若嵌入完整 PDK 路径可先确认可公开内容。
- **STOP discipline**：Stage A/B 如果 FAIL，最多一次有依据的 MP mirror sizing 修正；仍 FAIL 则停止，不擅自从 PMOS mirror 改架构、加电流源、调 OTA/CMFB、切 VDD；不为了 PASS 隐藏失败。完成 Stage C 后停止，不自动开始 R7E。
- **建议给用户的简短回报**：`R7D Stage A/B/C：PASS/FAIL`；`MP1/MP2 actual current`；`gain/CM/PM/edge/power vs R7C`；`实际新增功耗`；`最需要下一轮解决的一个问题`。**所有真实结果必须来自 Spectre**。

## 6. Claude 起步指令（paste）

> 读取 `docs/ECE203_round7d_mos_bias_mirror_integration_task.md`，按 Stage A → B → C 严格执行。仅把 R7C 的两只理想 IB/IBD 50nA 改成一个理想 IREF100nA + 三只真实 pfetx MP0/MP1/MP2，保持 VDD/VDDD 两路独立 1.8V 供应以保证单变量；除 Bias 以外的所有电路完全冻结。先审计电路与电流镜 DC，后验收 AC/STB，最后再开 2kHz 60ms。最多一轮合理镜像 W 修正。结果、代码、网表、CSV、日志提交 GitHub，明确标 PASS/FAIL/NOT RUN；严禁改旧 cell 或无边界优化。
