#!/usr/bin/env python3
"""R7E figures. r7e_stageAB.png: TG-static DM AC |Hbuf| (R7D C0 and R7E), |Hout| unloaded / with 10 pF per side, the LP transfer
H_LP = Hout/Hbuf (magnitude and phase). r7e_stageC.png (with C0=, C1= tran waves): 40-60 ms buf vs out DM, DM error at the 45.0 ms
TG edge for buf and out, out-DM spectrum vs buf-DM spectrum (40-60 ms FFT).
Usage: python3 r7e_plots.py [C0=r7d_tran.csv.gz C1=r7e_tran.csv.gz]"""
import sys, os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
here = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(here, '..', 'round7a'))
from r7a_sys_analysis import load, fit
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.alpha': 0.3})
G = '#8c8c8c'; B = '#0072B2'; O = '#D55E00'; Gr = '#009E73'
d0 = np.genfromtxt('../round7d/raw/stageB/B_bias_a0_dm_ac.csv', delimiter=',', names=True)
a = np.genfromtxt('raw/stageA/L_lp_a0_dm_ac.csv', delimiter=',', names=True); b = np.genfromtxt('raw/stageB/L_lp_load10p_dm_ac.csv', delimiter=',', names=True)
fig, ax = plt.subplots(1, 3, figsize=(15, 4.2), constrained_layout=True)
ax[0].semilogx(d0['f_Hz'], 20 * np.log10(d0['abs_Hbuf']), color=G, ls='--', lw=1.8, label='R7D C0 Hbuf (no LP)')
ax[0].semilogx(a['f_Hz'], 20 * np.log10(a['abs_Hbuf']), color=B, lw=1.2, label='R7E Hbuf')
ax[0].semilogx(a['f_Hz'], 20 * np.log10(a['abs_Hout']), color=O, lw=2.0, label='R7E Hout (outp/outn unloaded)')
ax[0].semilogx(b['f_Hz'], 20 * np.log10(b['abs_Hout']), color=Gr, lw=1.6, ls='-.', label='R7E Hout + 10 pF/side (sensitivity)')
ax[0].axhline(38, color='#555', lw=0.8, ls=':'); ax[0].text(1.2e-3, 38.3, '38 dB course minimum', fontsize=7, color='#555')
ax[0].set(xlim=(1e-3, 1e5), ylim=(0, 42), xlabel='f (Hz)', ylabel='dB (V/V)', title='TG static phase A, DM gain'); ax[0].legend(frameon=False, fontsize=7, loc='lower center')
for d, c, l in ((a, O, 'unloaded'), (b, Gr, '+10 pF/side')):
    ax[1].semilogx(d['f_Hz'], 20 * np.log10(d['abs_Hout']), color=c, lw=1.8, label=l)
ax[1].axvspan(225, 275, color=Gr, alpha=0.08); ax[1].axhline(20 * np.log10(a['abs_Hout'].max()) - 3, color='#555', lw=0.8)
ax[1].set(xlim=(10, 3000), ylim=(20, 40), xlabel='f (Hz)', ylabel='|Hout| (dB)', title='upper corner (band: 225-275 Hz target, line: plateau -3 dB)'); ax[1].legend(frameon=False, fontsize=8)
f = a['f_Hz']; m = (f >= 1) & (f <= 1e4)
ax[2].semilogx(f[m], a['ph_HLP'][m], color=O, lw=1.8, label='H_LP = Hout/Hbuf phase, unloaded')
ax[2].semilogx(f[m], np.degrees(-np.arctan(2 * np.pi * f[m] * 31.8e6 * 20e-12)), color=G, ls='--', lw=1.4, label='ideal 1st order, 250.2 Hz')
ax2 = ax[2].twinx(); ax2.semilogx(f[m], a['abs_HLP'][m], color=B, lw=1.4); ax2.set_ylabel('|H_LP| (blue)'); ax2.spines['top'].set_visible(False)
ax[2].set(xlabel='f (Hz)', ylabel='phase (deg)', title='LP transfer alone'); ax[2].legend(frameon=False, fontsize=7, loc='lower left')
fig.savefig('r7e_stageAB.png', dpi=140)

