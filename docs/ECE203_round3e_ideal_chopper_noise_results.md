# ECE203 Round 3E 结果：1 MHz 理想 Chopper 的噪声抑制数字

日期 2026-11-16 · 任务书 [ECE203_round3e_ideal_chopper_noise_demo.md](ECE203_round3e_ideal_chopper_noise_demo.md) · 数据 [ece203_data/chopper_noise/](ece203_data/chopper_noise/)

**一句话：** 用"无限带宽 + Round 3C C OTA 实测噪声谱"的带噪理想 OTA 做 Spectre PSS + PNoise。斩波后，0.1–250 Hz 差分输入参考噪声从 **15.85 µVrms 降到 2.01 µVrms**（应用型定义）：RMS 降 **7.9 倍**，功率降 **62 倍**，**低于 3 µVrms**。**这是理想模型的上限估算**：时钟、开关、反相器都是理想元件，OTA 带宽无限。它**不代表真实 C OTA**（Round 3D 已经表明真实 C 跟不上 1 MHz）。

## 结果
| 情况 | 方法 / 证据等级 | PAC 增益 @100 Hz | 输出 rms 0.1–250 Hz | **输入参考：应用型** = out_rms / \|Hdm(100 Hz)\| | 输入参考：逐点 de-embed 型 | RMS / 功率改善 |
|---|---|---|---|---|---|---|
| U：不斩波（时钟冻结） | Spectre 普通 noise | 99.90 | 1.584 mV | 15.85 µV | 16.27 µV | — |
| U：不斩波 | **Spectre PSS + PNoise** | 99.90 | 1.584 mV | **15.85 µV** | 16.28 µV | — |
| C：1 MHz 斩波 | **Spectre PSS + PNoise** | 99.90 | 0.200 mV | **2.01 µV** | 2.07 µV | **7.9× / 62×** |
| C：解析折叠，白噪声底 ×1.0 | 模型计算（不是 Spectre），只算 OTA | — | — | 1.72 µV | — | 9.4× / 87× |
| C：解析，白噪声底 ×0.5 / ×1.5 | 灵敏度（模型） | — | — | 1.22 / 2.10 µV | — | 13.2× / 7.7× |

- **斩波后的谱：** 10 Hz 以上就是白噪声底，约 112 nV/√Hz，与拟合的 109 nV/√Hz 加上折叠后的 1/f 残余（约 4 nV/√Hz）吻合。在 1 / 10 / 100 Hz 处分别为 364 / 121 / 112 nV/√Hz。
- **低频上翘：** 5 Hz 以下的上翘来自未被斩波的反馈电阻 Rfb（3.18 TΩ）的热噪声，因为 Rfb 在 chopper 外面。U 的 NoiseSummary 中 Rfb 占 0.34%，折算到输入约 0.92 µV。
- **两种结果的差别：** Spectre 的 2.01 µV 和解析的 1.72 µV 之间的差，主要就是这部分 Rfb 噪声：√(1.72² + 0.92²) ≈ 1.95 µV。
- **带内增益不变：** 斩波前后 PAC 增益都是 99.90，所以输入参考噪声是在**相同信号增益**下比较的。

## 模型（`Project/ece203_ss_chop_noise_tb`，job `ece203_ss_chop_noise`）
- **测试台：** 沿用 Round 3D 已验证的理想 chopper：1 MHz 两相不交叠时钟（10 ns 死区），开关为 relay，rc 1 Ω、ro 1e20 Ω。理想反相器 EINV 是非物理辅助块。反馈从解调后的 o 接回。S2 网络（Cc 50 p，Cfb 0.5 p，Rfb 3.1831 T）不变。仿真精度 gmin = iabstol = 1e-18。
- **OTA：** VCVS，aol 1e5，无带宽限制。在它的 (+) 输入端（输入 chopper 之后、放大之前）串一个 0 V 的 vsource `VN`，用 `noisefile` 实现噪声谱 S_e(f) = K/f^α + S_w：
  - K = 3.451e-11，α = 1.038，S_w = 1.188e-14 V²/Hz（109 nV/√Hz）。
  - 这是对 Round 3C C 的 `c_noise.csv` 中 de-embed 输入噪声谱，在 1 Hz–100 kHz 做的拟合，见 `noise_model_fit.csv`。
  - 各检查点偏差：1 / 10 / 100 Hz / 1 k / 10 k / 100 kHz 处为 −4.2 / +1.5 / +1.3 / −1.7 / −0.3 / +1.8%；0.1 Hz 处 −15.8%，那里主要是 Rfb 噪声，测试台里另有真实 Rfb。
  - **100 kHz 以上没有实测数据**，表格一直外推到 100 MHz。
