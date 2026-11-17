# ECE203 R6D-R 结果：Chopper 瞬态数值收敛恢复（只针对 R6D Stage B）

| 判定 | 结论 | 依据（同一数值设置 C，tt / 27 °C） |
|---|---|---|
| **数值收敛** | **NUMERICALLY RECOVERED** | 只加 tran `cmin = 1e-17 F`（设置 C），BUFFERED 1 pF 和 10 pF 都完整跑完 60 ms 两相 TG 斩波，没有出现时间步塌缩。 |
| **接入是否正常** | **INTEGRATION PASS** | 5 个用例在 20–40 ms 和 40–60 ms 两个窗口的增益、共模、vg、DRL 都一致到 5 位有效数字，没有漂移或振荡。fp/fn 共模 0.900062 V。接入 CD 后 fp/fn 增益变化 −0.001%。CD 局部增益 0.842、相位 0.01–0.11°。sink 最小余量 0.40 V，没有削顶。 |
| **缓冲价值** | **BUFFER VALUE PASS（仅限负载隔离）** | 同样 10 pF、同样设置下，BUFFERED 让原 fp/fn 节点完全不受影响：增益 −0.001%（DIRECT 为 −3.32%），送到负载的 100 Hz 相位滞后 0.60°（DIRECT 为 12.86°）。**但边沿建立和残差这一项缓冲更差**，见下文。 |

**范围说明：**

- 恢复用的是数值设置的改变（每个节点加 10 aF 的最小对地电容），不是电路修复。
- 设置 C 在 REF 和 DIRECT 1 pF 上与旧的默认设置交叉比对过，差别不到 0.5%。但收敛成功本身不能证明波形物理正确。
- CMFB、偏置、时钟、Rfb 仍是理想元件，理想 CMFB 的功耗没有计入。
- 静态 stb 不能代替时变环路的稳定性证明。这里的"无漂移、无振荡"是对 60 ms 时域波形的观察结论。

日期 2026-11-16 · 任务书 [ECE203_round6d_chopper_tran_recovery_task.md](ECE203_round6d_chopper_tran_recovery_task.md) · 原 R6D 报告 [ECE203_round6d_mos_cd_buffer_results.md](ECE203_round6d_mos_cd_buffer_results.md)（未修改） · 脚本 `ece203_r6dr.il`、`tools/r6dr_watchdog.sh` · 数据 [ece203_data/round6dr/](ece203_data/round6dr/) · 图 `r6dr_stageB.png`

## 0. 复现信息

| 项目 | 内容 |
|---|---|
| 运行用的代码 | 服务器上 `/tmp/lix015_r6dr/AutoCircuit` 的浅克隆，运行时 `AC_SKIP_GIT_PULL=1`。probe 和 short 用 `a2d4da7`，full 用 `198ee05`（只改了 watchdog 写标记的顺序）。实际 commit 见 `raw/r6dr_run_commits.txt`。 |
| 为什么用 /tmp | 服务器 home 只剩约 12 MB，这样避免 `git pull` 把历史数据下载到 home。psf 和 CSV 都写在 `/tmp/lix015_r6dr/`，提取后删除 psf。 |
| PDK / corner / 温度 | IBM cmrf7sf，`allModels.scs` section `tt`；27 °C |
| 工具 | Virtuoso IC-618；Spectre 15.1.0.803.isr18（`spectre -h` 在该机器上无法运行：32 位包装缺 libelf，所以选项生效与否通过网表和 spectre.out 的回显来核实） |
| 共同设置 | reltol 1e-5，vabstol 1e-6，gmin 1e-18，默认积分方法（不用 gear2only），maxstep 0.5 µs；2 kHz 两相理想时钟，死区 10 ns；vd = 1 mV，fin = 100 Hz；R6D 原有的 cell，一字未改 |
| 命令 | `cd /tmp/lix015_r6dr && AC_SKIP_GIT_PULL=1 [AC_R6DR_SETTING=C] /tmp/lix015_r6dr/AutoCircuit/run.sh ece203_r6dr_probe / ece203_r6dr_short / ece203_r6dr_full` |

**电路一致性核对**（`raw/r6dr_netlist_check.txt`）：R6D-R 完整运行的网表，与 R6D Stage A 的网表在元件语句上完全相同，只差分析语句。`VSPS sinephase=0` 仍在。

## 1. 最小诊断：BUFFERED 1 pF，跑到 1 ms，每次只改一个数值参数

