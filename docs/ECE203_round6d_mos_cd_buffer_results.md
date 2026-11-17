# ECE203 Round 6D 结果：真实 MOS 差分 CD 输出缓冲

**INTEGRATION：NOT PROVEN** — Stage A（TG 静止）所有静态条件 PASS；Stage B（2 kHz 斩波 60 ms tran）在 BUFFERED 用例的第一个 TG 边沿出现时间步塌缩，一次数值修正后仍失败，按任务书停止。斩波窗口统计这一项没有拿到。

**BUFFER VALUE：NOT PROVEN** — 瞬态对比没有完成。只有静态 AC 证据（10 pF 下，DIRECT 闭环 −3 dB 带宽 423 Hz，BUFFERED 8.1 kHz），不能代替任务书要求的建立和失真对比。

日期 2026-11-16 · 任务书 [ECE203_round6d_mos_cd_buffer_task.md](ECE203_round6d_mos_cd_buffer_task.md) · 脚本 `ece203_r6d.il` · 数据 [ece203_data/round6d/](ece203_data/round6d/) · 图 `r6d_stageA.png`

## 0. 复现信息

| 项目 | 内容 |
|---|---|
| 代码 commit | 建 cell 和 Stage A 第一次：`ca8f816`；Stage A 正式运行和 Stage B 第 1 次（trap）：`f4c8416`；Stage B 第 2 次（gear2only）：`27bbbc6`；报告：本报告所在 commit |
| PDK / corner / 温度 | IBM cmrf7sf，`allModels.scs` section `tt`；27 °C |
| 工具 | Virtuoso IC-618，Spectre 15.1.0.803.isr18；ieng6-ece-10，OCEAN 批处理 |
| Spectre 选项 | reltol 1e-5，vabstol 1e-6，iabstol 1e-17，gmin 1e-18（与 R6B/R6C 相同） |
| 分析 | dc；ac 1 mHz–100 kHz（20 点/十倍频）；stb 1 mHz–100 MHz，探针 `/IPRC`（CMFB）和 `/IPRD`（DRL）；tran 60 ms，maxstep 0.5 µs |
| 运行顺序 | `run.sh ece203_r6d_build_ref` → `_build_direct` → `_build_buf`（每个测试台在独立的 Virtuoso 会话里建）→ `ece203_r6d_a` → `ece203_r6d_b` → `ece203_r6d_ade` |

## 1. 实验设置

- **基线：** `Project/ece203_r6c_tb_ideal`，没有修改。R6D 的三个测试台由同一份 R6C-I 理想元件列表生成，包括 `VSPS sinephase 0` 的修复。
- **网表核对**（`raw/r6d_netlist_check.txt`，只比较元件语句）：
  - `ece203_r6d_tb_ref` 与 R6C-I 的理想测试台元件完全相同。
  - DIRECT 只多了 `CLDP/CLDN (fp/fn → 0) c=cld`。
  - BUFFERED 只多了 XCD（4 只 MOS）和 `CLBP/CLBN (bufp/bufn → 0) c=clb`。
- **CD cell `Project/ece203_r6d_cd`：**
  - follower：MSP/MSN 为 `nfetx` 6u/1u，D = VDD，G = fp/fn，S = bufp/bufn，B = GND。
  - sink：MKP/MKN 为 `nfetx` 4u/4u，D = buf，G = 现有 `ib`（OTA 内部 MREF 2u/4u 的二极管节点，参考电流 50 nA），S/B = GND。
- **CD 只接在 fp/fn 上：** 原来的 Cfb/Rfb、CMFB 对 op/on 的检测、DRL、时钟和 OTA 都没有改。尺寸和偏置修正一次都没有用。
- **其余理想部分（照实标注）：** VREF/VCAS/IB/IBD 偏置、两相时钟、Rfb、R6C-I 理想 CMFB（功耗没有计入）。
- **建 cell 的方式：** 每个测试台单独开一个 Virtuoso 会话来建。R6C 发现过 analogLib 实例会沿用会话里上一个同类实例的参数，三个测试台里都有带 max/min 的 vcvs（ELM），放在同一会话里可能把 max/min 带进后面测试台的其它 vcvs。

## 2. Stage A：TG 静止在 A 相 — 全部静态条件 PASS

