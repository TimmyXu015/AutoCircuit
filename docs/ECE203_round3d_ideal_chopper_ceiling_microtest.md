# ECE203 Round 3D — 1 MHz 理想时钟 / 理想开关 Chopper 极限小实验

**用户决定：2026-11-16（更新：Chopper clock 指定为 1 MHz，替代原 2 kHz）。** 目标不是制作可流片 Chopper，而是沿用 Round3 理想 VCVS 的思路，用 **零噪声理想 clock + ideal commutating switches**，确定现有单级电容耦合 BioAmp 使用 Chopper 是否值得继续投入。**只回答：信号能否闭环解调？理论上限假设下，0.1–250 Hz 的噪声能否明显接近 3 µVrms？** 不得自动实现真实 MOS switches、clock generator、ripple-reduction loop、辅助 OTA。

## 已确认数据 / 实验起点

- Read `CLAUDE.md`, `docs/automation_playbook.json`, `docs/ECE203_round3c_ota_compare_results.md`, `docs/ECE203_round3_single_stage_results.md`, original `ece203_ss.il` and Round3C scripts.
- **主参照 C（Round 3C）**：当前单级 S2 + 仅输出 NMOS 支路局部 cascode 的 OTA，开环 A0≈1627，闭环 |Hdm(100Hz)|≈94.22（39.48 dB）、输入参考噪声 0.1–250 Hz≈16.1 µVrms（输出噪声除以 100Hz 增益）；输入对和镜像 1/f 占大部分；功耗≈0.510 µW；M2 最小裕量**仅 0.047 V**，这一弱点要记录，不是最终可用设计。
- 固定 S2 两侧 `Cc=50pF, Cfb=0.5pF, ideal Rfb=3.1831TΩ`, VDD1.8V, VREF0.9V, CL0, 同一差分输入源；**不要**换 Round3B pseudo-R 或重新调 OTA W/L/VCAS。
- 保留静态基准 C 和已测 16.1 µVrms，若用新的输出低通滤波，静态基准也必须施加**相同**滤波才能比较（不能让 chopped 获得不公平的额外滤波）。

## 实验范围：先验明信号，再尝试周期噪声（两关，严格停止）

**A. 理想 Chopper 的信号功能，短测试**
1. 新建隔离 `ece203_ss_chop_*` cell 和一个新的 run.sh job，不覆盖旧 cell/ADE。用**理想 clock（fch=1 MHz，T=1 µs，半周期 0.5 µs）和理想 2 相 commutating switches**实现差分输入交换（±号），输出同步还原（±号），取回 0.9 V common-mode；**信号调制和解调必须围绕整个 OTA 内部，但负反馈的返回点要在解调之后，始终保持负反馈。** 如果因单端 OTA 输出而需要理想的单位增益反相（围绕 VREF）来提供输出 switch 的两条相位支路，允许这一**明确列为非物理、无噪声的理想辅助块**；绝不可假称单端输出能靠纯被动 SPDT 无成本完成正负号翻转。开关近似 Ron=0/Roff=∞，如 Spectre 必须使用有限 Ron/Roff，要写出实际取值与它们的等效热噪声是否被忽略。
2. 用课堂 **理想 VCVS OTA 版本**（与 Round3 同类的理想 aol=1e5，**无带宽限制**）先做短窗功能 golden：推荐在输入耦合电容之前对差分信号施加 **1 mV 阶跃**（相当于观察 10 Hz ECG 在很短窗口内的局部瞬态），只记录几十到几百个 1 MHz 时钟周期的已解调变化与波形极性；这仅用于检验调制/解调和近似 ×100 的瞬时响应，**不能冒充 10 Hz 稳态增益**。如果可用 PAC/PXF 在 1MHz 时钟的 PSS 工作点测试 10/100 Hz 小信号传递函数，可替代长时间 transient；否则报告“未测稳态 ECG 增益”。**严禁**为了 10Hz 单周期跑 0.1s–1s、数十万到百万次开关的超大 tran；只做一次短测试，接线错误最多修一次。
3. 同样短窗下，把 VCVS 换成 **冻结 C cascode OTA** 做**最多一次**真实带宽压力测试，报告调制后的输入/放大器内部输出/解调后输出的瞬态与 DC OP、是否出现极低响应、失真或饱和。**已知真实 C 闭环 fH≈8.81 kHz，远低于 1 MHz，预计半周期 0.5 µs 根本不足以建立响应；不要将它失败解释为 Chopper 原理失败。** 记录短窗响应而非在 1 MHz 情况下强行声称 ECG 10Hz 稳态增益或输出经过 250Hz LP 的结果。如果不能合理建立响应，立刻停止真实 OTA 测试，不修改 gm/Id、VCAS、偏置、增加级数或换频率。

