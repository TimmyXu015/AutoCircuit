# ECE203 R7C — 用真实 MOS pseudo-resistor 原位替换 R7A 的两只理想反馈电阻

**STATUS: TASK ONLY — NOT RUN.** 目的：完成真实 MOS feedback pseudo-R 集成。**明确冻结 R7B 电容问题**，本轮不做 CMFB、TG、OTA、DRL、CD、Clock、Bias、LP、Noise、Monte Carlo 或 PVT 优化；禁止触碰已验证旧 cell。

## 0. 来源与已知电路事实（开始前先复核）

阅读 `AGENTS.md`、`CLAUDE.md`、`docs/automation_playbook.json`、`docs/ECE203_HANDOFF.md` 及下列文件；过时的 Round-1 任务边界不是本研究分支的最新授权。

- `ece203_ss_pr.il`：`Project/ece203_ss_pr_cell` 是 **cmrf7sf/pfet33x 厚氧 PMOS**，端口 A（浮动高阻 p+）与 B（Gate、Bulk、另一侧 p+ 相连）。真实器件生成 `nsFetSpecVar("pfet33x","MP","prw","prl","B","B","A","B")`。**复用原 cell，不重新 build/覆盖。**
- `ece203_r4.il` / `ece203_r5n.il` / `ece203_r5nf.il` / `docs/ECE203_round5n_no_chopper_results.md`：在非斩波单端 R5N-F，`prw=4 µm`、`prl=2 µm` 使 `fL≈0.1005 Hz`。**该参数只作为 R7C 第一候选，不预设在 R7 同样有效。**
- `ece203_r6a.il`（`r6Specs`）/ `ece203_r6b.il`（`r6bSSpecs`）/ `ece203_r7a.il`（`r7aSysSpecs`）：R7A 的真实 MOS TG 输入/解调、FD OTA、真实 MOS CMFB a2、真实 DRL + MOS CD，BUFFERED 10 pF，理想参考与 VPULSE；**两只理想 Rfb 为**
  - `RFN (fp n) resistor r=3.1831e12`，反馈电容 `CFN (fp n) cfb=0.5 pF`；
  - `RFP (fn p) resistor r=3.1831e12`，反馈电容 `CFP (fn p) cfb=0.5 pF`；
  - 此处交叉连线是有意设计，**切勿按字母 P/N 自行修正连线**。
- `docs/ECE203_round7a_real_mos_cmfb_results.md`、`docs/ece203_data/round7a/r7a_stage3_summary.csv`：100 Hz、2 kHz TG 60 ms 时 R7A a2 Hpre 91.733、Hbuf 77.240、op/on CM 0.899939 V、200 Hz CM 3.94 µV、CMFB PM 84.46°、DRL PM 90.25°、功耗 1.999 µW（独立 VDD + VDDD）；R7B 67.4 fF 导致的 DM edge 问题已经查明，本轮**不优化、也不能归咎 pseudo-R**。
- `docs/ECE203_round7b_cmfb_gatecap_results.md`：R7B 的旧数据仍作只读资料。
- 其余参考 `ece203_ss_pr.il` 的 R3B I–V 实验；极小电流下默认 `gmin` 不可信；用于交流/瞬态的精度设置先从 R7A 复用并在输出日志核实。

## 1. 新电路：只替换 RFN / RFP，不改动其余网络

从 R7A `r7aSysSpecs(r7aCmfbCell("a2"))` 派生新 testbench，保留 XCI/XCO、XA、XC、XD、XCD、CLBP/CLBN、全部反馈电容、电子人体/电极网络与供电。**不得调用会重画 R7A 或旧 pseudo-R 的 build。**

```
原本: RFN(fp, n), RFP(fn, p) —— ideal 3.1831 TΩ
替换: XPRN : A=n, B=fp —— Project/ece203_ss_pr_cell
      XPRP : A=p, B=fn —— Project/ece203_ss_pr_cell
```
B 是 Gate+Bulk+另一 p+（接相对低阻的解调后输出 fp/fn），A 是高阻求和节点 n/p。所有 p/n 对称；**不要**把 B 接到 p/n，不能在反馈中增添理想辅助电阻或电压源；`CFN/CFP` 保留。真实 MOS 经变量 `prw/prl` 调尺寸；初始 **W=4 µm L=2 µm**。Clock、VREF、VCAS、理想参考电流保持原样。

