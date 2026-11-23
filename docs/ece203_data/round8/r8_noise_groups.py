#!/usr/bin/env python3
"""R8 noise-source grouping. Parses Spectre/OCEAN noiseSummary text dumps (<tag>_ns_int_0p1_250.txt, _ns_int_b0..b3.txt for
0.1-1/1-10/10-100/100-250 Hz) of a case and writes one long table: case, band, group, kind (flicker = param fn; thermal = id,
rd, rs, rn, ...), output V^2, % of the band total, and an input-referred V^2 obtained as (share of the band output power) x
(band de-embedded input power from the exported spectrum) - a stated approximation (assumes the group's spectral shape
within the band follows the total). Usage: python3 r8_noise_groups.py OUT.csv CASE=DIR/TAG [CASE=DIR/TAG ...]"""
import sys, re, csv
import numpy as np
_trapz = getattr(np, "trapezoid", None) or getattr(np, "trapz")
GROUPS = [('XA input pair M1/M2', r'^/?XA[/.]M[12]\b'), ('XA PMOS loads M3/M4', r'^/?XA[/.]M[34]\b'), ('XA cascodes MC1/MC2', r'^/?XA[/.]MC[12]\b'),
          ('XA tail/ref', r'^/?XA[/.]M(T|REF)\b'), ('XC CMFB', r'^/?XC[/.]'), ('XD DRL', r'^/?XD[/.]'), ('XCD CD', r'^/?XCD[/.]'),
          ('XCI input TG', r'^/?XCI[/.]'), ('XCO output TG', r'^/?XCO[/.]'), ('XPRN/XPRP pseudo-R', r'^/?XPR[NP][/.]'),
          ('RLP_P/N LP resistors', r'^/?RLP_[PN]\b'), ('bias MP0-2', r'^/?MP[012]\b'), ('electrode/body/source R', r'^/?R(E|S|EP|EN|SP|SN|ER|DR|CM|BODY)\w*\b')]
BANDS = [('0.1-250', 0.1, 250.0, '_ns_int_0p1_250.txt'), ('0.1-1', 0.1, 1.0, '_ns_int_b0.txt'), ('1-10', 1.0, 10.0, '_ns_int_b1.txt'),
         ('10-100', 10.0, 100.0, '_ns_int_b2.txt'), ('100-250', 100.0, 250.0, '_ns_int_b3.txt')]
def group(dev):
    for g, rx in GROUPS:
        if re.search(rx, dev): return g
    return 'other'
def parse(fn):
    rows = []; total = None
    for l in open(fn):
        f = l.split()
        if l.startswith('Total Summarized Noise'): total = float(f[-1]); continue
        if len(f) >= 3 and f[0] != 'Device':
            try: rows.append((f[0], f[1], float(f[2])))
            except ValueError: pass
    return rows, total
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import r8_spec
def band_in_power(base, a, b):
    f, so, H, _ = r8_spec.load(base)
    return r8_spec.rms(f, so / H, a, b) ** 2, r8_spec.rms(f, so, a, b) ** 2
out = []
for arg in sys.argv[2:]:
    case, base = arg.split('=', 1)
    for band, a, b, sfx in BANDS:
        try: rows, total = parse(base + sfx)
        except FileNotFoundError: continue
        if not rows: continue
        pin, pout = band_in_power(base, a, b)
        agg = {}
        for dev, par, v in rows:
            k = (group(dev), 'flicker' if par == 'fn' else 'thermal/other')
            agg[k] = agg.get(k, 0.0) + v
        tot = total or sum(agg.values())
        for (g, kind), v in sorted(agg.items(), key=lambda x: -x[1]):
            if v <= 0: continue
            out.append({'case': case, 'band_Hz': band, 'group': g, 'kind': kind, 'out_V2': v, 'pct_of_band_out': 100 * v / tot,
                        'in_V2_approx': pin * v / tot, 'in_uVrms_approx': 1e6 * (pin * v / tot) ** 0.5,
                        'band_total_out_V2_summary': tot, 'band_out_V2_trapz': pout, 'band_in_V2_trapz': pin})
with open(sys.argv[1], 'w', newline='') as fo:
    w = csv.DictWriter(fo, list(out[0].keys()), lineterminator='\n'); w.writeheader()
    for r in out: w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
for r in out:
    if r['band_Hz'] == '0.1-250' and r['pct_of_band_out'] >= 0.05:
        print('%-12s %-26s %-14s %10.4g V2 %6.2f %%  in~%.3f uV' % (r['case'], r['group'], r['kind'], r['out_V2'], r['pct_of_band_out'], r['in_uVrms_approx']))
for r in out:
    if r['group'] == out[0]['group'] and r['kind'] == out[0]['kind']:
        print('  band %-8s summary total %.4g V2 vs trapz %.4g V2 (%.2f %%)' % (r['band_Hz'], r['band_total_out_V2_summary'], r['band_out_V2_trapz'], 100 * (r['band_out_V2_trapz'] / r['band_total_out_V2_summary'] - 1)))
