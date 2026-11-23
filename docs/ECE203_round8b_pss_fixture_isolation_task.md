# ECE203 R8B — PSS 收敛硬骨头：隔离 R6A 遗留的 1 MF / 1 TΩ 假性慢状态，恢复 R8 PNoise

**状态：TASK ONLY / NOT RUN。** 用户明确要求先验收 R8，并且怀疑需要更新实验 setting。此文件是在审核 R8 真实 R7F Chopper PSS 两次失败后制定的**最小可证伪隔离实验**。没有跑过 R8B，也没有改任何已验收 R5N-F、R7F、R8 文件或 Cadence cell。

## 0. 当前已验证的事实：先别盲目调 Solver

- 来源：`docs/ECE203_round8_real_mos_chopper_noise_results.md`、`docs/ece203_data/round8/r8_pss_attempts.csv`、`raw/stageB/B_pss_a{1,2}_netlist.scs`、`r8_netlist_audit.txt`、`ece203_r8_noise.il`；原先任务 `docs/ECE203_round8_real_mos_chopper_noise_task.md`。
- R8 Stage A OFF **PASS**，真实 PDK MOS，`outp−outn`，0.1–250Hz 输入等效 **16.32 µVrms (de-embed)** / **16.87 µVrms (application)**、100Hz OFF H=85.67、两类 OTA 1/f 贡献合计约 **98.9% 输出噪声功率**。这个锚点要保留。
- R8 T0 零差模激励 / 2kHz Chopper **20ms transient 完成**，p/n 与 fp/fn 重复周期相差远小于 1µV、CD 输出稳定、未削顶。R8 PSS a1/a2 在实际 shooting 40/60 iterations **明确 NOT CONVERGED**；最大残差持续在 `VREF:p`、`EOC:p`，Newton norm 振荡。a2 将 `itres` 从 1e-4 收紧 1e-7 **无助**。PAC/PNoise 根本没有运行，所以 **不存在有效的 Chopper-ON 随机噪声数字**。
- 精确 R8 原网表 `raw/stageB/B_pss_a2_netlist.scs`：`EOC (ocx vref ocm vref) vcvs gain=1`、`CHP (ocx oac) capacitor c=1M`（**Spectre 1M = 1e6 F**）、`RHP (oac vref) resistor r=1T`。`EB2 (b2 b1 oac vref) vcvs gain=-kb*wob`，而 `kb=0`，故 EB2 对有效 body actuator 无贡献。CHP/RHP 时间常数 **1e18 秒**，相比 500µs TG 周期近似没有衰减，**有力怀疑**其近奇异的 shooting Jacobian 引发 EOC/VREF 电流残差；仍需**删除隔离对照后**才可因果确认。
- 既往 R6B PSS 也失败，但此处 R8 的 T0 真实 TG 正常运行。不能把 Spectre 求解器失败解释成电路不能斩波；也不允许放宽 `iabstol` 十亿倍伪造 PSS PASS。

## 1. 本轮唯一拓扑变更：只清掉诊断辅助中的两个冗余元件

**建立全新** `Project/ece203_r8b_tb_noeoc_chp`。从冻结 `Project/ece203_r7f_tb_gain_g0_load10p` 的**同一 `r7fSpecs("gain_g0_load10p")`** 派生，SKILL 列表按 **exact instance names** 过滤**且只过滤**下面两只：
```
REMOVED: EOC  (ocx vref ocm vref) vcvs gain=1
REMOVED: CHP  (ocx oac)           capacitor c=1M
KEEP:    RHP  (oac vref)          resistor r=1T
KEEP:    EB2  (b2 b1 oac vref)    vcvs gain=-kb*wob   // kb=0, input via oac tied to vref by RHP
```
**原因**：EOC/CHP 的 `ocx` 成为不再使用的节点，`oac` 留有 RHP 到 VREF 的 DC 定义，EB2 不会出现控制输入浮置。所有其它实例 **完全不变**：`EB1,EB2,EG1,EG2,VUB,VUG,CVG` 及所有 MOS 子电路、pseudoR、IREF、VREF/VCAS、双 TG、Clock、输入 Cc=60p、Cfb=0.5p、4MΩ/148p LP、10p/侧实际 COUT、CD 的旧 10p CLB、人体/电极，均不动。避免一轮删 10 个 probe 来源而造成无法归因。