| 用例 | 唯一改动 | 结果 | 停在何处 / 最小步长 | Spectre 提示 |
|---|---|---|---|---|
| P_A | 无（R6D 原设置：默认积分，iabstol 1e-17，cmin 0） | **卡住**，180 s 后被 watchdog 结束 | t = 250 µs（第 1 个 TG 边沿），重复 20 次，步长 0.23 fs 量级 | `Found trapezoidal ringing on node XA.MT.s1`（5 次） |
| P_B | iabstol 1e-17 → **1e-15**（网表 `iabstol=1e-15`，spectre.out 回显 `iabstol = 1e-15`） | **卡住**，180 s 后被 watchdog 结束 | t = 250 µs，重复 19 次，0.23 fs | `XA.MT.s1`，另有 `XA.MT.ddb:int_a`、`XA.MT.dsb:int_a` |
| P_C | 撤回 B，只加 **tran cmin = 1e-17 F**（网表 `cmin=1e-17`，回显 `cmin = 10 aF`） | **跑完 1 ms**（3 个边沿），2648 个时间步，约 12 s | 最小步长没有塌缩 | `Found trapezoidal ringing on node XCO.MN4.g1`（TG 栅内部节点） |

- 原始文件：`raw/probe/`（三份 spectre.out、P_C 的 1 ms 波形）、`raw/watchdog.log`、`r6dr_numerical_settings.csv`。
- **watchdog 和状态标记的说明：** 两次卡住都是 watchdog 结束的，只结束本次运行的 Spectre（watchdog 按本次 psf 路径匹配进程）。`r6dr_probe.csv` 里 P_A/P_B 的状态写成 "failed"（t_end 0.25 ms），而不是 "stalled"：watchdog 在结束进程之后才写停滞标记，SKILL 先返回了。之后已修正写标记的顺序（`198ee05`）。真实情况以 watchdog.log 为准。
- **没有使用 Spectre 的 `diagnose` 选项：** 当前机器上无法运行 `spectre -h` 来核实语法，所以只照录了 spectre.out 的原文提示，没有推断根因。
- **cmin 可能带来的偏差：** 10 aF 加在每个节点对地。与电路里最小的相关电容相比：TG 1 pF 级负载、Cfb 0.5 pF、MOS 栅电容几十 fF，10 aF 小 3 个数量级以上，预计不会扭曲快沿毛刺。下面第 2 节的交叉比对支持这一点。

## 2. 短程一致性（1 ms）：设置 C 与旧默认设置 A 比对

判据在比较前定好：TG 边沿 ±2 µs 以外，(fp−fn)、fp/fn 共模、op/on 共模、vg 的最大差 < 0.1 mV；三个边沿的 op/on 共模尖峰相差 ≤ 10%。旧数据用 R6D 第 1 次（默认积分）的 REF 和 DIRECT 1 pF 前 1 ms。

| 比较 | (fp−fn) 最大差 | fp/fn 共模 | op/on 共模 | vg | op/on 边沿尖峰（250 / 500 / 750 µs）旧 / 新 | 判定 |
|---|---|---|---|---|---|---|
| REF：A 对 C | 0.014 mV | 0.0003 mV | 0.0003 mV | 0.0003 mV | 48.32 / 47.85，48.19 / 48.04，48.31 / 47.92 mV（≤ 1.0%） | 一致 |
| DIRECT 1 pF：A 对 C | 0.005 mV | 0.0012 mV | 0.0012 mV | 0.0012 mV | 45.45 / 45.17，45.29 / 45.01，45.28 / 45.10 mV（≤ 0.6%） | 一致 |
| BUFFERED 1 pF 对 REF（都是 C） | 0.026 mV | 0.0004 mV | 0.0004 mV | 0.0004 mV | 47.85 / 47.78，48.04 / 47.76，47.92 / 47.57 mV | CD 对原系统几乎没有影响 |

完整 60 ms 也做了 A 对 C 复核（`r6dr_full_C_vs_A.csv`，40–60 ms 窗口）：

- REF 增益 93.5064 → 93.5037（−0.003%）；残差 RMS +0.47%；op/on 尖峰 −0.6%；op/on 共模平均差 0.1 µV。
- DIRECT 1 pF 增益 −0.003%，其余指标差 < 3%。
- 只有 µV 级的 200 Hz 分量相对差到 13%（0.28 → 0.24 µV），绝对值可以忽略。

**结论：设置 C 在已知能收敛的用例上没有可见的数值敏感性，所以进入完整 Stage B。**

## 3. 完整 Stage B（设置 C，60 ms，5 个用例）

两个窗口（20–40 / 40–60 ms）的增益一致到 5 位有效数字（见 `r6dr_stageB_summary.csv`）。下表是 40–60 ms 窗口：

