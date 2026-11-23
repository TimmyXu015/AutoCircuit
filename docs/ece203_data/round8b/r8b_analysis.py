#!/usr/bin/env python3
"""R8B data products (run from this folder).
r8b_sideband_convergence.csv : PNoise S10/S30/S60/S90 - OCEAN and Python output RMS, application and de-embedded input RMS, input
                               density at 0.1/1/10/100/250 Hz, change vs the previous count
r8b_onoff_summary.csv        : OFF (Gate A, static AC + ordinary noise) vs ON (PSS/PAC/PNoise S90, also S60) on the same R8B bench
r8b_pac.csv                  : PAC sideband-0 Hon(f) vs the OFF static Hoff(f)
r8b_noise_groups.csv         : source groups per band for OFF and ON S90 (via ../round8/r8_noise_groups.py)
r8b_pss_check.csv            : PSS (gate B) one-period waveform closure and ranges vs the R8 zero-input ON transient
figures r8b_onoff.png, r8b_sideband.png, r8b_sources.png"""
import os, sys, csv, subprocess
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
here = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(here, '..', 'round8')); import r8_spec
OFF = 'raw/gateA/A_off'; ON = {s: 'raw/gateD/C_pnoise_s%d' % s for s in (10, 30, 60, 90)}
CK = [0.1, 1.0, 10.0, 100.0, 250.0]
def at(f, y, x): return float(np.exp(np.interp(np.log(x), np.log(f), np.log(y))))
def kvs(b): return {r['key']: r['value'] for r in csv.DictReader(open(b + '.csv'))}
rows = []; prev = None
for s, b in ON.items():
    f, so, H, H100 = r8_spec.load(b); kv = kvs(b); si = so / H
    r = {'maxsideband': s, 'H100_pac': H100, 'out_rms_V_python': r8_spec.rms(f, so), 'out_rms_V_ocean': float(kv['out_rms']),
         'app_in_V_python': r8_spec.rms(f, so) / H100, 'app_in_V_ocean': float(kv['app_in']), 'deemb_in_V_python': r8_spec.rms(f, si), 'deemb_in_V_ocean': float(kv['deemb_in'])}
    for x in CK: r['in_%gHz_V_rtHz' % x] = at(f, si, x)
    for k in ('app_in_V_python', 'deemb_in_V_python', 'in_1Hz_V_rtHz', 'in_10Hz_V_rtHz', 'in_100Hz_V_rtHz'):
        r['d_' + k + '_pct'] = (r[k] / prev[k] - 1) * 100 if prev else float('nan')
    rows.append(r); prev = r
with open('r8b_sideband_convergence.csv', 'w', newline='') as fo:
    w = csv.DictWriter(fo, list(rows[0].keys()), lineterminator='\n'); w.writeheader()
    for r in rows: w.writerow({k: ('%.7g' % v if isinstance(v, float) else v) for k, v in r.items()})
for r in rows:
    print('S%-3d out %.5g V (OCEAN %.5g) app %.4f uV (%+.2f %%) deemb %.4f uV (%+.2f %%) | in 1/10/100 Hz %.4g/%.4g/%.4g nV/rtHz (%+.2f/%+.2f/%+.2f %%)'
          % (r['maxsideband'], r['out_rms_V_python'], r['out_rms_V_ocean'], r['app_in_V_python'] * 1e6, r['d_app_in_V_python_pct'], r['deemb_in_V_python'] * 1e6,
             r['d_deemb_in_V_python_pct'], r['in_1Hz_V_rtHz'] * 1e9, r['in_10Hz_V_rtHz'] * 1e9, r['in_100Hz_V_rtHz'] * 1e9, r['d_in_1Hz_V_rtHz_pct'],
             r['d_in_10Hz_V_rtHz_pct'], r['d_in_100Hz_V_rtHz_pct']))
fo_, soo, Ho, Ho100 = r8_spec.load(OFF); sio = soo / Ho
summ = []
def add(q, off, on60, on90, unit=''):
    summ.append({'quantity': q, 'OFF_static': off, 'ON_S60': on60, 'ON_S90_final': on90, 'unit': unit})
