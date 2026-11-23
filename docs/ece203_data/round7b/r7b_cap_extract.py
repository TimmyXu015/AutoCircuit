#!/usr/bin/env python3
"""R7B step 1: summarise the R7A a2 detector input capacitance (per branch) -> r7b_cap_estimate.csv.
Inputs (raw/cap): r7b_capop_system.csv (BSIM op of XC.MA1/MB1 in the unchanged R7A system, TG static, vd 0) and
cin_<op|on>_vd<m94|p0|p94>mV_ceff.csv (standalone AC gate-input admittance, Ceff = Im(Y)/(2 pi f))."""
import csv, numpy as np
rows = []
for br in ('op', 'on'):
    for vd, lab in (('m94', -0.094), ('p0', 0.0), ('p94', 0.094)):
        d = np.genfromtxt('raw/cap/cin_%s_vd%smV_ceff.csv' % (br, vd), delimiter=',', names=True)
        lf = np.log10(d['f_Hz'])
        r = {'branch': br, 'vd_V': lab}
        for f in (1e3, 1e5, 1e6, 1e7, 1e8):
            r['Ceff_%gHz_fF' % f] = float(np.interp(np.log10(f), lf, d['Ceff_F'])) * 1e15
        r['G_1kHz_S'] = float(np.interp(3, lf, d['Geff_S']))
        rows.append(r)
with open('r7b_cap_estimate.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, list(rows[0])); w.writeheader(); w.writerows(rows)
op = {r['inst']: r for r in csv.DictReader(open('raw/cap/r7b_capop_system.csv'))}
ma1 = op['XC.MA1']
cgg, cgs, cgb, cgd = (float(ma1[k]) * 1e15 for k in ('cgg', 'cgs', 'cgb', 'cgd'))
c0 = [r for r in rows if r['branch'] == 'op' and r['vd_V'] == 0.0][0]['Ceff_100000Hz_fF']
allc = [v for r in rows for k, v in r.items() if k.startswith('Ceff')]
print('BSIM op XC.MA1: cgg %.2f fF, cgs %.2f, cgb %.2f, cgd %.3f fF (BSIM sign convention: cgs = -dQg/dVs)' % (cgg, cgs, cgb, cgd))
print('admittance Ceff(op, vd 0, 100 kHz) = %.2f fF; implied source-follow factor k = (cgg - Ceff)/|cgs| = %.3f (intrinsic only, ignores PDK wiring caps)' % (c0, (cgg - c0) / abs(cgs)))
print('Ceff range over vd +-94 mV and 1 kHz-100 MHz: %.2f .. %.2f fF' % (min(allc), max(allc)))
