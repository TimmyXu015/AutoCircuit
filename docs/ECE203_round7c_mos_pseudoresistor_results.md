# ECE203 R7C — MOS pseudo-resistors replace the ideal feedback resistors in the R7A system (2026-11-22)

Task: [ECE203_round7c_mos_pseudoresistor_integration_task.md](ECE203_round7c_mos_pseudoresistor_integration_task.md).
Script `ece203_r7c.il`. Jobs `ece203_r7c_a / build / b / c / ade`, with env `AC_R7C_CASE=ideal|pr_w4` and `AC_R7C_IABSTOL`. Watchdog `tools/r7c_watchdog.sh`. Data in [ece203_data/round7c/](ece203_data/round7c/).

## Verdict

| Stage | Result |
|---|---|
| A: device and wiring check | **PASS** |
| B: TG-static DC / AC / STB, C0 vs C1 | **PASS**, all gates, at the first size (no W adjustment used) |
| C: 2 kHz TG chopper, 60 ms transient | **PASS**, all gates |
| Numerical sanity check (iabstol 1e-17 → 1e-18) | consistent |
| ADE state | saved: `Project/ece203_r7c_tb_pr_w4` / `r7c_pr_w4_phaseA` |
| Periodic fL (PAC/PSS), PVT, long-term (> 60 ms) behaviour | NOT RUN |

**Measured high-pass corner:** fL = **0.0956 Hz** with the pseudo-R (C0 ideal: 0.0943 Hz). This is the small-signal −3 dB point relative to |Hpre(100 Hz)|, with the TG held static in phase A.

**Main side effects:**
- Gain drops by 1.0 %. This is static and the same in the transient.
- H3 rises from −106 dBc to −86 dBc at 100 Hz. That is still negligible.
- A slow amplitude-dependent common-mode drift of the OTA input nodes (rectification in the pseudo-R). Within 60 ms it is only −0.18 mV/s. Its long-term steady state is estimated, not simulated (see Nonlinearity below).

**Unchanged:** the CMFB, the DRL, the DM edge error and the power.

## What changed (netlist audit)

`r7c_netlist_audit.py` gives **AUDIT PASS** (output in `round7c/r7c_netlist_audit.txt`). The structural diff from the ideal netlist (the R7A a2 bench, used read-only) to `ece203_r7c_tb_pr_w4` is exactly:

```
-RFP (fn p) resistor r=rfb            +XPRP (p fn) ece203_ss_pr_cell
-RFN (fp n) resistor r=rfb            +XPRN (n fp) ece203_ss_pr_cell
+subckt ece203_ss_pr_cell A B
+    MP (B B A B) pfet33 l=prl w=prw ...     (prw=4e-06, prl=2e-06)
```

- The existing R3B cell `ece203_ss_pr_cell` was reused as-is (`prBuild` was not called).
- Its device is thick-oxide pfet33 (the pfet33x schematic device). B = gate + n-well + one p+, and it sits on the demodulated output fp/fn. A = the other p+, on the OTA-input-side node n/p.
- CFN/CFP (0.5 pF), XCI, XCO, XA, XC (`ece203_r7a_cmfb_a2`), XD, XCD and CLBP/CLBN are all unchanged. VDD and VDDD are still independent sources to ground.
- No extra ideal R or V was added in the feedback.
- The Stage C netlist has the same instance list as Stage B.
- VSPS has `sinephase=0`.

## Stage A — device check (pfet33x 4u/2u, CM 0.9 V)

Setup:
- Bench: the existing R3B `ece203_ss_pr_iv_tb`, read-only, with prw/prl set to 4u/2u.
- Options: gmin = iabstol = 1e-18, reltol 1e-6 (the netlist echoes them).
- Data: `A_pr_iv_w4.csv`, `r7c_stageA.png`.

