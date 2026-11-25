"""F2 1 uA interference analysis (definitions in f2i_plan.md). Reads raw/<case>_<stop>s_tran.csv.gz, writes f2i_tran_summary.csv,
f2i_pairs.csv, f2i_samefreq.csv, f2i_gates.txt and figures. Coherent least-squares fit (DC + k*f0, k = 1..K) on windows that hold an
integer number of periods of every tone; amplitudes are peak values."""
import os, sys, gzip, csv, glob, math
import numpy as np
R = os.environ.get('F2I_RAW', 'raw'); VDD = 1.8; EDGE = 0.05
def load(fn):
    with gzip.open(fn, 'rt') as fh:
        r = csv.reader(fh); hdr = next(r); a = np.array([[float(x) for x in row] for row in r])
    d = {h: a[:, i] for i, h in enumerate(hdr)}
    # spsWriteWaves may repeat time points at breakpoints: keep strictly increasing
    t = d['t_s']; keep = np.concatenate([[True], np.diff(t) > 0]); return {k: v[keep] for k, v in d.items()}
def fit(t, y, f0, K, t0, t1, dt=2e-5):
    tt = np.arange(t0, t1, dt); yy = np.interp(tt, t, y)
    cols = [np.ones_like(tt), tt - (t0 + t1) / 2]   # plan update 3: linear term absorbs slow HPF settling drift
    for k in range(1, K + 1): cols += [np.cos(2 * np.pi * k * f0 * tt), np.sin(2 * np.pi * k * f0 * tt)]
    A = np.array(cols).T; c, *_ = np.linalg.lstsq(A, yy, rcond=None)
    ph = {k: complex(c[2 * k], -c[2 * k + 1]) for k in range(1, K + 1)}   # y = Re(ph * e^{jwt})
    fit.slope = c[1]
    return c[0], ph, yy - A @ c
def db(x): return 20 * math.log10(x) if x > 0 else float('-inf')
def case_files(): return sorted(glob.glob(f'{R}/*_tran.csv.gz'))
def analyse(fn, windows):
    d = load(fn); tag = os.path.basename(fn).replace('_tran.csv.gz', '')
    v0 = d['src_p_V'] - d['src_n_V']; vpost = d['vRight_V'] - d['vLeft_V']; out = d['out_V']; t = d['t_s']
    rows = []
    same = tag.startswith('S')
    f0 = 60.0 if same else 10.0; K = 5 if same else 30
    for (a, b) in windows:
        if t[-1] < b - 1e-9: continue
        _, Pv, _ = fit(t, vpost, f0, K, a, b); _, Ps, _ = fit(t, v0, f0, K, a, b)
        dc_o, Po, res = fit(t, out, f0, K, a, b); r = dict(case=tag, window=f'{a:g}-{b:g}', f0=f0, out_dc=dc_o, out_drift_mV_per_s=1e3 * fit.slope)
        k1 = 1
        r['src_amp_V'] = abs(Ps[k1]); r['post_amp_V'] = abs(Pv[k1]); r['out_amp_V'] = abs(Po[k1])
        r['Gpost_dB'] = db(abs(Po[k1]) / abs(Pv[k1])) if abs(Pv[k1]) > 1e-9 else float('nan')
        r['Gsrc_dB'] = db(abs(Po[k1]) / abs(Ps[k1])) if abs(Ps[k1]) > 1e-9 else float('nan')
        r['out_phase_deg'] = math.degrees(np.angle(Po[k1])); r['post_phase_deg'] = math.degrees(np.angle(Pv[k1]))
        if not same:
            for k in (2, 3, 5, 6, 7, 12, 18):
                r[f'out_{10 * k}Hz_V'] = abs(Po[k])
            r['post_60Hz_V'] = abs(Pv[6]); r['src_60Hz_V'] = abs(Ps[6])
        else:
            for k in (2, 3): r[f'out_{60 * k}Hz_V'] = abs(Po[k])
        r['out_fit_resid_rms_V'] = float(np.sqrt(np.mean(res ** 2)))
        s = (t >= a) & (t <= b)
        for n in ('out', 'oa', 'oa1', 'o', 'p', 'n', 'drlr', 'body', 'vRL', 'cm', 'inp', 'inn'):  # CSV extrema; exact Spectre extrema override below when present
            r[f'{n}_min_V'] = float(d[n + '_V'][s].min()); r[f'{n}_max_V'] = float(d[n + '_V'][s].max())
        kvp = fn.replace('_tran.csv.gz', '.csv')
        if os.path.exists(kvp):   # exact full-resolution Spectre extrema (plan update 2) override the resampled-CSV extrema
            kvd = {q['key']: q['value'] for q in csv.DictReader(open(kvp))}
            for n in ('out', 'oa', 'oa1', 'o', 'p', 'n', 'drlr', 'body', 'vRL', 'cm', 'inp', 'inn'):
                for mm in ('min', 'max'):
                    key = '%s_%s_V_w%g' % (mm, n, b)
                    if key in kvd and kvd[key] not in ('', 'n/a'): r[f'{n}_{mm}_V'] = float(kvd[key]); r['extrema_source'] = 'Spectre full resolution'
        el = (d['vRight_V'] + d['vLeft_V']) / 2; r['elcm_min_V'] = float(el[s].min()); r['elcm_max_V'] = float(el[s].max())
        r['I_IPRD_pk_A'] = float(np.max(np.abs(d['I_IPRD_A'][s]))) if 'I_IPRD_A' in d else float('nan')
        r['P_avg_uW'] = float(-np.mean(d['I_VDD_A'][s]) * VDD * 1e6) if 'I_VDD_A' in d else float('nan')
        near = [n for n in ('oa1', 'oa', 'out', 'drlr') if r[f'{n}_min_V'] < EDGE or r[f'{n}_max_V'] > VDD - EDGE]
        hd = (max(r.get('out_20Hz_V', 0), r.get('out_30Hz_V', 0)) / r['out_amp_V']) if (not same and r['post_amp_V'] > 1e-6 and r['out_amp_V'] > 1e-6) else 0.0
        r['harm_2_3_dBc'] = db(hd) if hd > 0 else float('-inf')
        r['clip_flag'] = ';'.join(near + (['out H2/H3 > -40 dBc'] if hd > 0.01 else [])) or 'none'
        rows.append(r)
    return rows, d