| 指标 | REF | DIRECT 1 pF | BUFFERED 1 pF | DIRECT 10 pF | BUFFERED 10 pF |
|---|---|---|---|---|---|
| fp/fn 共模 | 0.900059 V | 0.900059 | 0.900059 | 0.900059 | 0.900059 |
| op/on 共模 / VCMFB | 0.900059 / 1.32506 V | 同左 | 同左 | 同左 | 同左 |
| bufp/bufn 共模 | — | — | **0.5427 V** | — | **0.5427 V** |
| Hpre(100 Hz) = (fp−fn)/(ep−en) | 94.533 ∠−0.63° | 94.486 ∠−1.92° | 94.533 ∠−0.64° | **92.023 ∠−13.25°** | 94.533 ∠−0.64° |
| Hpre 相对 REF | 0 | −0.05% | −0.0002% | −2.66% | −0.0002% |
| Hpre −3 dB 带宽 | 8.45 kHz | 2.92 kHz | 8.32 kHz | **423 Hz** | 8.32 kHz |
| Hbuf(100 Hz) = (bufp−bufn)/(ep−en) | — | — | 79.643 ∠−0.65° | — | 79.643 ∠−0.75° |
| Hbuf −3 dB 带宽 | — | — | 8.31 kHz | — | 8.13 kHz |
| 局部 A_CD = (bufp−bufn)/(fp−fn)：100 Hz / 1 kHz / 10 kHz | — | — | 0.8425 ∠−0.01° / 0.8425 / 0.8423 | — | 0.8425 ∠−0.11° / 0.8423 / 0.8276 |
| CMRR @60 Hz（Cc 失配 1%）：fp/fn 端 / buf 端 | 108.62 dB | 108.62 | 108.62 / 108.62 | 108.62 | 108.62 / 108.62 |
| CMFB 环路 UGF / PM | 546 kHz / 87.78° | 187 kHz / 89.35° | 535 kHz / 88.04° | 27.1 kHz / 90.10° | 535 kHz / 87.85° |
| DRL 环路 UGF / PM | 1984 Hz / 90.25° | 同左 | 同左 | 同左 | 同左 |
| I(VDD) + I(VDDD) | 283.1 + 283.1 nA | 同左 | 493.4 + 283.1 nA | 同左 | 493.4 + 283.1 nA |
| 总功耗（不含理想 CMFB） | 1.019 µW | 1.019 | 1.398 µW | 1.019 | 1.398 µW |
| OTA 最紧余量 | M1 0.092 V | 同左 | 同左 | 同左 | 同左 |

**新增 4 只 MOS 的工作点（1 pF 和 10 pF 相同）：**

| 器件 | Id | gm | VGS | VDS | VDSAT | 饱和余量 |
|---|---|---|---|---|---|---|
| MSP / MSN（follower） | 105.1 nA | 2.78 µS | 0.357 V | 1.257 V | 0.044 V | **1.157 V** |
| MKP / MKN（sink） | 105.1 nA | — | 0.309 V | 0.543 V | 0.050 V | **0.443 V** |

**各项判定：**

- **REF 复现 R6C-I：** 94.533 / 0.900059 V / UGF 546 kHz、PM 87.78° / DRL PM 90.25°，与 R6C-I 在报告精度内一致。
- **fp/fn 共模：** 所有用例都是 0.900059 V（目标 ±1 mV 内）。CD 栅极负载没有影响 CMFB，也没有影响 Hpre（−0.0002%）。
- **CD 支路：**
  - sink 电流 105.1 nA。这是仿真值，不是按几何比推算的，对应镜像比 2.10（几何比 2）。
  - 4 只管都在饱和区，余量 ≥ 0.44 V。
  - follower 在 100 Hz 不反相，增益 0.8425，在 0.7–1.05 的建议范围内，是 NMOS 体效应造成的衰减。
- **CD 输出共模下移（CD OUT CM SHIFT），不是 CMFB 失效：**
  - bufp/bufn 共模 = 0.900 − VGS(0.357) = 0.543 V，这是 NMOS follower 固有的电平下移。原 fp/fn 共模仍然是 0.900059 V。
  - 如果后级要求输入共模 0.9 V，这个结构做不到。本轮没有加电平搬移，这是接口上的限制。
- **两个环路：** CMFB PM ≥ 87.8°，DRL PM 90.25°，都 ≥ 55°。
  - DIRECT 10 pF 让 CMFB 的 UGF 降到 27 kHz，因为 fp/fn 经 TG 挂在 op/on 上，多了共模电容。PM 反而升高，没有出现新的高频问题。
  - stb 是在 TG 静止 A 相下测的，**不能当作斩波时变系统的稳定性证明**。
