"""F2 final validation scout -- mismatch Monte Carlo analysis.
Usage: python3 f2v_mc.py <extract dir of the MC run> <tag> [replay extract dirs ...]
(extract dirs come from tools/f2v_extract.py on the server). Writes f2v_mc_<tag>_samples.csv, f2v_mc_<tag>_stats.csv,
f2v_mc_<tag>_mapping.txt, f2v_mc_<tag>.txt. Same definitions as f2v_nominal.py (course CMRR with the DRL-OFF post-electrode CM reference)."""
import sys, csv, gzip, math
import numpy as np

X, TAG = sys.argv[1], sys.argv[2]; REPLAYS = sys.argv[3:]
out = []; say = out.append

def load(d):
    dc = {}
    for r in csv.DictReader(open(d + '/mc_dc.csv')):
        dc.setdefault(r['iter'], {})[r['analysis']] = {k: float(v) for k, v in r.items() if k not in ('iter', 'analysis') and v != ''}
    acx = {}
    for r in csv.DictReader(open(d + '/mc_acx.csv')):
        v = {k[:-3]: complex(float(r[k]), float(r[k[:-3] + '_im'])) for k in r if k.endswith('_re')}
        acx.setdefault(r['iter'], {}).setdefault(int(r['mode']), {})[float(r['freq'])] = v
    acm = {}
    for r in csv.DictReader(gzip.open(d + '/mc_acm.csv.gz', 'rt')):
        a = acm.setdefault(r['iter'], {}).setdefault(int(r['mode']), {'f': [], 'out': [], 'vR': [], 'vL': []})
        a['f'].append(float(r['freq'])); a['out'].append(complex(float(r['out_re']), float(r['out_im'])))
        a['vR'].append(complex(float(r['vRight_re']), float(r['vRight_im']))); a['vL'].append(complex(float(r['vLeft_re']), float(r['vLeft_im'])))
    nz = {}
    for r in csv.DictReader(gzip.open(d + '/mc_nz.csv.gz', 'rt')):
        a = nz.setdefault(r['iter'], {'f': [], 'out': [], 'in': [], 'gain': []})
        for k in ('f', 'out', 'in', 'gain'): a[k].append(float(r['freq' if k == 'f' else k + ('_asd' if k in ('out', 'in') else '')]))
    stb = {}
    for r in csv.DictReader(open(d + '/mc_stb.csv')):
        stb.setdefault(r['iter'], {})[r['loop']] = {k: float(v) for k, v in r.items() if k not in ('iter', 'loop') and v != ''}
    return dc, acx, acm, nz, stb

def trapz(y, x): return float(np.sum((y[1:] + y[:-1]) * np.diff(x)) / 2)
def band(f, y, lo, hi):
    lf, ly = np.log(f), np.log(np.maximum(y, 1e-300)); inner = (f > lo) & (f < hi)
    xs = np.concatenate([[lo], f[inner], [hi]]); return trapz(np.exp(np.interp(np.log(xs), lf, ly)), xs)
def corners(f, m):
    k = int(np.argmax(m)); lvl = m[k] / math.sqrt(2)
    def cross(rng):
        prev = k
        for i in rng:
            if m[i] <= lvl:
                return float(np.exp(np.interp(math.log(lvl), np.log([m[i], m[prev]]), np.log([f[i], f[prev]]))))
            prev = i
        return float('nan')
    return m[k], cross(range(k - 1, -1, -1)), cross(range(k + 1, len(f)))

