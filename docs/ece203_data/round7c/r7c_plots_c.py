#!/usr/bin/env python3
"""R7C Stage C figure r7c_stageC.png: C0 (R7A a2, ideal Rfb, reused raw wave) vs C1 (pfet33x pseudo-R 4u/2u), 2 kHz TG, 1 mV 100 Hz DM.
Panels: fp-fn over 40-60 ms; DM error (minus 100/200/300 Hz fit) at the 45.0 ms TG edge; pseudo-R voltages V(A)-V(B) for both sides;
(p+n)/2 OTA-input-node CM vs time with a linear fit (slow rectification drift).
Usage: python3 r7c_plots_c.py C0=... C1=..."""
import sys, os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'round7a'))
from r7a_sys_analysis import load, fit
F = dict(a.split('=', 1) for a in sys.argv[1:])
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.alpha': 0.3})
STY = {'C0': dict(color='#8c8c8c', ls='--', lw=1.8, label='C0 ideal 3.1831 TOhm (R7A a2)'), 'C1': dict(color='#0072B2', ls='-', lw=1.4, label='C1 pfet33x pseudo-R 4u/2u')}
D = {k: load(v) for k, v in F.items()}
fig, ax = plt.subplots(2, 2, figsize=(12, 8), constrained_layout=True)
for k, d in D.items():
    t = d['t_s']; s = (t >= 0.04) & (t <= 0.06); v = d['fp_V'] - d['fn_V']
    ax[0, 0].plot(t[s] * 1e3, v[s] * 1e3, **STY[k])
    tt = np.arange(0.04, 0.06, 1e-6); c, _ = fit(tt, np.interp(tt, t, v))
    e = v[s] - (c[0] + c[1] * t[s] + sum(c[2 * j] * np.sin(2 * np.pi * j * 100 * t[s]) + c[2 * j + 1] * np.cos(2 * np.pi * j * 100 * t[s]) for j in (1, 2, 3)))
    te = 0.045; m = (t[s] >= te - 10e-6) & (t[s] <= te + 245e-6)
    ax[0, 1].plot((t[s][m] - te) * 1e6, e[m] * 1e3, **STY[k])
d = D['C1']; t = d['t_s']; s = (t >= 0.04) & (t <= 0.06)
ax[1, 0].plot(t[s] * 1e3, (d['n_V'] - d['fp_V'])[s] * 1e3, color='#0072B2', lw=1.2, label='XPRN: V(n) - V(fp)')
ax[1, 0].plot(t[s] * 1e3, (d['p_V'] - d['fn_V'])[s] * 1e3, color='#D55E00', lw=1.0, ls='--', label='XPRP: V(p) - V(fn)')
cm = (d['p_V'] + d['n_V']) / 2; tt = np.arange(0.002, 0.06, 1e-6); y = np.interp(tt, t, cm)
w = 2.5e-3; k = int(round(w / 1e-6)); ym = np.convolve(y, np.ones(k) / k, mode='valid'); tm = tt[k // 2: k // 2 + ym.size]
ax[1, 1].plot(tm * 1e3, (ym - 0.9) * 1e3, color='#0072B2', lw=1.4, label='(p+n)/2, 2.5 ms (5 TG periods) moving mean')
sel = tt >= 0.01; p = np.polyfit(tt[sel], y[sel], 1)
ax[1, 1].plot(tt[sel] * 1e3, (np.polyval(p, tt[sel]) - 0.9) * 1e3, color='#D55E00', lw=1.4, ls='--', label='linear fit 10-60 ms: %.2f mV/s' % (p[0] * 1e3))
ax[0, 0].set(title='Hpre output fp - fn (40-60 ms)', xlabel='t (ms)', ylabel='mV'); ax[0, 0].legend(frameon=False, fontsize=8, loc='lower right')
ax[0, 1].set(title='DM error (fp-fn minus 100/200/300 Hz fit) at the 45.0 ms TG edge', xlabel='t - edge (us)', ylabel='mV')
ax[1, 0].set(title='C1 pseudo-R voltage V(A) - V(B)', xlabel='t (ms)', ylabel='mV'); ax[1, 0].legend(frameon=False, fontsize=8)
ax[1, 1].set(title='C1 OTA-input-node CM (p+n)/2 - 0.9 V', xlabel='t (ms)', ylabel='mV'); ax[1, 1].legend(frameon=False, fontsize=8)
fig.savefig('r7c_stageC.png', dpi=140)