**B. 只有 A 通过才尝试噪声理论上限（一个周期噪声比较）**
1. 这是**周期时变**系统：普通 Spectre `noise` / `ac`、确定性 tran 不等于 chopped 后的输入参考噪声。只有 **1 MHz 下真实 C OTA 功能信号仍可信**时，才尝试 Spectre **PSS + PNoise**（或同原理可验证工具），时钟周期 **1 µs**，sidebands 要涵盖 1/f 噪声频谱搬移和白噪声折叠。只允许一次主配置 + 一次有理由的最小修正；不能为 PSS 收敛花无限时间。**理想 VCVS 本身无晶体管 1/f 噪声，因此“理想 VCVS+理想开关”得到的极低噪声不具有 OTA 降噪验证意义。**
2. 只有真实 C 的 **1 MHz 带内信号增益可信、且 PNoise 能成功**才对比 **unchopped C (Round3C 静态基准)** vs **C + 理想 chopper** 的 0.1–250 Hz 输出噪声 PSD / integrated Vrms（必要时同理想 LP），并用经 PAC/PXF 等有效方法测得的带内信号 gain 计算差分输入参考 noise。报告 baseline 与 chopped 的 gain、输出 noise、输入参考 noise（µVrms）、若能求得则白噪声地板与 flicker 残余。**必须说明 PNoise 采用 time-average / sideband / sample 定义**，避免拿 sampled noise 和连续时间输出混为一谈。
3. 如果 PSS/PNoise 不可用、工具失败或不能确信结果，报告为 **“仅信号闭环功能验证，噪声上限未验证”**；可以给基于 Round3C NoiseSummary 的**乐观解析下界估算**，但不得以推导值冒充 Spectre chopped-noise 实测。**不要直接以普通 AC/noise × 小于1的系数“假造降噪”。**

## 1 MHz 特别限制（本轮实验的核心预期）

- **1 MHz 是用户指定的极限压力测试，不是推荐的真实 Chopper 工作频率。** 冻结 C 的 8.81 kHz 闭环带宽比斩波时钟低约 113 倍。理想无带宽 VCVS 可以“跟上”，真实 OTA 大概率跟不上。严格区分这两种结论。
- 在 1 MHz 时，半周期只有 0.5 µs。为了比较 10Hz ECG 真正稳态而做超过 0.1s 的 tran 需要 10万以上开关周期，不符合用户“短实验快速决策”的要求。**首选短窗阶跃功能验证 / 轻量 PSS+PAC**，不要让仿真规模爆炸。
- 若真实 OTA 在 1MHz 下失效，**直接报告带宽瓶颈并停止，不做 PSS/PNoise，也不自动退回 2 kHz。** 此时可报告 1 MHz 理想逻辑已验证，但**Chopper 降噪上限仍未测出**。
- 目标只在 **1MHz**，不要搞多频率 sweep。

## 交付与停止点

- **简短** `docs/ECE203_round3d_ideal_chopper_results.md`：1 张小对照表（1MHz 的理想 VCVS 短窗功能/真实 C OTA 短窗功能；仅在有效测到时报告真正稳态增益或周期噪声数值）、clock/sw 架构和 PNoise 是否通过、失败原因与明确下一步建议。最少必要的 raw CSV（tran 采样 / PNoise PSD 如成功），一张图可选。复用 AutoCircuit 的既有流程/Windows lab notebook；保护所有旧 cell / 用户 GUI，不提交 PDK 机密信息。
- **不做** 实际 MOS switch、真实 clock、Chopper 频率优化扫描、offset cancellation、ripple suppression、2nd amplifier、Harrison 整体复刻、改变反馈网络、PVT/MC/CMRR/人体电极。
- **做完 A + 最多一次 B 尝试就停**，给用户和 GPT 决定是否继续“追梦”。这是一个**架构可行性研究和上限估算**，不是对最终 3µV 性能的承诺。