dc, acx, acm, nz, stb = load(X)
its = sorted(dc)
rows = []
for it in its:
    r = dict(iter=it, status='ok', reason='')
    try:
        d = dc[it]; a = acx[it]
        r['out_dc'] = d['dcop']['out']; r['I_VDD'] = -d['dcop']['VDD:p']; r['P_total_uW'] = 1.8 * r['I_VDD'] * 1e6
        r['I_VDDD'] = -d['dcop']['VDDD:p']; r['I_fwd'] = r['I_VDD'] - r['I_VDDD'] - (-d['dcop']['MP2:d'])
        r['p_minus_n_dc_mV'] = 1e3 * (d['dcop']['p'] - d['dcop']['n']); r['body_dc'] = d['dcop']['net5']; r['oa1_dc'] = d['dcop']['oa1']
        for ff in (10.0, 60.0, 100.0):
            v = a[0][ff]; r['Gpost_%d' % ff] = abs(v['out'] / (v['vRight'] - v['vLeft'])); r['Gsrc_%d' % ff] = abs(v['out'] / (v['net1'] - v['net013']))
            r['Gpost_%d_dB' % ff] = 20 * math.log10(r['Gpost_%d' % ff])
        v1, v2 = a[1][60.0], a[2][60.0]
        vcm_off = abs(v1['vRight'] + v1['vLeft']) / 2
        r['vcm_off60'] = vcm_off; r['out60_off'] = abs(v1['out']); r['out60_on'] = abs(v2['out'])
        r['CMRR_on_dB'] = 20 * math.log10(r['Gpost_60'] * vcm_off / r['out60_on']); r['CMRR_off_dB'] = 20 * math.log10(r['Gpost_60'] * vcm_off / r['out60_off'])
        v0 = a[0][10.0]; r['Zin_P_10'] = abs(v0['inp'] / v0['VPP:p']); r['Zin_N_10'] = abs(v0['inn'] / v0['VPN:p'])
        m0 = acm[it][0]; f = np.array(m0['f']); H = np.array(m0['out']) / (np.array(m0['vR']) - np.array(m0['vL']))
        pk, fL, fH = corners(f, np.abs(H)); r['G_plateau'] = pk; r['fL'] = fL; r['fH'] = fH
        z = nz[it]; fz = np.array(z['f']); So = np.array(z['out']) ** 2; Si = np.array(z['in']) ** 2
        Hp = np.exp(np.interp(np.log(fz), np.log(f), np.log(np.abs(H))))
        for bn, lo, hi in (('full', 1e-3, 1e5), ('band', 0.1, 250.0)):
            po = band(fz, So, lo, hi)
            r['nz_M1_G10_%s_uV' % bn] = 1e6 * math.sqrt(po) / r['Gpost_10']; r['nz_M1_G100_%s_uV' % bn] = 1e6 * math.sqrt(po) / r['Gpost_100']
            r['nz_M2_V0ref_%s_uV' % bn] = 1e6 * math.sqrt(band(fz, Si, lo, hi)); r['nz_M3_post_%s_uV' % bn] = 1e6 * math.sqrt(band(fz, So / Hp ** 2, lo, hi))
        s = stb.get(it, {})
        r['PM_main'] = s.get('stbm', {}).get('phaseMargin_deg', float('nan')); r['PM_drl'] = s.get('stbd', {}).get('phaseMargin_deg', float('nan'))
        r['UGF_main'] = s.get('stbm', {}).get('phaseMarginFreq_Hz', float('nan'))
        # same-sample mapping inside one iteration: DC of the DRL-on modes must equal the iteration's dcop
        r['map_dc_maxdiff_V'] = max(abs(d['swm-000_dcm'][k] - d['dcop'][k]) for k in ('out', 'p', 'n', 'oa1', 'net5', 'drlr', 'ib')) \
            if 'swm-000_dcm' in d else float('nan')
        r['map_dc_maxdiff_mode2_V'] = max(abs(d['swm-002_dcm'][k] - d['dcop'][k]) for k in ('out', 'p', 'n', 'oa1', 'net5', 'drlr', 'ib')) \
            if 'swm-002_dcm' in d else float('nan')
        r['mode1_body_dc'] = d.get('swm-001_dcm', {}).get('net5', float('nan'))
    except Exception as e:
        r['status'] = 'failed'; r['reason'] = repr(e)[:200]
    rows.append(r)
