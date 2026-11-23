#!/usr/bin/env python3
"""R7F figures. r7f_static.png: TG-static |Hout| near the upper corner for R7E / L0 / L1 (cc 50p) unloaded and +10 pF, the G0 (cc 60p)
gain plateau vs the 38-42 dB window, and the fH / Hout100 summary. r7f_stageC.png (with C0= R7E tran, C1= R7F tran): 40-60 ms out DM,
DM error at the 45.0 ms TG edge for buf/out, out-DM spectrum. Usage: python3 r7f_plots.py [C0=... C1=...]"""
import sys, os, csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
here = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(here, '..', 'round7a'))
from r7a_sys_analysis import load, fit
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.alpha': 0.3})
S = 'raw/static/'; E = '../round7e/raw/'
cur = [('R7E 31.8M/20p', E + 'stageA/L_lp_a0_dm_ac.csv', E + 'stageB/L_lp_load10p_dm_ac.csv', '#8c8c8c'),
       ('L0 4.77M/133p', S + 'L_lp_l0_dm_ac.csv', S + 'L_lp_l0_load10p_dm_ac.csv', '#E69F00'),
       ('L1 4.0M/148p', S + 'L_lp_l1_dm_ac.csv', S + 'L_lp_l1_load10p_dm_ac.csv', '#0072B2')]
fig, ax = plt.subplots(1, 3, figsize=(15, 4.3), constrained_layout=True)
for lab, a, b, c in cur:
    for fn, ls, sfx in ((a, '-', 'unloaded'), (b, '--', '+10 pF/side')):
        d = np.genfromtxt(fn, delimiter=',', names=True); h = d['abs_Hout']
        ax[0].semilogx(d['f_Hz'], 20 * np.log10(h / h.max()), color=c, ls=ls, lw=1.6, label='%s %s' % (lab, sfx))
ax[0].axhline(-3, color='#555', lw=0.8); ax[0].axvspan(225, 275, color='#009E73', alpha=0.08)
ax[0].set(xlim=(50, 1000), ylim=(-8, 0.5), xlabel='f (Hz)', ylabel='|Hout| / plateau (dB)', title='Stage A: LP upper corner (cc 50 pF)'); ax[0].legend(frameon=False, fontsize=7, loc='lower left')
for lab, fn, c, ls in (('R7E lp_a0 (cc 50p, unloaded)', E + 'stageA/L_lp_a0_dm_ac.csv', '#8c8c8c', '--'), ('L1 cc 50p +10 pF', S + 'L_lp_l1_load10p_dm_ac.csv', '#0072B2', ':'),
                       ('G0 cc 60p +10 pF', S + 'L_gain_g0_load10p_dm_ac.csv', '#D55E00', '-'), ('G0 cc 60p unloaded', S + 'L_gain_g0_unloaded_dm_ac.csv', '#009E73', '-.')):
    d = np.genfromtxt(fn, delimiter=',', names=True); ax[1].semilogx(d['f_Hz'], 20 * np.log10(d['abs_Hout']), color=c, ls=ls, lw=1.6, label=lab)
ax[1].axhspan(38, 42, color='#009E73', alpha=0.08); ax[1].set(xlim=(1e-3, 1e4), ylim=(20, 43), xlabel='f (Hz)', ylabel='|Hout| (dB)', title='Stage B: gain (band 38-42 dB)')
ax[1].legend(frameon=False, fontsize=7, loc='lower center')
R = {r['case']: r for r in csv.DictReader(open('r7f_static_summary.csv'))}
names = ['R7E_lp_a0', 'R7E_lp_load10p', 'lp_l0', 'lp_l0_load10p', 'lp_l1', 'lp_l1_load10p', 'gain_g0_unloaded', 'gain_g0_load10p']
names = [n for n in names if n in R]; x = np.arange(len(names))
fh = [float(R[n]['LP_fH_flat']) for n in names]; g = [float(R[n]['Hout100_dB']) for n in names]
ax[2].bar(x, fh, color=['#8c8c8c' if 'R7E' in n else '#E69F00' if 'l0' in n else '#0072B2' if 'l1' in n else '#D55E00' for n in names])
for xi, v, gg in zip(x, fh, g): ax[2].text(xi, v + 3, '%.1f Hz\n%.2f dB' % (v, gg), ha='center', fontsize=6.5)
ax[2].axhspan(225, 275, color='#009E73', alpha=0.1); ax[2].set(xticks=x, ylim=(0, 300), ylabel='fH_flat (Hz)', title='fH_flat (bars) and Hout(100 Hz) in dB (labels)')
ax[2].set_xticklabels([n.replace('_', '\n') for n in names], fontsize=6.5)
fig.savefig('r7f_static.png', dpi=140)

