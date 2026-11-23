#!/usr/bin/env python3
"""R8 data products (run from this folder):
r8_static_noise.csv  OFF (Stage A) output PSD, |Hoff|, input-referred PSD, cumulative input RMS from 0.1 Hz
r8_noise_summary.csv OFF noise-source groups per band (via r8_noise_groups.py)
r8_pss_attempts.csv  every shooting iteration of PSS a1 / a2 (Conv norm, largest residual and where)
r8_t0_summary.csv    zero-input chopper-ON 20 ms transient: node ranges and period-to-period change
r8_pac.csv, r8_sideband_convergence.csv: NOT RUN markers (Stage B blocked)
r8_stageA.png, r8_stageB_pss.png"""
import os, re, csv, gzip, subprocess, sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
here = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, here)
import r8_spec
A = 'raw/stageA/A_off'; B = 'raw/stageB/'
f, so, H, H100 = r8_spec.load(A); si = so / H
cum = np.sqrt(np.concatenate([[0.0], np.cumsum(0.5 * (si[1:] ** 2 + si[:-1] ** 2) * np.diff(f))]))
with open('r8_static_noise.csv', 'w', newline='') as fo:
    w = csv.writer(fo, lineterminator='\n'); w.writerow(['f_Hz', 'Sout_V_rtHz', 'absHoff', 'Sin_deemb_V_rtHz', 'cum_in_rms_from_0p1_V'])
    for row in zip(f, so, H, si, cum): w.writerow(['%.6g' % x for x in row])
out_rms = r8_spec.rms(f, so); app = out_rms / H100; de = r8_spec.rms(f, si)
print('OFF: H100 %.4f, out %.4g Vrms, app %.4g uV, deemb %.4g uV' % (H100, out_rms, app * 1e6, de * 1e6))
subprocess.run([sys.executable, 'r8_noise_groups.py', 'r8_noise_summary.csv', 'OFF=' + A], check=True, stdout=subprocess.DEVNULL)
# PSS attempts
rows = []
for att in ('a1', 'a2'):
    txt = gzip.open(B + 'B_pss_%s_spectre.out.gz' % att, 'rt', errors='replace').read()
    ph = 'tstab'
    for k, m in enumerate(re.finditer(r'Conv norm = ([0-9.e+\-]+)\s*(k|M)?, max d([VI])\(([^)]*)\) = ([-0-9.e+]+ ?[a-zA-Z]*), took ([0-9.]+ ?m?s)', txt)):
        v = float(m.group(1)) * {'k': 1e3, 'M': 1e6, None: 1.0}[m.group(2)]
        rows.append({'attempt': att, 'iteration': k, 'conv_norm': v, 'max_d': m.group(3), 'where': m.group(4), 'value': m.group(5), 'took': m.group(6)})
    print(att, 'iterations', sum(r['attempt'] == att for r in rows), 'converged' if re.search(r'pss analysis did not converge', txt) is None else 'NOT CONVERGED')
with open('r8_pss_attempts.csv', 'w', newline='') as fo:
    w = csv.DictWriter(fo, list(rows[0].keys()), lineterminator='\n'); w.writeheader(); [w.writerow(r) for r in rows]
# T0
with gzip.open(B + 'T0_on_zero_tran.csv.gz', 'rt') as fi:
    h = fi.readline().strip().split(','); a = np.loadtxt(fi, delimiter=',')
d = {k: a[:, i] for i, k in enumerate(h)}; t = d['t_s']; s = t > 0.01; t0 = []
for k in ('fp_V', 'fn_V', 'op_V', 'on_V', 'vg_V', 'bufp_V', 'bufn_V', 'outp_V', 'outn_V', 'p_V', 'n_V', 'pref_V', 'ib_V'):
    v = [np.interp(n * 500e-6 + 240e-6, t, d[k]) for n in range(20, 40)]
    t0.append({'node': k[:-2], 'min_10_20ms_V': d[k][s].min(), 'max_10_20ms_V': d[k][s].max(), 'mean_10_20ms_V': d[k][s].mean(),
               'mean_abs_period_change_V': float(np.mean(np.abs(np.diff(v))))})
dm = d['outp_V'] - d['outn_V']
t0.append({'node': 'outp-outn', 'min_10_20ms_V': dm[s].min(), 'max_10_20ms_V': dm[s].max(), 'mean_10_20ms_V': dm[s].mean(), 'mean_abs_period_change_V': ''})
with open('r8_t0_summary.csv', 'w', newline='') as fo:
    w = csv.DictWriter(fo, list(t0[0].keys()), lineterminator='\n'); w.writeheader()
    for r in t0: w.writerow({k: ('%.7g' % v if isinstance(v, float) else v) for k, v in r.items()})
