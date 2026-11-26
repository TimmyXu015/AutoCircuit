# ECE203 F2 final validation scout — nominal noise, nominal checks, mismatch MC (results, 2026-11-25)

Tasks:
- [ECE203_F2_final_validation_scout_task.md](ECE203_F2_final_validation_scout_task.md) (active);
- [ECE203_F2_final_noise_mc_scout_task.md](ECE203_F2_final_noise_mc_scout_task.md) (same scope, earlier wording — both covered).

Data: [ece203_data/f2_final_scout/](ece203_data/f2_final_scout/). No redesign, no chopper, no PVT, no 1 µA rerun. Nothing was written to or simulated in any `203ECG*` library.

## Setup

**DUT and fixture.**
- Frozen early F2: OTA `ece203_r5nf_ota_f2` in the audited instructor-fixture copy `Project/ece203_f2_1ua_prof_tb` (built in the 1 µA task; audit PASS: instructor elements = read-only `ECG_tb/ECG_tb`, 36 DUT elements = archived `ece203_r5nf_tb_f2` minus its fixture).
- TT / 27 °C, the same PDK section (`allModels.scs section=tt`), supply, bias and tolerances (gmin 1e-18, iabstol 1e-18, reltol 1e-6).

**How it was run.**
- Spectre was run directly on the audited ADE netlist of that cell (`A_prof_dm_netlist.scs` from the 1 µA task), with every circuit line copied unchanged.
- Only the stimulus parameters were made functions of one mode parameter `fvm` (`tools/f2v_netlist.py`):

| `fvm` | Drive | DRL |
|---|---|---|
| 0 | pure DM: V0 AC 1, I2 AC 0 | real DRL on (rdr 1 MΩ) |
| 1 | pure CM: V0 AC 0, I2 = 100 nA AC at 60 Hz | **off** (rdr 1e15 Ω, rl0 floats) |
| 2 | pure CM, same as 1 | real DRL on |

- Gain definitions: Gpost = |V(out) / (V(vRight) − V(vLeft))| (post-electrode, course gain); Gsrc = |V(out)/V0|.
- With the instructor wiring, (vRight − vLeft)/V0 = 0.6660, flat from 1 mHz to 1 kHz ([fig_f2v_gain.png](ece203_data/f2_final_scout/fig_f2v_gain.png)).

**Differences from the historical custom fixture.**
- The historical fixture drives ideal VSP/VSN at ±½ (ep − en = 1 V exactly, body-referenced) and has its own copy of the same electrode network (2 kΩ + 1 MΩ ‖ 50 nF, body 200 pF).
- The instructor fixture drives V0 inside the 200 Ω body loop, so the post-electrode differential is 2/3 · V0. Everything else (DUT, electrodes, body C) is identical.
- Re-run of the archived fixture netlist in the same flow:
  - 100 Hz gain 39.215 dB (historical 39.22);
  - 0.1–250 Hz noise 2.928 µV as out/H100 (historical 2.930) and 2.877 µV pointwise (historical 2.880).

**Ideal sources and power bookkeeping.**
- Only VDD (1.8 V) and IREF (100 nA, the allowed reference) are active ideal sources.
- VDDD (vdd→vddd, 0 V) and VPP/VPN (0 V, at the amplifier inputs) are current meters. IPRB and IPRD are STB probes (ideal 0 V iprobes).
- The vref and vcas dividers are ideal resistors from vdd.
- EDRL (ideal VCVS) hangs on RDRI = 1e15 Ω and is inactive.
- **I(VDD) already contains the DRL current**, so P = 1.8 V · I(VDD). This corrects the power note in the 1 µA report.

## A. Nominal noise

Noise was computed at node `out` (single-ended, to ground) from 1 mHz to 100 kHz at 50 points/decade, with iprobe = V0, DRL on, interference off, and all fixture resistors noisy.