def write(fn, rows):
    cols = []; [cols.append(c) for r in rows for c in r if c not in cols]
    with open(fn, 'w', newline='') as fh:
        w = csv.DictWriter(fh, cols, restval=''); w.writeheader()
        for r in rows: w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
if __name__ == '__main__':
    out = []; say = lambda s='': (out.append(s), print(s))
    allrows = []; data = {}
    for fn in case_files():
        tag = os.path.basename(fn).replace('_tran.csv.gz', '')
        stop = float(tag.rsplit('_', 1)[1][:-1])
        wins = [(stop - 2, stop - 1), (stop - 1, stop)]
        rows, d = analyse(fn, wins); allrows += rows; data[tag] = d
    write('f2i_tran_summary.csv', allrows)
    say('== Test 2/4 per case and window (peak amplitudes)')
    for r in allrows:
        say('  %-16s %-6s post %.4g mV src %.4g mV out %.4g mV | Gpost %.3f dB Gsrc %.3f dB | out60 %.4g mV out DC %.4f V | out %.3f..%.3f oa1 %.3f..%.3f drlr %.3f..%.3f body %.3f..%.3f | H2/3 %.1f dBc | clip %s'
            % (r['case'], r['window'], 1e3 * r['post_amp_V'], 1e3 * r['src_amp_V'], 1e3 * r['out_amp_V'], r['Gpost_dB'], r['Gsrc_dB'],
               1e3 * r.get('out_60Hz_V', float('nan')), r['out_dc'], r['out_min_V'], r['out_max_V'], r['oa1_min_V'], r['oa1_max_V'],
               r['drlr_min_V'], r['drlr_max_V'], r['body_min_V'], r['body_max_V'], r['harm_2_3_dBc'], r['clip_flag']))
    # settling between the two windows
    say('== settling (last two windows)')
    for tag in sorted({r['case'] for r in allrows}):
        rs = [r for r in allrows if r['case'] == tag]
        if len(rs) == 2:
            dg = rs[1]['Gpost_dB'] - rs[0]['Gpost_dB'] if not math.isnan(rs[0]['Gpost_dB']) else float('nan'); ddc = 1e3 * (rs[1]['out_dc'] - rs[0]['out_dc'])
            ok = (math.isnan(dg) or abs(dg) <= 0.05) and abs(ddc) <= 1.0
            say('  %-16s dGpost %+.4f dB, dDC(out) %+.4f mV -> %s' % (tag, dg, ddc, 'settled' if ok else 'NOT settled'))
    # paired subtraction (signal response = mixed - interference-only), last window
    prow = []
    for T, I in (('T100n', 'I100n'), ('T1u', 'I1u'), ('T1u_dcc1', 'I1u_dcc1')):
        for tk in sorted(k for k in data if k.rsplit('_', 1)[0] == T):
            sfx = tk.rsplit('_', 1)[1]; ik = f'{I}_{sfx}'
            if ik not in data: continue
            a, b = data[tk], data[ik]; stop = float(sfx[:-1]); t = a['t_s']
            yo = a['out_V'] - np.interp(t, b['t_s'], b['out_V']); yp = (a['vRight_V'] - a['vLeft_V']) - np.interp(t, b['t_s'], b['vRight_V'] - b['vLeft_V'])
            _, Po, res = fit(t, yo, 10.0, 30, stop - 1, stop); _, Pp, _ = fit(t, yp, 10.0, 30, stop - 1, stop)
            prow.append(dict(pair=f'{tk} - {ik}', Gpost_sub_dB=db(abs(Po[1]) / abs(Pp[1])), out10_sub_V=abs(Po[1]), out60_sub_V=abs(Po[6]),
                             out20_sub_V=abs(Po[2]), out30_sub_V=abs(Po[3]), resid_rms_V=float(np.sqrt(np.mean(res ** 2)))))
            say('  paired %-26s Gpost %.3f dB, 60 Hz left after subtraction %.4g uV, 20/30 Hz %.3g/%.3g uV'
                % (prow[-1]['pair'], prow[-1]['Gpost_sub_dB'], 1e6 * prow[-1]['out60_sub_V'], 1e6 * prow[-1]['out20_sub_V'], 1e6 * prow[-1]['out30_sub_V']))
    if prow: write('f2i_pairs.csv', prow)
    # Test 4 same frequency: complex 60 Hz phasors on the last 1 s window; mixed ratio is APPARENT only
    srow = []
    for sfx in sorted({k.rsplit('_', 1)[1] for k in data if k.startswith('S')}):
        if f'Si_{sfx}' not in data: continue
        stop = float(sfx[:-1]); win = (stop - 1, stop)
        def ph(k):
            d = data[k]; t = d['t_s']
            return [fit(t, y, 60.0, 5, *win)[1][1] for y in (d['out_V'], d['vRight_V'] - d['vLeft_V'], d['src_p_V'] - d['src_n_V'])]
        oi, pi, si = ph(f'Si_{sfx}')
        g0 = None
        if f'S0_{sfx}' in data:
            o0, p0, s0 = ph(f'S0_{sfx}'); g0 = db(abs(o0) / abs(p0))
            srow.append(dict(case=f'S0_{sfx}', out60_V=abs(o0), post60_V=abs(p0), src60_V=abs(s0), apparent_post_dB=g0, apparent_src_dB=db(abs(o0) / abs(s0)), sub_post_dB='', d_vs_S0_dB=0.0))
        srow.append(dict(case=f'Si_{sfx}', out60_V=abs(oi), post60_V=abs(pi), src60_V=abs(si)))
        for p in (0, 90, 180, 270):
            k = f'S1u_p{p}_{sfx}'
            if k not in data: continue
            om, pm, sm = ph(k); gs = db(abs(om - oi) / abs(pm - pi))
            srow.append(dict(case=k, out60_V=abs(om), post60_V=abs(pm), src60_V=abs(sm), apparent_post_dB=db(abs(om) / abs(pm)), apparent_src_dB=db(abs(om) / abs(sm)),
                             sub_post_dB=gs, d_vs_S0_dB=(gs - g0) if g0 is not None else '', sub_out60_V=abs(om - oi)))
    if srow:
        write('f2i_samefreq.csv', srow); say('== Test 4 same frequency (60 Hz phasors, last 1 s; "apparent" = mixed ratio, NOT the differential gain)')
        for r in srow:
            say('  %-16s out60 %.4g mV post60 %.4g mV src60 %.4g mV | apparent out/post %s out/src %s | paired-sub Gpost %s (vs S0 %s)'
                % (r['case'], 1e3 * r['out60_V'], 1e3 * r['post60_V'], 1e3 * r['src60_V'],
                   *[('%.3f dB' % r[c]) if isinstance(r.get(c), float) else '-' for c in ('apparent_post_dB', 'apparent_src_dB', 'sub_post_dB', 'd_vs_S0_dB')]))
    open('f2i_gates.txt', 'w').write('\n'.join(out) + '\n')
