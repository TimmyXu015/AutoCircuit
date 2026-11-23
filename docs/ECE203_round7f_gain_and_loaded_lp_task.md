# ECE203 R7F — 修复输出增益缺口 + 10pF 输出负载下的 LP 带宽（两步正交实验）

**STATUS: TASK ONLY / NOT RUN.** 这是一份发给 Claude/Cadence 执行的受控实验任务书，不代表已经运行。**冻结 R7E 已验收设计**：`Project/ece203_r7e_tb_lp_a0` / ADE `r7e_lp_phaseA`。不得修改或重建任何旧 cell、ADE、脚本输出、数据。任务与 R7B 的 CMFB 栅电容切换误差优化无关。

## 0. 阅读和确认

优先阅读：
1. `docs/ECE203_round7e_output_lp_results.md`, `docs/ECE203_round7e_output_lp_integration_task.md`, `docs/ece203_data/round7e/r7e_stageA_summary.csv`, `r7e_stageC_summary.csv`, `r7e_plan.md`, `ece203_r7e.il`;
2. `docs/ECE203_round7d_mos_bias_mirror_results.md`, `ece203_r7d.il`, `ece203_r6d.il`, `ece203_r6a.il`, `ece203_r7c.il`;
3. `AGENTS.md`, `CLAUDE.md`, `docs/automation_playbook.json`, `docs/ECE203_CHOPPER_HANDOFF_AFTER_R7C_2026-11-22.md`, 以及 `docs/ECE203_HANDOFF.md` **只为课程约束**（其中 Round-1 的“不做 Chopper”是过期阶段计划，不能覆盖 R7F 授权）。

**课程约束**：增益 38–42 dB；fL 约 0.1Hz（0.09–0.11Hz）；fH 225–275Hz；CMRR60 >=85dB；Zin10Hz >=100MΩ；总供电功耗 <4µW；设计电容总量 **<1nF**（电极模型外部的 50nF 不计入）。R5N-F F2 是课程独立正式保险基线，**只读**，不可替换为尚未整体达标的 R7F。

**R7E 已实测**：
- R7E `lp_a0`：双路 `RLP_P/N=31.8MΩ`、`CLP_P/N=20pF`，`bufp→outp`, `bufn→outn`；旧 `CLBP/CLBN=10pF` **仍在 buf 侧**；反馈 `CFN/CFP/XPRN/XPRP` **仍在 fp/fn→p/n**，不能动。
- TG 静态 A 相、**未加载 out**：`fH_flat=247.6Hz`, `fL_out(vs plateau)=0.09564Hz`, `|HLP100|=0.92860`, `Hout100=73.124 V/V`, `Hout_peak=78.845V/V`。
- 静态输出端 `+10pF/侧`：`fH_flat=165.47Hz`、`Hout100=67.47V/V`，**不能认为 10pF 负载已经达标**。
- 2kHz chopper、100Hz 1mV differential、60ms、**未加载 out**：`Hpre100=90.9808`, `Hbuf100=76.5058`, `Hout100=71.0418=37.03dB`; LP 后 >1kHz 切换残差 **112µV RMS**、输出边沿 **0.281mV**、平均功耗 **2.311µW**，op/on CM `0.899524V`；CMFB PM `84.55°`，DRL PM `90.25°`（STB 在 TG 静止 A 相）。
- 有效需求是**至少** `10^(38/20)=79.43 V/V` 的 100Hz 输出增益（比当前 71.04 高 11.8%），然而本任务的 **10pF 负载是工程压力测试假设，不是被用户/下游 ADC 确认的最终负载规格**。
- R7E 使用的理想 `31.8MΩ` 电阻不可直接宣称 PDK 可版图实现；新 R/C 的 manufacturability、thermal noise、PVT/寄生仍未完成 sign-off。

## 1. R7F 技术策略（两组受控修改，先后单独归因）

**禁止一个大跳跃把 LP 数值、输入 Cc、CD 或主 OTA 同时改掉再声称改进成功。**

### 阶段 A — 只改变 LP 的阻抗缩放，补足对 10pF 下游电容的带宽容忍度

