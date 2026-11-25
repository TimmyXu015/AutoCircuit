"""Figures for the F2 1 uA interference test. Usage: F2I_RAW=<raw dir> python3 f2i_figs.py <stop, e.g. 10>. Needs f2i_tran_summary.csv
(f2i_analysis.py) in the working directory. Writes fig_f2i_*.png."""
import os, sys, csv, gzip
import numpy as np, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
R = os.environ.get('F2I_RAW', 'raw'); ST = sys.argv[1] if len(sys.argv) > 1 else '10'
C = {'0': '#2a78d6', '100n': '#eb6834', '1u': '#1baf7a'}; INK = '#3a3a38'; GRID = '#e4e3de'
plt.rcParams.update({'font.size': 9, 'axes.edgecolor': GRID, 'axes.labelcolor': INK, 'xtick.color': INK, 'ytick.color': INK,
                     'axes.grid': True, 'grid.color': GRID, 'grid.linewidth': 0.6, 'axes.spines.top': False, 'axes.spines.right': False,
                     'lines.linewidth': 1.4, 'legend.frameon': False})
def load(fn):
    with gzip.open(fn, 'rt') as fh:
        r = csv.reader(fh); h = next(r); a = np.array([[float(x) for x in row] for row in r])
    d = {k: a[:, i] for i, k in enumerate(h)}; keep = np.concatenate([[True], np.diff(d['t_s']) > 0]); return {k: v[keep] for k, v in d.items()}
def have(tag, kind=''): return os.path.exists(f'{R}/{tag}_{ST}s_tran{kind}.csv.gz')
st = float(ST)
# 1) waveforms, last 0.3 s (3 ECG periods, 18 interference periods)
cases = [('T0', '0', 'ECG + 0'), ('T100n', '100n', 'ECG + 100 nA'), ('T1u', '1u', 'ECG + 1 µA')]
sig = [('out_V', 'out (final LPF output) [V]'), ('oa1_V', 'oa1 (OTA1 out) [V]'), ('oa_V', 'oa (CS out) [V]'),
       ('drlr_V', 'drlr (DRL OTA out) [V]'), ('body_V', 'body [V]'), ('elcm', 'electrode CM (vRight+vLeft)/2 [V]'), ('I_IPRD_A', 'DRL drive current [µA]')]
fig, ax = plt.subplots(len(sig), 1, figsize=(8, 12), sharex=True)
for tag, k, lab in cases:
    if not have(tag): continue
    d = load(f'{R}/{tag}_{ST}s_tran.csv.gz'); s = d['t_s'] >= st - 0.3; t = d['t_s'][s] - (st - 0.3)
    d['elcm'] = (d['vRight_V'] + d['vLeft_V']) / 2
    for a, (n, yl) in zip(ax, sig):
        y = d[n][s] * (1e6 if n == 'I_IPRD_A' else 1); a.plot(t * 1e3, y, color=C[k], label=lab); a.set_ylabel(yl, fontsize=8)
for a, (n, _) in zip(ax, sig):
    if n.endswith('_V') or n == 'elcm':
        for v in (0, 1.8): a.axhline(v, color='#9a9992', lw=0.8, ls=(0, (3, 3)))
ax[0].legend(ncol=3, loc='upper center', bbox_to_anchor=(0.5, 1.35)); ax[-1].set_xlabel(f'time from t = {st - 0.3:g} s [ms]')
fig.suptitle(f'F2 in instructor ECG_tb, last 0.3 s of {ST} s transient (dashed: 0 V / 1.8 V rails)', fontsize=10, color=INK)
fig.tight_layout(); fig.savefig('fig_f2i_waveforms.png', dpi=150); plt.close(fig)
# 2) whole-run out trend (1 ms), settling
fig, ax = plt.subplots(2, 1, figsize=(8, 5), sharex=True)
for tag, k, lab in cases + [('I100n', '100n', 'interference 100 nA only'), ('I1u', '1u', 'interference 1 µA only')]:
    if not have(tag, '1ms'): continue
    d = load(f'{R}/{tag}_{ST}s_tran1ms.csv.gz'); ls = '-' if tag.startswith('T') else (0, (2, 2))
    a = ax[0] if tag.startswith('T') else ax[1]; a.plot(d['t_s'], d['out_V'], color=C[k], lw=0.7, ls=ls, label=lab)
for a in ax: a.set_ylabel('out [V]'); a.legend(fontsize=8, ncol=3)
ax[1].set_xlabel('time [s]'); fig.suptitle(f'Final output over the whole {ST} s run (1 ms grid)', fontsize=10, color=INK)
fig.tight_layout(); fig.savefig('fig_f2i_out_trend.png', dpi=150); plt.close(fig)
# 3) gain per case, last window, vs the 38-42 dB band
rows = [r for r in csv.DictReader(open('f2i_tran_summary.csv')) if r['case'].endswith(f'_{ST}s') and r['window'] == f'{st - 1:g}-{st:g}'
        and r['Gpost_dB'] not in ('', 'nan') and not r['case'].startswith(('S', 'I'))]
if rows:
    fig, a = plt.subplots(figsize=(7, 3)); a.axhspan(38, 42, color='#cde2fb', lw=0)
    x = np.arange(len(rows)); g = [float(r['Gpost_dB']) for r in rows]
    a.bar(x, g, width=0.5, color='#2a78d6')
    for i, v in enumerate(g): a.text(i, v + (0.8 if v >= 0 else -2.5), '%.2f dB' % v, ha='center', fontsize=8, color=INK)
    a.set_xticks(x, [r['case'].replace(f'_{ST}s', '') for r in rows]); a.set_ylabel('10 Hz Gpost [dB]'); a.axhline(0, color=INK, lw=0.6)
    a.set_title(f'Mixed-run 10 Hz fundamental gain, window {st - 1:g}-{st:g} s (shaded: 38-42 dB)', fontsize=10, color=INK)
    fig.tight_layout(); fig.savefig('fig_f2i_gain.png', dpi=150); plt.close(fig)
print('figs done')
