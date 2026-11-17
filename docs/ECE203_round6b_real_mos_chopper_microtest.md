# ECE203 Round 6B — 最基础真实 MOS Chopper Microtest（待执行，小实验）

**状态：READY, NOT RUN。** 用户要求：先验收6A，暂时停止莫比乌斯环、CDS、SC、RRL、论文等发散研究。6B 只要一个可以复用、真正 MOS transistor-level 的 Chopper；先证明开关工作，再轻量接回全差分 OTA。用户明确不希望继续靠理想 Chopper 假设，**但允许理想时钟电压源驱动真实 MOS TG**。本任务准备好后不得自行开始更大的 6C。

## 背景与唯一目标

- 6A 报告 `docs/ECE203_round6a_drl_cmfb_coupled_results.md`，脚本 `ece203_r6a.il`：独立真实双环 MOS FD OTA + CMFB + R4 DRL 已运行，静态 Hdm100=94.56，CMFB PM73.5°、DRL PM90.3°；6A 的**理想2kHz Chopper**在完全对称、无 offset 条件下增益保持0.988（这本身不能证实真实纹波）；给1mV理想offset的20ms tran出现大差模纹波/CMFB 非线性，但**该 tran 尚未稳态**，不可作为真实MOS Chopper失败的证据。6A无PNoise，无真实开关。 
- R4/R5完整备份保留；R6A cell与数据只读。**研究问题**：「一种最简单的可复用四路 CMOS transmission gate 交叉差分换向器，在当前 IBM PDK、1.8V、0.9V 共模、2/4kHz 时钟下是否真正能把差分信号翻转并恢复？接到R6A后是否还能正常切换且两个共模环没有被毁掉？」
- **不要进行**：新OTA设计、D2SE、CD/CS×早晚四路赛、RRL、charge injection calibration、dummy MOS、PVT/MC、1/f噪声优化或复杂PNoise。**不要把理想外接时钟误称为完整晶体管时钟产生器**。

## 1. 做标准模块（真实晶体管，不是理想 switch / EINV）

- 新建 `ece203_r6b_tgchop` 以及独立 `ece203_r6b_tg_tb`，推荐脚本 `ece203_r6b.il`；只创建新 cell，绝不覆盖已有 `ece203_r6a_*` / R4/R5。
- `INP,INN,OUTP,OUTN,CLK_A,CLKB_A,CLK_B,CLKB_B,VDD,GND`（实际 cell pin 尽量清晰简约）：**4个Transmission Gates = 8只真实 NMOS/PMOS**。直通相位 `INP→OUTP,INN→OUTN`，交叉相位 `INP→OUTN,INN→OUTP`；每支 TG 的 PMOS gate 使用对应 NMOS gate 的互补相位；两相非重叠，禁止A/B同时导通。实现要保证关断时不把两路直接短接。
- PDK `nfetx/pfetx`、真实合法 L、先用适中 W（记录具体值）、器件4端接对，不允许 behavioral `switch` 取代 TG。允许简易理想 0↔1.8V pulse 驱动这些 gate，先不造时钟反相器/driver（否则添加了另一个问题）。
- 用小信号DC/100Hz differential（约1mV）、Vcm=0.9V、真实结点电容和轻微电容负载诊断（至少评估R6A input/output真实连接负载；不要选不具代表性的巨大纯电阻加载让Ron看起来很优）。检查TG单边Ron、Vdiff符号、2相dead time、短路电流、开关馈通、外部驱动时钟是否对齐。输出完整 tran raw 数据（含 clocks, inputs, both outputs, supply currents），**不要只凭图判断直通/交叉**。
- 单元测试须在 2kHz 和 4kHz 运行一次，必要时额外一个 Vcm偏移点（例如0.75或1.05V），确认不是巧合只在0.9V起作用。对比ideal switch可以作为**reference**,但本轮PASS证据必须来自真实 MOS 数据。

## 2. 只做最轻量系统集成

- 保留 R6A 成功的 **独立真实 CMFB + 真实 DRL**（B 基线），暂时不选H2协同分支；复用同样的FD OTA1。因实验重要变量是真实Chopper，不要更改OTA管尺寸、CMFB、反馈电容、DRL、右腿电极和电源。
- 构造新 `ece203_r6b_fd_tg_tb`，输入及输出位置各用一个**相同cell实例**（合计2×8 FET），不允许原R6A的ideal relay仍并联影响结果。用于输出解调的四支TG置于 `op/on` 与反馈网络 `fp/fn` 之间，CMFB继续直接观测 `op/on`。输出仍保持差分，不需要增加D2SE。
- 冻结 VDD1.8V，Vref0.9V，理想bias参考与6A相同，理想Rfb仍可用（只验证Chopper功能）；明确**这不代表整机完工、噪声达标、物理bias全部实现**。
- 三个有限测试点：
  (i) chopper OFF / 直通phase（真实TG一直导通）确保重建B基线的DC和100Hz gain；
  (ii) chopper 2kHz ON（100Hz 1mV差分ECG模拟输入），记录在两个相位里差分极性、恢复后的输入到输出波形及Vod、Vcm_out、Vcm_in；
  (iii) chopper 4kHz ON，按完全相同条件比较gain/settling/ripple。
- 很重要：同时有慢速 Rfb 的长时间常数（6A 报约1.6s），不要将20ms未稳定tran平均值当作稳态Ripple；必要时通过周期稳态/PAC（**最多1次PSS**）或长时间瞬态+稳态检验，明确未稳态；小输入阶跃/非零offset测试若加做，先使用**小的、受控**offset（如100µV），1mV只作为stressing，不能让CMFB饱和掩盖TG功能。不必在本轮为了offset改善另造RRL。
- 核对被调制与解调的输入输出差分**正确的传输极性/时序**，不要在有输出饱和或连续漂移时直接从峰峰值得到增益；若MOS开关受寄生冲击造成波形很差，隔离开关本体和FD-OTA/CMFB分别定位根因。
- 记录系统输入高阻节点对真实开关引入的加载与漏电，避免把理想bias维持的表面成功当成电极输入Zin通过。

## 3. 预算/停止规则

- **建议≤8 case、最多1次PSS，不做PNoise**。模块单元测试失败则先停，最多允许1次开关尺寸或gate-clock时序修正，不允许大规模调参；系统集成如果偏置/CMFB崩溃，只做一次因果隔离（开关单元 vs OTA本体）。失败时也保存结果，STOP。
- 记录模块电路图/连接示意、`r6b_tg_unit.csv`（clk, Ron, phases, differential outputs, feedthrough）、`r6b_fd_compare.csv`（OFF,2k,4k：H100,settling,Vod ripple,Vcm ripple,DC bias, current, reason）、关键原始tran、Spectre logs/exit status、`docs/ECE203_round6b_real_mos_chopper_results.md`。所有“PASS”必须区别 **[MOS Spectre] / [ideal clock] / [ideal bias] / [not measured]**，明确真实MOS开关是PASS的哪一部分。
- 使用现有 `docs/automation_playbook.json` 的远程环境/路径，核对quota，不杀用户自己的Virtuoso，不上传IBM PDK和私有内容。
- 最后向用户只回答：
  1. **TG Chopper模块真实MOS是否按相位正确换向？**
  2. **2k/4k哪一个至少能在已跑的真实FD OTA双环上维持正常输出，实际限制是什么？**
  3. **是否值得进入下一轮R6C（而非立即进入Noise/RRL优化）？**
- 本任务是**READY，不自动执行**。需用户明确将此文档交给Claude后再动手。
