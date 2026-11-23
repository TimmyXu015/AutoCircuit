#!/usr/bin/env python3
"""R7A Stage 3 chopped-transient analysis (2 kHz TG, 100 Hz 1 mV DM, 60 ms). Metric definitions follow
docs/ece203_data/round6dr/r6dr_analysis.py (same windows 20-40 / 40-60 ms, 1 us resampling, least-squares fit with
DC + linear drift + 100/200/300 Hz; TG-edge CM glitch = deviation from the line through the [-20,-1] us and
[+40,+60] us means, recovery = last time |dev| > 1 mV), plus vg metrics. numpy version of the same fits.
Usage: python3 r7a_sys_analysis.py OUT.csv tag=path/to/tran.csv.gz [tag=...]"""
import sys, csv, gzip, math, cmath
import numpy as np

def load(fn):
    with (gzip.open(fn, 'rt') if fn.endswith('.gz') else open(fn)) as f:
        h = f.readline().strip().split(',')
        a = np.loadtxt(f, delimiter=',')
    return {k: a[:, i] for i, k in enumerate(h)}

def fit(tt, y, f0=100.0, harm=(1, 2, 3)):
    cols = [np.ones_like(tt), tt]
    for k in harm:
        cols += [np.sin(2 * np.pi * k * f0 * tt), np.cos(2 * np.pi * k * f0 * tt)]
    A = np.column_stack(cols)
    c, *_ = np.linalg.lstsq(A, y, rcond=None)
    return c, A @ c

def amp(c, k):  # complex amplitude of harmonic index k (1-based in the harm tuple order 1,2,3)
    return complex(c[2 * k + 1], c[2 * k])

def glitch(t, o, w0, w1, tch=500e-6):
    k = math.ceil((w0 + 30e-6) / (tch / 2)); pos = []; neg = []; rec = []
    while k * tch / 2 + 70e-6 <= w1:
        te = k * tch / 2
        def mean(a, b):
            m = (t >= a) & (t < b); return o[m].mean(), t[m].mean()
        m0, c0 = mean(te - 20e-6, te - 1e-6); m1, c1 = mean(te + 40e-6, te + 60e-6)
        m = (t >= te - 50e-9) & (t < te + 40e-6)
        dev = o[m] - (m0 + (m1 - m0) * (t[m] - c0) / (c1 - c0)); dt = t[m] - te
        pos.append(dev.max()); neg.append(dev.min())
        big = dt[np.abs(dev) > 1e-3]; rec.append(big.max() if big.size else 0.0)
        k += 1
    return max(pos), min(neg), max(rec), len(pos)

def analyse(tag, fn):
    d = load(fn); t = d['t_s']; out = []
    vpre = d['fp_V'] - d['fn_V']; vbuf = d['bufp_V'] - d['bufn_V']
    cms = {'opon_cm': (d['op_V'] + d['on_V']) / 2, 'fpfn_cm': (d['fp_V'] + d['fn_V']) / 2,
           'buf_cm': (d['bufp_V'] + d['bufn_V']) / 2, 'vg': d['vg_V']}
    for w0, w1 in ((0.020, 0.040), (0.040, 0.060)):
        tt = np.arange(w0, w1 + 1e-12, 1e-6); R = lambda a: np.interp(tt, t, a)
        cin, _ = fit(tt, R(d['vid_V']), harm=(1,)); ain = amp(cin, 1)
        m = {'case': tag, 'window_ms': '%g-%g' % (w0 * 1e3, w1 * 1e3), 't_end_ms': t[-1] * 1e3}
        for lab, arr in (('Hpre', vpre), ('Hbuf', vbuf)):
            y = R(arr); c, f = fit(tt, y); g = amp(c, 1) / ain; res = y - f
            m[lab + '_gain'] = abs(g); m[lab + '_phase_deg'] = math.degrees(cmath.phase(g))
            m[lab + '_H2_dBc'] = 20 * math.log10(max(abs(amp(c, 2)), 1e-30) / abs(amp(c, 1)))
            m[lab + '_H3_dBc'] = 20 * math.log10(abs(amp(c, 3)) / abs(amp(c, 1)))
            m[lab + '_resid_rms_uV'] = float(np.sqrt(np.mean(res ** 2))) * 1e6
        for lab, arr in cms.items():
            y = R(arr); c, _ = fit(tt, y, harm=(1, 2))
            m[lab + '_avg_V'] = float(y.mean()); m[lab + '_200Hz_uV'] = abs(amp(c, 2)) * 1e6
            m[lab + '_100Hz_uV'] = abs(amp(c, 1)) * 1e6
            m[lab + '_pp_mV'] = float(y.max() - y.min()) * 1e3; m[lab + '_drift_mV_per_s'] = c[1] * 1e3
            sel = (t >= w0) & (t <= w1)
            gp, gn, gr, ne = glitch(t[sel], arr[sel], w0, w1)
            m[lab + '_edge_pos_mV'] = gp * 1e3; m[lab + '_edge_neg_mV'] = gn * 1e3; m[lab + '_recover_1mV_us'] = gr * 1e6
            m['n_edges'] = ne
        sel = (t >= w0) & (t <= w1)
        for k in ('op_V', 'on_V', 'fp_V', 'fn_V', 'bufp_V', 'bufn_V', 'vg_V', 'drlr_V'):
            m[k[:-2] + '_min_V'] = float(d[k][sel].min()); m[k[:-2] + '_max_V'] = float(d[k][sel].max())
        if 'i_vdd_A' in d:
            m['I_VDD_nA'] = -float(R(d['i_vdd_A']).mean()) * 1e9; m['I_VDDD_nA'] = -float(R(d['i_vddd_A']).mean()) * 1e9
            m['P_total_uW'] = (m['I_VDD_nA'] + m['I_VDDD_nA']) * 1.8e-3
        out.append(m)
    return out

if __name__ == '__main__':
    rows = []
    for a in sys.argv[2:]:
        tag, fn = a.split('=', 1); rows += analyse(tag, fn)
    keys = []; [keys.append(k) for r in rows for k in r if k not in keys]
    with open(sys.argv[1], 'w', newline='') as f:
        w = csv.DictWriter(f, keys, restval='n/a'); w.writeheader()
        for r in rows:
            w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
    for r in rows:
        print(r['case'], r['window_ms'], 'Hpre %.5g Hbuf %.5g | opon cm avg %.6f 200Hz %.2f uV pp %.2f mV edge +%.2f/%.2f mV rec %.2f us | vg %.5f..%.5f 200Hz %.2f uV | P %.4g uW'
              % (r['Hpre_gain'], r['Hbuf_gain'], r['opon_cm_avg_V'], r['opon_cm_200Hz_uV'], r['opon_cm_pp_mV'], r['opon_cm_edge_pos_mV'],
                 r['opon_cm_edge_neg_mV'], r['opon_cm_recover_1mV_us'], r['vg_min_V'], r['vg_max_V'], r['vg_200Hz_uV'], r.get('P_total_uW', float('nan'))))
