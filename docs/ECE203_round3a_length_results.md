# ECE203 Round 3A 结果：5T 输入对沟道长度四点扫描（S2 单级 BioAmp）

日期 2026-11-16 · 任务书 [ECE203_round3a_5t_input_length_scan.md](ECE203_round3a_5t_input_length_scan.md) · 数据 [ece203_data/single_stage_length/length_scan.csv](ece203_data/single_stage_length/length_scan.csv)

**改动只有一处：** M1/M2 的 L 改为 1/2/4/8 µm，W 保持 10 µm。其余全部冻结：其它管子尺寸、ib3 = 50 nA、S2 网络（Cc 50 p，Cfb 0.5 p，Rfb 3.1831 T）、CL = 0、VDD 1.8 V、VREF 0.9 V、差分 AC ±0.5 V。只跑了 DC op 和 AC。
**新 cell：**
- `Project/ece203_ss_lscan_ota`：拓扑与 `ece203_a3_ota` 相同，M1/M2 的 L 是设计变量 `lin`。
- `Project/ece203_ss_lscan_tb`：S2 闭环。
- `Project/ece203_ss_lscan_ol_tb`：开环 A0 测试。
- 两个 tb 各存了 ADE state `lscan_L1u/L2u/L4u/L8u`（dc op + ac）。
- 旧 cell 没有改动。

**核对：** 四个网表里 `lin` 分别为 1e-06、2e-06、4e-06、8e-06，M1/M2 都是 `l=lin w=10u`。实例为 `XA (0 ib n p oa vdd) ece203_ss_lscan_ota`，极性和 Round 3 一样。四个点的 DC 都正常，o = n ≈ 0.90 V。

**A0 的测量方法：** “实际 A0”来自独立的开环 tb。这个 tb 在 DC 是跟随器：VINP 为 0.9 V 加 1 V AC，OUT 经 1 TΩ 接回 INN，INN 再接 1 F 到地。读 |V(out)| 在 10 Hz 的值，1 Hz 读数相同。表中还单独列了**近似 A0 = gm1/(gds2+gds4)**，取自闭环 S2 的 OP，两种结果不要混用。

| L (µm) | 闭环 \|Hdm(100 Hz)\| | dB | **实际 A0**（开环 AC） | 近似 A0（gm/gds） | 100·A0/(A0+101) | gm1 (µS) | gds2 / gds4 (nS) | Id1 (nA) | gm/Id | region M1/M2 | 最小 margin（不含 MREF） | I_VDD / P |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 41.19 | 32.30 | 71.1 (37.0 dB) | 71.1 | 41.3 | 3.14 | 42.6 / 1.59 | 116.8 | 26.9 | 3/3 | 0.251 (M2) | 284.4 nA / 0.512 µW |
| 2 | 51.31 | 34.20 | 107.2 (40.6 dB) | 107.1 | 51.5 | 2.99 | 26.4 / 1.59 | 116.7 | 25.6 | 3/3 | 0.256 (M2) | 284.2 nA / 0.512 µW |
| 4 | 62.82 | 35.96 | 172.7 (44.7 dB) | 172.2 | 63.1 | 2.84 | 14.9 / 1.59 | 116.5 | 24.4 | 3/3 | 0.270 (M2) | 283.7 nA / 0.511 µW |
| 8 | **73.12** | **37.28** | **280.4 (49.0 dB)** | 279.5 | 73.5 | 2.69 | 8.03 / 1.59 | 116.2 | 23.1 | 3/3 | 0.291 (M2) | 283.1 nA / 0.510 µW |

补充说明：
- 把 MREF 算进去时，四个点的最小 margin 都是 0.209 V，出现在 MREF 上。MREF 是二极管接法，Vds = Vgs = 0.309 V，而 margin 按 max(Vdsat, 0.1 V) 计算。
- M3/M4 处于饱和区（region 2）；M1/M2/MT 处于亚阈值（region 3）。
- 每个点用一行关系式 100·A0/(A0+101) 交叉检查，与仿真闭环值相差不到 0.6%。

**结论：** 在这四个点内，L 加长到 8 µm 时实际 A0 为 280，闭环为 73.1（37.3 dB），**仍未达到 38 dB（79.4）的最低门槛**，四个点全部未达标。到 L = 8 µm 时，gds2 已降到 8.0 nS，但 gds4（1.59 nS，M3/M4 尺寸未动）保持不变。按扫描设定，任务开头已说明的混杂因素仍然存在：固定 W 扫 L 会同时改变 W/L 和反型程度，gm/Id 从 26.9 降到 23.1。

**等待用户 + GPT 决定的下一步：** 是否继续加长 L（超出本轮的四个点），改动 M3/M4 或偏置电流，还是换拓扑。本轮已经停止，没有做任何额外扫描。