- **功耗：**
  - 在这个 R6 测试台里，VDDD 是独立的 1.8 V 电源（网表 `VDDD (vddd 0) vsource dc=vdd`），给 DRL OTA 供电，不是串在 VDD 上的 0 V 电流表。所以总电流 = I(VDD) + I(VDDD)。
  - 任务书中"I(VDDD) 已计入 VDD"的说法适用于 R4/R5 的真实偏置测试台，不适用于 R6。
  - CD 增加 210.3 nA（两路 sink 各 105.1 nA），总功耗 1.019 → 1.398 µW。理想 CMFB 的功耗没有计入。

## 3. Stage B：2 kHz 斩波 tran — 被仿真器卡住（BLOCKED）

| 尝试 | 设置 | REF | DIRECT 1 pF | BUFFERED 1 pF | DIRECT 10 pF / BUFFERED 10 pF |
|---|---|---|---|---|---|
| 第 1 次（`f4c8416`） | 默认 trapezoidal 积分 | 完成，169 088 行 | 完成，166 052 行 | **卡住**：t = 250 µs（第一个 TG 边沿），时间步约 40–460 as，持续 5 分钟以上没有前进。Spectre 提示 `Found trapezoidal ringing on node XA.MT.s1`（5 次） | 没有运行（任务被我终止） |
| 第 2 次（`27bbbc6`，唯一一次数值修正：`method=gear2only`，5 个用例统一） | gear2only | **卡住**：同样在 t = 250 µs，时间步约 160–320 as，约 4 分钟没有前进 | 没有运行 | 没有运行 | 没有运行 |

- **根因：没有找到。**
  - 第 1 次的提示指向 OTA 尾管 MT 内部源极节点的 trapezoidal ringing，所以第 2 次换成 gear2only 积分方法。
  - 但 gear2only 连原本能跑完的 REF 也卡在同一个边沿，说明不是简单的积分方法问题。
  - 第一个 TG 边沿处的牛顿迭代 / 时间步控制在当前严格容差（iabstol 1e-17）下很脆弱，加上 CD 以后就跑不过去。这只是推测，没有验证。
  - 按任务书"一次根因修正后仍失败也 STOP"，本轮停止。
- **两次卡住的仿真都是我自己终止的**（本任务自己的 Virtuoso 和 spectre 进程），用户自己的进程没有动。
  - 第 2 次的 spectre.out 摘录：`raw/stageB_attempt2_gear2only/B_ref_spectre_out_excerpt.txt`。
  - 第 1 次 BUFFERED 1 pF 卡住时的 spectre.out，在第 2 次启动前被我清理 /tmp 时删掉了。上面的提示信息是删除前从服务器上读到的。

**第 1 次（trapezoidal）完成的两个用例**（`raw/stageB_attempt1_trap/`，完整分辨率 gzip，带 SHA-256）：

| 指标（20–40 ms / 40–60 ms 两窗一致） | REF | DIRECT 1 pF |
|---|---|---|
| Hpre(100 Hz)，正弦拟合 | 93.5064 ∠0.48° | 93.3771 ∠1.75° |
| op/on 共模平均 / 200 Hz 分量 | 0.900148 V / 4.79 µV | 0.900142 V / 4.42 µV |
| fp/fn 共模平均 / 200 Hz 分量 | 0.900062 V / 0.35 µV | 0.900060 V / 0.15 µV |
| op/on 边沿共模尖峰 | 48.4 mV | 45.5 mV |
| fp/fn 边沿共模尖峰 | 3.8 mV | 1.0 mV |
| Vpre 拟合残差（RMS）/ 边沿最大误差 | 916 µV / 9.8 mV | 455 µV / 2.3 mV |
| 边沿后误差进入 1% 以内（最大） | 30.4 µs | 30.4 µs |

- REF 与 R6C-I 的 C_ideal 一致（93.506，0.900148 V，4.75–4.79 µV，48.4 mV），说明 R6D 的 REF 测试台在斩波下也复现了基线。
- 这两个用例都不含 CD，所以不能用来判断 BUFFER VALUE。

## 4. 10 pF 时缓冲有没有价值（只有静态证据）

| 10 pF 负载、TG 静止 | DIRECT（直接挂在 fp/fn） | BUFFERED（挂在 bufp/bufn） |
|---|---|---|
| 送到负载的 100 Hz 增益 | 92.02 ∠−13.25° | 79.64 ∠−0.75° |
| 送到负载的 −3 dB 带宽 | 423 Hz | 8.13 kHz |
| 送到负载的 1 kHz 增益 | 36.8 | 约 79.1（= Hpre 93.87 × A_CD 0.8423） |
| 原系统 Hpre(100 Hz) 相对 REF | −2.66% | −0.0002% |