- 若 SKILL 的派生 spec 无法安全精确过滤或生成的新网表除两只删除外还有其它结构差异，**STOP，不跑仿真**。不允许直接修改原 `r6Specs()`、旧 `ece203_r7f.il` 或旧 cell、ADE。
- R8 OFF 和 ON 仅 `chen=0/1` 的运行变量不同；本轮的实验因果自变量是**有/无 EOC+CHP 两只假性辅助元件**，不得更改 Clock rise/fall、freq 2k、MOS、DC 偏置、C/R 或 PSS 对真实电路的激励参数。

## 2. Gate A — 比较新旧 testbench 的 DC/AC/ordinary noise，证明清理不改变电路物理性能

- 原 R8 Stage A OFF：`chen=0` / TG static Phase A、`vd=0`、`dcc=0`、`adm=1` AC、真实 noise differential `outp/outn`；C0 直接复用原 Stage A 只读数据（必要时重测相同条件，以说明理由）。C1 只使用**新 R8B** cell。
- 两者用同一 Spectre `tt`/27°C、`gmin=1e-18,iabstol=1e-17,reltol=1e-5`；记录 `V(op),V(on),p/n,vg,buf,out,pref/ib`、I_VDD/I_VDDD、Hout(f) (0.1–250Hz, 100Hz gain)、0.1–250Hz noise spectral density 和 integrated **output RMS, app, de-embed**；NoiseSummary 检查主要器件噪声组是否不变。
- **等效 gate**：DC 主要输出差异 <= 1µV，100Hz Hout 相对变化 <=0.1%，`Sout(f)` 在检查点0.1/1/10/100/250Hz <=1%，输入两类 noise RMS <=1%，主要 source-group 排名不变；原 OFF 输入噪声 **16.32/16.87 µVrms** 需可复现。保留数字小偏差的精度来源说明。
- 用**真实网表 diff**证明只删 EOC 与 CHP，没有其它实例/子电路/参数变动。注意旧 Stage A netlist里的 `noise` analysis statement 和新表项差异在预期集合内。
- 若 A fail：STOP，不能用后续 PSS “成功”来掩盖已经变更真实物理性能的事实。

## 3. Gate B — 在新 fixture 上运行**一次**原 R8 PSS a1 设置，验证假设

- `chen=1`, `vd=0`、`adm=0`、`dcc=0`、`pacd=0`、`pa=1,pb=0,tch=500us`；R8 A/B 同一电路。
- **首轮 PSS 参数严格继承失败 a1**：`fund=2k, harms=40, maxacfreq=200k, errpreset=moderate,tstab=5ms,maxperiods=40,cmin=1e-17,itres=1e-4`，物理零输入源相位、Spectre 15.1 不动。使用短时诊断 trace（如必要只做一个 10–20ms）监测周期稳态。最大存储/CPU 有 watchdog 和 `/tmp` PSF。
- **PSS PASS** 必须有 Spectre **明确 converged success**，`pss_td` 500µs 周期闭合并且无削顶/异常工作点。保存原始 `spectre.out`、convergence norm 序列、迭代最大残差器件清单、PSS TD 和 SHA。若收敛，支持 **“EOC/CHP 对旧 PSS 不收敛有决定性贡献”**，但不要声称证明系统的其它长期 slow modes 不存在。
- 如果**仍不收敛**，先记录最大 residual 是否**转移出 VREF/EOC**、norm 是否明显改善；不要立刻要求 maxperiods 500 / iabstol 1e-10。只允许**一次**以新日志为依据、预先登记的真正数值分析 setting 调整（例如与 PDK/Spectre help 符合的 method/steadyratio/tstab/itres，参数要有合理解释），再跑一次。同 fixture 不能更动器件。二次失败 -> **R8B BLOCKED，停止**，将长 pseudoR 和其它可疑退化模式列作新原因候选，不能伪造 PSS 完成。

## 4. Gate C — PAC 先确认信号响应，再决定 PNoise

只有 B PASS 才做 `readpss`、零边带 PAC 0.1–250Hz，源 PAC `pacd=1`、正确正幅度+180°负输入，Clock PAC=0，除分析设置外硬件和无周期输入均不变。记录 `Hon(f)=(outp-outn)_0/(ep-en)_0`。**Hon100 应接近 R7F 2kHz/1mV transient 83.25V/V（±10%）**；若不可信则 C FAIL/STOP，不进入 PNoise。注意原 R7F 60ms 瞬态与此 PSS 零驱动小信号定义不同，偏差须解释。

## 5. Gate D — PNoise + sideband convergence，回到原 R8 目标

