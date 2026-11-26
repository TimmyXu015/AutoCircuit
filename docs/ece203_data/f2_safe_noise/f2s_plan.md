# F2S plan (registered before any F2S simulation, 2026-11-25)

Task: [../../ECE203_F2_safe_noise_optimization_task.md](../../ECE203_F2_safe_noise_optimization_task.md).

## Flow (same as F2V, only the OTA1 cell differs)
1. SKILL job `ece203_f2s_build` (file `ece203_f2s.il`), per case:
   - New OTA1 cell `Project/ece203_f2s_ota_<case>`, drawn with the same device list as `ece203_r5nf_ota_f2` (pfetx/nfetx through the PDK CDF callbacks, the same hw2DiffParams), with only the case's W/L changed.
   - New whole-system cell `Project/ece203_f2s_tb_<case>`: a fresh read-only copy of `ECG_tb/ECG_tb` plus the F2 system (f2iBuild with only XA's master swapped).
   - One ADE DC+AC run gives the real netlist `~/AutoCircuit_results/ece203_f2s/<case>_netlist.scs`.
   - The CDF w/l definitions of nfetx/pfetx are dumped once.
2. Audit (`f2s_audit.py`): each case netlist vs the F2V audited netlist (`A_prof_dm_netlist.scs`). The only allowed differences are the W/L (and the CDF-derived ad/as/pd/ps) of the changed OTA1 devices. Realised W/L in the netlist must equal the requested values (no clipping).
3. Standalone Spectre (`tools/f2v_run.sh`, base netlist = the case netlist, `F2V_SET` for Stage B design-variable overrides), unchanged F2V analyses:
   - dc/opinfo; ac 1 mHz–100 kHz 50/dec in modes DM / CM DRL off / CM DRL on, plus exact 10/60/100 Hz;
   - noise 50/dec (+100/dec for the convergence check);
   - stb for the main loop (IPRB) and the DRL loop (IPRD).
   - dcc = 0 is the gate value; the dcc 1 % sweep that the F2V netlist also contains is reported only as information.
4. Metrics: identical F2V definitions (`f2v_nominal.py`).
   - M1 = sqrt(∫ S_out over 1 mHz–100 kHz) / Gpost(10 Hz), also / Gpost(100 Hz).
   - M2 = Spectre "in" (V0-referred) and M3 = post-electrode pointwise, both bands.
   - CMRR course definition (DRL-off post-electrode CM reference, same run); Zin = v(inp)/i(VPP), v(inn)/i(VPN) at 10 Hz.
   - P = 1.8 V · I(VDD), which includes the DRL meter VDDD.
   - Margins = |VDS| − VDSAT (Spectre opinfo), region codes.
   - OTA1 area = Σ W·L of the OTA1 devices; Cgg of the input devices from opinfo.

## Cases (Stage A ≤ 11 including baseline)
Sizes in µm; MC 10/4 and MREF 2/4 are unchanged everywhere.

| Case | Input pair M1/M2 | Mirror M3/M4 | Tail MT |
|---|---|---|---|
| B0 (F2 rebuilt through the new path; must reproduce F2V nom2) | 50/40 | 8/42 | 32/4 |
| N1 | 55/44 | base | base |
| N2 | 60/48 | base | base |
| P1 | base | 10/52.5 | base |
| P2 | base | 12/63 | base |
| T1 | base | base | 36/4 |
| T2 | base | base | 40/4 |
| T0 (optional, only if T1/T2 show a useful current trend) | base | base | 28/4 |

- Then ≤ 3 combinations chosen from the measured Stage A results. Area at similar current is preferred over more current.
- A case is reported invalid (not substituted) if the CDF / netlist does not realise the requested W/L. The model files contain no geometry bins or geometry asserts, so there is no model-range extrapolation flag; the layout penalty of large devices is reported as area.

## Stage B (only if needed; A + B ≤ 16)
- Best sizing with Cc/Cf 60p/0.6p and 70p/0.7p.
- prw scaled ∝ Cf (start 4.8u / 5.6u at L 2u), with at most one bounded prw correction per cap case to centre fL.
- Optionally one Miller cm2 change (0.6p or 0.75p) if PM alone blocks.

## Stage C (winner only)
- Full F2V signoff incl. noise 50 vs 100/dec.
- 10 s transient with ECG 1 mV 10 Hz + 100 nA 60 Hz, extracted as in F2I.
- MC mismatch N = 20 then N = 100, seed 12345, same sample for all analyses, replay of ≥ 2 iterations.
- Hand-drawing parameters plus the audit of the winner's ADE netlist.

## Gates
As the task: Gpost 38–42 dB (10/60/100 Hz), fL 0.09–0.11, fH 225–275, CMRR_on > 85 dB (dcc 0), worst Zin10 > 100 MΩ, P < 4 µW, C < 1 nF, PM ≥ 60° both loops, no clipping. Noise target: M1/G10 ≤ 2.6 µV (≤ 2.7 acceptable) and M1/G100 < 3 µV.