**Checks:**
- 100 points/decade changes every number below by ≤ 0.02 %.
- Trapezoid and piecewise-power-law integration agree to < 0.05 %.
- Spectre `in · gain = out` (to 1e-15), and the noise gain equals AC |out/V0| (to 4e-6).
- The OCEAN Calculator read-back `sqrt(integ(getData("out")**2 …))` gives 293.812 µV (full) and 267.508 µV (0.1–250 Hz), identical to these scripts.
- The source contributions sum to the total (ratio 1.000000).

| Method (input reference) | 1 mHz–100 kHz | 0.1–250 Hz | < 3 µVrms? |
|---|---|---|---|
| Output RMS at `out` | 293.81 µV | 267.51 µV | — |
| **M1 (course): out RMS / Gpost(10 Hz) = 98.524** | **2.982 µV** | 2.715 µV | full **PASS (0.6 % margin)**, band PASS |
| M1: out RMS / Gpost(100 Hz) = 91.456 (historical gain point) | **3.213 µV** | 2.925 µV | full **FAIL**, band PASS |
| M1: out RMS / plateau max 98.570 | 2.981 µV | 2.714 µV | PASS / PASS |
| M2 Spectre native "in" (referred to **V0 = source**, includes the 2/3 divider) | 47.21 µV | 4.316 µV | FAIL / FAIL (wrong reference for the course gain) |
| M3 post-electrode pointwise √∫S_out/\|Hpost(f)\|² | 31.04 µV | 2.875 µV | FAIL / PASS |

Frequency split of the full-band output noise power:

| Band | 1 mHz–0.1 Hz | 0.1–1 Hz | 1–10 Hz | 10–100 Hz | 100–250 Hz | 250 Hz–1 kHz | > 1 kHz |
|---|---|---|---|---|---|---|---|
| Share | 6.5 % | 26.1 % | 24.5 % | 23.0 % | 9.4 % | 7.9 % | 2.6 % |

- **The two input-referred methods diverge outside the passband.** Dividing by |H(f)| inflates the input-referred PSD wherever the gain falls (below fL and above fH), so pointwise full-band integration (M2/M3) is dominated by > 250 Hz (M3: 30.6 µV of the 31.0 µV). This is the expected behaviour of pointwise de-embedding, not a hidden fault. The course method (M1) uses a constant midband gain and stays near 3 µV.
- **Sources (0.1–250 Hz and full band are almost identical):**
  - OTA1 input pair XA.M1/M2: 54.4 % of output power;
  - PMOS mirror XA.M3/M4: 40.9–41.1 %;
  - instructor electrode resistors (2 kΩ + 1 MΩ): 2.1–2.3 %;
  - pseudo-R: 0.6–1.0 %;
  - everything else: < 1 % each.
  - Electrode noise is included in all totals; no source was switched off. Per-device table: [f2v_noise_sources.csv](ece203_data/f2_final_scout/f2v_noise_sources.csv).
- **NEF** = Vni · √(2 I_fwd / (π · U_T · 4kT · BW)) at T = 300.15 K, U_T = 25.865 mV.
  - I_fwd = I(VDD) − I(VDDD) − I(MP2) = 1.7640 − 0.2489 − 0.0535 = **1.4616 µA**. This excludes the DRL OTA and its bias mirror; the shared IREF branch and both dividers are kept in.
  - 0.1–250 Hz (BW 249.9 Hz): NEF 8.00 (M1, 2.715 µV) / 8.47 (M3, 2.875 µV).
  - Full band (BW = π/2·(fH − fL) = 389.7 Hz): 7.04 (M1, 2.982 µV).
- Plots: [fig_f2v_noise.png](ece203_data/f2_final_scout/fig_f2v_noise.png) (output ASD, the three input-referred ASDs, cumulative out/G10). Tables: `f2v_noise_bands.csv`, `f2v_noise_psd.csv`.

## B. Nominal checks (instructor fixture, dcc = 0 unless marked)

