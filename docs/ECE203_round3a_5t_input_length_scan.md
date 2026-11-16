# ECE203 Round 3A — 5T 单级 BioAmp：输入对沟道长度四点小实验

**用户批准：2026-11-16。** 执行者 Claude Code；设计决策由用户与 GPT 保留。**本轮只回答一个问题：延长普通 5T OTA 的 M1/M2 沟道，能否把开环增益从约 71 提高到满足 S2 40 dB 容差所需的约 390？**

## 实验依据（先读）
- `CLAUDE.md`、`docs/automation_playbook.json`（复用现有 GitHub → ieng6 → SKILL/OCEAN → CSV → Windows 实验记录本的流程）。
- `docs/ECE203_round3_single_stage_results.md`、`ece203_ss.il`、`ece203_ota.il`：现有 S2（Cc=50 pF/支、Cfb=0.5 pF/支、Rfb=3.1831 TΩ/支）真实 5T：开环 A0≈71，闭环 |Hdm(100 Hz)|=41.19=32.30 dB；偏置电流约 284 nA；最小 margin 0.251 V。OTA M1/M2 为 4 端 nfetx **W=10 µm、L=1 µm**；此轮**其它所有晶体管、元件、源和连接冻结**。
- 真实电路为 **单个普通 5T OTA + 对称电容反馈**；**不要**重回旧 Cascode、三级级联或 Buffer。

## 执行：仅四点；不扩大范围
1. 不修改/重建任何旧 cell（特别是 `ece203_a3_ota`、`ece203_ss_real_tb`、原有 ADE 状态）。新建专用 `ece203_ss_lscan_ota` 与 `ece203_ss_lscan_tb`（或等效隔离命名），确保拓扑与原版五管 OTA 完全一致，**仅 M1/M2 的长度设为设计变量**；保留两管一致，所有其它 W/L、偏置、S2 的 R/C、VDD=1.8 V、VREF=0.9 V、CL=0、差分 AC ±0.5 V 完全相同。注：固定 W 扫 L 会同时改变 W/L 和反型程度；这属于快速 screening，不是单独测量 r_o 的纯净因果实验。
2. 对 **L = 1、2、4、8 µm** 四点依次运行 **DC operating point + AC**，无需任何其它分析。不重新跑 S1、理想 VCVS、Noise、STB、tran、Monte Carlo、CMRR、DRL、pseudo-resistor，也不要自动调偏置或优化 W。
3. 四点记录相同的指标：实际 `|Hdm(100 Hz)|` 和 dB；OTA **真实开环增益 A0**（如用独立极简 OL AC 测试，明确测量方法与工作点；若仅有 `gm/(gds_M2+gds_M4)`，必须标成**近似 A0**，不得冒充实际 OL AC）；关键 OP `gm(M1/M2)`, `gds(M2/M4)`, `Id(M1/M2)`、`gm/Id`、region；全管最小 `sat_margin`；实际 VDD 电流及功耗。检查电路 DC 是否正常、反馈极性及 netlist 实际采用的 L。任何点失败如实写 failed，不重试改变架构。
4. 用简单一行理论关系交叉检查闭环数值：`A_CL≈100 A0/(A0+101)`（大致忽略输入寄生、频率依赖，正常 100Hz 中频适用）。判断是否达到最低 38 dB（79.4 V/V），**不要**把它当成 40 dB 精确达标。
5. 只保存一个四行表 `docs/ece203_data/single_stage_length/length_scan.csv` 和一个**简短**中文结论 `docs/ECE203_round3a_length_results.md`（表格 + 一句话结论 + 明确下一步待决策）。无须大批图片；若方便，仅一张 A0 和 |Hdm| vs L 的简图。
6. 使用仓库现有运行框架，注册一个新 `run.sh` job（例如 `ece203_ss_lscan`）；结果按 playbook 抄回 Windows 的 `AutoCircuit_Results` 实验记录本。先检查 ieng6 磁盘 quota，禁止删除不可重建的旧课程数据、用户的现有 Cadence 库和交互文件。不得将 IBM PDK/模型、机密 netlist 或密钥上传公开仓库。

## 强制停止点
**只跑这四个 L 点就停止。** 即使未达到 390 也不自动增加更多 L / W、改镜像、加二级/Buffer/Cascode，或转去优化噪声。汇报结论后，等用户/GPT 再作决定。**目标是缩短“实验—观察—决策”周期，而非一次性做出最终合规设计。**