创建新 cell 名 `ece203_r7c_tb_ideal`（读/重建新 cell 的 C0 理想基线）、`ece203_r7c_tb_pr_w4`（C1）、如允许调整才创建 `ece203_r7c_tb_pr_w<...>`。**不要修改旧 Project/ece203_r7a_tb_buf_a2，也不要覆盖历史结果**；初版 `C0` 可直接模拟旧 R7A cell 作为只读 baseline，如有全新 C0 则需经 netlist diff 证明一致。输出 `r7c*.il`、`batch/ece203_r7c_*.il`，新数据放 `docs/ece203_data/round7c/`。

在每个 case 的 netlist 中自动审核：
1. `RFN/RFP` 确实不存在，**恰好两只 XPRN/XPRP** 实例真实 `pfet33x`，参数 `prw`、`prl` 已生效；
2. `CFN/CFP`、全部 XCI/XCO/XA/XC/XD/XCD 仍存在，独立 `VDD/VDDD` 结构未改；
3. 单变量对照仅改变 2×反馈电阻实例（允许参数声明和分析语句不同）。

## 2. 分阶段、有限预算的实验

### Stage A：独立器件复核（少量，不优化）
- 不重建原 `ece203_ss_pr_cell`；用旧 R3B I–V 数据和必要的简短新 AC/DC 复核，测 `V(A)-V(B)=0, ±10, ±30, ±50, ±100 mV`，Common Mode 0.9V。
- 存 `Id`、`g_{ac}`、`1/Re(g_{ac})`、极性对称/非线性、VDS、DC 泄漏；注意两端在输入 ECG 1 mV → 放大后约几十 mV 的实际摆幅。
- 目的只是确认 4/2 物理 PDK 器件在 0.9V 和小摆幅下可提供 TΩ 量级反馈。若理想导通、gmin 限制、工作区或电流提取不可信，**STOP**。

### Stage B：TG 静止 A 相、真实 MOS CMFB a2 的全系统 DC/AC/STB
- C0 = R7A original, ideal 3.1831 TΩ；C1 = real pseudoR 4/2。仅这两个先跑。
- 频率 `1 mHz–100 kHz` 的高分辨率差模 AC；给出以 **各自中频平台 / |H(100Hz)| 为基准**的 `f_L` -3 dB 交点，明确增益/滤波器相位；不是拿低频某固定电压估算。R7A 采用 50pF/0.5pF 交叉电容反馈，`fL` 理想目标约 0.1 Hz。
- 关键记录：`fL`, `Hpre(10,60,100 Hz)`, `Hbuf(100 Hz)`, `(op+on)/2`, `(fp+fn)/2`, `(p+n)/2`, pseudoR 的 **每侧 B-A 端电压**及 MP `id` / OP, input impedance Zin @10Hz (若稳定可测), `VDD+VDDD` 总功耗, CMFB PM, DRL PM；在 1% `Cc` mismatch 下检验 CMRR60。
- 建议门槛：`fL` **0.09–0.11 Hz**（若偏离，标首轮 FAIL 后只做一次明确有限 W 调整）；Hpre100 相对 C0 变化 <=5%；TG 静止的输出共模在 0.9 V ±1 mV；CMFB PM >=60°、DRL PM >=60°；关键 MOS 不失去有效工作区；总功耗不得有不可解释的突增。不要把缓冲器输出的 37.x dB 当前不足 38 dB 误判为 pseudoR 新问题。
- **最多一轮 W 调整**：只在 C1 的 `fL` 不达标时，按实际 `fL(W)` 的局部近似有方向地选择一只 W（可借用 R5N 线性比例为初始估计），保持 L=2u 和全系统其他参数完全不变；先登记选择与理由，再运行。不得为了完美的 0.100000 Hz 反复扫参数。
- **重要边界：** 这里的 DC/AC 是 **Chopper 停在 A 相**时的线性小信号高通，不等于 2 kHz 周期斩波系统的严格 PAC 高频/低频响应。后者留给 PSS/PAC 或其他方法研究，不能偷换结论。

