# ECE203 Round 3D — 理想时钟 / 理想开关 Chopper 的最小上限实验

**用户决定：2026-11-16。** 目标不是制作可流片 Chopper，而是沿用 Round3 理想 VCVS 的思路，用 **零噪声理想 clock + ideal commutating switches**，确定现有单级电容耦合 BioAmp 使用 Chopper 是否值得继续投入。**只回答：信号能否闭环解调？理论上限假设下，0.1–250 Hz 的噪声能否明显接近 3 µVrms？** 不得自动实现真实 MOS switches、clock generator、ripple-reduction loop、辅助 OTA。

## 已确认数据 / 实验起点

- Read `CLAUDE.md`, `docs/automation_playbook.json`, `docs/ECE203_round3c_ota_compare_results.md`, `docs/ECE203_round3_single_stage_results.md`, original `ece203_ss.il` and Round3C scripts.
- **主参照 C（Round 3C）**：当前单级 S2 + 仅输出 NMOS 支路局部 cascode 的 OTA，开环 A0≈1627，闭环 |Hdm(100Hz)|≈94.22（39.48 dB）、输入参考噪声 0.1–250 Hz≈16.1 µVrms（输出噪声除以 100Hz 增益）；输入对和镜像 1/f 占大部分；功耗≈0.510 µW；M2 最小裕量**仅 0.047 V**，这一弱点要记录，不是最终可用设计。
- 固定 S2 两侧 `Cc=50pF, Cfb=0.5pF, ideal Rfb=3.1831TΩ`, VDD1.8V, VREF0.9V, CL0, 同一差分输入源；**不要**换 Round3B pseudo-R 或重新调 OTA W/L/VCAS。
- 保留静态基准 C 和已测 16.1 µVrms，若用新的输出低通滤波，静态基准也必须施加**相同**滤波才能比较（不能让 chopped 获得不公平的额外滤波）。

## 实验范围：先验明信号，再尝试周期噪声（两关，严格停止）

**A. 理想 Chopper 的信号功能，短测试**
1. 新建隔离 `ece203_ss_chop_*` cell 和一个新的 run.sh job，不覆盖旧 cell/ADE。用**理想 clock（默认 fch=2 kHz）和理想 2 相 commutating switches**实现差分输入交换（±号），输出同步还原（±号），取回 0.9 V common-mode；**信号调制和解调必须围绕整个 OTA 内部，但负反馈的返回点要在解调之后，始终保持负反馈。** 如果因单端 OTA 输出而需要理想的单位增益反相（围绕 VREF）来提供输出 switch 的两条相位支路，允许这一**明确列为非物理、无噪声的理想辅助块**；绝不可假称单端输出能靠纯被动 SPDT 无成本完成正负号翻转。开关近似 Ron=0/Roff=∞，如 Spectre 必须使用有限 Ron/Roff，要写出实际取值与它们的等效热噪声是否被忽略。
2. 用课堂 **理想 VCVS OTA 版本**（与 Round3 同类的理想 aol=1e5）先做单一 10 Hz 小信号 tran（如 1 mVpk 差模），确认 after-demod 输出有正确极性、约 100 倍理想闭环 gain、无系统性翻相/崩溃。**只做一次功能 golden test；错了最多修一次接线。**
3. 用 **冻结 C cascode OTA** 替换 VCVS，在同一信号条件做一次 tran；分别记录原始 OTA 节点的 chopping、解调后输出的带内幅度/相位、开关纹波（建议在同样理想 250Hz lowpass 观察 ECG band；给静态 C 同样 LP 以公平比较），检查输出摆幅是否撞 rails、M2 headroom 是否持续足够。电容高通慢常数可能造成短暂启动漂移：稳态窗口的定义要说明，不能把未收敛误当成性能。**如 C 不能稳定收敛或正反馈，诚实报 blocker，不引入复杂新架构**。

**B. 只有 A 通过才尝试噪声理论上限（一个周期噪声比较）**
1. 这是**周期时变**系统：普通 Spectre `noise` / `ac`、确定性 tran 不等于 chopped 后的输入参考噪声。优先尝试 Spectre **PSS + PNoise**（或相同原理的可验证周期噪声工具），用同一时钟周期/2 kHz，sidebands 要能捕获低频 1/f upconversion 和高频热噪声下折。只允许**一次主配置 + 一次有理由的参数修正**；不应为了 PSS 收敛花无限时间。
2. 只对比 **unchopped C (Round3C 已有静态 noise)** vs **C + 理想 chopper** 的 0.1–250 Hz 输出噪声 PSD / integrated Vrms（必要时同理想 LP），并用实测调制解调后的带内信号 gain 计算差分输入参考 noise。报告 baseline 与 chopped 的 gain、输出 noise、输入参考 noise（µVrms）、若能求得则白噪声地板与 flicker 残余。**必须说明 PNoise 采用 time-average / sideband / sample 定义**，避免拿 sampled noise 和连续时间输出混为一谈。
3. 如果 PSS/PNoise 不可用、工具失败或不能确信结果，报告为 **“仅信号闭环功能验证，噪声上限未验证”**；可以给基于 Round3C NoiseSummary 的**乐观解析下界估算**，但不得以推导值冒充 Spectre chopped-noise 实测。**不要直接以普通 AC/noise × 小于1的系数“假造降噪”。**

## 交付与停止点

- **简短** `docs/ECE203_round3d_ideal_chopper_results.md`：1 张小对照表（理想 VCVS vs C 真实 OTA、chopped vs unchopped 的信号增益；噪声如工具确实测到才列数值）、clock/sw 架构和 PNoise 是否通过、失败原因与明确下一步建议。最少必要的 raw CSV（tran 采样 / PNoise PSD 如成功），一张图可选。复用 AutoCircuit 的既有流程/Windows lab notebook；保护所有旧 cell / 用户 GUI，不提交 PDK 机密信息。
- **不做** 实际 MOS switch、真实 clock、Chopper 频率优化扫描、offset cancellation、ripple suppression、2nd amplifier、Harrison 整体复刻、改变反馈网络、PVT/MC/CMRR/人体电极。
- **做完 A + 最多一次 B 尝试就停**，给用户和 GPT 决定是否继续“追梦”。这是一个**架构可行性研究和上限估算**，不是对最终 3µV 性能的承诺。