s60 = rows[2]; s90 = rows[3]
add('|H(100 Hz)| (OFF static AC; ON PAC sb0)', Ho100, s60['H100_pac'], s90['H100_pac'], 'V/V')
add('output RMS 0.1-250 Hz', r8_spec.rms(fo_, soo), s60['out_rms_V_python'], s90['out_rms_V_python'], 'V')
add('input RMS, application type', r8_spec.rms(fo_, soo) / Ho100, s60['app_in_V_python'], s90['app_in_V_python'], 'V')
add('input RMS, point-wise de-embedded', r8_spec.rms(fo_, sio), s60['deemb_in_V_python'], s90['deemb_in_V_python'], 'V')
for x in CK: add('input density %g Hz' % x, at(fo_, sio, x), s60['in_%gHz_V_rtHz' % x], s90['in_%gHz_V_rtHz' % x], 'V/rtHz')
for x in CK: add('output density %g Hz' % x, at(fo_, soo, x), at(*r8_spec.load(ON[60])[:2], x), at(*r8_spec.load(ON[90])[:2], x), 'V/rtHz')
for x in (0.1, 1.0, 10.0, 250.0): add('|H(%g Hz)|' % x, at(fo_, Ho, x), at(r8_spec.load(ON[60])[0], r8_spec.load(ON[60])[2], x), at(r8_spec.load(ON[90])[0], r8_spec.load(ON[90])[2], x), 'V/V')
off_app = r8_spec.rms(fo_, soo) / Ho100; off_de = r8_spec.rms(fo_, sio)
add('OFF/ON input RMS ratio, application', '', off_app / s60['app_in_V_python'], off_app / s90['app_in_V_python'], 'x')
add('OFF/ON input RMS ratio, de-embedded', '', off_de / s60['deemb_in_V_python'], off_de / s90['deemb_in_V_python'], 'x')
add('OFF/ON input power ratio, application', '', (off_app / s60['app_in_V_python']) ** 2, (off_app / s90['app_in_V_python']) ** 2, 'x')
add('OFF/ON input power ratio, de-embedded', '', (off_de / s60['deemb_in_V_python']) ** 2, (off_de / s90['deemb_in_V_python']) ** 2, 'x')
add('< 3 uVrms (application)', off_app < 3e-6, s60['app_in_V_python'] < 3e-6, s90['app_in_V_python'] < 3e-6, '')
add('< 3 uVrms (de-embedded)', off_de < 3e-6, s60['deemb_in_V_python'] < 3e-6, s90['deemb_in_V_python'] < 3e-6, '')
with open('r8b_onoff_summary.csv', 'w', newline='') as fo:
    w = csv.DictWriter(fo, list(summ[0].keys()), lineterminator='\n'); w.writeheader()
    for r in summ: w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
for r in summ: print('%-44s %-12s %-12s %-12s %s' % (r['quantity'], ('%.5g' % r['OFF_static']) if isinstance(r['OFF_static'], float) else r['OFF_static'],
                     ('%.5g' % r['ON_S60']) if isinstance(r['ON_S60'], float) else r['ON_S60'], ('%.5g' % r['ON_S90_final']) if isinstance(r['ON_S90_final'], float) else r['ON_S90_final'], r['unit']))
# PAC vs OFF transfer
pac = np.genfromtxt('raw/gateC/B_pac_pac.csv', delimiter=',', names=True); ac = np.genfromtxt(OFF + '_ac.csv', delimiter=',', names=True)
with open('r8b_pac.csv', 'w', newline='') as fo:
    w = csv.writer(fo, lineterminator='\n'); w.writerow(['f_Hz', 'absHon_pac_sb0', 'phHon_deg', 'absHoff_static', 'Hon_over_Hoff'])
    for fq, a, p in zip(pac['f_Hz'], pac['abs_Hon'], pac['ph_Hon']):
        hoff = at(ac['f_Hz'], ac['abs_Hoff'], fq); w.writerow(['%.6g' % fq, '%.6g' % a, '%.5g' % p, '%.6g' % hoff, '%.5g' % (a / hoff)])
subprocess.run([sys.executable, os.path.join(here, '..', 'round8', 'r8_noise_groups.py'), 'r8b_noise_groups.csv', 'OFF=' + OFF, 'ON_S60=' + ON[60], 'ON_S90=' + ON[90]], check=True, stdout=subprocess.DEVNULL)
# PSS closure vs R8 T0 transient
td = np.genfromtxt('raw/gateB/B_pss_a1_pss_td.csv', delimiter=',', names=True)
import gzip
with gzip.open('../round8/raw/stageB/T0_on_zero_tran.csv.gz', 'rt') as fi:
    h = fi.readline().strip().split(','); a = np.loadtxt(fi, delimiter=',')
t0 = {k: a[:, i] for i, k in enumerate(h)}; s = t0['t_s'] > 0.01; pc = []
for k in ('op_V', 'fp_V', 'bufp_V', 'outp_V', 'p_V', 'n_V', 'vg_V', 'pref_V', 'ib_V'):
    pc.append({'node': k[:-2], 'pss_start_V': td[k][0], 'pss_end_V': td[k][-1], 'pss_min_V': td[k].min(), 'pss_max_V': td[k].max(), 'pss_mean_V': td[k].mean(),
               't0_min_V': t0[k][s].min(), 't0_max_V': t0[k][s].max(), 't0_mean_V': t0[k][s].mean()})