| V(A)−V(B) (mV) | −100 | −50 | −30 | −10 | 0 | +10 | +30 | +50 | +100 |
|---|---|---|---|---|---|---|---|---|---|
| I into A (fA) | −6.47 | −6.24 | −5.51 | −2.71 | 0 | 4.20 | 20.3 | 53.8 | 444.7 |
| 1/g_ac (TΩ) | 838 | 65.7 | 14.0 | 4.49 | **3.13** | 1.89 | 0.883 | 0.416 | 0.055 |
| secant V/I (TΩ) | 15.5 | 8.01 | 5.45 | 3.70 | – | 2.38 | 1.48 | 0.929 | 0.225 |

Findings:
- **Region.** The device is in region 0 (sub-threshold / off) at every point. |VTH| is 0.65–0.71 V, VGS = −V(A)+V(B), and the current is set by the source/drain diffusion and the sub-threshold channel.
- **Small-signal R at 0 V** is r(0) = 3.13 TΩ, 1.7 % below the 3.1831 TΩ target. This is consistent with the old R3B data: W3u gave 4.09 TΩ; the ratio 0.765 is close to 3/4.
- **Asymmetry.** The device conducts much more when A is above B: about ×8.6 at ±50 mV and ×70 at ±100 mV in secant R. It is linear only within about ±10 mV (secant 3.70 vs 2.38 TΩ).
- **Current extraction is credible.**
  - I_A = I_B to 1e-30 A, so there is no DC leakage in the model. Note that the n-well-to-substrate diode is not modelled, so substrate leakage is not assessed.
  - The gmin current (≤ 1 aA) is below 0.04 % of the smallest non-zero current.
  - MP id equals the terminal current.

## Stage B — TG static phase A, full system

Setup:
- Options: gmin 1e-18, iabstol 1e-17, reltol 1e-5, with 1 % Cc mismatch.
- DM AC from 1 mHz to 100 kHz at 50 points/decade.
- Data: `r7c_stageB_summary.csv`, `raw/stageB/`, `r7c_stageB.png`.

| | C0 ideal 3.1831 TΩ | C1 pseudo-R 4u/2u | Gate |
|---|---|---|---|
| fL (−3 dB vs \|H(100)\|) | 0.0943 Hz | **0.0956 Hz** | 0.09–0.11 Hz PASS |
| Hpre 10 / 60 / 100 Hz | 94.543 / 94.537 / 94.531 | 93.589 / 93.583 / 93.578 | Hpre100 −1.01 % (≤ 5 %) PASS |
| Hpre phase at 100 Hz | −0.730° | −0.728° | |
| Hpre(0.1 Hz) | 68.87 at 43.3° | 67.71 at 43.7° | |
| Hbuf(100) | 79.641 | 78.838 | |
| fH | 7384 Hz | 7394 Hz | |
| (op+on)/2, (fp+fn)/2 | 0.8999181 V | 0.8999181 V | −0.08 mV (±1 mV) PASS |
| (p+n)/2 | 0.8999189 V | 0.8999189 V | |
| V(A)−V(B), XPRN / XPRP | – | +0.81 µV / +0.81 µV | |
| MP id / gds / region | – | 0.26 aA / 3.19e-13 S (3.13 TΩ) / 0, both sides | |
| CMFB UGF / PM | 122.4 kHz / 84.46° | 121.4 kHz / 84.51° | ≥ 60° PASS |
| DRL UGF / PM | 1983 Hz / 90.25° | 1983 Hz / 90.25° | ≥ 60° PASS |
| CMRR60 (pre = buf) | 108.50 dB | 108.42 dB | |
| \|Zin\| at 10 Hz (source DM) | 658.4 MΩ | 658.0 MΩ | |
| P = 1.8·(I_VDD + I_VDDD) | 1.994 µW | 1.994 µW | no jump PASS |
| Worst sat margin (OTA / CMFB) | 0.0917 V XA.M1 / 0.200 V XC.MTB | same | regions kept PASS |

**The size adjustment was not used.** W = 4u passed at the first try.

