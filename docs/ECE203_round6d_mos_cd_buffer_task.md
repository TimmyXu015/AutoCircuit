# ECE203 Round 6D — Real MOS differential Common-Drain output buffer (project stop gate)

**状态：任务书已冻结，尚未仿真。** 本轮是 R6C-I 已验证理想 CMFB + 真实 FD OTA + 真实 2 kHz TG chopper 的**最后一个小范围架构扩展**。**只增加一对真实 MOS CD / source followers 和其真实 MOS 电流偏置**。不开始两级 CS OTA、不重新设计 CMFB、不增加新环路。运行后 STOP。

## 0. 源与复现要求

先读 `CLAUDE.md`、`docs/automation_playbook.json`、`docs/ECE203_round6c_ideal_cmfb_task.md`、`docs/ECE203_round6c_ideal_cmfb_results.md`、`ece203_r6c.il`、`ece203_r6b.il`、`ece203_r6a.il`。以 `Project/ece203_r6c_tb_ideal` 为**不可修改基线**，特别保证 R6C-I 的修复 `VSPS sinephase=0` 不被回退。记录实际 git SHA、PDK corner、温度、仿真器版本和执行命令。

R6C-I 标杆：chopper OFF 的增益 94.533 V/V、VoutCM 0.900059 V、CMFB UGF 546 kHz / PM 87.78°、DRL PM 90.25°；2 kHz chopper ON 时增益 93.506 V/V、输出共模均值 0.900148 V、200 Hz 共模分量 4.75 uV；控制端无撞轨。以上供参考，**本轮原测试台应同条件重测或核对**，不可用旧指标替代当前负载比较。

## 1. 核心连接——CD 在 demod TG 后面，原反馈回路不得重接

R6B/R6C 的 `XCO` 是输出 TG：`op/on -> fp/fn`。而 `fp/fn` 也是原差模电容反馈的取样节点。因此：
```
真实 FD OTA op/on ── XCO TG ── fp/fn ── 原 Cfb/Rfb 反馈，保持原样
                                  │ │
                                  │ └─ CD_N gate
                                  └─── CD_P gate
                                           ↓
                                   bufp / bufn  (新外部输出)
                                           ↓
                                  外部 CLP / CLN
```
新 CD 只以**MOS Gate 高阻输入**并联在 `fp/fn` 上，**不允许**将 Cfb/Rfb 改接至 `bufp/bufn`；不修改 CMFB `op/on` 感测和 PMOS 控制、DRL、时钟或 OTA。不要误将 `op/on` 当成输出 TG 后的节点。

**关键 DC 事实：**纯 NMOS CD 约满足 `Vbuf ≈ Vfp − VGS`，不会天然保持 0.9 V。必须分别报告 `(fp+fn)/2` 和 `(bufp+bufn)/2`。输出 CM 的移动不等于既有 CMFB 失稳；如果负载接口要求固定 0.9 V，此结构不具备该能力，明确标记限制，不要加入新电平搬移/反馈来造出表面 PASS。

## 2. 一版真实 MOS CD（仅允许一次有依据的修正）

新建 `ece203_r6d_cd`（两个完全对称的 MOS source follower），和 `ece203_r6d_tb_cd`（由 R6C-I ideal 规格复制构建，新 cell，不改旧 cell）：

建议初始器件：
- CD 每侧一只真实 PDK `nfetx`，Drain=VDD，Gate=FP 或 FN，Source=BUFP 或 BUFN，Bulk=GND。起始 W/L 约 6 µm / 1 µm；由实测 DC 调整，不把尺寸视为最优解。
- 每侧一只真实 NMOS 电流 sink，Drain=BUF，Gate=现有 `ib` NMOS 镜像参考，Source/Bulk=GND。初始 W/L 约 4 µm / 4 µm（现有 MREF=2/4 µm，参考约 50 nA，设计目标单侧约 100 nA）；务必核实复制器件是否真按期望镜像且 DC 饱和，不能仅凭几何比判断电流。
- 外部负载使用 `CL`，分别接于 `bufp/bufn` 对地；初测每侧 1 pF，重载测试每侧 10 pF（若可能，报告负载扫点，不扩成多参数优化）。
- **不使用理想电流源伪造 CD 静态功耗。** 不额外添加独立反馈环或补偿。所有 MOS 身份、W/L、bulk 和偏置路径应有可复查网表。
- 若 DC 不收敛、sink 进入三极区、或者 NMOS 输出共模太低导致无法工作，仅允许**一次**有原理依据的 CD 尺寸/偏置修正；不换成复杂电平搬移或另设计整级放大器。

## 3. 三组公平测试（避免把“有缓冲器”误判成“改善负载驱动”）

固定同一个 R6C-I ideal CMFB：
- **REF**：原 R6C-I，无新 CD；原 `fp/fn` 节点无新增外部负载。
- **DIRECT**：原 R6C-I，直接在 `fp/fn` 接指定 `CL`，代表前级直驱负载。
- **BUFFERED**：原 R6C-I + 真实 MOS CD，`CL` 接 `bufp/bufn`，`fp/fn` 只承受 CD 栅寄生。

每组使用**相同** 1 pF / 10 pF 负载定义与测试激励；REF 用于检查原系统基准，DIRECT vs BUFFERED 才能评估实际加载改善。报告总增益 `V(bufp-bufn)/V(ep-en)`，并单独报告局部 follower gain `V(bufp-bufn)/V(fp-fn)`，不得把 0.9 V 偏置下降说成电压增益损失。

## 4. Stage A — 静态 TG 直通：先查 DC/AC/STB