保留现有两路 `CLBP/CLBN=10pF`、现有 `cc=50pF/侧`、`cfb=0.5pF/侧`、`prw=4µm`、所有真实 MOS 和参考电流不变。**唯一功能性变化**是用等时间常数 `R*C` 的一组新 LP 元件取代 R7E 输出 LP 参数（仍是同样两路、一阶差分对称 RC）：

| 输出 RC 每侧 | R | C | 无额外输出负载理论 fc | 新增 10pF/侧理论 fc |
|---|---:|---:|---:|---:|
| R7E 旧基线 | 31.8MΩ | 20pF | 250.24Hz | 166.83Hz |
| **R7F 候选 L0** | **4.77MΩ** | **133pF** | **250.87Hz** | **233.33Hz** |

- `RLP_P/N` 仍连接 `bufp/bufn -> outp/outn`，`CLP_P/N` 仍 `outp/outn -> 0`；上游无源器件/10pF buffer 输出负载均完全不变。
- 新建 `Project/ece203_r7f_tb_lp_l0`（原 `cc=50pF`, 新 R/C，**无新增 COUT**）和 `Project/ece203_r7f_tb_lp_l0_load10p`（仅在 outp/outn 各增 `COUTP/COUTN=10pF`）；不得修改 R7E 或其 load10p cell。
- 静态 TG A 相 TT27°C，同样 AC/CM/STB：必须测 `fH_flat`（**相对于 10Hz/plateau**，不可拿 100Hz 参考 fH 代替）、`HLP(100)`、相位、`Hout(100)`、`fL_out`（相对 plateau）、`Hpre/Hbuf`、op/on CM、PM、CMRR、Zin、最小 margin、功耗与 10pF 加载敏感度。
- Stage A PASS：空载 **225–275Hz**，加 10pF/侧后也 **225–275Hz**；完整链路 `fL=0.09–0.11Hz`; Hpre/Hbuf 100Hz vs R7E (同 cc) 变化 <=2%，CMFB/DRL PM>=60°、CMRR60>=85dB、Zin10Hz>=100MΩ、op/on CM error<=1mV，P<4µW，无 clipping；新 RC 不影响源电流和其它器件工作区。
- 面积必须核算：LP 设计电容 `2×133=266pF`，较 R7E `2×20=40pF` **增加226pF**，而本课程设计 cap 总额 <1nF；分别报 `Cc`、`Cfb`、`CLB`、`CLP`、DRL耦合、其它设计电容之和（外部电极 50nF 与体模独立列出）。更高输出节点电容意味着面积代价，不能称作免费提升驱动；即使加 10pF 通过，**out 是数 MΩ 高阻节点，仍未证明可驱动低阻或 switched-cap ADC**。
- **此阶段只是 LP/负载补偿，不要求 38dB 增益 PASS**。若 L0 失败：只允许**一次**基于实测 fH 的合理 RC 比例修正（保持时间常数近 0.636µs、记录面积成本并先登记），再静态 AC，仍失败则 STOP。禁止在同阶段改 Cc/CD。

### 阶段 B — 固定已通过的 LP，单独测试最小增益修正

