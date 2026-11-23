# R8 pre-run plan (registered before any Spectre run)

Task: docs/ECE203_round8_real_mos_chopper_noise_task.md. Script ece203_r8_noise.il, watchdog tools/r8_watchdog.sh (code = this commit).
Circuit: **Project/ece203_r7f_tb_gain_g0_load10p, read-only** (no rebuild, no new cell; netlist reference
docs/ece203_data/round7f/raw/static/B_gain_g0_load10p_netlist.scs sha256 edf405bca15ab0e2...). Every R8 netlist is audited against it
(instances and subckts identical; only analysis variables may differ).
Simulator: Spectre 15.1.0 64bit (06/21/2017), cmrf7sf tt, 27 C. Options gmin 1e-18, iabstol 1e-17, reltol 1e-5 (R7F setting C).

**Only operational variable: chen = 0 (static phase A, pa 1 pb 0) vs chen = 1 (2 kHz TG, tch 500 us).** Noise runs use vd 0 (no
100 Hz stimulus), dcc 0 (no Cc mismatch aid), vcmin 0; everything else = R7F G0 loaded (cc 60p, LP 4.0M/148p, COUT 10p).
Stimulus check (from the R7F netlist): VSP mag = adm/2, pacmag = pacd, pacphase 0; VSN mag = -adm/2, pacmag = pacd,
pacphase 180 (positive PAC amplitude + 180 deg, not a negative pacmag). AC: adm 1 -> ep-en 1 V. PAC: pacd 1 -> ep-en 2 V.
All transfers are divided by the measured ep-en (sideband 0 for PAC). Clock sources have pacmag 0. VSPS/VSNS ampl = vd/2 = 0.

Spectre facts checked on the server before running (raw/spectre_help/): pnoise noisetype default = timeaverage ("the
time-average of the noise at the output ... spectral density"); maxsideband default 7 (shooting); p/n terminals give the
differential output; pss has cmin, tstab, maxperiods, maxacfreq, errpreset, method, writepss/readpss.

Frequency grid: noise / PAC / PNoise 0.1-250 Hz, 20 points/decade (log); checkpoints 0.1, 1, 10, 100, 250 Hz.
Metrics: app = sqrt(int_0.1^250 Sout df) / |H(100)|; deemb = sqrt(int Sout/|H(f)|^2 df); OFF uses its own static AC H(f),
ON its own PAC sideband-0 H(f). Integrals checked twice (OCEAN integ vs Python trapezoid on the exported CSV, < 2 %).
Source groups (noiseSummary device names, flicker = param fn): XA input pair M1/M2, XA PMOS loads M3/M4, XA cascodes MC1/MC2,
XA tail/ref, XC CMFB, XD DRL, XCD CD, XCI / XCO TG, XPRN/XPRP pseudo-R, RLP_P/N, bias MP0-2, electrode/body/other R.
Per-band input referral of a group = its share of the band output power x the band deemb input power (stated approximation).

Stage A (chen 0): dc + ac 1 mHz-100 kHz (50/dec) + noise (p outp, n outn). Gate: Hoff100 plausible (R7F static loaded 86.06
with dcc 0.01), valid PSD, both integrals agree, flicker + thermal of real MOS present. No noise-spec gate.

Stage B (chen 1, vd 0): (i) one 20 ms zero-input ON tran (setting C: maxstep 0.5u, cmin 1e-17) for DC/swing/drift.
(ii) PSS attempt a1: fund 2k, harms 40, maxacfreq 200k (covers sideband 90 x 2 kHz + 250 Hz), errpreset moderate, tstab 5 ms,
maxperiods 40, cmin 1e-17, writepss. Watchdog: spectre.out silent 900 s or 90 min wall -> kill. PASS needs Spectre's explicit
converged/steady-state message, a closed period (pss_td start = end), sane operating ranges. One numerically motivated retry
a2 allowed (registered here with the a1 evidence before running); otherwise STOP: periodic noise BLOCKED, no ON number.
(iii) PAC (readpss) sideband 0, 0.1-250 Hz: |Hon(100)| within +-10 % of the R7F chopped 83.25 V/V, else FAIL (no PNoise).

Stage C: PNoise (readpss + PAC, noisetype timeaverage, p outp n outn, relative, relharmnum 0) with maxsideband 10 (pilot),
30, 60, and 90 only if 30 -> 60 is not converged (max 4). Converged = the last two completed counts differ <= 5 % in both input
RMS metrics and <= 10 % in input density at 1, 10, 100 Hz. Watchdog: spectre.out silent 30 min or 6 h wall.
Not converged -> SIDEBAND NOT CONVERGED, values shown as a function of maxsideband only, no final number, no 3 uV claim.
Course spec: ON input noise (both metrics) < 3 uVrms, judged only if converged.

Deterministic items (R7F transient: 141.7 uV residual, H3, drift) are never mixed into the noise RMS.

## Update 1 (after Stage A and PSS a1, before a2)

Stage A (script 9c7c43b): valid; OFF H(100) 85.67 V/V, output 1.445 mVrms, input 16.87 uV (app) / 16.32 uV (deemb, Python
re-integration on the AC grid; the SKILL-written deemb column of A_off_noise.csv is mis-aligned and not used), 98.9 % XA
input-pair + PMOS-load flicker; noiseSummary total = trapezoid within 0.00 %.
Zero-input ON tran T0 (20 ms): symmetric, out DM ~5 nV, every node changes < 1e-9 V per period after ~10 ms (the circuit is
periodic in practice).
**PSS a1 FAILED**: 40 shooting iterations (45 s), Conv norm oscillating 4.35 ... 5e4 without a trend; the largest residuals are
the branch currents of the ideal sources VREF and EOC (pA-nA) against abstol(I) = 10 aA; tstab used traponly (ringing notices
on TG gates), iterations gear2only. Spectre saved the unconverged solution (moved to pss_a1_UNCONVERGED_saved.pss, never read).
**a2 (the one retry, numerical only):** itres 1e-4 -> 1e-7 (tighter residual for the GMRES solve of the shooting Newton step;
Spectre help: "Tightening the parameter can help with the Newton convergence, but does not affect the result accuracy"),
maxperiods 40 -> 60. Reason: a near-singular shooting Jacobian (Floquet multipliers ~1 from the TOhm pseudo-R / 60 pF nodes,
tau ~ seconds vs 500 us period) solved inexactly gives the oscillating Newton steps seen. Nothing else changes (same circuit,
tolerances, tstab, cmin). If a2 does not report convergence: Stage B BLOCKED, STOP, no ON noise number.