keys = list(rows[0].keys())
for r in rows:
    for k in r:
        if k not in keys: keys.append(k)
with open('f2v_mc_%s_samples.csv' % TAG, 'w') as fh:
    w = csv.DictWriter(fh, keys); w.writeheader(); [w.writerow(r) for r in rows]
ok = [r for r in rows if r['status'] == 'ok']
say('== MC %s: attempted %d, valid %d, failed %d' % (TAG, len(rows), len(ok), len(rows) - len(ok)))
# distinct draws / mismatch actually active
for k in ('out_dc', 'p_minus_n_dc_mV', 'I_VDD', 'body_dc'):
    vals = np.array([r[k] for r in ok]); say('  draw spread %-16s mean %.6g std %.3g min %.6g max %.6g, distinct values %d/%d' % (k, vals.mean(), vals.std(ddof=1), vals.min(), vals.max(), len(set(np.round(vals, 12))), len(vals)))
say('  same-sample mapping in one iteration: max |DC(DM-mode dc) - DC(dcop)| %.3g V, max |DC(CM DRL-on mode dc) - DC(dcop)| %.3g V over all samples'
    % (max(r['map_dc_maxdiff_V'] for r in ok), max(r['map_dc_maxdiff_mode2_V'] for r in ok)))
# replay check
for rp in REPLAYS:
    rdc, racx, racm, rnz, rstb = load(rp)
    for it in rdc:
        if it not in dc: say('  replay %s iter %s: not in the main run' % (rp, it)); continue
        ddc = max(abs(rdc[it]['dcop'][k] - dc[it]['dcop'][k]) for k in dc[it]['dcop'])
        dac = max(abs(racx[it][m][f_][n] - acx[it][m][f_][n]) / max(abs(acx[it][m][f_][n]), 1e-30) for m in racx[it] for f_ in racx[it][m] for n in racx[it][m][f_]
                  if abs(acx[it][m][f_][n]) > 1e-9)
        dnz = max(abs(a_ - b_) / b_ for a_, b_ in zip(rnz[it]['out'], nz[it]['out']))
        # neighbouring sample for contrast
        other = its[(its.index(it) + 1) % len(its)]
        dother = max(abs(dc[other]['dcop'][k] - dc[it]['dcop'][k]) for k in ('out', 'p', 'n', 'oa1', 'net5'))
        say('  replay (firstrun=%s, numruns=1, separate Spectre run) vs main-run sample %s: max |dDC| %.3g V, max rel AC diff %.3g, max rel noise ASD diff %.3g '
            '(contrast: sample %s vs %s max |dDC| %.3g V)' % (int(it), it, ddc, dac, dnz, other, it, dother))
# stats + yield
spec = [('Gpost_10_dB', 38, 42, 'gain @10 Hz (primary midband)'), ('Gpost_100_dB', 38, 42, 'gain @100 Hz (historical)'),
        ('fL', 0.09, 0.11, 'fL (plateau-3 dB)'), ('fH', 225, 275, 'fH (plateau-3 dB)'),
        ('nz_M1_G10_full_uV', None, 3.0, 'noise M1 full 1mHz-100kHz out/G10'), ('nz_M1_G100_full_uV', None, 3.0, 'noise M1 full out/G100'),
        ('nz_M1_G10_band_uV', None, 3.0, 'noise M1 0.1-250 out/G10'), ('nz_M3_post_band_uV', None, 3.0, 'noise M3 0.1-250 post pointwise'),
        ('nz_M3_post_full_uV', None, 3.0, 'noise M3 full post pointwise'), ('nz_M2_V0ref_full_uV', None, 3.0, 'noise M2 native V0-ref full'),
        ('nz_M2_V0ref_band_uV', None, 3.0, 'noise M2 native V0-ref 0.1-250'),
        ('CMRR_on_dB', 85, None, 'CMRR60 DRL on (course)'), ('CMRR_off_dB', None, None, 'CMRR60 DRL off (info)'),
        ('Zin_P_10', 100e6, None, 'Zin10 P'), ('Zin_N_10', 100e6, None, 'Zin10 N'), ('P_total_uW', None, 4.0, 'total power'),
        ('PM_main', None, None, 'main loop PM (no course spec)'), ('PM_drl', None, None, 'DRL loop PM (no course spec)'), ('out_dc', None, None, 'out DC')]