- 在 Stage A L0 **真实 PASS** 后，保留该组 LP 参数和 10pF 输出压力测试，**单独改变左右匹配输入耦合电容 `CCP/CCN` 所共用 `cc` 从 50pF → 60pF**（称 Gain 候选 **G0**）。本方案利用电容反馈的输入/反馈比尝试提高闭环增益，**只是待实测的可行性假设；增加 Cc 不能保证 Hout 按 20% 比例提高**。
- `CFP/CFN=0.5pF`、`XPR`、所有 MOS W/L（包括 XCD）、bias MP0-2、CMFB、DRL、Clock 完全冻结；左/右 Cc **必须一起**变到 60p，原 `dcc=1%` 的错配试验手段不变。
- 新建 `Project/ece203_r7f_tb_gain_g0_load10p`（L0 RC + `cc=60p` + 下游 `10pF/侧`）。可用新的 testbench cell 或同一 r7f 新 cell 加受控变量，但每份网表的器件值和 `cc` 实际生效要由 netlist audit 验证，且 **Stage A→B 的唯一差异是 `cc=50p`→60p，两侧同时变化**。
- 再创建一份 `Project/ece203_r7f_tb_gain_g0_unloaded` 以核查未加载的同一增益 candidate。初期**只跑静态 DC/AC/STB**，不要提前运行 60ms transient。
- **增益 PASS 门槛（静态预检）**：两种 out 负载（0 与 10pF）均在完整通过的系统 **38–42dB 中频平台增益**及 **100Hz 增益≥38dB、≤42dB**；`fH_flat=225–275Hz`、`fL_out(plateau)=0.09–0.11Hz`，CMFB PM >=60°、DRL PM >=60°、Zin10Hz >100MΩ、CMRR60 >=85dB、功耗 <4µW、器件工作区无明显劣化（OTA 最小 sat margin >=50mV）、两侧对称且无 DC CM 漂移异常。
- **修正预算**：若 G0 静态增益差一点但频响/余量/CMRR 均有正面证据，可以只在 `Cc` 这一旋钮上做**一次**由实测增益斜率推导的候选 `G1`，先在 `r7f_plan.md` 登记后再新 cell/静态测试；不得一边改 `Cc`、一边修 LP 或 MOS。若 G0 / G1 不达标或造成 fL/CMRR/Zin/面积失控，**Stage B FAIL，STOP，提交结果并请求用户决定是否转向真正的 MOS 后级增益 stage**；不要把 source follower 调到一个凭空假定的 >0.94 增益、不要偷偷改反馈电容来凑分。
- 这一方案牺牲额外输入电容：2×(60−50)=20pF；两阶段计划的 **新增设计电容总额约 246pF**（与 R7E 对照，不含原有负载/外部测试电容）。预算 <1nF 必须逐项确认。

### 阶段 C — full Chopper 60ms，确认真实 100Hz end-to-end 结果

**只有 A 与 B 静态必要门槛通过才能跑。** 两个 20ms 分析窗（20–40、40–60ms），真实 2kHz TG，100Hz/1mV differential input，VSPS sinephase=0，tt27°C，**与 R7E 完全一致**的 `tran 60ms maxstep=0.5µs, cmin=1e-17F, gmin=1e-18, iabstol=1e-17, reltol=1e-5`。只读 R7E 完整原始波形为历史基线。
- 默认 **仅跑最终 G0/G1 的 loaded 10pF 一次 full 60ms**；必要时另一次 unloaded 最终候选来完成可比性；**新 full 60ms 总预算<=2次**。注意 R7E 的 60ms C0 是**未加载 out、旧 LP/旧 Cc**，因此归因应以 Stage A (R/C only) 与 Stage B (Cc only) 的静态对照为主；不得将新 loaded waveform 相对旧 unloaded R7E 的所有变化都归因增益修正。
- 同一 `r7e_analysis.py` / `r7d_analysis.py` 指标口径：`Hpre`、`Hbuf`、`Hout` 100Hz gain (linear + dB)/phase/H2/H3；LP clock spur bins / >1kHz residual RMS、DM edge max/mean；op/on output CM, CM 200Hz、CMFB control vg、bias pref/ib/ibd、IREF/MPx branch currents、p/n pseudoR 趋势、Ptotal + DC device headroom、outp/outn 范围。
- **最终 R7F loaded gate**：运行60ms无数值停顿/削顶，`38<=20log10(Hout_100)<=42dB`（把 100Hz 作为比平台更严格的检查），`fH_flat=225–275Hz` 和 `fL_flat=0.09–0.11Hz` 是 Stage B **静态 AC** 验收；CMFB+DRL phase margin >=60°（静态），CMFB op/on CM error<=1mV、CMRR60>=85dB、Zin10Hz>100MΩ、P<4µW、H3不能比 R7E 的 −88.9dBc 恶化 >10dB（若波形和观测范围改变，要标注可比性）；输出的高频 residual RMS 不应较 R7E unloaded 112µV 恶化超过2倍（**这是保守报警线，不是两工况同一变量的因果证明**），切换边沿显著非线性/alias 或慢输入共模漂移加速必须如实报告。
- 若 chopped 100Hz 低于38dB、频谱/共模/功耗或 margin 失败，标 **R7F FAIL/INCOMPLETE**，不得为求 PASS 在 Stage C 修改器件。只有明确数值不可信时可用一次小精度核查，但不突破 full-run 预算。
- **特别保留** R7B 67.4fF CMFB detector cap 引发的 31mV 未滤波 DM edge 既有问题，不是本轮改进对象。R7C pseudoR 约 −0.18mV/s 在60ms内的微弱整流趋势仍保留长期 NOT RUN，不能用本轮 transient 证明慢时间尺度。**周期 PSS/PAC 频响、周期 noise/PNoise、PVT/MC、输出 PDK R/C 物理实现仍 NOT RUN**。