| Item | Result | Course spec |
|---|---|---|
| Gpost 10 / 60 / 100 Hz | 98.524 / 95.845 / 91.456 (**39.871** / 39.631 / 39.224 dB); plateau 98.570 (39.875 dB) at 5 Hz | 38–42 dB PASS |
| Gsrc 10 / 60 / 100 Hz | 65.62 / 63.83 / 60.91 | — |
| fL / fH (Gpost plateau max / √2) | **0.1004 Hz / 248.16 Hz** | 0.09–0.11 / 225–275 PASS |
| CMRR60, course definition (see below) | **ON 86.33 dB**, OFF 55.59 dB | > 85 dB PASS (1.3 dB margin) |
| CMRR60 with fixed dcc = 1 % (sensitivity, not MC) | ON 89.85 dB, OFF 59.11 dB | — |
| Zin @10 Hz, \|v(inp)/i(VPP)\| / \|v(inn)/i(VPN)\| | 3.86 GΩ / **162.5 MΩ**; differential \|v(inp) − v(inn)\|/\|i(VPP)\| 7.71 GΩ | > 100 MΩ PASS |
| Total power 1.8 V · I(VDD) (includes DRL) | **3.175 µW** (I_VDD 1.764 µA; DRL OTA 0.249 µA, DRL bias 0.053 µA) | < 4 µW PASS |
| Designed capacitance (all capacitors except instructor C0–C3) | **143.5 pF** | < 1 nF PASS |
| Main loop STB (probe IPRB, oa → o) | PM 73.02° at 29.0 kHz, GM 19.4 dB | (no course spec) |
| DRL loop STB (probe IPRD, rl0 → vRL) | PM 90.13° at 2.0 kHz, GM 78.1 dB | (no course spec) |

**CMRR60 definition used:**
- Adm60 = pure-DM Gpost(60 Hz).
- vcm_post,off = |(vRight + vLeft)/2| at 60 Hz with 100 nA AC into the body and **DRL off** = 1.285 V.
- out_on = 5.94 mV and out_off = 204.6 mV.
- CMRR_on = 20·log10(Adm60 · vcm_off / out_on); CMRR_off uses out_off.
- For information only: CMRR_on with its own DRL-on CM reference (37.4 mV) is 55.60 dB.
- dcc = 1 % raises CMRR because the topology's CM gain is systematic: the inp side has Cfb to vref, the inn side has feedback. The deliberate CCX offsets part of that asymmetry. This is a fact, not a recommendation.

**DC operating point:**
- out 0.89980 V, oa1 1.4349 V, p 0.900000 V, n 0.899796 V, inputs and body 0.90148 V, vcas 1.100 V.
- Every non-pseudo-R MOS is in saturation or subthreshold. The pseudo-Rs are "off" (by design).
- Smallest |VDS| − VDSAT: XA.M4 0.076 V, XA.M2 0.116 V.
- Files: `f2v_dcop_devices.csv`, `f2v_caps.csv`, `f2v_nominal_summary.csv`, `f2v_nominal.txt`.

## C. Mismatch Monte Carlo

**Method.** Spectre `montecarlo variations=mismatch seed=12345 numruns=100`. Each iteration contains, on one random sample, in order:
1. `dc`;
2. a nested sweep over the three modes (`dc` + `ac` 1 mHz–100 kHz + `ac` at exactly 10/60/100 Hz);
3. `noise`;
4. both `stb` analyses.

**Coverage.**
- The PDK `process.scs` has a `statistics { mismatch { … } }` block (MOS Vth/β/body plus PDK resistor/capacitor/diode terms).
- In this design only the MOSFETs are randomised. The analogLib R/C (Cc, Cfb, LP, electrodes, dividers) are ideal and not varied, and dcc stays 0.

**The same sample is used for every measurement:**
- Inside each iteration, the DC of the DM mode equals the iteration's DC (diff 0 V), and the DC of the CM/DRL-on mode equals it to 8.5e-10 V.
- Separate replay runs (`firstrun=7/15/63, numruns=1`) reproduce main-run samples 7, 15 and 63 to |ΔDC| ≤ 8.5e-10 V, AC ≤ 4e-6 relative and noise ≤ 2.4e-6 relative. Neighbouring samples differ by 1.8–3.9 mV.

