#!/usr/bin/env python3
"""R7A device characterization (design input only, not a CMFB candidate run): single nfet/pfet from the cmrf7sf
PDK at the bias conditions of a CMFB detector pair / tail / diode load. Writes netlist, runs Spectre, parses
psfascii oppoint. Runs on ieng6 in /tmp/lix015_r7a/char."""
import os, subprocess, re
W = '/tmp/lix015_r7a/char'
os.makedirs(W, exist_ok=True)
MODELS = '/software/linux/IBM7RF/IBM_PDK/cmrf7sf/V2.0.0.2AM/Spectre/models'

def fet(name, typ, d, g, s, b, w, l):
    ad = w * 0.54e-6; pd = 2 * w + 2 * 0.54e-6
    return ('%s (%s %s %s %s) %s l=%g w=%g nf=1 m=1 par=1 ad=%g as=%g pd=%g ps=%g nrd=0.4814815 nrs=0.4814815 '
            'gcon=1 rf=0 rsx=50 dtemp=0%s' % (name, d, g, s, b, typ, l, w, ad, ad, pd, pd, ' stis=2 gns=0' if typ == 'nfet' else ''))

L = ['simulator lang=spectre', 'global 0', 'parameters p5vonly=0 phires=0', 'include "design.scs"', 'include "wafer.scs"', 'include "allModels.scs" section=tt',
     'VG (g 0) vsource dc=0.9', 'VD (d 0) vsource dc=1.3', 'VDD (vdd 0) vsource dc=1.8', 'VPD (pd 0) vsource dc=0.9']
cases = []
# NMOS input-pair device: gate 0.9 V, drain 1.3 V, bulk 0, source fed by an ideal sink of I
for w in (0.5e-6, 1e-6, 2e-6):
    for l in (4e-6, 8e-6, 16e-6, 24e-6, 32e-6, 40e-6):
        for i in (25e-9, 50e-9, 75e-9):
            n = 'N_%g_%g_%g' % (w * 1e6, l * 1e6, i * 1e9)
            n = n.replace('.', 'p')
            L.append(fet(n, 'nfet', 'd', 'g', 's' + n, '0', w, l))
            L.append('I%s (s%s 0) isource dc=%g' % (n, n, i))
            cases.append(n)
# PMOS diode (vg generator) and mirror device at VSD 0.9: 2u/4u reference size, plus a few widths
for w in (1e-6, 2e-6, 4e-6):
    for l in (4e-6,):
        for i in (50e-9, 100e-9, 150e-9):
            n = ('PD_%g_%g_%g' % (w * 1e6, l * 1e6, i * 1e9)).replace('.', 'p')
            L.append(fet(n, 'pfet', 'g' + n, 'g' + n, 'vdd', 'vdd', w, l))
            L.append('I%s (g%s 0) isource dc=%g' % (n, n, i))
            cases.append(n)
L += ['simulatorOptions options reltol=1e-5 vabstol=1e-6 iabstol=1e-17 temp=27 tnom=25 gmin=1e-18',
      'dcop dc oppoint=rawfile', '']
open(W + '/char.scs', 'w').write('\n'.join(L))
env = dict(os.environ); env['LD_LIBRARY_PATH'] = os.environ.get('SPECTRE_LDLP', '')
subprocess.call(['spectre', 'char.scs', '+log', 'char.out', '-format', 'psfascii', '-raw', 'psf', '-I' + MODELS],
                cwd=W, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
import sys; sys.path.insert(0, '/tmp/lix015_r7a')
import psfop
op = psfop.oppoint(W + '/psf/dcop.info')
print('case,ids_nA,vgs,vds,vth,vov,vdsat,gm_uS,gm_over_id,gds_nS,region')
for c in cases:
    o = op.get(c, {})
    if not o:
        print(c, 'missing'); continue
    print('%s,%.2f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%.3f,%s' % (c, abs(o['ids'])*1e9, o['vgs'], o['vds'], o['vth'],
          abs(o['vgs']) - abs(o['vth']), o['vdsat'], o['gm']*1e6, o['gm']/abs(o['ids']), o['gds']*1e9, o.get('region')))