**Where the −1.0 % gain comes from (hypothesis, not separately measured).** It fits a parasitic of about 5.1 fF bridging A and B, in parallel with CFN/CFP:
- 0.5 pF × (94.531/93.578 − 1) ≈ 5.1 fF.
- All of the device's capacitance at A (the p+ junction to the n-well, and gate overlap) lands on B = fp/fn, because both the gate and the well sit on B.
- That size is consistent with about 2.2 µm² of junction plus about 1 fF of overlap.

## Stage C — 2 kHz TG chopper, 100 Hz 1 mV DM, 60 ms

Setup:
- Settings are those of R6D-R / R7A setting C: cmin 1e-17 (echo "cmin = 10 aF"), maxstep 0.5 µs (echo "500 ns"), gmin 1e-18 (echo "1 aS"), iabstol 1e-17, reltol 1e-5.
- The watchdog was never triggered. Each run took about 2 minutes.
- C0 is the existing R7A wave, reused with an unchanged SHA (`round7a/raw/stage3/T_a2_buf10p_tran.csv.gz`).
- Analysis: `r7c_analysis.py`, which uses the R7A metrics and adds pseudo-R terms. Figure: `r7c_stageC.png`. Summary: `r7c_stageC_summary.csv`.

Values are for the 40–60 ms window; 20–40 ms gives the same.

| | C0 ideal | C1 pseudo-R | C1, iabstol 1e-18 | Gate |
|---|---|---|---|---|
| t_end | 60 ms | 60 ms | 60 ms | complete PASS |
| Hpre gain / phase | 91.733 / 0.565° | **90.831** / 0.535° | 90.831 / 0.536° | −0.98 % (≤ 5 %) PASS |
| Hpre H2 / H3 (dBc) | −103.8 / −106.2 | −102.1 / **−85.7** | −102.2 / −85.7 | |
| DM residual RMS | 3589 µV | 3520 µV | 3520 µV | 0.98× (≤ 3×) PASS |
| DM edge error max / mean | 31.97 / 20.71 mV | 31.45 / 20.37 mV | 31.45 / 20.37 mV | |
| Hbuf gain | 77.24 | 76.48 | 76.48 | |
| op/on CM average | 0.899939 V | 0.899940 V | 0.899940 V | −0.06 mV (≤ 1 mV) PASS |
| op/on CM at 200 Hz | 3.94 µV | 3.87 µV | 3.86 µV | ≤ 0.20 mV PASS |
| op/on CM edge spike | +8.46 / −2.87 mV | +8.46 / −2.86 mV | same | |
| vg range | 1.32321–1.32586 V | same | same | |
| fp range / bufp min | 0.8507–0.9506 / 0.5029 V | 0.8511–0.9501 / 0.5033 V | same | no clipping PASS |
| P (tran average) | 1.999 µW | 1.998 µW | 1.996 µW | |
| V(A)−V(B) XPRN (min..max, avg) | – | −48.0..+46.7 mV, +0.135 mV | same | |
| XPRP | – | −48.3..+46.4 mV | same | |
| p−n average / pp | – | −0.26 µV / 0.63 mV | same | |
| (p+n)/2 slope over 10–60 ms | – | **−0.18 mV/s** | same | explained, see below |

**Numerical check.** C1 at iabstol 1e-17 vs 1e-18 differs by 0.94 µV RMS on fp/fn. The maximum difference is 132 µV, at TG edges (time-step placement), and every metric agrees to 4–5 digits.

**Stage C conclusion.**
- The pseudo-R does not touch the chopper or CMFB dynamics: edge spike, CM 200 Hz, vg and the DM edge error are all within 2 % of C0.
- The only differences are the static 1 % gain drop, H3, and a slow input-node CM drift.
- The R7A/R7B DM edge error of about 31 mV (the CMFB-detector gate capacitance) is still the dominant transient error. R7C neither changes nor addresses it.

## Nonlinearity — what it does and what was not tested

**1. At 100 Hz it is negligible.**
- With 1 mV DM input the pseudo-R sees ±47 mV, far outside its ±10 mV linear range.
- But at 100 Hz the feedback current goes almost entirely through CF: |Z_CF| = 3.2 GΩ against roughly 3 TΩ for the pseudo-R.
- So the strongly distorted pseudo-R current (about 5 % H3 of its own) shows up only as H3 = −85.7 dBc, about 4.8 µV on a 93 mV output.

