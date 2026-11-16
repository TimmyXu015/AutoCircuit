# ECE203 Round 3C — 普通 5T OTA 的两个最小改进方向：PMOS 输入、局部 Cascode

**用户决定（2026-11-16）：** 暂停 Pseudo-Resistor 和其它模块开发，回到单级电容反馈 BioAmp 的 OTA。复制已经工作的 5T，在相同的 S2 电容反馈测试环境里**分别**比较 (P) PMOS 输入对版和 (C) 局部 Cascode 版，**这两组都记录 Gain + 0.1–250 Hz Noise**。不跳到完整 Harrison OTA，不引入 Chopper（后续由用户/GPT 讨论）。

## 0. 范围和对照

先读 `CLAUDE.md`、`docs/automation_playbook.json`、`docs/ECE203_round3_single_stage_results.md`、`docs/ECE203_round3a_length_results.md` 及其现有脚本 `ece203_ss.il`、`ece203_ota.il`。

固定 **S2**：每支路 Cc = 50 pF、Cfb = 0.5 pF、**理想** Rfb = 3.1831 TΩ，VDD = 1.8 V、VREF = 0.9 V、CL = 0，差分 AC 正负各 0.5 V、同样的 0.1–250 Hz 积分区间。**本实验使用理想 Rfb 是为了隔离 OTA 差异**，不要使用 Round3B pseudo-R；带有极高 Rfb 时沿用 Round3B 已证明必要的精度控制（如 gmin=iabstol=1e-18，reltol=1e-6），核实稳定性。

**基准 B**：Round3A 中 NMOS 输入对的普通 5T，M1/M2 W=10µm L=8µm，其它尺寸、50nA 参考支路全同。基准已有 A0≈280、闭环 |Hdm(100Hz)|≈73.13、功耗≈0.510 µW，**但该 L=8µm 版本尚没有一份在相同测试环境下的完整 Noise Summary**，所以本轮只需基准 B + P + C **三次**配对 DC/AC/Noise，避免拿 L=1µm 时的 46.8µVrms 作为 L=8µm 的噪声参照。

所有新 cell/网表/job 使用专用前缀 `ece203_ss_ota_cmp_`，旧 cell / ADE / 用户运行中的 Virtuoso / 结果只读。现有 run.sh / SKILL / OCEAN 复用，不扩展框架，不导出机密 PDK 到公开仓库。

## 1. 两个新器件变体：只做一版各自可用的尺寸

**P: PMOS 输入普通 5T（仍然是一个单级、单端输出 OTA）**
- 输入差分对换成 PMOS，电流镜负载改成 NMOS，尾电流源方向调整为 PMOS，从 VDD 供电；在新的 cell 里明确引脚顺序、信号极性、B/S/well 连接、IBIAS 的电流方向。避免因为 INP/INN 反接，把正反馈误当成性能差。
- 优先保持**实际 VDD 总电流接近 B（≈0.28µA）**，且两支路各约 0.116µA。PMOS 输入管尺寸选择基于 DC 正常、gm/Id 及 area 的一个合理初始点；如首个尺寸无法建立 OP，最多进行一次有理由的最小修改。**不进行多维 W/L 搜索。** 汇报输入对 W/L、总 WL 面积、gm/Id，以免把输入面积变化误认为 PMOS 沟道类型的固有低噪声优势。
- 除了为了反转极性所必须改变的晶体管类型、偏置外，不新增其他电路级。

**C: 局部 Cascode 版（沿用基准 B 的 NMOS 输入对 W=10µm/L=8µm）**
- 只在输出侧**NMOS M2 的漏极与输出节点之间**尝试一个 NMOS cascode，目标是降低输出支路等效 gds，提高 A0；保留 PMOS 电流镜和原 5T 其它管不变。偏置可以先用理想 VCAS，只作为诊断，不算最终源数合规。
- 选择**一个**基于 M2 原 DC OP（tail, drain, Vdsat, Vout≈0.9 V）的合理 VCAS；若失败，最多一次必要的偏置修正。必须检查新的 cascode、自身 M2、M4 是否处于合适状态，M1/M2 Vds 是否明显失配，输出摆幅/输入共模余量是否受损。若单侧 cascode 导致工作点或闭环失败，**如实标记 FAIL，不能擅自升级为全 cascode / folded cascode**。
- 明确 C 是带局部 cascode 的单级 OTA，不再是严格的“5T”；命名/报告必须区分。

## 2. 只进行三组相同的小测试（B/P/C）

1. **DC OP**：V(out)/V(+) /V(-)、关键 MOS region / gm / gds / Id / gm/Id / 最小 saturation margin，VDD 总电流功耗。PMOS 版本记录 W/L 与输入 WL 面积；Cascode 版本记录 VCAS 以及每个串叠管的 Vds 与饱和余量。
2. **AC**：独立的真实开环 A0（与基准测法相同，不能只拿 gm/gds 充当“测量 A0”）；S2 差分闭环 |Hdm|@10/100Hz、dB、fL、若可测 fH。附一个简单预测 `Acl≈100 A0/(A0+101)`，如变体输入电容/共模影响大需标注近似失效。
3. **Noise**：真实电路输出谱密度与积分 `0.1–250Hz` RMS、器件 Noise Summary（输入对 flicker%、镜像 flicker%、新 cascode 噪声%、白噪声%），差分输入参考噪声**同时报告两个明确不同定义**：
   - **应用型**：`Vn,out,rms(0.1–250) / |Hdm(midband,100Hz)|`；
   - **频率逐点 de-embed 型**：`sqrt(∫[Vn,out(f)/|Hdm(f)|]^2 df)`。
   固定基准条件/积分点数，使三组可比；不可因高通导致的分母不同混淆数值；不要将单端输入源的输入参考噪声冒充差分源定义。核对 NoiseSummary 输出积分功率与独立积分一致。
   
**不做** STB、Tran、DRL、Pseudo-R 调整、Chopper、Monte Carlo、PVT、其它参数海扫、二级 OTA 或整机验证。只比较 B/P/C 三点。若某变体无法正常 DC/AC，记录 blocker 并只跑其余可运行变体。

## 3. 交付与停止点

- 一张小表 `docs/ece203_data/ota_compare/bpc_summary.csv`，一份短报告 `docs/ECE203_round3c_ota_compare_results.md`，简洁展示 B/P/C 的实际 Gain/Noise/Power/Headroom、噪声贡献和失败原因；至少一张 Gain + Noise 对照图（可选，不为了图额外跑仿真）。
- 记录如何复现的新 run.sh job 与 Cadence cell 名称；依 playbook 同步 Windows AutoCircuit_Results 实验本。注意 ieng6 quota；不得删用户文件、不干扰 GUI、不上传 PDK 模型或机密网表。
- **完成三点就停，等用户/GPT 讨论 Chopper 和下一步增益/噪声方向。** 核心问题是：PMOS 输入是否真的有较低 1/f 噪声？单侧 NMOS cascode 能否低成本提高 Gain？不要改设计直到有数据。