| 指标 | REF | DIRECT 1 pF | BUFFERED 1 pF | DIRECT 10 pF | BUFFERED 10 pF |
|---|---|---|---|---|---|
| Hpre = (fp−fn)/(ep−en)，100 Hz | 93.504 | 93.374 | 93.503 | **90.395**（−3.32%） | **93.503**（−0.001%） |
| Hpre 相位滞后 | 0.48° | 1.75° | 0.49° | **12.86°** | 0.49° |
| Hbuf = (bufp−bufn)/(ep−en) | — | — | 78.767 ∠0.50° | — | **78.762 ∠0.60°** |
| CD 局部增益 Hbuf/Hpre | — | — | 0.8424 ∠0.01° | — | 0.8424 ∠0.11° |
| 送到负载的差模峰峰值 | 0.1887 V | 0.1879 V | 0.1585 V | 0.1808 V | 0.1585 V |
| 送到负载的残差（拟合后 RMS）/ 占峰峰值 | 920 µV / 4.9% | 457 µV | 777 µV / 4.9% | **73 µV / 0.22%** | **722 µV / 4.9%** |
| 边沿最大误差 / 建立到 1% 的最长时间 | 9.86 mV / 30.4 µs | 2.30 mV / 30.5 µs | 5.35 mV / 30.7 µs | **0.20 mV / 0** | **3.91 mV / 33.8 µs** |
| H3（dBc） | −102.4 | −103.2 | −99.3 | −104.6 | −99.2 |
| fp/fn 共模平均 / 200 Hz | 0.900062 V / 0.24 µV | 0.900060 / 0.16 µV | 0.900062 / 0.29 µV | 0.900058 / 0.10 µV | 0.900062 / 0.29 µV |
| op/on 共模平均 / 200 Hz / 边沿尖峰 | 0.900147 V / 4.7 µV / 48.1 mV | 0.900142 / 4.6 / 45.2 | 0.900147 / 4.7 / 47.8 | 0.900141 / 4.4 / 44.9 | 0.900147 / 4.7 / 47.8 |
| 送到负载的共模平均 / 边沿尖峰 | 0.900062 V / 3.83 mV | 0.900060 / 0.98 mV | **0.542746 V** / 0.051 mV | 0.900058 / 0.12 mV | **0.542746 V** / 0.005 mV |
| buf 共模 200 Hz / 峰峰值 | — | — | 19.9 µV / 0.23 mV | — | 20.2 µV / 0.12 mV |
| bufp 范围 / sink 最小余量 | — | — | 0.503–0.582 V / 0.403 V | — | 0.503–0.582 V / 0.403 V |
| vg 范围 | 1.3238–1.3632 V | 1.3246–1.3609 | 1.3238–1.3630 | 1.3250–1.3607 | 1.3238–1.3630 |
| DRL 输出 drlr 平均 / 范围 | 0.901491 V / 0.8990–0.9046 | 0.901491 / 0.9002–0.9026 | 0.901491 / 0.8991–0.9044 | 0.901491 / 0.9006–0.9022 | 0.901491 / 0.8991–0.9044 |
| I(VDD) + I(VDDD)（独立的 1.8 V 电源；SKILL 时间积分平均） | 283.1 + 283.1 nA → 1.019 µW | 同左 | 493.4 + 283.1 nA → 1.398 µW | 1.019 µW | 1.398 µW |

- **相位符号：** 拟合给出的正值表示滞后。AC 里 DIRECT 10 pF 是 −13.25°，与这里的 12.86° 相符。
- **功耗：** 理想 CMFB 和理想时钟的栅极充放电功耗都没有计入。Python 按 1 µs 重采样的电流平均值会比上表高约 2 nA，因为采到了时钟边沿的尖峰电流，所以以 SKILL 积分值为准。

### 判定依据

**INTEGRATION PASS：**

- **共模：**
  - fp/fn 共模 0.900058–0.900062 V（±1 mV）；op/on 共模 0.90014 V。
  - vg 范围与 REF 相同，没有撞轨。
  - drlr 平均值 5 个用例相同。
- **增益与稳定：**
  - 接入 CD 后 Hpre 变化 −0.001%（< 5%）。
  - 两个窗口的增益、共模、vg 一致，没有漂移，没有持续振荡。
- **新增器件：**
  - CD 支路电流 2 × 105 nA。
  - sink 在整个摆幅内余量 ≥ 0.40 V，follower 的 VDS 约 1.2 V，没有削顶。
  - 局部增益 0.842，不反相，在 0.7–1.05 的建议范围内。
- **环路：** Stage A 静态 PM（CMFB 87.8–90.1°，DRL 90.25°）在 R6D 已通过。时域上 60 ms 没有出现异常。

**BUFFER VALUE PASS，仅限负载隔离（同 10 pF、同设置 C）：**