**Draws are distinct:** 100/100 different out_DC, p − n and I_VDD values. σ(I_VDD) = 58.5 nA; σ(body DC) = 1.2 mV.

**Pilot N = 20 → full N = 100.** Attempted 100, valid 100, failed 0. Full tables: `f2v_mc_n100_stats.csv`, per sample `f2v_mc_n100_samples.csv`, histograms [fig_f2v_mc_hist.png](ece203_data/f2_final_scout/fig_f2v_mc_hist.png). The N = 20 pilot is in `f2v_mc_n20_*`.

| Metric | Mean | σ | Min | Max | Spec | Pass |
|---|---|---|---|---|---|---|
| Gpost 10 Hz [dB] | 39.871 | 0.0024 | 39.863 | 39.875 | 38–42 | 100/100 |
| Gpost 100 Hz [dB] | 39.224 | 0.0033 | 39.215 | 39.231 | 38–42 | 100/100 |
| fL [Hz] | 0.1002 | 0.0033 | 0.0919 | 0.1075 | 0.09–0.11 | 100/100 |
| fH [Hz] | 248.14 | 0.19 | 247.61 | 248.62 | 225–275 | 100/100 |
| Noise M1 full, out/G10 [µV] | 2.9835 | 0.0105 | 2.958 | **3.012** | < 3 | **94/100** |
| Noise M1 full, out/G100 [µV] | 3.214 | 0.011 | 3.188 | 3.245 | < 3 | 0/100 |
| Noise M1 0.1–250 Hz, out/G10 [µV] | 2.716 | 0.006 | 2.703 | 2.733 | < 3 | 100/100 |
| Noise M3 0.1–250 Hz, post pointwise [µV] | 2.876 | 0.005 | 2.862 | 2.889 | < 3 | 100/100 |
| Noise M2 native V0-ref, full / 0.1–250 Hz [µV] | 47.24 / 4.317 | 0.74 / 0.007 | — | — | < 3 | 0/100 (source reference) |
| CMRR60 ON, course [dB] | 86.33 | 0.43 | **85.16** | 87.30 | > 85 | 100/100 |
| CMRR60 OFF [dB] | 55.60 | 0.28 | 54.69 | 56.15 | — | — |
| Zin10 P / N [MΩ] | 3856 / 162.5 | 3.3 / 0.04 | 3846 / 162.4 | — | > 100 | 100/100 |
| Total power [µW] | 3.177 | 0.105 | 2.952 | 3.472 | < 4 | 100/100 |
| PM main / DRL [deg] | 73.03 / 90.13 | 0.16 / 0.004 | 72.66 / 90.12 | 73.51 / 90.14 | — | — |

**Joint yield over the measured metrics:**
- Gain 10 Hz, fL, fH, CMRR_on, Zin P/N, power and course noise (full band, out/G10): **94/100**. Every one of the 6 failures is noise (3.000–3.012 µV).
- With 0.1–250 Hz noise instead: 100/100.
- Without noise: 100/100.
- Worst CMRR: sample 82, 85.16 dB. Worst noise: sample 94, 3.012 µV.

**Not run:** NEF per sample (only nominal), PVT, passive mismatch, dcc MC.

## 中文小结

