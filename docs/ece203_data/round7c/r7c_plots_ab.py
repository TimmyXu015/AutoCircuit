#!/usr/bin/env python3
"""R7C figures for Stage A and B: r7c_stageA.png (pfet33x W4/L2 pseudo-R I-V, small-signal and secant R vs V(A)-V(B))
and r7c_stageB.png (TG-static DM AC |Hpre| C0 ideal 3.1831 TOhm vs C1 pseudo-R, low-frequency corner and the 100 Hz plateau).
Usage (from this folder): python3 r7c_plots_ab.py"""
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.alpha': 0.3})
C0 = dict(color='#8c8c8c', ls='--', lw=1.8); C1 = dict(color='#0072B2', ls='-', lw=2.0)
A = [r for r in csv.DictReader(open('A_pr_iv_w4.csv'))]
v = np.array([float(r['vd_mV']) for r in A]); I = np.array([float(r['I_A_into_A']) for r in A])
rac = np.array([float(r['r_ac_ohm']) for r in A]); rs = np.array([float(r['r_secant_ohm']) if r['r_secant_ohm'] != 'n/a' else np.nan for r in A])
fig, ax = plt.subplots(1, 2, figsize=(11, 4), constrained_layout=True)
ax[0].plot(v, I * 1e15, 'o-', **{k: C1[k] for k in ('color', 'lw')})
ax[0].plot(v, v * 1e-3 / 3.1831e12 * 1e15, color='#8c8c8c', ls='--', lw=1.5, label='ideal 3.1831 TOhm')
ax[0].set(xlabel='V(A) - V(B) (mV), CM 0.9 V', ylabel='I into A (fA)', title='pfet33x pseudo-R W 4u / L 2u: DC I-V'); ax[0].legend(frameon=False)
ax[1].semilogy(v, rac, 'o-', color='#0072B2', lw=2, label='small-signal 1/g_ac')
ax[1].semilogy(v, rs, 's-', color='#D55E00', lw=1.5, label='secant V/I')
ax[1].axhline(3.1831e12, color='#8c8c8c', ls='--', lw=1.5, label='target 3.1831 TOhm')
ax[1].set(xlabel='V(A) - V(B) (mV)', ylabel='Ohm', title='resistance vs bias (gmin = iabstol = 1e-18, reltol 1e-6)'); ax[1].legend(frameon=False)
fig.savefig('r7c_stageA.png', dpi=140)

fig, ax = plt.subplots(1, 2, figsize=(11, 4), constrained_layout=True)
for fn, s, lab in (('raw/stageB/B_ideal_dm_ac.csv', C0, 'C0 ideal 3.1831 TOhm (R7A a2)'), ('raw/stageB/B_pr_w4_dm_ac.csv', C1, 'C1 pfet33x pseudo-R 4u/2u')):
    d = np.genfromtxt(fn, delimiter=',', names=True)
    f = d['f_Hz']; h = d['abs_Hpre']; h100 = np.interp(np.log10(100), np.log10(f), h)
    ax[0].semilogx(f, 20 * np.log10(h / h100), label=lab, **s)
    ax[1].semilogx(f, h, label=lab, **s)
ax[0].axhline(-3, color='#555', lw=0.8); ax[0].set(xlim=(1e-3, 10), ylim=(-30, 1), xlabel='f (Hz)', ylabel='|Hpre| / |Hpre(100 Hz)| (dB)', title='high-pass corner (TG static phase A)')
ax[0].legend(frameon=False, loc='lower right')
ax[1].set(xlim=(1, 2e4), ylim=(85, 96), xlabel='f (Hz)', ylabel='|Hpre| (V/V)', title='mid-band plateau'); ax[1].legend(frameon=False, loc='lower left')
fig.savefig('r7c_stageB.png', dpi=140)
