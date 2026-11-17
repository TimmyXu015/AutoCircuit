# ECE203 Round 6A micro-PoC — DRL 与全差分 OTA CMFB 的协同 / 共享控制

> 用户授权于 2026-11-16：创新性小实验，**允许理想 chopper**，不要启动大规模 Round 6、四路 CD/CS 排位赛、真实 MOS chopper、RRL 设计。目标是验证 **DRL + OTA output CMFB 是否能够真实共享/耦合控制，同时有利于全差分斩波**。实验范围有限，结果可能是“单控制量不足”；反证也是有价值的成果。

## 研究假说：严格区分三种含义

输入共模 `e_in = (Vinp+Vinn)/2 - VREF`（人体/电极驱动的 DRL 闭环）；输出共模 `e_out=(Vop+Von)/2 - VREF`（全差分 OTA 的 CMFB 闭环）。它们是**不同误差**，右腿电极和OTA负载偏置是**不同执行器**。

1. H0：**简单共用一个误差放大器输出**：例如 `u = K[e_in + α e_out]`，分别以固定增益驱动 right-leg 和 OTA CM bias。只有一个独立控制自由度；可能只把加权误差降为零，却不能在独立干扰下把两个误差同时归零。**必须实测这个陷阱，不要当创新成功**。
2. H1：**协同双自由度**：同一 DRL/CMFB control macro 共享参考、部分传感/偏置/补偿，并保留 `u_body` 与 `u_OTAcm` 两个可独立调节的执行信号；可加入有理据的交叉补偿 `u_body = K11 e_in + K12 e_out`，`u_OTAcm = K21 e_in+K22 e_out`。参考结构是彼此独立的DRL+CMFB（K12=K21=0），与其公平比较。**如果没有减少器件/功耗/纹波或提升性能，不得称其有创新优势。**
3. H2（可选）：shared DRL output can be feed-forward into CMFB **reference**（或限幅的辅助项），但独立的 `e_out` 本地纠偏仍在。对比能否改善对人体共模扰动的输出纹波/恢复速度，且不恶化静态偏置/CMRR。

**不得直接宣称“原 DRL 就是 CMFB”。** 多输入多输出控制理论上，两独立干扰通常需要两个控制自由度；用DC/AC灵敏度和独立扰动验证，不能只看一次 nominal DC 收敛。

## 先读 / 冻结的电路

- `CLAUDE.md`、`docs/automation_playbook.json`、`docs/ECE203_round4_integrated_results.md`、`docs/ECE203_round5_architecture_noise_demod_results.md`、`ece203_r4.il`、`ece203_r5.il`；复用已有real `ece203_r4_drl_ota` 和原电极/身体模型（右腿串联≥1MΩ），**不许修改/覆盖任何R4/R5 cell、ADE state、结果，禁止kill用户Virtuoso**。
- 冻结 VDD=1.8V，VREF=0.9V，60Hz body current 0.1µA，典型几何/电极参数来自R4，bias reference机制沿用 100nA 约束；若测试阶段有理想误差放大器、增益/电流镜/独立偏置，必须标 **diagnostic**，不得把其电流作为零功耗的真实实现。
- 不要求延续原单端 C OTA 全部电性能：**只新建一个最小对称的 fully differential OTA1 概念 cell** `ece203_r6a_fd_ota`，保留R4 NMOS输入对/VCAS局部cascode思路，改成两支可独立观测的输出 + 受CMFB控制的对称PMOS负载，必要时左右cascode对称。原R4镜像左节点是二极管连接，不能假装已有真对称Vop/Von。最先确认差分极性与输出DC/common mode调节方向。
- 新建`ece203_r6a_*` TB、`ece203_r6a.il` 或同项目脚本与新 job。iENG6 quota先查、check logs和exit code；SSH stdin关闭，不能无限等MATLAB命令，不杀GUI进程。用户Windows实验记录本与Repo的数据按playbook。

## 四个小阶段 / 预算闸门

### A. 单控制量可行性门槛，最优先

做 **2×2 低频/AC灵敏度识别**：在可控制的诊断模型或MOS FD OTA里，分别小扰动 `u_body`（DRL drive）和`u_OTAcm`（OTA负载偏置）测输入、输出CM变化，形成

`P(s) = [[∂Vcm_in/∂u_body, ∂Vcm_in/∂u_OTAcm],[∂Vcm_out/∂u_body, ∂Vcm_out/∂u_OTAcm]]`。

最少报DC/1Hz/60Hz magnitudes/phases, determinant/rank概念，**不允许在输入源理想锁死body共模时量错导数**。施加两类**独立扰动**：
- `d_body`: R4 0.1µA @60Hz body current，检查Vin_cm以及Vout_cm；
- `d_ota`: 对`Vop`、`Von`等量注入可调的小共模测试电流（初值每支约 1nA，保证不饱和），或等效可验证的负载偏置变化；确保它确实改变OTA输出CM而不直接改变人体CM。