- **Test 1 与复现：** 原夹具复现了历史值（100 Hz 39.215 dB；0.1–250 Hz 噪声 2.928/2.877 µV）。F2 放到教授 ECG_tb 中：Gpost 10 Hz 为 39.871 dB，fL 0.1004 Hz，fH 248.2 Hz，功耗 3.175 µW（含 DRL），电容 143.5 pF，Zin 最小 162.5 MΩ（inn 端）。
- **A. 噪声（关键门）：** 课程方法（1 mHz–100 kHz 输出 RMS ÷ 中频增益）对 10 Hz 增益为 **2.982 µV（标称 PASS，仅 0.6 % 余量）**，对 100 Hz 增益为 3.213 µV（FAIL）。“中频增益”取 10 Hz 还是 100 Hz 会决定结论，需要你按课程定义确认。0.1–250 Hz 各方法都 < 3 µV（2.715 / 2.925 / 2.875）。
  - Spectre 原生 input-referred 噪声是折算到 **V0（源端，含 2/3 分压）**的：全带 47.2 µV，0.1–250 Hz 4.32 µV。逐点 de-embed 到电极后全带为 31.0 µV，主要来自 250 Hz 以上增益下降的区域。这是逐点折算方法本身的特性，已画在图中，没有隐藏。
  - 噪声源：输入对 54 %，PMOS 镜像 41 %，电极电阻约 2 %。NEF（0.1–250 Hz，前向 1.46 µA）为 8.0。
- **B. CMRR（课程定义，DRL OFF 电极共模作参考）：** ON 86.33 dB（PASS，余量 1.3 dB），OFF 55.6 dB。固定 dcc = 1 % 时 ON 为 89.85 dB（与历史 89.85 相同）。
- **C. MC（N = 100，仅 MOS 失配，同一样本跑全部测量，并用 replay 验证了映射）：** 增益、fL/fH、CMRR、Zin、功耗全部 100/100。CMRR 最差 85.16 dB。课程全带噪声（out/G10）94/100（6 个样本在 3.000–3.012 µV）；0.1–250 Hz 噪声 100/100。联合良率 94/100，失败的都是噪声。
- **结论交给你和 GPT：** 标称全带噪声与 CMRR 都贴近规格线。是否需要降噪，以及“中频增益”取 10 Hz 还是 100 Hz，请你们决定。我没有改设计。

## Manual reproduction (your own library; do not use 203ECG_CCF_TwoStage for experiments you don't want there)

**Verified here (batch, this server, IC 6.1.8 / Spectre 15.1):**
- the netlist statements and OCEAN functions below;
- model library `…/cmrf7sf/V2.0.0.2AM/Spectre/models/allModels.scs`, section `tt` (its `process.scs` holds `statistics { process {…} mismatch {…} }`).

**Not verified (GUI, no screen access here):** every menu path below is the usual IC 6.1.x location. Check it in your session.

1. **Testbench.** Your copy of the instructor ECG_tb with your F2 instance. Keep V0 (1 mV sine, AC mag 1) and I2 (60 Hz isin, AC mag 0 for DM).
   - *ADE L → Setup → Model Libraries:* allModels.scs, section tt.
   - *Simulation → Options → Analog:* reltol 1e-6, gmin 1e-18, iabstol 1e-18.
2. **Noise (ADE L → Analyses → Choose… → noise).**
   - Start 1m, Stop 100k, Points per decade 50.
   - Output noise: voltage, positive node `/out`, negative `/gnd!`.
   - Input noise: voltage, input source `/V0`.
   - Also run an `ac` analysis on the same grid.
3. **Calculator after the run.** Units are V/√Hz, so square before integrating.
   - Output RMS: `sqrt(integ((getData("out" ?result "noise") ** 2) 0.001 100000))`. Here: 293.8 µV.
   - Course method 1: divide that by `value(mag(VF("/out")/(VF("/vRight") - VF("/vLeft"))) 10)`. Here: 98.52, giving 2.982 µV. Use 100 instead of 10 for the historical gain point.
   - Spectre native: `sqrt(integ((getData("in" ?result "noise") ** 2) 0.001 100000))`. This is referred to V0, not post-electrode.
   - Results → Print → Noise Summary (integrated, from/to): gives the same totals and the contributor table in ADE. Its OCEAN form `noiseSummary` failed here on psfascii data read without ADE, which is why the contributor table above comes from the psf.