**2. There is a rectified DC current (measured trend, estimated end point).**
- Asymmetric conduction under a symmetric ±47 mV swing gives a net current into A. The quasi-static estimate from the Stage A I–V is +10.7 fA on each side.
- Both sides rectify in the same direction, so it is a common-mode effect: p−n stays within 0.3 µV.
- The prediction: n and p drift down at about 10.7 fA / C_node. The transient shows (p+n)/2 falling linearly at −0.18 mV/s, which implies C_node ≈ 59 pF.
- The drift stops when the average current is zero. Quasi-static steady-state shifts of V(A)−V(B):

  | Output swing per side | 10 mV | 20 mV | 47 mV (this test) | 60 mV |
  |---|---|---|---|---|
  | Steady-state shift | −1.5 mV | −5.2 mV | **−22 mV** | −32 mV |

- The time constant is about C_node / g ≈ 59 pF × 3 TΩ, roughly 3 minutes.
- These numbers come from linear interpolation of 9 I–V points. They are not simulated.
- The effect is an amplitude-dependent shift of the OTA input CM (through the input TG) by tens of mV. The OTA input pair's headroom under that shift is NOT verified. The current worst margin is XA.M1 at 0.092 V.

**3. Large-signal corner and low-frequency distortion are NOT RUN.**
- fL = 0.0956 Hz is a small-signal value.
- At ECG fundamentals (about 1–2 Hz) the pseudo-R current is no longer small against CF, so distortion and a signal-dependent corner will be much larger than at 100 Hz.
- A 60 ms transient cannot show this. It would need a multi-second slow-signal transient without chopping, or PSS.

## Is further optimisation worth it?

**Not for the pseudo-R size.** W 4u / L 2u already lands fL at 0.0956 Hz, inside 0.09–0.11, with every Stage B/C gate passing, and the system-level cost is 1 % gain. Changing W would only move fL and the rectification by the same factor.

What is worth checking before a sign-off claim (bounded, not run here):
- **(a)** A static DC check of OTA and TG headroom with the input-node CM shifted by about −25 / −35 mV. This bounds the rectification risk. If it fails, a symmetric pseudo-R (two series devices, back-to-back) is the standard fix, but that is a topology change.
- **(b)** A slow, large-signal test without chopping at 1 Hz with 1 mV, for distortion and corner shift.
- **(c)** fL over process and temperature corners. Sub-threshold R is strongly process- and temperature-dependent.

The bigger open system item remains the CMFB-detector-capacitance DM edge error from R7A/R7B.

## Files

`round7c/` contains:
- `A_pr_iv_w4.csv`
- `r7c_stageB_summary.csv`
- `r7c_stageC_summary.csv`
- `r7c_netlist_audit.txt`, `r7c_netlist_audit.py`
- `r7c_analysis.py`, `r7c_plots_ab.py`, `r7c_plots_c.py`
- `r7c_stageA.png`, `r7c_stageB.png`, `r7c_stageC.png`
- `raw/stageA` (netlist, job log)
- `raw/stageB` (per-case CSV, DC operating points, DM AC curves, STB CSVs, netlists, job logs)
- `raw/stageC` (full-resolution transient `.csv.gz` with SHA-256, spectre.out, netlists, job logs; both iabstol settings)

New Cadence objects:
- cell `Project/ece203_r7c_tb_pr_w4`;
- ADE state `r7c_pr_w4_phaseA` (DC, AC, CMFB STB, tight options);
- simulation directory `ece203_r7a_tb_buf_a2/spectre/schematic_B_ideal_*`. This was created by running the R7A cell read-only; the cell itself was not edited.

Runs used:
- Stage A: 9 DC+AC points.
- Stage B: 2 cases × (DM AC + CM AC + STB).
- Stage C: 2 full 60 ms runs (C1 plus the one numerical check). C0 was reused.