for fn, cols in (('r8_pac.csv', 'f_Hz,absHon,phHon'), ('r8_sideband_convergence.csv', 'maxsideband,out_rms_V,app_in_V,deemb_in_V,in_1Hz,in_10Hz,in_100Hz')):
    open(fn, 'w').write(cols + '\nNOT RUN: Stage B BLOCKED (PSS a1 and a2 not converged), see docs/ECE203_round8_real_mos_chopper_noise_results.md\n')
# figures
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.alpha': 0.3})
fig, ax = plt.subplots(1, 3, figsize=(15, 4.3), constrained_layout=True)
ax[0].loglog(f, so * 1e6, color='#8c8c8c', lw=1.6, label='output outp-outn (uV/rtHz)')
ax[0].loglog(f, si * 1e9, color='#0072B2', lw=2, label='input-referred, de-embedded (nV/rtHz)')
ax[0].set(xlabel='f (Hz)', title='Stage A, chopper OFF (TG static phase A): noise density'); ax[0].legend(frameon=False, fontsize=8)
ax[1].semilogx(f, cum * 1e6, color='#0072B2', lw=2, label='cumulative de-embedded input RMS from 0.1 Hz')
ax[1].axhline(3, color='#D55E00', lw=1.2, ls='--', label='3 uVrms course spec'); ax[1].axhline(app * 1e6, color='#8c8c8c', lw=1, ls=':', label='application-type total %.2f uV' % (app * 1e6))
ax[1].set(xlabel='f (Hz)', ylabel='uVrms', title='OFF input-referred noise, 0.1-250 Hz'); ax[1].legend(frameon=False, fontsize=8)
G = [r for r in csv.DictReader(open('r8_noise_summary.csv')) if r['case'] == 'OFF']
bands = ['0.1-1', '1-10', '10-100', '100-250']; keys = []
for r in G:
    k = r['group'] + (' (1/f)' if r['kind'] == 'flicker' else ' (thermal)')
    if r['band_Hz'] == '0.1-250' and float(r['pct_of_band_out']) > 0.3 and k not in keys: keys.append(k)
bottom = np.zeros(len(bands)); cols = ['#0072B2', '#E69F00', '#56B4E9', '#009E73', '#CC79A7', '#8c8c8c']
for i, k in enumerate(keys + ['all other']):
    vals = []
    for b in bands:
        rs = [r for r in G if r['band_Hz'] == b]; tot = sum(float(r['in_V2_approx']) for r in rs)
        v = sum(float(r['in_V2_approx']) for r in rs if (r['group'] + (' (1/f)' if r['kind'] == 'flicker' else ' (thermal)')) == k) if k != 'all other' else \
            sum(float(r['in_V2_approx']) for r in rs if (r['group'] + (' (1/f)' if r['kind'] == 'flicker' else ' (thermal)')) not in keys)
        vals.append(v * 1e12)
    ax[2].bar(bands, vals, bottom=bottom, color=cols[i % len(cols)], label=k); bottom += np.array(vals)
ax[2].set(ylabel='input-referred power (uV^2, approx. split)', title='OFF noise by source and band'); ax[2].legend(frameon=False, fontsize=7)
fig.savefig('r8_stageA.png', dpi=140)
fig, ax = plt.subplots(1, 2, figsize=(12, 4), constrained_layout=True)
for att, c in (('a1', '#8c8c8c'), ('a2', '#D55E00')):
    rr = [r for r in rows if r['attempt'] == att]
    ax[0].semilogy([r['iteration'] for r in rr], [r['conv_norm'] for r in rr], 'o-', color=c, ms=3, lw=1.2,
                   label='%s (%s)' % (att, 'itres 1e-4, maxperiods 40' if att == 'a1' else 'itres 1e-7, maxperiods 60'))
ax[0].axhline(1, color='#009E73', lw=1, ls='--', label='convergence (norm < 1)')
ax[0].set(xlabel='shooting iteration (0 = after tstab 5 ms)', ylabel='Conv norm', title='PSS shooting: Conv norm per iteration (both NOT CONVERGED)'); ax[0].legend(frameon=False, fontsize=8)
wh = {}
for r in rows[1:]: wh[r['where']] = wh.get(r['where'], 0) + 1
ax[1].bar(list(wh.keys()), list(wh.values()), color='#0072B2'); ax[1].set(ylabel='iterations', title='where the largest residual sits (a1 + a2)')
fig.savefig('r8_stageB_pss.png', dpi=140)