### Stage C：Chopper ON 的全系统 MOS pseudoR transient
- 只有 Stage B 的基本 DC/AC/环路验收成立才做；真实 TG 2kHz，100Hz 1mV differential input，60ms，R7A 相同 `tran cmin=1e-17`, `maxstep=0.5us`, `gmin=1e-18`, `iabstol=1e-17`, `reltol=1e-5`; 继续理想 VPULSE。确认 `VSPS sinephase=0`。
- C0 vs C1/已校准候选：使用同一个 `docs/ece203_data/round7a/r7a_sys_analysis.py` 指标，检查 20–40/40–60ms 窗口，Hpre/Hbuf/相位、差模 2nd/3rd harmonic、瞬态残差与 TG 切换边沿、op/on 共模平均及 200Hz 分量、`vg` 峰值、伪电阻端电压/电流、开环问题；**新增的 MOS 寄生电容/导通非线性需要归因，但禁止再优化 R7B 的 CMFB 输入晶体管**。
- 初始门槛：60ms 完成不漂移不削顶；Hpre100 变化 <=5%；CM 平均误差 <=1mV、200Hz CM <=0.20mV（R7A 原先约 3.94µV）；不出现超出 C0 3 倍的差模残差、不可解释的高频尖峰/低频漂移。报告任何未登记的差模/失真劣化，不要用“PASS”遮掩。
- **低频重要限制：** 60ms 只能检验 100Hz chopped transient，绝不能从中推定 0.1Hz 的高通响应。周期斩波的 `fL` 需另行 PAC/PSS 检查；本轮标记 **NOT RUN**。
- 符合条件后，保留新的可运行 testbench + ADE L state（静态 A 相，DC/AC/CMFB+DRL STB；若 ADE 更新有风险，标 NOT RUN 而不是破坏现有 state）。

## 3. 数据与技术纪律

- 设计/分析结果使用真实 Spectre/IBM cmrf7sf TT、27°C；决不可写预测结果为测量。
- 先核查 `prw/prl` 对变量传递是否真实生效；读原 `r5n` 对 PDK 模型/参数的成功检查做法。要额外确认选用的 PMOS 是厚氧器件 `pfet33x` 而非 `pfetx`。
- Pseudo-R 微电流可能与绝对电流容差及 `gmin` 接近；报出 Spectre options 回显，必要时仅进行 **一个有限的数值精度 sanity check**（如收紧 `iabstol`），明确这不是换电路；记录可重现的 numerical limitations。
- 当前 R7A 电源 `VDD` 和 `VDDD` 是各自对地的独立 1.8V 源，所以总功耗 **P = 1.8×(I_VDD+I_VDDD)**，与 R5N-F 的串联电表方法不同，严禁重复计数。理想 clock/reference 仍不完整计功耗。
- 保留历史单次结果和失败；最长三个 full 60ms chopped runs（C0 如仅复用已有完整原始波形则不重跑）；禁止大规模 sweep。
- 服务器 home 容量紧，PSF 使用 `/tmp` 分离独立目录，加入 watchdog；压缩重要 raw tran CSV 并保存哈希、Spectre log、最终 netlist 关键 diff；只清理本轮可重建 psf，不要杀用户个人 Virtuoso/Spectre 进程。
- 交付 `docs/ECE203_round7c_mos_pseudoresistor_results.md`、`ece203_r7c.il`、新 `batch/` jobs、`docs/ece203_data/round7c` 下数值/图/日志 + 新 ADE state（如成功）。结果必须明确 Stage A/B/C PASS/FAIL/NOT RUN，标称 tt 是否通过、剩余风险、真实 pseudoR 的低频非线性和 Chopper 条件下尚未验证的内容。
- **STOP**：若独立器件/静态环路出现明确失败，停止而非无限迭代、不得顺带补 clock、LP、Bias 或重新设计 main OTA/CMFB。R5N-F 课程正式基线保持完全独立。
