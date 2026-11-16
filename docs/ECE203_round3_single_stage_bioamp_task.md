# ECE203 Round 3 — 课堂基础单级电容反馈 BioAmp：最小晶体管级验证

**设计决定（2026-11-16）：** 用户选择暂时**放弃旧三级 Telescopic Cascode + 四电阻差分 A3 的修补路线**，转而单独搭建、验证教授 Lec8–10 所讲的最基础 **single-stage capacitively coupled instrumentation amplifier**。本轮**不允许**重试 Cascode、加 Buffer、引入第二放大器、chopper、DRL 或任何自动架构升级。架构和取舍由用户 + GPT 决策；Claude 负责 Cadence/Spectre 可复现实验。

## 0. 必读与隔离

1. `CLAUDE.md`, `AGENTS.md`, `docs/automation_playbook.json`：先核对程序/权限/结果存储路径，以及 git-pull → run.sh job → Spectre → CSV → 本地实验记录本的标准流程。
2. `docs/ECE203_round2b_loading_results.md`：旧架构是已诊断的失败基准，**不要复用旧三级级联拓扑，也不要破坏旧 cell**。
3. 用户提供的课堂原始资料 **Lec8-9-10-BioAmp.pdf, 课件页 23–27（PDF 第 12–14 页）**：第 24 页双路电容耦合 + 单个差分 OTA；第 27 页例子给出 Cin=500fF、Cc=50pF、Cfb=500fF、理想增益 100、fL=0.1Hz。注意：Cin=500fF 是教授的**举例**，实际 OTA 的输入寄生需报告，不能偷偷当成真实值。第 40、49 页 Harrison 晶体管电路仅作背景；**不要照抄第 49 页含 Cascode 的 OTA**。
4. 复用现有 SKILL/OCEAN 工具箱和可工作的真实 `Project/ece203_a3_ota` 普通五管 OTA **作为初始受测器件**，其此前测试开环 A0 ≈71 V/V（37 dB），所以它**预期不能准确实现闭环 100 倍增益**。这是我们希望实测的物理局限，不要擅自把它换成理想高增益电路，也不要为了“过关”虚构增益。
5. 全部新 cell / testbench / 仿真 job 使用 `ece203_ss_` 前缀和新结果目录 `docs/ece203_data/single_stage/`。不覆盖、重建或修改旧 Round1/2A/2B cell、ADE、CSV 和用户交互进程。公开仓库不可上传 IBM PDK/模型、机密 netlist、密钥、许可文件。不要清除 Windows 实验记录本。

## 1. 原理图必须与课件保持一致

**只有一只差分输入、单端输出 OTA**，原始模拟供电 1.8 V；参考节点 `VREF = 0.9 V`（在诊断 testbench 中可暂用理想源）；两路信号输入各有一个串联 `Cc`：

- `VIN_MINUS -- Cc --> OTA(-)` 的 summing node，`OTA_OUT -- (Cfb || Rfb) --> OTA(-)` 作为负反馈；
- `VIN_PLUS -- Cc --> OTA(+)`，`OTA(+) -- (Cfb || Rfb) --> VREF` 作为参考支路；
- **确保 plus 端也有 Cfb || Rfb 到 VREF，不是只接一个无偏置的输入电容；两端节点均能确立 DC 工作点**。
- 若具体 PDK 五管 OTA 引脚极性不同时，应按实际符号/网表校正，并保存节点与输入极性的核对记录。
- 输出先取 OTA 的原始 `VOUT`；**本轮不要连接旧 A3 后面的 3.18 MΩ/200 pF RC 低通**，避免重演新 loading。只考虑小的明确记录的验证用 CL（例如 0 pF/5 pF 两点），不假设已经满足 fH=250 Hz。
- 此轮**不接电极、人体、DRL**；偏置源允许诊断用途使用先前 validated 五管 OTA 的既有方式，标记为“not final source-count compliant”，实际电源电流需实测。

两组纯电容反馈（其余连接完全不变）：
- **S1 教学健全检查：** Cc=50 pF（每路），Cfb=5 pF（每路），Rfb=1/(2π×0.1×5 pF)≈318.31 GΩ（每条偏置通路），理想 midband |A_dm|=10 (20dB)。这是为验证物理五管 OTA、输入极性及闭环而设置的**自选预实验**，并非课件指定的 100 倍增益配置。
- **S2 教授原例：** Cc=50 pF（每路），Cfb=0.5 pF（每路），Rfb=1/(2π×0.1×0.5 pF)≈3.1831 TΩ，每条偏置通路；理想 midband |A_dm|=100 (40dB)。电容标称总量约 101 pF（不含 OTA 内部、测试负载及寄生）。
- `Rfb` 仍用理想元件，只为验证课堂机制，**绝不可称片上可实现、实体验收**。