- **增益：** BUFFERED 在 100 Hz 的增益更低（follower 只有 0.84 倍），这一项 DIRECT 更好。
- **带宽：** 10 pF 直接挂在 OTA 输出上，把闭环带宽压到 423 Hz（ECG 带宽 250 Hz 的边缘），100 Hz 处多出约 13° 相移。BUFFERED 时原系统完全不受影响，带宽 8.1 kHz。
- **斩波下的推测（未验证）：** 2 kHz 斩波每 250 µs 翻转一次输出，DIRECT 10 pF 的建立预计会明显变差。但这项瞬态没有跑出来，**BUFFER VALUE 仍为 NOT PROVEN**。

## 5. 运行量与问题记录

- **主要用例：**
  - Stage A：5 个（每个含 DM AC、CM AC、2 次 stb）；
  - Stage B：第 1 次完成 2 个、卡住 1 个；第 2 次卡住 1 个；
  - 建 cell 3 次，ADE 1 次。
- **Stage A 第一次运行因磁盘配额满而失败**（DIRECT 10 pF 和 BUFFERED 10 pF 的 `close: Disk quota exceeded`）。
  - 原因：服务器上 run.sh 每次会 `git pull`，把 R6C 推上去的数据（约 35 MB，含 git 对象）下载到了 home，配额从约 53 MB 降到 0。
  - 处理：只删除了本轮 Stage A 可重建的 psf；之后每个用例做完立刻删掉自己的 psf，Stage B 的 psf 和 CSV 改写到服务器 `/tmp`（不占 home 配额）。
  - 失败那次的数据保留在 `_raw\...\r6d_a.tgz` 的 `aborted_stageA_quota/`。
- **服务器配额目前仍只剩约 12 MB。** 之后 run.sh 每次 `git pull` 还会把新推送的数据下载到 home。建议由你决定是否给服务器上的 `~/AutoCircuit` 设置 sparse-checkout，跳过 `docs/ece203_data/`；我没有改。
- **Cadence：**
  - 新 cell：`Project/ece203_r6d_cd`、`ece203_r6d_tb_ref`、`ece203_r6d_tb_direct`、`ece203_r6d_tb_buf`；
  - ADE state：`r6d_ref_phaseA`、`r6d_direct_10p_phaseA`、`r6d_buf_10p_phaseA`（dc / ac / CMFB stb，10 pF 负载）；
  - R4–R6C 的 cell、ADE state 和数据都没有修改。
- **没有运行：** 第二级 CS、真实 CMFB、SC-CMFB、RRL、噪声、PVT、MC。

## 6. 数据

- **`docs/ece203_data/round6d/`：**
  - `r6d_stageA_summary.csv`、`r6d_stageB_summary.csv`（只有第 1 次完成的 REF 和 DIRECT 1 pF）；
  - `r6d_analysis.py`、`r6d_plots.py`、`r6d_netlist_check.py`；
  - `r6d_stageA.png`。
- **`raw/`：**
  - Stage A 的 `A_*_dm_ac.csv`、`A_*_dcop.csv`、`A_*_stb_{cmfb,drl}.csv`、`r6d_stageA.csv`、`stageA_run_lines.txt`、`r6d_netlist_check.txt`；
  - `stageB_attempt1_trap/`：B_ref、B_direct_1p 的完整分辨率 tran（gzip）和 SHA-256，以及 spectre.out 尾部、运行行；
  - `stageB_attempt2_gear2only/`：spectre.out 摘录。
- **实验记录本 `_raw\2026-11-16_ece203_round6d_cd_buffer\`：** 完整网表、日志，以及失败尝试的全部文件。
- **复现：** 先在 `docs/ece203_data/round6d/` 下运行 `python3 r6d_analysis.py raw raw/stageB_attempt1_trap && python3 r6d_plots.py raw`，再核对 `r6d_stageA_summary.csv` 与本报告的表格是否一致。

**本轮到此停止。** 继续推进 Stage B 需要你决定换哪种数值设置，例如：

- tran 加 `cmin`（如 1e-17 F）给无电容的内部节点；
- 只在斩波 tran 中把 iabstol 放宽到 1e-15；
- 改用 errpreset conservative。
