#!/usr/bin/env python3
"""R7C Stage C analysis. Same metrics as R7A (r7a_sys_analysis.analyse: windows 20-40 / 40-60 ms) plus pseudo-R terms:
V_PRN = V(A)-V(B) = n - fp, V_PRP = p - fn (A = OTA-input side, B = gate/well side on the demodulated output), the CM of the
OTA-input nodes (p+n)/2 and the DM input-node voltage p-n, and an ESTIMATED pseudo-R current from the Stage A DC I-V
(A_pr_iv_w4.csv, quasi-static, interpolated; the tran itself does not save the MOS current).
Usage: python3 r7c_analysis.py OUT.csv STAGE_A.csv tag=tran.csv.gz [tag=...]"""
import sys, os, csv
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'round7a'))
from r7a_sys_analysis import load, analyse

def iv(fn):
    r = [x for x in csv.DictReader(open(fn)) if x['status'] == 'ok']
    v = np.array([float(x['vd_mV']) for x in r]) * 1e-3; i = np.array([float(x['I_A_into_A']) for x in r])
    o = np.argsort(v); return v[o], i[o]

def extra(tag, fn, ivv, ivi):
    d = load(fn); t = d['t_s']; rows = []
    if 'p_V' not in d:
        return [{} for _ in range(2)]
    vprn = d['n_V'] - d['fp_V']; vprp = d['p_V'] - d['fn_V']
    for w0, w1 in ((0.020, 0.040), (0.040, 0.060)):
        s = (t >= w0) & (t <= w1); tt = np.arange(w0, w1 + 1e-12, 1e-6); R = lambda a: np.interp(tt, t, a)
        m = {}
        for lab, a in (('VPRN', vprn), ('VPRP', vprp)):
            y = R(a); m[lab + '_avg_mV'] = y.mean() * 1e3; m[lab + '_min_mV'] = a[s].min() * 1e3; m[lab + '_max_mV'] = a[s].max() * 1e3
            ie = np.interp(y, ivv, ivi)    # quasi-static estimate, |V| > 100 mV clamps to the table end
            m[lab + '_Iest_avg_fA'] = ie.mean() * 1e15; m[lab + '_Iest_absmax_fA'] = np.abs(ie).max() * 1e15
            m[lab + '_frac_beyond_100mV'] = float(np.mean(np.abs(y) > 0.1))
        pn = R(d['p_V'] - d['n_V']); cm = R((d['p_V'] + d['n_V']) / 2)
        m['pn_dm_avg_uV'] = pn.mean() * 1e6; m['pn_dm_pp_mV'] = (pn.max() - pn.min()) * 1e3
        m['pn_cm_avg_V'] = cm.mean(); m['pn_cm_pp_mV'] = (cm.max() - cm.min()) * 1e3
        rows.append(m)
    return rows

if __name__ == '__main__':
    ivv, ivi = iv(sys.argv[2]); rows = []
    for a in sys.argv[3:]:
        tag, fn = a.split('=', 1); base = analyse(tag, fn); ex = extra(tag, fn, ivv, ivi)
        for b, e in zip(base, ex):
            b.update(e); rows.append(b)
    keys = []; [keys.append(k) for r in rows for k in r if k not in keys]
    with open(sys.argv[1], 'w', newline='') as f:
        w = csv.DictWriter(f, keys, restval='n/a'); w.writeheader()
        for r in rows:
            w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
    for r in rows:
        print(r['case'], r['window_ms'], 'Hpre %.5g ph %.3f H2 %.1f H3 %.1f resid %.1f uV edge %.2f mV | Hbuf %.5g | opon cm avg %.6f 200Hz %.2f uV edge %+.2f/%.2f mV | vg %.5f..%.5f | P %.4g uW'
              % (r['Hpre_gain'], r['Hpre_phase_deg'], r['Hpre_H2_dBc'], r['Hpre_H3_dBc'], r['Hpre_resid_rms_uV'], r['Hpre_edge_err_max_mV'],
                 r['Hbuf_gain'], r['opon_cm_avg_V'], r['opon_cm_200Hz_uV'], r['opon_cm_edge_pos_mV'], r['opon_cm_edge_neg_mV'],
                 r['vg_min_V'], r['vg_max_V'], r.get('P_total_uW', float('nan'))),
              ('| VPRN %.2f..%.2f avg %.3f mV Iest avg %.3g fA | VPRP %.2f..%.2f | p-n avg %.2f uV pp %.2f mV' % (r['VPRN_min_mV'], r['VPRN_max_mV'], r['VPRN_avg_mV'], r['VPRN_Iest_avg_fA'], r['VPRP_min_mV'], r['VPRP_max_mV'], r['pn_dm_avg_uV'], r['pn_dm_pp_mV']) if 'VPRN_avg_mV' in r else ''))