F = dict(x.split('=', 1) for x in sys.argv[1:])
if 'C0' in F and 'C1' in F:
    c0 = load(F['C0']); c1 = load(F['C1'])
    fig, ax = plt.subplots(2, 2, figsize=(12, 8), constrained_layout=True)
    t = c1['t_s']; s = (t >= 0.04) & (t <= 0.06)
    ax[0, 0].plot(t[s] * 1e3, (c1['bufp_V'] - c1['bufn_V'])[s] * 1e3, color=B, lw=1.0, label='R7E buf DM (bufp-bufn)')
    ax[0, 0].plot(t[s] * 1e3, (c1['outp_V'] - c1['outn_V'])[s] * 1e3, color=O, lw=1.8, label='R7E out DM (outp-outn)')
    ax[0, 0].set(title='chopped 100 Hz, 1 mV DM in (40-60 ms)', xlabel='t (ms)', ylabel='mV'); ax[0, 0].legend(frameon=False, fontsize=8, loc='lower right')
    te = 0.045
    def err(d, k1, k2):
        t = d['t_s']; v = d[k1] - d[k2]; tt = np.arange(0.04, 0.06, 1e-6); c, _ = fit(tt, np.interp(tt, t, v)); sl = (t >= 0.04) & (t <= 0.06); ts = t[sl]
        e = v[sl] - (c[0] + c[1] * ts + sum(c[2 * j] * np.sin(2 * np.pi * j * 100 * ts) + c[2 * j + 1] * np.cos(2 * np.pi * j * 100 * ts) for j in (1, 2, 3)))
        m = (ts >= te - 10e-6) & (ts <= te + 245e-6); return (ts[m] - te) * 1e6, e[m] * 1e3
    for d, k1, k2, c, ls, l in ((c0, 'bufp_V', 'bufn_V', G, '--', 'R7D C0 buf DM'), (c1, 'bufp_V', 'bufn_V', B, '-', 'R7E buf DM'), (c1, 'outp_V', 'outn_V', O, '-', 'R7E out DM')):
        x, y = err(d, k1, k2); ax[0, 1].plot(x, y, color=c, ls=ls, lw=1.5, label=l)
    ax[0, 1].set(title='DM error (minus 100/200/300 Hz fit) at the 45.0 ms TG edge', xlabel='t - edge (us)', ylabel='mV'); ax[0, 1].legend(frameon=False, fontsize=8)
    tt = np.arange(0.04, 0.06, 1e-6)
    for d, k1, k2, c, l in ((c0, 'bufp_V', 'bufn_V', G, 'R7D C0 buf DM'), (c1, 'outp_V', 'outn_V', O, 'R7E out DM')):
        y = np.interp(tt, d['t_s'], d[k1] - d[k2]); Y = np.abs(np.fft.rfft(y)) / len(y) * 2; fr = np.fft.rfftfreq(len(y), 1e-6)
        ax[1, 0].loglog(fr[1:], Y[1:] * 1e6, color=c, lw=0.9, label=l)
    ax[1, 0].set(xlim=(50, 5e5), ylim=(1e-3, 1e5), title='DM spectrum 40-60 ms (rect window, 50 Hz bins)', xlabel='f (Hz)', ylabel='uV (amplitude)'); ax[1, 0].legend(frameon=False, fontsize=8)
    cmo = (c1['outp_V'] + c1['outn_V']) / 2; cmb = (c1['bufp_V'] + c1['bufn_V']) / 2; m = (t >= te - 2e-6) & (t <= te + 20e-6)
    ax[1, 1].plot((t[m] - te) * 1e6, (cmb[m] - cmb[m][0]) * 1e3, color=B, lw=1.2, label='buf CM - pre-edge')
    ax[1, 1].plot((t[m] - te) * 1e6, (cmo[m] - cmo[m][0]) * 1e3, color=O, lw=1.8, label='out CM - pre-edge')
    ax[1, 1].set(title='R7E output common mode at the 45.0 ms edge', xlabel='t - edge (us)', ylabel='mV'); ax[1, 1].legend(frameon=False, fontsize=8)
    fig.savefig('r7e_stageC.png', dpi=140)