## 2. 提交工件与纪律

- 新脚本：`ece203_r7f.il`，新 `batch/ece203_r7f_*.il`，如需 `tools/r7f_watchdog.sh`。所有目标 cell 名 `ece203_r7f_tb_*`，非覆盖式创建。R7E、R7D、R5N-F 旧 cell/数据/ ADE 只读。暂不做 Explore/Final Library 迁移/批量改名。
- 先在 **`docs/ece203_data/round7f/r7f_plan.md`** 登记本轮 R/C、Cc、容量预算、Stage A/B/C gates，Git **先提交**预登记 + 代码，**后跑** Spectre；尺寸修正需原位更新 pre-run plan 并 commit 说明，不能事后美化。
- 数据：`docs/ece203_data/round7f/` 下 Stage A/B DC/AC/STB/operating point 和已处理 csv、netlist compare audit（验证 R/C only、Cc only、10p load only）、plot、Stage C 完整解析度 tran gzip CSV+SHA、Spectre log/precision、watchdog log、analysis scripts 与能复现的命令；报告 `docs/ECE203_round7f_gain_and_loaded_lp_results.md` 明确 A/B/C PASS/FAIL/NOT RUN 及 COURSE GAIN PASS/PENDING、实际已设计电容总和/面积成本。
- 实测条件：`cmrf7sf tt`，27°C；VDD 和 VDDD 独立 1.8V 电源，要用**供电电流之和**计算总功耗，IREF 支路已经计入、不能重复计功率。Clock、VREF、VCAS、100nA IREF 仍是用户许可的理想外部资源。
- GPU? 不需要。服务器 `/tmp` 保存可重建的 PSF、每次长瞬态带 watchdog；home quota 敏感；保存重要 gzip raw + SHA。不要杀掉用户自己的 Virtuoso/Spectre，不可改动 R5N-F 课程保险版；公共 GitHub 禁止上传 IBM PDK model 内容、私钥或凭据。参考 `run.sh`、`docs/automation_playbook.json`。
- **STOP**：Stage A 加载带宽失败即停，只有一次受控 R/C 校正；Stage B 静态增益/其他 spec 失败，最多一次 Cc 修正；Stage C 失败直接停。**不可自动开启 R8 Noise/MC，也不可一次加入后级有源增益放大器**。若本策略不达标，先把证据交用户审查，再决定下一版拓扑。
- 交付时给 GPT 验收：本任务 `C0=R7E` vs `A=R7F LP scaled with Cc50` vs `B=R7F same LP Cc60`，展示每阶段相应**唯一变量差异**；并解释 10p 负载只是假设且高阻 out 仍存在，避免声称已可直接驱动 ADC。

## 3. 发给 Claude 的最简启动语

> 开始 ECE203 R7F。严格执行 `docs/ECE203_round7f_gain_and_loaded_lp_task.md`。先复制 R7E 创建新的 r7f-only cell；Stage A 只把差分 LP 从每侧31.8MΩ/20pF 等时间常数改成4.77MΩ/133pF，并测试 out 每侧额外10pF 的 fH；Stage B LP固定后，才单独尝试 CC=50pF→60pF 以修复100Hz gain，先静态 DC/AC/STB，最多一次数据驱动 Cc 修正；A/B PASS 才跑 C：2kHz 60ms、loaded 10pF full transient 最多两次。所有已有 MOS 尺寸、feedback、pseudoR、bias、CMFB、DRL 和 clock 不动，旧 R7E / R5N-F 不动。必须核算设计电容<1nF、报告高阻 out 的真实局限，所有代码/网表 diff/CSV/Spectre 原始日志和波形 commit 到 GitHub；任何 gate FAIL 停止，绝不能调参藏失败。