## 2. 执行阶段（先搭并跑通，出数据后停止）

**A. Ideal-golden 单 OTA 替身：** 使用一个理想差分 VCVS（高 A0，例如 1e5/1e6）和与真实 OTA 完全一致的双支路电容网络，分别跑 S1/S2。测试 DC（各节点在 0.9V 附近）、差分 AC（VINP AC +0.5V, VINN AC -0.5V，差分幅度 1V）、频响 1mHz–100kHz。报告每组 midband gain (10/60/100 Hz)、fL、fH（若可定义）和 0.1Hz 周边传递。期望 S1 ≈10、S2 ≈100、fL ≈0.1Hz；理想电路不代表物理达标。

**B. 同网表改为真实 5T OTA：** `Project/ece203_a3_ota` 最初**不改任何尺寸/偏置**，依次跑 S1/S2。将差模增益 (Vout/(Vinp-Vinn)) 与 ideal golden 用相同坐标/源规范对比。看：`A0`、跨导/输出阻抗、OTA +/- 端静态工作点、MOS 饱和余量、实际 VDD 电流/功耗、闭环是否有可靠负反馈、10/60/100 Hz 真实增益、fL/fH、相位、CL=0/5pF 对照、两端有效输入电容/Cin 与不匹配的影响。**若 S2 低于 40dB，明确量化短缺，不能改变闭环增益定义。**

**C. STB + Noise 最简验证：** 对真实 S1/S2 在适当位置加 iprobe、其他连线不变，跑真实 Spectre stb，保存 loopGain Bode、UGF 和 PM。Noise 仅先跑 0.1–250Hz 的输出 PSD 和 total diff-input referred RMS、Noise Summary 前 10 个器件贡献；注明输入噪声参考必须是**1 V 差分输入归一化**，不要把单端 1 V 源测得的 input-referred noise 冒充差分值。可通过单个差分电压源/受控激励或等效输出噪声积分除真实差模 midband gain 的方式交叉检查。不要做全面 W/L 优化和参数海扫。

**D. 10 Hz 小信号 transient（如适用）：** 差模 1mVpk 和 5mVpk 两点，验证极性、失真/削顶和稳态增益。高通 Rfb 很大，10Hz transient 可能遭遇初始条件/长时间常数问题，务必区分 DC OP 初始状态和实际启动过程。若有收敛/初始化障碍，不要通过篡改电阻来伪造通过。

**门槛与边界：** 只要求这一轮先证明（i）课件电容反馈网络是可被 Cadence 正确构造的、（ii）单只真实普通 5T OTA 下哪些指标能达到、哪些达不到。**不要把 S2 当成必须修到全指标达标才能交付。** 若 A0≈71 导致真实 S2 只有几十倍，这是很有价值的结果；记录并停止，交由用户 + GPT 决定下一轮五管 OTA 的 gm/ro/长沟道/电流优化，或整体其他课堂拓扑。尤其不要擅自加任何 Cascode、Buffer、第二级或 chopper。

## 3. 必交成果与日志

1. 新的、能在 Cadence Library Manager 打开的明确命名 cell：`ece203_ss_ideal_tb`, `ece203_ss_real_tb` 等；确认 schCheck、pins、网表、差分源和 DC 正常。
2. 中文简报 `docs/ECE203_round3_single_stage_results.md`：S1/S2 理想 vs 真实对照表（gain@10/60/100, fL/fH, DC, current/power, saturation, PM, noise）；失败原因；未做项目硬指标列表；任何单独验证的诊断不可冒充全系统通过。
3. 新 SKILL 主脚本和 batch 注册；CSV、noise summary、AC/STB/Transient 图，放在 `docs/ece203_data/single_stage/`；工作命令及完成标记，README 中文复现步骤。
4. Windows `C:\Users\Timmy\AutoCircuit_Results\` 的规范实验记录（`log.md` + PNG、`_raw`、`LOG.md`），依 playbook。不要求将本地未授权文件推到公开 repo。
5. **运行结束停下，不自动启动新的电路架构改造。** 给用户汇报：单级框架是否通了、真实五管 OTA 的增益瓶颈是否确立、下一步最小设计决策。

磁盘：ieng6 5 GB quota 曾在 Round2B 满额，最近余量约 556 MB。新任务开始前先查 quota / 可用空间，优先清理**本轮可重建的仿真缓存**；绝不删除旧课程工程、旧设计 cell、用户 GUI 文件。若空间不足，报告并停止，不要冒险删除。