F = dict(a.split('=', 1) for a in sys.argv[1:])
if 'C0' in F and 'C1' in F:
    c0 = load(F['C0']); c1 = load(F['C1']); fig, ax = plt.subplots(1, 3, figsize=(15, 4.3), constrained_layout=True)
    for d, c, l in ((c0, '#8c8c8c', 'R7E lp_a0 (cc 50p, unloaded)'), (c1, '#D55E00', 'R7F G0 (cc 60p, L1, +10 pF)')):
        t = d['t_s']; s = (t >= 0.04) & (t <= 0.06); ax[0].plot(t[s] * 1e3, (d['outp_V'] - d['outn_V'])[s] * 1e3, color=c, lw=1.5, label=l)
    ax[0].set(title='chopped 100 Hz, 1 mV DM: outp - outn (40-60 ms)', xlabel='t (ms)', ylabel='mV'); ax[0].legend(frameon=False, fontsize=8, loc='lower right')
    te = 0.045
    def err(d, k1, k2):
        t = d['t_s']; v = d[k1] - d[k2]; tt = np.arange(0.04, 0.06, 1e-6); c, _ = fit(tt, np.interp(tt, t, v)); sl = (t >= 0.04) & (t <= 0.06); ts = t[sl]
        e = v[sl] - (c[0] + c[1] * ts + sum(c[2 * j] * np.sin(2 * np.pi * j * 100 * ts) + c[2 * j + 1] * np.cos(2 * np.pi * j * 100 * ts) for j in (1, 2, 3)))
        m = (ts >= te - 10e-6) & (ts <= te + 245e-6); return (ts[m] - te) * 1e6, e[m] * 1e3
    for d, k1, k2, c, ls, l in ((c0, 'bufp_V', 'bufn_V', '#8c8c8c', '--', 'R7E buf'), (c1, 'bufp_V', 'bufn_V', '#0072B2', '-', 'R7F buf'),
                                (c0, 'outp_V', 'outn_V', '#8c8c8c', ':', 'R7E out'), (c1, 'outp_V', 'outn_V', '#D55E00', '-', 'R7F out')):
        xx, yy = err(d, k1, k2); ax[1].plot(xx, yy, color=c, ls=ls, lw=1.4, label=l)
    ax[1].set(title='DM error (minus 100/200/300 Hz fit), 45.0 ms TG edge', xlabel='t - edge (us)', ylabel='mV'); ax[1].legend(frameon=False, fontsize=8)
    tt = np.arange(0.04, 0.06, 1e-6)
    for d, c, l in ((c0, '#8c8c8c', 'R7E out DM'), (c1, '#D55E00', 'R7F out DM')):
        y = np.interp(tt, d['t_s'], d['outp_V'] - d['outn_V']); Y = np.abs(np.fft.rfft(y)) / len(y) * 2; fr = np.fft.rfftfreq(len(y), 1e-6)
        ax[2].loglog(fr[1:], Y[1:] * 1e6, color=c, lw=0.9, label=l)
    ax[2].set(xlim=(50, 5e5), ylim=(1e-3, 1e5), title='out DM spectrum 40-60 ms (rect, 50 Hz bins)', xlabel='f (Hz)', ylabel='uV'); ax[2].legend(frameon=False, fontsize=8)
    fig.savefig('r7f_stageC.png', dpi=140)
