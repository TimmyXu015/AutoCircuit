#!/usr/bin/env python3
"""R7B figures: r7b_edges.png (wave overlays at the 42.5 ms and 45.0 ms TG edges) and r7b_ratios.png (explanatory ratios).
Usage (from this folder): python3 r7b_plots.py R6D_ideal=... R7A_a2=... C0=... C1=... C2=...
C0 is drawn only in the metric figure: its waves are identical to R6D_ideal (same netlist, see report)."""
import sys, csv, importlib.util
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

spec = importlib.util.spec_from_file_location('b', 'r7b_analysis.py'); b = importlib.util.module_from_spec(spec); spec.loader.exec_module(b)
F = dict(a.split('=', 1) for a in sys.argv[1:])
STY = {'R6D_ideal': dict(color='#8c8c8c', ls='--', lw=1.8, label='R6D-R ideal CMFB (= C0)'),
       'R7A_a2': dict(color='#0072B2', ls='-', lw=2.4, label='R7A a2 MOS CMFB'),
       'C1': dict(color='#D55E00', ls=':', lw=2.0, label='C1: ideal CMFB + 67.4 fF on op/on'),
       'C2': dict(color='#009E73', ls='-', lw=1.2, label='C2: ideal CMFB + 134.8 fF (bracket)')}
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.alpha': 0.3})
fig, ax = plt.subplots(3, 2, figsize=(12, 10), constrained_layout=True)
for name in ('R6D_ideal', 'C2', 'R7A_a2', 'C1'):
    d = b.r7a.load(F[name]); t = d['t_s']; s = STY[name]
    tn, e, _ = b.dm_error(d, 0.04, 0.06)
    for col, te in ((0, 0.0425), (1, 0.0450)):
        m = (tn >= te - 10e-6) & (tn <= te + 245e-6)
        ax[0, col].plot((tn[m] - te) * 1e6, e[m] * 1e3, **s)
        m = (t >= te - 0.3e-6) & (t <= te + 2e-6)
        cm = (d['op_V'] + d['on_V']) / 2
        ax[1, col].plot((t[m] - te) * 1e6, (cm[m] - 0.9) * 1e3, **s)
        m = (t >= te - 1e-6) & (t <= te + 40e-6)
        ax[2, col].plot((t[m] - te) * 1e6, d['vg_V'][m], **s)
for col, te in ((0, 42.5), (1, 45.0)):
    ax[0, col].set(title='DM error fp-fn minus its 100/200/300 Hz fit, TG edge at %.1f ms' % te, xlabel='t - edge (us)', ylabel='mV')
    ax[1, col].set(title='op/on common mode - 0.9 V at the %.1f ms edge' % te, xlabel='t - edge (us)', ylabel='mV')
    ax[2, col].set(title='vg (CMFB output) at the %.1f ms edge' % te, xlabel='t - edge (us)', ylabel='V')
ax[0, 0].legend(frameon=False, fontsize=8, loc='lower right')
fig.savefig('r7b_edges.png', dpi=140)

# explanatory ratios (40-60 ms window)
R = [r for r in csv.DictReader(open('r7b_ratios.csv')) if r['window_ms'] == '40-60']
lab = {'Hpre_edge_err_max_mV': 'DM edge error max', 'Hpre_resid_rms_uV': 'DM residual RMS', 'Hpre_edge_err_mean_mV': 'DM edge error mean',
       'Hpre_gain': '100 Hz gain Hpre', 'edges_imm_peak_mV_mean': 'edge 0-2 us peak', 'edges_early_mean_abs_mV_mean': 'edge 2-40 us |e|',
       'edges_late_plateau_abs_mV_mean': 'edge 40-200 us plateau', 'opon_cm_edge_pos_mV': 'op/on CM edge spike +', 'opon_cm_200Hz_uV': 'op/on CM 200 Hz'}
fig, axr = plt.subplots(figsize=(9, 4.2), constrained_layout=True)
y = np.arange(len(R)); h = 0.38
f1 = [float(r['F_C1']) for r in R]; f2 = [float(r['F_C2']) for r in R]
axr.barh(y - h / 2, f1, h, color='#D55E00', label='F(C1) = (C1 - C0)/(R7A - R6D)')
axr.barh(y + h / 2, f2, h, color='#009E73', label='F(C2), 2x bracket (not used for attribution)')
axr.axvspan(0.6, 1.4, color='#D55E00', alpha=0.08, lw=0); axr.axvline(1.0, color='#444', lw=0.8)
for yi, v in zip(y, f1):
    axr.text(min(v, 5.6) + 0.05, yi - h / 2, '%.3f' % v, va='center', fontsize=8)
axr.set_yticks(y, [lab[r['metric']] for r in R]); axr.invert_yaxis()
axr.set(xlim=(0, 6), xlabel='explanatory ratio F (1 = C alone reproduces the R7A - R6D change); shaded 0.6-1.4 = registered "strong" band',
        title='R7B: how much of the R7A vs R6D change a passive 67.4 fF on op/on reproduces (40-60 ms window)')
axr.legend(frameon=False, fontsize=8, loc='upper right')
fig.savefig('r7b_ratios.png', dpi=140)
print('wrote r7b_edges.png r7b_ratios.png')