先做 **H0 单控制器、两执行端固定比例**的概念诊断，对比两种扰动。若两项误差无法同时抑制，明确记 **H0 BLOCKED**, 这也是正确结论。不能为“创新成功”调换检查口径。这个阶段可用独立理想源/controlled sources验证控制维度；理想部分不得算作物理电路成功。

### B. 最小真实 FD OTA + 独立 DRL/CMFB 基线

只用**一版**对称MOS FD前级及一版CMFB：CM sense `(vop+von)/2` 与VREF，CMFB输出控制对称PMOS gate/尾电流中一个可调端；已有R4真实DRL OTA仍独立驱动电极。若CMFB需要理想误差放大器才能工作，结果标 diagnostic，**不得替代真实共模环路后宣称物理可行**。受控调整最多 1 次控制极性或补偿元件以修正明显错误，禁止多轮 sizing探索。

量：Vop、Von、Vcm_out、Vin_cm、尾电流、负载headroom、ΔVdiff/ΔVin差分传递、CM loop stb与DRL loop stb及其在另一个环闭合时的结果；测 `d_body` 与 `d_ota` 两种独立扰动。先识别两条回路的实际反馈极性；PM目标≥55°仅对能正确测量且条件成立的loop而言；有多环耦合时单独断环PM不足以证明整体稳定，补充tran两个干扰恢复过程。

### C. 真正协同控制候选 H1/H2（只选1种）

根据A的P矩阵结果选最简单、可物理解释的协同方式：例如两个误差传感器存在且执行器独立，但借用真实DRL控制误差作为CMFB bias的**小幅 feed-forward**，同时保留输出CM本地反馈；或共享参考/偏置路径同时增加合理交叉补偿。**必须说明共享了什么，省了什么，并把交叉增益设成0做同MOS公平对照。**

同样 `d_body`、`d_ota`，评价两个共模误差/恢复时间、输入信号增益、CMRR @60Hz、头间距及静态电流。若只有控制器数量相同而性能没有提高，标 **WORKS BUT NO BENEFIT YET**；若能稳定但性能退化，标 **NOT PREFERRED**；若不稳或一个扰动无法调平，标 **FAIL FOR INDEPENDENT DISTURBANCES**。不因为论文/直觉偏爱协同结构而篡改基线。

### D. 理想 Chopper *仅最后一项、条件触发*

只有B/C中有DC稳定的真差分输出后，才在**同一个fully differential OTA**的输入/输出做 **±1 理想两相commutator / swap**，初始 `fch=2kHz`，仅必要时改为4kHz作为一个额外点。不需要单端EINV/VCVS产生第二输出；保留真实信号增益及CMFB/DRL，输出可简单差分测试或在已知可工作的轻量理想D2SE读取差分量（标 diagnostic）。测 `Vop,Von,Vcm_out,Vdiff`、vcm_in、解调后的signal 100Hz / 1mV小信号增益、每相收敛、PSS波形/纹波；不跑大范围 PNoise、不宣称noise<3µV，也不做物理开关/clock/RRL。
若Chopper destabilizes CMFB或引入严重共模纹波，记录具体节点与相位，优先判定**架构未验证**；不要转去全面补偿优化。

### 工作预算 / 停止条件

- 本轮为**小型 PoC**，建议 **≤12个Spectre仿真用例、最多1次PSS、每阶段最多一次方向性修正、无大批量MC/PVT**。在最小全差分MOS做不出稳定操作点或H0被证伪但H1无清晰物理收益时，**保存现有部分并STOP**；不要偷偷扩展为新的全差分BioAmp项目。
- 阶段A先产CSV/short report，有关键结果再B，然后最多C/D；禁止把“概念逻辑示意”写成“已成功仿真”。
- 输出：`docs/ECE203_round6a_drl_cmfb_coupled_results.md`，`docs/ece203_data/round6a/`中`control_matrix.csv`、`cm_step_60hz.csv`、`comparison.csv`、若D运行 `ideal_chop_waveforms.csv`，以及新脚本和一张连接图。报告顶部必须写 **“概念可行 / 部分可行 / 未证实 / 被证伪”**，明确 **Spectre / ideal diagnostic / analytic only / not run**，注明额外bias成本与是否真正减少电路。
- **停止后向用户回报**三句话：简单共用单误差信号是否能用？共享/耦合双自由度是否优于独立双环？有无可供真实MOS Chopper继续用的差分输出？结束后STOP，不自动开始四路决赛或Round6B。
