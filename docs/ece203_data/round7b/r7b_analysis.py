#!/usr/bin/env python3
"""R7B analysis. Window metrics use the UNCHANGED R7A ruler (docs/ece203_data/round7a/r7a_sys_analysis.py, imported, not
rewritten): 20-40 / 40-60 ms, 1 us resample, LSQ DC + drift + 100/200/300 Hz, TG-edge CM glitch rule. Added here:
edge-local DM error measures on the same fit residual (immediate 0-2 us peak |e|, early 2-40 us mean |e|, late
40-200 us mean signed e = post-edge plateau), at every TG edge of the window and at the 42.5 ms edge; explanatory
ratios F = (m(C1) - m(C0)) / (m(R7A_a2) - m(R6D_ideal)).
Usage (from this folder): python3 r7b_analysis.py name=tran.csv.gz ...   (names: R6D_ideal R7A_a2 C0 C1 C2)"""
import sys, csv, math, importlib.util
import numpy as np

spec = importlib.util.spec_from_file_location('r7a', '../round7a/r7a_sys_analysis.py')
r7a = importlib.util.module_from_spec(spec); spec.loader.exec_module(r7a)

def dm_error(d, w0, w1):
    t = d['t_s']; v = d['fp_V'] - d['fn_V']
    tt = np.arange(w0, w1 + 1e-12, 1e-6)
    c, _ = r7a.fit(tt, np.interp(tt, t, v))
    sel = (t >= w0) & (t <= w1); tn = t[sel]
    f = c[0] + c[1] * tn + sum(c[2 * k] * np.sin(2 * np.pi * k * 100 * tn) + c[2 * k + 1] * np.cos(2 * np.pi * k * 100 * tn) for k in (1, 2, 3))
    return tn, v[sel] - f, abs(r7a.amp(c, 1))

def edge_local(tn, e, te):
    def win(a, b):
        m = (tn >= te + a) & (tn < te + b); return e[m]
    i0, i1, i2 = win(-50e-9, 2e-6), win(2e-6, 40e-6), win(40e-6, 200e-6)
    pre = win(-20e-6, -1e-6)
    return {'imm_peak_mV': float(np.abs(i0).max()) * 1e3, 'imm_signed_peak_mV': float(i0[np.argmax(np.abs(i0))]) * 1e3,
            'early_mean_abs_mV': float(np.abs(i1).mean()) * 1e3, 'late_mean_mV': float(i2.mean()) * 1e3,
            'late_plateau_abs_mV': abs(float(i2.mean())) * 1e3,
            'pre_mean_mV': float(pre.mean()) * 1e3}

def analyse(name, fn):
    d = r7a.load(fn)
    rows = r7a.analyse(name, fn)
    for m in rows:
        w0, w1 = [float(x) * 1e-3 for x in m['window_ms'].split('-')]
        tn, e, a1 = dm_error(d, w0, w1)
        k = math.ceil((w0 + 30e-6) / 250e-6); acc = []
        while k * 250e-6 + 205e-6 <= w1:
            acc.append(edge_local(tn, e, k * 250e-6)); k += 1
        for key in acc[0]:
            vals = [x[key] for x in acc]
            m['edges_' + key + '_mean'] = float(np.mean(vals))
            m['edges_' + key + '_absmax'] = float(np.max(np.abs(vals)))
        if w0 <= 0.0425 < w1:
            for key, v in edge_local(tn, e, 0.0425).items():
                m['e42p5_' + key] = v
        m['n_local_edges'] = len(acc)
        # "settle1pct": last 1 % exceedance inside the half cycle (same rule as R7A) -> flag only
        m['settles_below_1pct_before_next_switch'] = 'no' if m['Hpre_settle1pct_max_us'] > 240 else 'yes'
    return rows

if __name__ == '__main__':
    allr = []
    for a in sys.argv[1:]:
        name, fn = a.split('=', 1); allr += analyse(name, fn)
    keys = []; [keys.append(k) for r in allr for k in r if k not in keys]
    with open('r7b_summary.csv', 'w', newline='') as f:
        w = csv.DictWriter(f, keys, restval='n/a'); w.writeheader()
        for r in allr:
            w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
    S = {(r['case'], r['window_ms']): r for r in allr}
    out = []
    for win in ('20-40', '40-60'):
        if not all((c, win) in S for c in ('R6D_ideal', 'R7A_a2', 'C0', 'C1')):
            continue
        for met in ('Hpre_edge_err_max_mV', 'Hpre_resid_rms_uV', 'Hpre_edge_err_mean_mV', 'Hpre_gain', 'edges_imm_peak_mV_mean',
                    'edges_early_mean_abs_mV_mean', 'edges_late_plateau_abs_mV_mean', 'opon_cm_edge_pos_mV', 'opon_cm_200Hz_uV'):
            g = {c: S[(c, win)][met] for c in ('R6D_ideal', 'R7A_a2', 'C0', 'C1', 'C2') if (c, win) in S}
            den = g['R7A_a2'] - g['R6D_ideal']
            r = {'window_ms': win, 'metric': met, **{k: '%.6g' % v for k, v in g.items()},
                 'F_C1': '%.4g' % ((g['C1'] - g['C0']) / den) if den else 'n/a',
                 'F_C2': '%.4g' % ((g['C2'] - g['C0']) / den) if den and 'C2' in g else 'n/a',
                 'C0_vs_R6D_rel_pct': '%.3g' % (100 * (g['C0'] / g['R6D_ideal'] - 1)) if g['R6D_ideal'] else 'n/a'}
            out.append(r)
    if out:
        with open('r7b_ratios.csv', 'w', newline='') as f:
            w = csv.DictWriter(f, list(out[0])); w.writeheader(); w.writerows(out)
        for r in out:
            print(r)