st = []
for k, lo, hi, nm in spec:
    v = np.array([r[k] for r in ok], float)
    pas = np.ones(len(v), bool)
    if lo is not None: pas &= v >= lo
    if hi is not None: pas &= v <= hi
    st.append(dict(metric=k, name=nm, lo='' if lo is None else lo, hi='' if hi is None else hi, n=len(v), mean=v.mean(), std=v.std(ddof=1), min=v.min(),
                   p5=np.percentile(v, 5), p50=np.median(v), p95=np.percentile(v, 95), max=v.max(),
                   pass_n=int(pas.sum()) if (lo is not None or hi is not None) else '', yield_pct=100 * pas.mean() if (lo is not None or hi is not None) else ''))
with open('f2v_mc_%s_stats.csv' % TAG, 'w') as fh:
    w = csv.DictWriter(fh, list(st[0])); w.writeheader(); [w.writerow(r) for r in st]
for s in st:
    say('  %-22s %-38s mean %-10.5g std %-9.3g min %-10.5g p5 %-10.5g p50 %-10.5g p95 %-10.5g max %-10.5g %s'
        % (s['metric'], s['name'], s['mean'], s['std'], s['min'], s['p5'], s['p50'], s['p95'], s['max'],
           ('pass %s/%d (%.0f %%)' % (s['pass_n'], s['n'], s['yield_pct'])) if s['pass_n'] != '' else ''))
def joint(keys):
    n = 0
    for r in ok:
        good = True
        for k, lo, hi, _ in spec:
            if k not in keys: continue
            if lo is not None and not r[k] >= lo: good = False
            if hi is not None and not r[k] <= hi: good = False
        n += good
    return n
J1 = ['Gpost_10_dB', 'fL', 'fH', 'nz_M1_G10_full_uV', 'CMRR_on_dB', 'Zin_P_10', 'Zin_N_10', 'P_total_uW']
J2 = ['Gpost_10_dB', 'fL', 'fH', 'nz_M1_G10_band_uV', 'CMRR_on_dB', 'Zin_P_10', 'Zin_N_10', 'P_total_uW']
J3 = ['Gpost_10_dB', 'fL', 'fH', 'CMRR_on_dB', 'Zin_P_10', 'Zin_N_10', 'P_total_uW']
for nm, J in (('joint (gain10, fL, fH, noise M1 full/G10, CMRR_on, Zin P/N, P)', J1), ('joint with noise M1 0.1-250/G10 instead', J2), ('joint without noise', J3)):
    n = joint(J); say('  %s: %d/%d valid (%.0f %%; attempted %d)' % (nm, n, len(ok), 100.0 * n / len(ok), len(rows)))
worst = min(ok, key=lambda r: r['CMRR_on_dB'])
say('  worst CMRR_on sample %s: %.2f dB, out_dc %.5f, p-n %.3f mV, I_VDD %.4g' % (worst['iter'], worst['CMRR_on_dB'], worst['out_dc'], worst['p_minus_n_dc_mV'], worst['I_VDD']))
worstn = max(ok, key=lambda r: r['nz_M1_G10_full_uV'])
say('  worst noise (M1 full/G10) sample %s: %.4f uV' % (worstn['iter'], worstn['nz_M1_G10_full_uV']))
open('f2v_mc_%s.txt' % TAG, 'w').write('\n'.join(out) + '\n'); print('\n'.join(out))