with open('r8b_pss_check.csv', 'w', newline='') as fo:
    w = csv.DictWriter(fo, list(pc[0].keys()), lineterminator='\n'); w.writeheader()
    for r in pc: w.writerow({k: ('%.7g' % v if isinstance(v, float) else v) for k, v in r.items()})
# figures
plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.alpha': 0.3})
fig, ax = plt.subplots(1, 3, figsize=(15, 4.3), constrained_layout=True)
ax[0].loglog(fo_, sio * 1e9, color='#8c8c8c', lw=2, label='OFF (static phase A), de-embedded')
cols = {10: '#E69F00', 30: '#56B4E9', 60: '#009E73', 90: '#D55E00'}
for sb, b in ON.items():
    f, so, H, _ = r8_spec.load(b); ax[0].loglog(f, so / H * 1e9, color=cols[sb], lw=1.8 if sb == 90 else 1.0, label='ON 2 kHz, PNoise S%d' % sb)
ax[0].set(xlabel='f (Hz)', ylabel='nV/rtHz', title='input-referred noise density (each with its own H(f))'); ax[0].legend(frameon=False, fontsize=7)
f9, so9, H9, _ = r8_spec.load(ON[90])
ax[1].loglog(fo_, soo * 1e6, color='#8c8c8c', lw=2, label='OFF output'); ax[1].loglog(f9, so9 * 1e6, color='#D55E00', lw=1.8, label='ON output (S90)')
ax[1].set(xlabel='f (Hz)', ylabel='uV/rtHz', title='output noise density outp-outn'); ax[1].legend(frameon=False, fontsize=8)
ax[2].loglog(ac['f_Hz'], ac['abs_Hoff'], color='#8c8c8c', lw=2, label='|Hoff| static AC'); ax[2].loglog(pac['f_Hz'], pac['abs_Hon'], color='#D55E00', lw=1.8, label='|Hon| PAC sideband 0')
ax[2].set(xlim=(0.05, 300), ylim=(10, 120), xlabel='f (Hz)', ylabel='V/V', title='signal transfer ep-en -> outp-outn'); ax[2].legend(frameon=False, fontsize=8)
fig.savefig('r8b_onoff.png', dpi=140)
fig, ax = plt.subplots(1, 2, figsize=(11, 4), constrained_layout=True)
sb = [r['maxsideband'] for r in rows]
ax[0].plot(sb, [r['app_in_V_python'] * 1e6 for r in rows], 'o-', color='#0072B2', label='application type'); ax[0].plot(sb, [r['deemb_in_V_python'] * 1e6 for r in rows], 's-', color='#D55E00', label='point-wise de-embedded')
ax[0].axhline(3, color='#555', ls='--', lw=1, label='3 uVrms spec'); ax[0].set(xlabel='maxsideband', ylabel='uVrms (0.1-250 Hz)', title='ON input-referred RMS vs sidebands'); ax[0].legend(frameon=False, fontsize=8)
for x, c in ((1.0, '#0072B2'), (10.0, '#009E73'), (100.0, '#D55E00')):
    ax[1].plot(sb, [r['in_%gHz_V_rtHz' % x] / rows[-1]['in_%gHz_V_rtHz' % x] for r in rows], 'o-', color=c, label='%g Hz' % x)
ax[1].set(xlabel='maxsideband', ylabel='density / S90 value', title='ON input density vs sidebands (normalised to S90)'); ax[1].legend(frameon=False, fontsize=8)
fig.savefig('r8b_sideband.png', dpi=140)
G = list(csv.DictReader(open('r8b_noise_groups.csv'))); fig, ax = plt.subplots(1, 1, figsize=(11, 4.5), constrained_layout=True)
keys = []
for r in G:
    if r['band_Hz'] == '0.1-250' and float(r['pct_of_band_out']) > 0.5:
        k = r['group'] + (' 1/f' if r['kind'] == 'flicker' else ' thermal')
        if k not in keys: keys.append(k)
x = np.arange(len(keys)); wdt = 0.38
for i, (case, c) in enumerate((('OFF', '#8c8c8c'), ('ON_S90', '#D55E00'))):
    v = []
    for k in keys:
        v.append(sum(float(r['in_V2_approx']) for r in G if r['case'] == case and r['band_Hz'] == '0.1-250' and (r['group'] + (' 1/f' if r['kind'] == 'flicker' else ' thermal')) == k) * 1e12)
    ax.bar(x + (i - 0.5) * wdt, v, wdt, color=c, label=case)
ax.set(xticks=x, yscale='log', ylabel='input-referred power 0.1-250 Hz (uV^2, approx. split)', title='noise sources, OFF vs ON (S90)'); ax.set_xticklabels(keys, rotation=25, ha='right', fontsize=7); ax.legend(frameon=False)
fig.savefig('r8b_sources.png', dpi=140)
