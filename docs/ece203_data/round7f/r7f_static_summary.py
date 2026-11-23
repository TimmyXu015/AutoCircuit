#!/usr/bin/env python3
"""R7F static (TG phase A) summary: one row per case from the system CSV (B_<case>.csv, r7cStageB1) + LP CSV (L_<case>.csv, r7eLp)
+ plateau-referenced corners from the Hout AC curve (L_<case>_dm_ac.csv): Hout_max, fL_plat / fH_plat = -3 dB vs |Hout| maximum,
Hout100 and plateau in dB. R7E C0 rows are read from round7e. Usage: python3 r7f_static_summary.py OUT.csv"""
import sys, os, csv, math
import numpy as np
here = os.path.dirname(os.path.abspath(__file__))
cases = [('R7E_lp_a0', os.path.join(here, '..', 'round7e', 'raw', 'stageA'), 'B_lp_a0', 'L_lp_a0'),
         ('R7E_lp_load10p', os.path.join(here, '..', 'round7e', 'raw', 'stageB'), None, 'L_lp_load10p')]
for c in ('lp_l0', 'lp_l0_load10p', 'lp_l1', 'lp_l1_load10p', 'gain_g0_load10p', 'gain_g0_unloaded', 'gain_g1_load10p', 'gain_g1_unloaded'):
    d = os.path.join(here, 'raw', 'static')
    if os.path.exists(os.path.join(d, 'L_%s.csv' % c)): cases.append((c, d, 'B_' + c, 'L_' + c))
def corners(fn):
    d = np.genfromtxt(fn, delimiter=',', names=True); f = d['f_Hz']; h = d['abs_Hout']; i0 = int(np.argmax(h)); hm = h[i0]
    db = 20 * np.log10(h / hm)
    lo = np.where((f < f[i0]) & (db <= -3))[0][-1]; fl = 10 ** np.interp(-3, [db[lo], db[lo + 1]], [np.log10(f[lo]), np.log10(f[lo + 1])])
    hi = np.where((f > f[i0]) & (db <= -3))[0][0]; fh = 10 ** np.interp(-3, [db[hi], db[hi - 1]], [np.log10(f[hi]), np.log10(f[hi - 1])])
    return hm, f[i0], fl, fh
rows = []
for name, d, b, l in cases:
    r = {'case': name}
    if b and os.path.exists(os.path.join(d, b + '.csv')):
        r.update({k: v for k, v in next(csv.DictReader(open(os.path.join(d, b + '.csv')))).items() if k not in ('case', 'cell', 'opts', 'reason')})
    r.update({'LP_' + k: v for k, v in next(csv.DictReader(open(os.path.join(d, l + '.csv')))).items() if k not in ('case', 'cell', 'status', 'reason')})
    hm, fm, fl, fh = corners(os.path.join(d, l + '_dm_ac.csv'))
    r.update({'Hout_plateau': hm, 'Hout_plateau_dB': 20 * math.log10(hm), 'f_at_plateau_Hz': fm, 'fL_plateau_Hz': fl, 'fH_plateau_Hz': fh,
              'Hout100_dB': 20 * math.log10(float(r['LP_Hout100']))})
    rows.append(r)
keys = []; [keys.append(k) for r in rows for k in r if k not in keys]
with open(sys.argv[1], 'w', newline='') as f:
    w = csv.DictWriter(f, keys, restval='n/a', lineterminator='\n'); w.writeheader()
    for r in rows: w.writerow({k: ('%.7g' % v if isinstance(v, float) else v) for k, v in r.items()})
for r in rows:
    print('%-18s Hpre100 %-9s Hbuf100 %-9s Hout100 %-9s (%.2f dB) plateau %.3f (%.2f dB) | fH_flat %-8s fH_plat %.1f fL_plat %.5f | PM %s/%s CMRR %s Zin %s CM %s P %s minA %s'
          % (r['case'], r.get('Hpre100', 'n/a')[:9], r.get('LP_Hbuf100', '')[:9], r['LP_Hout100'][:9], r['Hout100_dB'], r['Hout_plateau'], r['Hout_plateau_dB'],
             r['LP_fH_flat'][:8], r['fH_plateau_Hz'], r['fL_plateau_Hz'], r.get('cmfb_pm', 'n/a')[:6], r.get('drl_pm', 'n/a')[:6], r.get('CMRR60_pre', 'n/a')[:7],
             r.get('Zin_dm_src_10', 'n/a')[:8], r.get('op_cm', 'n/a'), r.get('P_uW', 'n/a')[:6], r.get('minA', 'n/a')[:7]))
