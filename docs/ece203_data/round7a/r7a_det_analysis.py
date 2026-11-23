#!/usr/bin/env python3
"""R7A Stage 2 standalone detector analysis -> r7a_det_summary.csv (+ per-variant e(Vd) curves).
Usage: python3 r7a_det_analysis.py RAWDIR VG_TARGET variant [variant ...]   (variant 'old' = R6A DD-pair)"""
import sys, csv, os
import numpy as np

raw, vgt = sys.argv[1], float(sys.argv[2])
vars_ = sys.argv[3:]

def sweep(v, vcm):
    d = np.genfromtxt(os.path.join(raw, 'D_%s_sw_vcm%d.csv' % (v, round(vcm * 1000))), delimiter=',', names=True)
    return d['vd_V'], d['vg_V'], d['i_vddc_A']

def at(x, y, x0):
    return float(np.interp(x0, x, y))

rows = []
for v in vars_:
    vd, vg900, ic = sweep(v, 0.900)
    _, vg899, _ = sweep(v, 0.899)
    _, vg901, _ = sweep(v, 0.901)
    A = (at(vd, vg901, 0) - at(vd, vg899, 0)) / 0.002            # dvg/dVcm at vd = 0
    Avd = (vg901 - vg899) / 0.002                                  # dvg/dVcm along vd
    vcm0 = 0.9 + (vgt - at(vd, vg900, 0)) / A
    r = {'variant': v, 'A_ctrl': A, 'A_ctrl_min_over_vd': float(Avd.min()), 'vg_at_0p9': at(vd, vg900, 0),
         'vg_target': vgt, 'Vcm0_minus_0p9_mV': (vcm0 - 0.9) * 1e3, 'I_ctrl_nA': at(vd, ic, 0) * 1e9}
    curves = {'vd_V': vd}
    for vcm in (0.88, 0.90, 0.92):
        _, vgc, _ = sweep(v, vcm)
        e = (vgc - at(vd, vgc, 0)) / A
        curves['e_vcm%d_mV' % round(vcm * 1000)] = e * 1e3
        for x in (0.05, 0.10, 0.20):
            r['e_vcm%d_vd%+.2f_mV' % (round(vcm * 1000), x)] = at(vd, e, x) * 1e3
            r['e_vcm%d_vd%+.2f_mV' % (round(vcm * 1000), -x)] = at(vd, e, -x) * 1e3
        r['vg_vcm%d' % round(vcm * 1000)] = at(vd, vgc, 0)
    # quadratic coefficient fit over |vd| <= 0.1 at vcm 0.9 -> predicted 200 Hz CM for a +-94 mV DM sine
    m = np.abs(vd) <= 0.1
    k = np.polyfit(vd[m], curves['e_vcm900_mV'][m], 2)[0]       # mV / V^2
    r['k2_vcm900_mV_per_V2'] = k
    r['pred_200Hz_mV_at_94mV'] = abs(k) * 0.094 ** 2 / 2
    with open(os.path.join(raw, '..', 'r7a_det_e_%s.csv' % v), 'w', newline='') as f:
        w = csv.writer(f); w.writerow(list(curves)); w.writerows(np.column_stack(list(curves.values())))
    # oppoint margins
    op = list(csv.DictReader(open(os.path.join(raw, 'D_%s_op.csv' % v))))
    mins = [(float(o['margin_V']), o['inst'], o['vcm'], o['vd']) for o in op if o['margin_V'] not in ('n/a', '')]
    mn = min(mins)
    r['min_margin_V'], r['min_margin_where'] = mn[0], '%s vcm %s vd %s' % mn[1:]
    vgs = [float(o['vg_V']) for o in op]
    r['vg_min_op'], r['vg_max_op'] = min(vgs), max(vgs)
    r['regions'] = ' '.join(sorted({'%s:%s' % (o['inst'].split('.')[-1], o['region']) for o in op if o['vcm'] == '0.9' and o['vd'] == '0'}))
    rows.append(r)

keys = list(rows[0].keys())
with open(os.path.join(raw, '..', 'r7a_det_summary.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, keys); w.writeheader(); w.writerows(rows)
old = next((r for r in rows if r['variant'] == 'old'), None)
for r in rows:
    print('\n== %s' % r['variant'])
    for k in keys:
        print('  %-28s %s' % (k, r[k]))
    if r['variant'] != 'old':
        g = {}
        g['S1 polarity'] = r['A_ctrl_min_over_vd'] > 0
        g['S2 0.2<=A<=2'] = 0.2 <= r['A_ctrl'] <= 2
        g['S3 |Vcm0-0.9|<=1mV'] = abs(r['Vcm0_minus_0p9_mV']) <= 1
        g['S4 |e(+-0.1)|<=0.4mV'] = max(abs(r['e_vcm900_vd+0.10_mV']), abs(r['e_vcm900_vd-0.10_mV'])) <= 0.4
        if old:
            ok = True
            for vc in (880, 920):
                for s in ('+', '-'):
                    kk = 'e_vcm%d_vd%s0.10_mV' % (vc, s)
                    ok = ok and abs(r[kk]) <= abs(old[kk]) / 4
            g['S5 <=1/4 old at vcm 0.88/0.92'] = ok
        g['S6 margins>=0, vg 0.3-1.6'] = r['min_margin_V'] >= 0 and 0.3 <= r['vg_min_op'] and r['vg_max_op'] <= 1.6
        g['S7 I<=0.5uA'] = r['I_ctrl_nA'] <= 500
        for k, x in g.items():
            print('  GATE %-32s %s' % (k, 'PASS' if x else 'FAIL'))