| 10 pF 负载 | DIRECT | BUFFERED | 谁更好 |
|---|---|---|---|
| 原核心节点 fp/fn 的增益（相对 REF） | −3.32% | −0.001% | **BUFFERED**：核心不受负载影响 |
| 送到负载的 100 Hz 相位滞后 | 12.86° | 0.60° | **BUFFERED** |
| 送到负载的 −3 dB 带宽（R6D Stage A，AC） | 423 Hz | 8.13 kHz | **BUFFERED**（静态辅助证据） |
| 送到负载的 100 Hz 增益 | 90.40 | 78.76 | DIRECT（follower 衰减 0.842） |
| 送到负载的残差 / 边沿误差 / 建立到 1% | 73 µV / 0.20 mV / 0 | 722 µV / 3.91 mV / 33.8 µs | **DIRECT** |
| 送到负载的共模 | 0.900 V | 0.543 V | DIRECT（BUFFERED 有 VGS 电平下移，是接口限制） |
| 总功耗（不含理想 CMFB） | 1.019 µW | 1.398 µW | DIRECT |

- **为什么 DIRECT 10 pF 的残差更小：** 10 pF 挂在 fp/fn 上，把闭环带宽压到约 423 Hz，等于对斩波边沿误差做了低通滤波。代价是 100 Hz 处相位滞后 12.9°、核心增益下降 3.3%，在 ECG 带宽（250 Hz）内也会衰减。
- **BUFFERED 的残差为什么大：** 缓冲器把核心节点本来就有的斩波边沿误差原样传了出来（REF 自身也有 920 µV，× 0.842 ≈ 775 µV），并没有新增。
- **结论：** 缓冲的价值确实存在，但只在**负载隔离**这一项（增益和相位不受负载影响，静态带宽保持 8 kHz）。
  - 在"建立/残差"这一项**不成立**。
  - 如果后级需要 0.9 V 共模，也不满足。

## 4. 运行量与问题记录

- **用例：** probe 3 个（A、B 卡住，C 成功）；short 3 个；full 5 个。共 11 次 tran，其中 2 次被 watchdog 结束。没有改电路、尺寸、偏置、负载、时钟或 CMFB。
- **配额：** 服务器 home 用量 5108/5120 MB，这一轮没有增加数据（只多了约 1 MB 日志，`.log.cds` 已删）。
  - 所有 psf 都在 /tmp，提取后删除。
  - 服务器上的 `~/AutoCircuit` 没有 pull，仍停在 `27bbbc6`。
- **进程：** 只结束了本任务 watchdog 匹配到的 Spectre 进程，没有动用户自己的进程。
- **新增文件：** `ece203_r6dr.il`；`batch/ece203_r6dr_{probe,short,full}.il`；`tools/r6dr_watchdog.sh`；`run.sh` 增加了 `AC_SKIP_GIT_PULL` 开关，默认行为不变。
- **没有修改：** 原 R6D 的脚本、cell、ADE state 和 raw 数据。
- **没有运行：** 真实 CMFB、第二级 CS、噪声、PVT、MC。

## 5. 数据

- **`docs/ece203_data/round6dr/`：**
  - `r6dr_numerical_settings.csv`：每次运行实际的 reltol / iabstol / gmin / tran 语句 / cmin 回显 / 最后时刻 / 最小步长 / 是否完成；
  - `r6dr_short_consistency.csv`、`r6dr_full_C_vs_A.csv`；
  - `r6dr_stageB_summary.csv`、`r6dr_ab_summary.csv`；
  - `r6dr_stageB.png`；
  - 脚本：`r6dr_analysis.py`（指标定义沿用 `round6d/r6d_analysis.py`）、`r6dr_consistency.py`、`r6dr_settings.py`、`r6dr_plots.py`。
- **`raw/`：**
  - `probe/`、`short/`、`full/`：完整分辨率 tran CSV（gzip）和 SHA-256（解压前），以及每次运行的 spectre.out.gz 和运行汇总 CSV；
  - `watchdog.log`、`r6dr_run_lines.txt`、`r6dr_run_commits.txt`、`r6dr_netlist_check.txt`。
- **没有提交的内容：** 网表（含 PDK 模型路径）和 psf。网表保存在实验记录本 `_raw\2026-11-16_ece203_round6dr_chopper_tran_recovery\`。
- **复算方法：** 在本目录下依次运行：
  - `python3 r6dr_analysis.py raw/full`
  - `python3 r6dr_consistency.py ../round6d/raw/stageB_attempt1_trap raw/short`
  - `python3 r6dr_plots.py raw/full`

  `r6dr_settings.py` 需要网表，所以只能在 `_raw` 里运行。

**本轮到此停止。** 没有进入真实 MOS CMFB、第二级 CS 或新的优化轮次。