逐项：
1. `dc`：`fp/fn`、`bufp/bufn` 的 DC/CM，四只新增 MOS 的 Id/gm/VGS/VDS/VDSAT、饱和余量；CD sink 与 follower 不撞轨，不能出现不可接受削顶。
2. `ac`：100 Hz `Hdm_pre=(fp-fn)/(ep-en)`、`Hdm_buf=(bufp-bufn)/(ep-en)`、局部 `A_CD`；比较 REF/DIRECT/BUFFERED 同 CL 的差异及相位。CD 只作为 buffer，不期望局部增益 >1。
3. `stb`：原 CMFB（`/IPRC`）和 DRL（`/IPRD`）保持闭环；二者 PM≥55°。检查是否出现额外高频问题；若使用静态 A 相测 STB，结果不得直接宣传为斩波周期时变系统的稳定性证明。
4. 输出 `fp/fn` 的静态共模不应偏离 0.9 V 超过 1 mV（沿用 R6C-I 的理想 CMFB 目标）；新增 CD 输出共模不要求为 0.9 V，但必须有足够双向输出摆幅和 MOS 饱和余量。
5. 若 CD 缓冲对原始 `fp/fn` 增益或 CMFB 偏置造成明显退化，停止 Stage B，记录真正原因。

## 5. Stage B — 真实 TG 2 kHz Chopper，瞬态验收

在 Stage A 有效后，运行 2 kHz TG + 100 Hz、1 mV 差分输入，60 ms transient；20–40 ms、40–60 ms 两个窗口分别分析。

分别统计：
- `Hdm_pre`、`Hdm_buf` 和局部 CD Gain，100 Hz 频率/相位；
- `fp/fn` 共模均值、200 Hz 分量、波形；`bufp/bufn` 共模均值/纹波；
- 两输出差模峰峰值及残差、是否削顶；`bufp/bufn` 在每个 TG 翻转后的瞬态/建立时间、边沿毛刺；
- 控制电压 `vg`、DRL、增益在两个时窗之间是否漂移；
- 整机 supply `I(VDD)` 前后差额，`I(VDDD)` 已经包含在上游 VDD 计数中，不得重复相加；明确**理想 CMFB 功耗未计入**。
- 用相同 `CL` 进行 DIRECT/BUFFERED 对比以证明负载隔离确有益处，不能只比较 unloaded 与 buffered。

参数只测 1 pF、10 pF 两档，避免新一轮 sizing/compensation 扫描。视服务器配额压缩原始 transient，保留所有结论所需的 full-resolution 数据和 SHA-256，不提交 PDK 专有模型。

## 6. PASS / FAIL——以“没有烂”为首要标准

**INTEGRATION PASS** 必须同时满足：
- 两条反馈环路仍正常，静态相位裕度均≥55°；没有持续振荡、漂移或 Chopper 相位混乱。
- `fp/fn` 的静态共模与原 R6C-I 的 0.9 V 目标一致（±1 mV），核心 MOS 工作区有效；
- CD 支路 DC 电流可控，新增 MOS 工作区和输出摆幅有效，无明显削顶；局部 follower 在 100 Hz 不反相且增益合理（建议 `0.7≤|A_CD|≤1.05`，应报告实际负载条件）。
- 原系统差模增益 `Hdm_pre` 相对同负载 REF 的变化 <5%；DRL/CMFB 没有被 CD Gate 负载严重破坏；
- 2 kHz 斩波两个观测窗口的增益/共模统计无明显漂移。

**BUFFER VALUE PASS** 另行判断：在**相同 10 pF 负载**下，BUFFERED 比 DIRECT 显著改善缓冲输出的建立/失真或负载驱动指标，并量化收益；若只做到源跟随功能但负载并未改善，标记 `INTEGRATION PASS / BUFFER VALUE NOT PROVEN`，不要修饰。

严格区分 `CD OUT CM SHIFT`（NMOS VGS 固有电平位移）和 `CMFB FAILURE`（原 fp/fn 共模失控）；如果输出端必须 0.9 V 而未满足，报告这项接口局限，不另加电路补救。**本轮不要求**满足最早 ECE203 单端 BioAmp 全部指标、Chopper 噪声 PNoise、完整 PVT/MC。

## 7. GitHub 交付与停止边界

- 本任务：`docs/ECE203_round6d_mos_cd_buffer_task.md`
- 源码：`ece203_r6d.il`，新 MOS CD cell 和新 R6D testbenches/ADE，不修改旧库。
- 结果：`docs/ECE203_round6d_mos_cd_buffer_results.md`，顶部先写 `INTEGRATION PASS/FAIL` 和 `BUFFER VALUE PASS/NOT PROVEN`。
- 数据：`docs/ece203_data/round6d/`，包含 MOS DC OP、AC、CMFB/DRL STB、1/10 pF 的直驱/缓冲对照、2 kHz transient 的原始 CSV（可压缩）、分析脚本、图、有限仿真日志及相关 SHA。
- 复现：按 Git commit、软件/PDK 信息、任务命令、参数、实际数据和核对方法写清楚；使用 GitHub 版本化保存所有必要产物。
- 跑通就 **STOP**；如果跑不通，在一次根因修正后仍失败也 **STOP**。**禁止**主动开始第二级 CS、真实 MOS CMFB、SC-CMFB、RRL、完整噪声/PVT/MC、甚至自动追加新实验。

最终回复只需：是否接入成功？原 CMFB/DRL 是否完好？实际输出共模与增益怎样？10 pF 时缓冲是否有价值？然后停止。