4. **CMRR.**
   - Run 1 (DM): V0 AC 1, I2 AC 0, DRL on → Adm60.
   - Runs 2 and 3: V0 AC 0, I2 AC mag 100n, DRL off (rdr = 1e15, rdi = 1e15) and DRL on.
   - CMRR_on = `20*log10(Adm60 * value(mag((VF("/vRight")+VF("/vLeft"))/2) 60) [run 2] / value(mag(VF("/out")) 60) [run 3])`.
   - Use ADE L parametric analysis on one mode variable (as the `fvm` expressions here), or three saved states.
5. **STB:** stb analysis with probe `/IPRB` (main loop) or `/IPRD` (DRL loop), 1m–10M. Read PM/GM in Results → Direct Plot → Main Form (stb).
6. **Mismatch MC.** Use ADE XL / Explorer.
   - Create Monte Carlo Sampling, Statistical Variation = Mismatch, number of points 100, sampling method random, starting seed 12345.
   - Put the noise, ac and stb analyses and the expressions above in the same test so every point is one sample.
   - Histogram: right-click an output in the Results tab → Plot Histogram (spec lines via the Specifications column).
   - Equivalent Spectre (verified):
     ```
     mc1 montecarlo numruns=100 seed=12345 variations=mismatch savefamilyplots=yes donominal=no {
         dcop dc
         swm sweep param=fvm values=[0 1 2] { dcm dc  acm ac start=1m stop=100k dec=50  acx ac values=[10 60 100] }
         nz (out 0) noise start=1m stop=100k dec=50 iprobe=V0
         stbm stb start=1m stop=10M dec=10 probe=IPRB
         stbd stb start=1m stop=10M dec=10 probe=IPRD
     }
     ```
     A single sample is replayed with `firstrun=k numruns=1`.
7. **Common errors:**
   - Integrating `out` instead of `out**2`.
   - Dividing the noise by the V0-referred gain while quoting the post-electrode gain.
   - Using the DRL-on CM as the CMRR reference (it gives ~55 dB, not the course number).
   - Ratioing CMRR across different MC samples.
   - Forgetting that I(VDD) already includes the VDDD meter.

## Commands (server, `~/AutoCircuit`)

```
tools/f2v_run.sh nom2 nominal 50             # dc, ac (modes 0/1/2, dcc 0 and 1 %), noise 50 + 100 pts/dec, stb main + DRL
tools/f2v_run.sh ref2 ref 50                 # archived F2 fixture netlist, dc + ac + noise (reproduction)
tools/f2v_run.sh mc20 mc 20 12345 1 50       # pilot
tools/f2v_run.sh mc100 mc 100 12345 1 50     # full (9.5 min)
tools/f2v_run.sh rp63 mc 1 12345 63 50       # replay of sample 63 (also rp7, rp15)
python3 tools/f2v_extract.py /tmp/lix015_f2v/mc100/psf /tmp/lix015_f2v/x_mc100
AC_F2V_RUN=nom2 ~/AutoCircuit/run.sh ece203_f2v_ocean    # OCEAN Calculator read-back
```

Run locally in `docs/ece203_data/f2_final_scout/`:
```
python3 f2v_nominal.py <nom2> <ref2>
python3 f2v_mc.py <x_mc100> n100 <x_rp7> <x_rp15> <x_rp63>
python3 f2v_figs.py
```

Raw psf and logs: notebook `_raw\2026-11-25_ece203_f2_final_scout\`.

## Limitations

- **Psfascii AC precision.** AC values are written with 6 significant digits. This is enough for gains, CMRR and Zin. The CM-to-DM residual at the electrodes is below that resolution and is not reported.
- **Corners:** TT/27 °C only. No PVT.
- **MC coverage:** MOS mismatch only, because the passives are ideal analogLib parts. There is no global process variation.
- **The noise pass depends on the gain point.** The course full-band noise passes only against the 10 Hz (or plateau) gain, with 0.6 % nominal margin and 94 % MC yield. Against the 100 Hz gain it fails.
- **GUI steps not verified;** see the manual section.
