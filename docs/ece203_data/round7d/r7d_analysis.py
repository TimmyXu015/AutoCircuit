#!/usr/bin/env python3
"""R7D Stage C analysis: the R7C metrics (r7c_analysis: R7A windows 20-40 / 40-60 ms + pseudo-R terms) plus bias-network
terms when present: V(pref), V(ib), V(ibd) mean / pp / 2 kHz-edge deviation (same line-through-the-edge method as the CM
glitch), and the IREF / MP0 / MP1 / MP2 branch currents (mean, pp). Spectre current sign: i(X:PLUS)/i(MPx:D) positive INTO
the terminal; MP1/MP2 drain currents are reported as magnitudes delivered into ib/ibd.
Usage: python3 r7d_analysis.py OUT.csv STAGE_A_IV.csv tag=tran.csv.gz [tag=...]"""
import sys, os, csv
import numpy as np
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, '..', 'round7c')); sys.path.insert(0, os.path.join(here, '..', 'round7a'))
from r7a_sys_analysis import load, analyse, glitch
from r7c_analysis import iv, extra

def bias(fn):
    d = load(fn); t = d['t_s']; rows = []
    for w0, w1 in ((0.020, 0.040), (0.040, 0.060)):
        s = (t >= w0) & (t <= w1); tt = np.arange(w0, w1 + 1e-12, 1e-6); m = {}
        for k in ('pref_V', 'ib_V', 'ibd_V'):
            if k not in d: continue
            y = np.interp(tt, t, d[k]); n = k[:-2]
            m[n + '_avg_V'] = y.mean(); m[n + '_pp_mV'] = (d[k][s].max() - d[k][s].min()) * 1e3
            gp, gn, gr, _ = glitch(t[s], d[k][s], w0, w1)
            m[n + '_edge_pos_mV'] = gp * 1e3; m[n + '_edge_neg_mV'] = gn * 1e3
        for k in ('i_iref_A', 'i_mp0_d_A', 'i_mp1_d_A', 'i_mp2_d_A'):
            if k not in d: continue
            y = np.interp(tt, t, d[k]); n = k[2:-2]
            m[n + '_avg_nA'] = abs(y.mean()) * 1e9; m[n + '_pp_nA'] = (d[k][s].max() - d[k][s].min()) * 1e9
            m[n + '_absmax_nA'] = np.abs(d[k][s]).max() * 1e9
        rows.append(m)
    return rows

if __name__ == '__main__':
    ivv, ivi = iv(sys.argv[2]); rows = []
    for a in sys.argv[3:]:
        tag, fn = a.split('=', 1); base = analyse(tag, fn); ex = extra(tag, fn, ivv, ivi); bi = bias(fn)
        for b, e, c in zip(base, ex, bi):
            b.update(e); b.update(c); rows.append(b)
    keys = []; [keys.append(k) for r in rows for k in r if k not in keys]
    with open(sys.argv[1], 'w', newline='') as f:
        w = csv.DictWriter(f, keys, restval='n/a', lineterminator='\n'); w.writeheader()
        for r in rows:
            w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
    for r in rows:
        print(r['case'], r['window_ms'], 'Hpre %.5g ph %.3f H2 %.1f H3 %.1f resid %.1f uV edge max %.2f mean %.2f mV | Hbuf %.5g | opon cm avg %.6f 200Hz %.2f uV edge %+.2f/%.2f | vg %.5f..%.5f | P %.4g uW'
              % (r['Hpre_gain'], r['Hpre_phase_deg'], r['Hpre_H2_dBc'], r['Hpre_H3_dBc'], r['Hpre_resid_rms_uV'], r['Hpre_edge_err_max_mV'], r['Hpre_edge_err_mean_mV'],
                 r['Hbuf_gain'], r['opon_cm_avg_V'], r['opon_cm_200Hz_uV'], r['opon_cm_edge_pos_mV'], r['opon_cm_edge_neg_mV'], r['vg_min_V'], r['vg_max_V'], r.get('P_total_uW', float('nan'))))
        if 'ib_avg_V' in r:
            print('   bias: pref %.5f pp %.3f mV edge %+.3f/%.3f | ib %.5f pp %.3f edge %+.3f/%.3f | ibd %.5f pp %.3f | IREF %.3f MP0 %.3f MP1 %.3f (pp %.2f, max %.2f) MP2 %.3f (pp %.2f) nA'
                  % (r['pref_avg_V'], r['pref_pp_mV'], r['pref_edge_pos_mV'], r['pref_edge_neg_mV'], r['ib_avg_V'], r['ib_pp_mV'], r['ib_edge_pos_mV'], r['ib_edge_neg_mV'],
                     r['ibd_avg_V'], r['ibd_pp_mV'], r.get('iref_avg_nA', float('nan')), r.get('mp0_d_avg_nA', float('nan')), r.get('mp1_d_avg_nA', float('nan')),
                     r.get('mp1_d_pp_nA', float('nan')), r.get('mp1_d_absmax_nA', float('nan')), r.get('mp2_d_avg_nA', float('nan')), r.get('mp2_d_pp_nA', float('nan'))))