只有 A/B/C 都 PASS，才允许在**同一新的 R8B testbench**上执行原 R8 已预登记的 `pnoise` 阶梯：`maxsideband=10,30,60`，若尚未收敛再至 90。使用该 Spectre help 已证实的默认 `timeaverage`、连续时间差模端 `outp/outn`、`sweeptype=relative,relharmnum=0`、0.1–250Hz；报告每档的 OCEAN + Python double-check 的 output spectral density/integral、application & pointwise de-embed RMS、0.1/1/10/100/250Hz 输入PSD。
- **最后两个高档**：app 和 de-embed RMS 差 <=5%，1/10/100Hz density 差 <=10% 才接受为 numerical convergence。未达到不得宣称 Chopper ON 的 noise true value 或 `<3µVrms` PASS。
- 如果 Spectre noiseSummary 可以分组，按 XA M1/M2 flicker vs M3/M4 flicker & folded thermal，XC CMFB、TG XCI/XCO、CD XCD、pseudoR 与 LP resistor thermal 分源；不可因为 noiseSummary API 缺数据就将其当0。
- 与 **原 R8 Stage A OFF** 相同硬件条件的 16.32/16.87µVrms 比较；A 等效通过后，可使用新 R8B 的 OFF 重测数据作为更严格的直接对照；与 R5N-F F2 的 2.88µV 噪声仅做跨架构工程比较，**不是因果基线**。
- 把 R7F 的 141.7µV **确定性**边沿残差、H3、pseudoR 整流漂移放在另一个表，绝不可加入随机 PNoise 积分。

## 6. 代码、数据与纪律

- 新 `ece203_r8b.il` 和 `batch/ece203_r8b_*.il`；新 Cell 只能叫 `Project/ece203_r8b_tb_noeoc_chp`，旧 `Project/ece203_r7f_tb_gain_g0_load10p`、R8 原仿真结果、R5N-F F2 全部只读。不要碰 Explore/Final Library 批量重命名。
- **先**建立并 Git 提交 `docs/ece203_data/round8b/r8b_plan.md`（上面 A→D 的 gate、允许的 one retry、如何证明 netlist only 2 deletions）、源代码及 batch，再运行。所有中途调整提前登记，保留失败日志/结果，不覆盖。
- `docs/ECE203_round8b_pss_fixture_isolation_results.md` 与 `docs/ece203_data/round8b/` 输出 Stage A 的 old/new noise AC comparison CSV、netlist diff、PSS convergence logs、PAS/PAC/PNoise results depending on completion、sideband convergence CSV 和 plot、真实 model config、spectre.out、若有 PSF 确认 SHA+必要波形。PNoise 未跑写 NOT RUN；A/B失败写 FAIL/BLOCKED 而非空缺。
- 运行环境 `cmrf7sf tt 27°C`、IC618/Spectre15.1。按 `docs/automation_playbook.json` 使用 `~/AutoCircuit/run.sh`；每次运行 `/tmp` 保存大 PSF，watchdog限时/限磁盘，**不杀用户原有 Virtuoso/Spectre 进程**，公开GitHub禁上传 IBM PDK 全模型与凭据。完整记录 git commit/SHA / netlist hash / seed / 运行时间。不得在失败后自动改变实际电路拓扑、开关器件尺寸、2kHz 时钟或 LP 参数。
- **本轮可以验证“清除诊断支路”是否救回 PSS，并且若成功推进到原 R8 PNoise；不能预设成功。** 失败也要提交完全部可复现证据，STOP。

## 7. 给 Claude 的启动消息

> R8 已验收：OFF 静态 Noise PASS 16.32/16.87µVrms；PSS a1/a2 BLOCKED，主要残差在 VREF/EOC。执行 **`docs/ECE203_round8b_pss_fixture_isolation_task.md`**。建一个新 R8B cloned bench，只从 R7F spec 删除 **EOC + CHP**，保留 EB2、RHP、其它所有元件（kb=0，RHP 继续约束 EB2 input）；先网表 only-two-removals 审计与 OFF DC/AC/noise 等效验证，再用原 a1 setting 跑 PSS。若成功，PAC 83V/V 附近再测 PNoise 10/30/60(/90) 边带收敛。若失败最多一次有记录的合理数值 setting 调整后停。严禁修改旧 cell、凭感觉大幅放宽 iabstol、换理想 TG，或将未经收敛的 PNoise 当 PASS。所有原始失败日志/CSV/plots/报告 commit GitHub。
