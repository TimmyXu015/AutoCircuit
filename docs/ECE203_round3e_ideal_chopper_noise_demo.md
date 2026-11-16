# ECE203 Round 3E — 1 MHz 理想 Chopper：**直接展示噪声抑制数字**（短实验）

**用户明确纠错（2026-11-16）：** Round3D 只测了 1 MHz 信号带宽，**没测试 Chopper 能降多少噪声，错过真正目标**。本轮只为回答一个问题：**理想无噪声时钟/开关 + 无限带宽的带噪 OTA，Chopper OFF vs ON 的 0.1–250 Hz 差分输入参考噪声各是多少？** 禁止 Round4 整机、真实 OTA 带宽阻止本轮、真实 MOS switch、扫频、额外 OTA、优化与偏置研究。

## 实验依据：现有真实数据，不造噪声

先读 `docs/ECE203_round3d_ideal_chopper_results.md`, `docs/ECE203_round3c_ota_compare_results.md`, `docs/ece203_data/ota_compare/c_noise.csv`, `docs/ece203_data/ota_compare/c_noisesummary_0p1_250.txt` 与 `ece203_ss_chop.il`，以及 `CLAUDE.md`, `docs/automation_playbook.json`。

- 已验证 chopper：1MHz 两相不交叠 `relay`，10ns deadtime，理想 VCVS 1e5 无带宽限制，短窗 signal gain 99.89，反馈在输出解调节点；**保留既有理想 Chopper 架构**。真实 C OTA 因 fH 8.8kHz 跟不上，与本轮“假设 OTA 无限快”的噪声上限**无关，不要重跑真实 C**。
- Round3C 真实 C 的 **0.1–250Hz** 原输入参考噪声约 **16.1µVrms（output_rms / midband |Hdm|）**，**逐频率 de-embed** 为 **16.6µVrms**；在 100kHz 的输入参考噪声密度约 **108 nV/√Hz**，说明白噪声底约 **1.7µVrms / 250Hz**。这个数字只是基准参考，**不等于已验证的 chopped noise**。
- 现有 `c_noise.csv` 频率只到 **100kHz**，**没有测到 1MHz**！超过实测上限要从拟合白噪声与 flicker PSD 延拓，并明确属于模型假设。原 C 电路带宽有限，不可不加说明地把它 100kHz 输出噪声当作 1MHz 真实器件噪声。

## 核心测试（只 2 个 cases）

**模型：** 复制 `ece203_ss_chop_ideal_tb` 为隔离新测试 cell/job；将无噪声 ideal VCVS 转换为**无限带宽、相同线性开环增益 1e5 的「带噪声理想 OTA」**。仅让 OTA **内部**具有等效输入噪声 `S_e(f)=K/f^alpha + S_white`，在**输入 Chopper 之后 / 放大之前**注入等效差分零均值噪声（例如经验证的 Verilog-A `flicker_noise` + `white_noise` 合法建模），确保在输出解调前它不随信号一起被预调制；不要在外部电极信号源注入这份噪声，因为那样不会被 Chopper 消除。模型参数**拟合 Round3C 实测 `c_noise.csv` 的 de-embed 输入参考密度**，至少核对 1Hz/10Hz/100Hz/10kHz/100kHz 与 0.1–250Hz 积分；白噪声不可凭空设为0。静态无斩波 case 应能复现 **~16.6µVrms（允许约 15% 拟合误差，但须逐点披露偏差）**。可用一组等效 noise sources 代表整个 OTA 的输入对+镜像贡献；不是声称真实 OTA 在 1MHz 有同样增益。
- **U（unchopped）**：时钟关闭/交换不进行，完全相同 noisy-VCVS、反馈和输出测量点、理想 250Hz 低通、Rfb/Cc/Cfb。确保增益带内约100×，测 0.1–250 Hz 输出噪声以及正确折算的差模 input noise。
- **C（chopped）**：打开已经验证的 **1MHz ideal clock/switch**，开环/白+1/f 噪声模型及整个反馈/LP 完全相同。经输出解调再通过与 U **同样的理想 250Hz LP** 后提取输出噪声 PSD；计算 integrated output RMS 与 input-referred RMS（**不要拿不同 signal gain 的输出噪声直接比**）。

**注意：** 系统是周期时变的，必须用 Spectre **PSS + time-averaged PNoise**（正确 baseband sidebands 和 continuous-time 输出）或另一个严谨可复核的 **周期频谱 folding** 方法，**普通 AC/noise 只适用于 U，不能冒充 C 的噪声**。优先尝试 PSS/PNoise **一套配置，最多一次定向修复**；要检查模型 `flicker_noise/white_noise` 在该分析中真实生效，给出 sideband 截断与结果是否收敛的说明，避免断言“全局 0 噪声”。PSS 若被 3.18TΩ 的长时间常数阻碍，**不要跑很多秒 1MHz tran**，可使用 analytically known periodic initial conditions/稳态 PSS 合理方式，仍不行即停。

### 保障必有一个定量结果的轻量 fallback（不可以当作 Spectre 测量）

若 Spectre behavioral noise 或 PSS/PNoise **无法在这一短实验的限额内成功**，用 Round3C 已测噪声 `c_noise.csv` 的**拟合白噪声 + 1/f 模型**计算理想方波混频后基带 PSD：
`S_on(f) = sum_{k odd, k=±1,±3,...} (4/(pi^2 k^2)) S_e(|f-k*1MHz|)`（**双边 PSD 约定、系数归一化要严格自检：对白噪声总权重=1**），并与 `S_off(f)=S_e(f)` 在 0.1–250Hz 积分比较。**至少 k=±1、±3、±5、±7**，清楚注明 100kHz–7MHz 的**未测得外推**。加一个保守的 `±50% white floor PSD` 灵敏度范围（只作解析不增加 Spectre sweep），避免把 1.7µV 当确定值。要同时报告 `RMS` 和 `Noise Power` 改善；不要用“消除98.6%功率”直接充当 RMS 降幅。
- 解析估算必须标为 **“基于实测 PSD 的理想模型计算，不是 Spectre Chopper Noise”**。哪怕 Periodic Noise 失败也要提供一张简表及两条 PSD 曲线、确切来源数据和公式，**让用户真正看到噪声抑制有多大**。

## 交付（短、即时、只回答本题）

- `docs/ECE203_round3e_ideal_chopper_noise_results.md` 一页中文：U vs C，**输入参考 0.1–250Hz noise（µVrms）、改善倍数、功率/PSD改善、是否 <3µVrms、证据等级（Spectre PNoise / 模型预测）**；如果仅模型推导，要明确无法确认真实 OTA 性能。1MHz noiseless VCVS 的“零噪声”不得作为成功依据。
- `docs/ece203_data/chopper_noise/` 两份最小 CSV（`noise_model_fit.csv` / `chopper_noise_compare.csv`）、可选一张噪声谱图；如做到了 PSS/PNoise，提供对应 PSD 原始数据/设置。不要生成数十张图。
- 如存在新 cells/job/Verilog-A source，使用独立 `ece203_ss_chop_noise_*` 名称；保护已有 Chopper/OTA/ECG/用户 GUI、PDK 机密与 notebook。写明实际完成与未完成项。
- **完成后停止**。**Round4 大综合任务保留，但现在不启动、不修改、不自动跳转。**
