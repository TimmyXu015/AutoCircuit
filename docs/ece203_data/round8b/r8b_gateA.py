#!/usr/bin/env python3
"""R8B Gate A: OFF equivalence of the new bench (C1) vs the R8 Stage A run on the R7F bench (C0). Writes r8b_gateA.csv.
Usage: python3 r8b_gateA.py C0_BASE C1_BASE   (bases ending in .../A_off)"""
import sys, os, csv
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'round8')); import r8_spec
c0, c1 = sys.argv[1], sys.argv[2]
kv = [{r['key']: r['value'] for r in csv.DictReader(open(b + '.csv'))} for b in (c0, c1)]
rows = []
def add(name, a, b, tol, unit, rel=True):
    a = float(a); b = float(b); d = (b / a - 1) * 100 if rel else (b - a)
    ok = abs(d) <= tol; rows.append({'quantity': name, 'C0_R8': '%.9g' % a, 'C1_R8B': '%.9g' % b, 'diff': '%.4g %s' % (d, '%' if rel else unit), 'gate': '%s %s' % (tol, '%' if rel else unit), 'pass': ok})
for n in ('op', 'on', 'fp', 'fn', 'p', 'n', 'bufp', 'bufn', 'outp', 'outn', 'vg', 'ib', 'pref'):
    add('DC ' + n, kv[0]['dc_' + n], kv[1]['dc_' + n], 1e-6, 'V', rel=False)
add('I_VDD', kv[0]['I_VDD'], kv[1]['I_VDD'], 0.1, ''); add('I_VDDD', kv[0]['I_VDDD'], kv[1]['I_VDDD'], 0.1, '')
for k in ('Hoff0p1', 'Hoff1', 'Hoff10', 'Hoff60', 'Hoff100', 'Hoff250'): add('|' + k + '|', kv[0][k], kv[1][k], 0.1, '')
for k in ('out_0p1', 'out_1', 'out_10', 'out_100', 'out_250'): add('Sout ' + k[4:] + ' Hz', kv[0][k], kv[1][k], 1.0, '')
m = []
for b in (c0, c1):
    f, so, H, H100 = r8_spec.load(b); m.append((r8_spec.rms(f, so), r8_spec.rms(f, so) / H100, r8_spec.rms(f, so / H)))
add('output RMS 0.1-250', m[0][0], m[1][0], 1.0, ''); add('input app RMS', m[0][1], m[1][1], 1.0, ''); add('input de-embedded RMS', m[0][2], m[1][2], 1.0, '')
with open('r8b_gateA.csv', 'w', newline='') as fo:
    w = csv.DictWriter(fo, list(rows[0].keys()), lineterminator='\n'); w.writeheader(); [w.writerow(r) for r in rows]
for r in rows: print('%-24s %-14s %-14s %-14s %s' % (r['quantity'], r['C0_R8'], r['C1_R8B'], r['diff'], 'PASS' if r['pass'] else 'FAIL'))
print('GATE A numeric', 'PASS' if all(r['pass'] for r in rows) else 'FAIL', '| C0 app/deemb %.4f/%.4f uV, C1 %.4f/%.4f uV' % (m[0][1] * 1e6, m[0][2] * 1e6, m[1][1] * 1e6, m[1][2] * 1e6))
