#!/usr/bin/env python3
"""R7D figures. r7d_stageB.png: TG-static DM AC |Hpre| C0 (R7C, ideal IB/IBD) vs C1 (IREF + PMOS mirrors) and the bias
branch currents. r7d_stageC.png (if C waves are given): DM error at the 45.0 ms TG edge, op/on CM at the edge, ib / pref at
the edge, MP1/MP2 drain current around the edge. Usage: python3 r7d_plots.py [C0=r7c_tran.csv.gz C1=r7d_tran.csv.gz]"""
import sys, os, csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
here = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(here, '..', 'round7a'))
from r7a_sys_analysis import load, fit
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.alpha': 0.3})
S0 = dict(color='#8c8c8c', ls='--', lw=1.8, label='C0 R7C: ideal IB/IBD 50 nA'); S1 = dict(color='#0072B2', ls='-', lw=1.4, label='C1 R7D a0: IREF 100 nA + PMOS mirrors')
fig, ax = plt.subplots(1, 3, figsize=(14, 4), constrained_layout=True)
for fn, s in (('../round7c/raw/stageB/B_pr_w4_dm_ac.csv', S0), ('raw/stageB/B_bias_a0_dm_ac.csv', S1)):
    d = np.genfromtxt(fn, delimiter=',', names=True); f = d['f_Hz']; h = d['abs_Hpre']; h100 = np.interp(2.0, np.log10(f), h)
    ax[0].semilogx(f, 20 * np.log10(h / h100), **s); ax[1].semilogx(f, h, **s)
ax[0].axhline(-3, color='#555', lw=0.8); ax[0].set(xlim=(1e-3, 10), ylim=(-30, 1), xlabel='f (Hz)', ylabel='|Hpre|/|Hpre(100 Hz)| (dB)', title='high-pass corner (TG static phase A)')
ax[1].set(xlim=(1, 3e4), ylim=(85, 96), xlabel='f (Hz)', ylabel='|Hpre| (V/V)', title='mid-band plateau'); ax[1].legend(frameon=False, loc='lower left', fontsize=8)
A = {r['case']: r for r in csv.DictReader(open('raw/stageA/A_a0.csv'))}
lab = ['IREF', 'MP0', 'MP1 -> ib', 'MP2 -> ibd', 'XA.MREF', 'XD.MREF']
c1 = A['C1_a0']; v1 = [abs(float(c1[k])) * 1e9 for k in ('I_IREF', 'MP0_id', 'MP1_id', 'MP2_id', 'XA_MREF_id', 'XD_MREF_id')]
c0 = A['C0_r7c']; v0 = [np.nan, np.nan, abs(float(c0['I_IB_ideal'])) * 1e9, abs(float(c0['I_IBD_ideal'])) * 1e9, float(c0['XA_MREF_id']) * 1e9, float(c0['XD_MREF_id']) * 1e9]
x = np.arange(len(lab)); ax[2].bar(x - 0.2, v0, 0.38, color='#8c8c8c', label='C0 (IB/IBD ideal)'); ax[2].bar(x + 0.2, v1, 0.38, color='#0072B2', label='C1 a0')
for xi, v in zip(x, v1): ax[2].text(xi + 0.2, v + 1.5, '%.2f' % v, ha='center', fontsize=7)
ax[2].axhspan(45, 55, color='#009E73', alpha=0.08); ax[2].set(xticks=x, xticklabels=lab, ylabel='nA', title='bias branch DC currents (gate 45-55 nA on MP1/MP2)')
ax[2].tick_params(axis='x', labelsize=7); ax[2].legend(frameon=False, fontsize=8)
fig.savefig('r7d_stageB.png', dpi=140)

F = dict(a.split('=', 1) for a in sys.argv[1:])
if 'C0' in F and 'C1' in F:
    D = {'C0': load(F['C0']), 'C1': load(F['C1'])}; te = 0.045
    fig, ax = plt.subplots(2, 2, figsize=(12, 8), constrained_layout=True)
    for k, s in (('C0', S0), ('C1', S1)):
        d = D[k]; t = d['t_s']; sel = (t >= 0.04) & (t <= 0.06); v = d['fp_V'] - d['fn_V']
        tt = np.arange(0.04, 0.06, 1e-6); c, _ = fit(tt, np.interp(tt, t, v)); ts = t[sel]
        e = v[sel] - (c[0] + c[1] * ts + sum(c[2 * j] * np.sin(2 * np.pi * j * 100 * ts) + c[2 * j + 1] * np.cos(2 * np.pi * j * 100 * ts) for j in (1, 2, 3)))
        m = (ts >= te - 10e-6) & (ts <= te + 245e-6); ax[0, 0].plot((ts[m] - te) * 1e6, e[m] * 1e3, **s)
        m = (t >= te - 0.3e-6) & (t <= te + 3e-6); ax[0, 1].plot((t[m] - te) * 1e6, ((d['op_V'] + d['on_V']) / 2 - 0.9)[m] * 1e3, **s)
    d = D['C1']; t = d['t_s']; m = (t >= te - 2e-6) & (t <= te + 40e-6)
    if 'ib_V' in d:
        ax[1, 0].plot((t[m] - te) * 1e6, (d['ib_V'][m] - d['ib_V'][m][0]) * 1e3, color='#0072B2', lw=1.4, label='V(ib) - pre-edge')
        ax[1, 0].plot((t[m] - te) * 1e6, (d['ibd_V'][m] - d['ibd_V'][m][0]) * 1e3, color='#009E73', lw=1.2, ls='--', label='V(ibd) - pre-edge')
        ax[1, 0].plot((t[m] - te) * 1e6, (d['pref_V'][m] - d['pref_V'][m][0]) * 1e3, color='#D55E00', lw=1.2, ls=':', label='V(pref) - pre-edge')
    for k, c, l in (('i_mp1_d_A', '#0072B2', 'MP1 drain'), ('i_mp2_d_A', '#009E73', 'MP2 drain'), ('i_iref_A', '#D55E00', 'IREF')):
        if k in d: ax[1, 1].plot((t[m] - te) * 1e6, np.abs(d[k][m]) * 1e9, color=c, lw=1.3, label=l)
    ax[0, 0].set(title='DM error (fp-fn minus 100/200/300 Hz fit), TG edge 45.0 ms', xlabel='t - edge (us)', ylabel='mV'); ax[0, 0].legend(frameon=False, fontsize=8, loc='lower right')
    ax[0, 1].set(title='op/on CM - 0.9 V at the edge', xlabel='t - edge (us)', ylabel='mV')
    ax[1, 0].set(title='C1 bias nodes at the edge', xlabel='t - edge (us)', ylabel='mV'); ax[1, 0].legend(frameon=False, fontsize=8)
    ax[1, 1].set(title='C1 bias branch currents at the edge (|I|)', xlabel='t - edge (us)', ylabel='nA'); ax[1, 1].legend(frameon=False, fontsize=8)
    fig.savefig('r7d_stageC.png', dpi=140)
