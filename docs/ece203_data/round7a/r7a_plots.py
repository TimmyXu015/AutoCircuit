#!/usr/bin/env python3
"""R7A figures: r7a_stage2.png (standalone detector) and r7a_stage3.png (integrated 2 kHz chopper transient).
Usage (from this folder): python3 r7a_plots.py IDEAL_TRAN.csv.gz A2_TRAN.csv.gz"""
import sys, csv, importlib.util
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

C_OLD, C_NEW, C_IDEAL = '#D55E00', '#0072B2', '#6b6b6b'      # Okabe-Ito orange / blue, neutral grey for the ideal reference
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True,
                     'grid.alpha': 0.3, 'lines.linewidth': 1.6})

def ecurve(v):
    r = list(csv.DictReader(open('r7a_det_e_%s.csv' % v)))
    return {k: np.array([float(x[k]) for x in r]) for k in r[0]}

# ---------- Stage 2 ----------
old, a2 = ecurve('old'), ecurve('a2')
summ = {r['variant']: r for r in csv.DictReader(open('r7a_det_summary.csv'))}
fig, ax = plt.subplots(1, 3, figsize=(12, 3.6), constrained_layout=True)
ax[0].plot(old['vd_V'], old['e_vcm900_mV'], color=C_OLD, label='old DD-pair (R6A)')
ax[0].plot(a2['vd_V'], a2['e_vcm900_mV'], color=C_NEW, label='candidate A, a2')
ax[0].axhspan(-0.4, 0.4, color=C_NEW, alpha=0.08, lw=0); ax[0].text(-0.19, 0.45, 'S4 gate +-0.4 mV at |Vd| = 0.1 V', fontsize=8)
ax[0].set(title='(a) DM-to-CM error, Vcm = 0.90 V', xlabel='Vd = OP - ON (V)', ylabel='equivalent CM error e (mV)')
ax[0].legend(frameon=False, loc='lower center')
for vc, ls in ((880, '-'), (920, '--')):
    ax[1].plot(old['vd_V'], old['e_vcm%d_mV' % vc], color=C_OLD, ls=ls, label='old, Vcm 0.%d' % (vc // 10))
    ax[1].plot(a2['vd_V'], a2['e_vcm%d_mV' % vc], color=C_NEW, ls=ls, label='a2, Vcm 0.%d' % (vc // 10))
ax[1].set(title='(b) same with a +-20 mV CM imbalance', xlabel='Vd (V)', ylabel='e (mV)')
ax[1].legend(frameon=False, fontsize=8, ncol=2, loc='lower left')
names = ['old', 'a0', 'a1', 'a2']
x = np.arange(4); y = [float(summ[n]['Vcm0_minus_0p9_mV']) for n in names]
cols = [C_OLD, C_NEW, C_NEW, C_NEW]
ax[2].bar(x, y, color=cols, width=0.6)
ax[2].axhspan(-1, 1, color='#009E73', alpha=0.15, lw=0); ax[2].text(2.35, 2, 'S3 gate +-1 mV', fontsize=8)
for xi, yi in zip(x, y):
    ax[2].text(xi, yi + (3 if yi >= 0 else -3), '%+.2f' % yi, ha='center', va='bottom' if yi >= 0 else 'top', fontsize=8)
ax[2].set_xticks(x, ['old DD', 'a0\nMD 2.085u', 'a1\nMD 2.95u', 'a2\nMD 2.932u'])
ax[2].set(title='(c) DC zero: predicted Vcm0 - 0.9 V', ylabel='mV', ylim=(-30, 85))
fig.savefig('r7a_stage2.png', dpi=150)

# ---------- Stage 3 ----------
spec = importlib.util.spec_from_file_location('a', 'r7a_sys_analysis.py'); a = importlib.util.module_from_spec(spec); spec.loader.exec_module(a)
D = {'ideal CMFB (R6D-R)': (a.load(sys.argv[1]), C_IDEAL), 'MOS CMFB a2 (R7A)': (a.load(sys.argv[2]), C_NEW)}
fig, ax = plt.subplots(2, 2, figsize=(12, 7), constrained_layout=True)
for lab, (d, c) in D.items():
    t = d['t_s']; cm = (d['op_V'] + d['on_V']) / 2
    m = (t >= 0.040) & (t <= 0.050)
    ax[0, 0].plot(t[m] * 1e3, (cm[m] - 0.9) * 1e3, color=c, lw=0.8, label=lab)
    m = (t >= 0.0425 - 0.3e-6) & (t <= 0.0425 + 2e-6)
    ax[0, 1].plot((t[m] - 0.0425) * 1e6, (cm[m] - 0.9) * 1e3, color=c, label=lab)
    m = (t >= 0.040) & (t <= 0.050)
    ax[1, 0].plot(t[m] * 1e3, d['vg_V'][m], color=c, lw=0.8, label=lab)
    w0, w1 = 0.04, 0.06; tt = np.arange(w0, w1, 1e-6); v = d['fp_V'] - d['fn_V']
    cc, _ = a.fit(tt, np.interp(tt, t, v)); sel = (t >= 0.0425 - 5e-6) & (t <= 0.0425 + 245e-6); tn = t[sel]
    f = cc[0] + cc[1] * tn + sum(cc[2 * k] * np.sin(2 * np.pi * k * 100 * tn) + cc[2 * k + 1] * np.cos(2 * np.pi * k * 100 * tn) for k in (1, 2, 3))
    ax[1, 1].plot((tn - 0.0425) * 1e6, (v[sel] - f) * 1e3, color=c, label=lab)
ax[0, 0].set(title='(a) op/on CM - 0.9 V, 40-50 ms (TG edges every 250 us)', xlabel='t (ms)', ylabel='mV')
ax[0, 1].set(title='(b) op/on CM at the TG edge t = 42.5 ms (DM near its peak)', xlabel='t - 42.5 ms (us)', ylabel='mV')
ax[1, 0].set(title='(c) vg (PMOS load gates = CMFB output)', xlabel='t (ms)', ylabel='V')
ax[1, 1].set(title='(d) fp - fn minus its 100/200/300 Hz fit, edge at 42.5 ms', xlabel='t - 42.5 ms (us)', ylabel='mV')
for x_ in ax.flat:
    x_.legend(frameon=False, fontsize=8)
fig.savefig('r7a_stage3.png', dpi=150)
print('wrote r7a_stage2.png r7a_stage3.png')