- **噪声源确实生效：** U 的输入参考噪声在 1 / 10 / 100 Hz 处为 5.94 / 1.80 / 0.555 µV/√Hz，模型值为 5.88 / 1.78 / 0.549。NoiseSummary 中 VN 占 99.67%。U 整体为 16.28 µV，Round 3C 实测为 16.6 µV，相差 −2%。
- **Spectre 分析设置：** `pss fund=1M harms=50 errpreset=moderate`；`pac` 和 `pnoise` 都用 `sweeptype=relative relharmnum=0`，频率 0.1–250 Hz、每十倍频 20 点，pnoise 的 `maxsideband=49`。
  - **noisetype：** 网表里没有写 noisetype，用的是 Spectre pnoise 的默认值。我的理解是这个默认值是 timeaverage，即时间平均、连续时间输出，不是 sampled 噪声，但这一点**没有在本机核实**。
  - **边带截断：** 只算到 ±49 个边带，解析计算表明此时白噪声折叠权重为 0.992；49 MHz 以上的折叠被截掉（约 0.8%）。
  - **"理想 250 Hz LP"：** 实现方式是只在 0.1–250 Hz 内积分（理想砖墙），U 和 C 完全相同。
  - PSS 在两种情况下都收敛了。
- **解析交叉检查：** 单边谱约定 S_on(f) = Σ_{k 奇数, ±} (4/π²k²) S_e(|f − k·1 MHz|)，取 k 到 ±49。自检：k ≤ 7 时白噪声总权重为 0.950，k ≤ 49 时为 0.992，趋向 1。数据见 `analytic_folding_estimate.csv` 和 `analytic_folding_psd.csv`。

## 修复记录（本轮唯一一次定向修复）
第 1 次运行三个 case 都在 Spectre 网表阶段报错：
- VINN 的 PAC 幅度写成了 −0.5，而 `pacmag` 必须 ≥0；改为 0.5 加 180° 相位。
- 两个时钟源意外继承了 `pacmag = −0.5`；改为显式写 0。
- analogLib vdc 的 F/N 噪声频点对在批处理下没有写进网表；改用 `noisefile`。

第 2 次运行全部通过。

## 不能据此声称的
- **不代表真实 OTA：** 这不是真实 OTA 的结果。真实 C 的闭环带宽只有 8.8 kHz，在 1 MHz 下连信号都处理不了（Round 3D）。
- **开关和时钟是理想的：** 没有电荷注入、残余失调、纹波，也没有开关和时钟的噪声。
- **理想 VCVS 不能作证据：** 无噪声的理想 VCVS 本身不能说明降噪；这里的降噪来自加进去的、经过校准的噪声谱。
- **改善倍数取决于白噪声底：** 斩波后的结果几乎完全由白噪声底（实测到 100 kHz，以上为外推）决定，所以改善倍数对它很敏感。白噪声底 ±50% 时，OTA 部分为 1.2–2.1 µV。

## Cadence 里新建的东西
- cell：`ece203_ss_chop_noise_tb`。变量 `chen` 控制是否斩波；噪声表文件由 job 生成。
- job：`ece203_ss_chop_noise`。
- 旧 cell 没有改动。Round 4 没有启动。
