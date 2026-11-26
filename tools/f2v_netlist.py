#!/usr/bin/env python3
"""F2 final validation scout: build a standalone Spectre netlist from the audited ADE netlist of
Project/ece203_f2_1ua_prof_tb (f2i job A_prof_dm) -- circuit lines are copied unchanged, only the
stimulus parameters become functions of a mode parameter fvm and the analyses are replaced.

  fvm = 0 : pure DM (V0 AC 1, interference AC 0), real DRL on  (rdr 1 MOhm)
  fvm = 1 : pure CM (V0 AC 0, I2 AC 100 nA),  DRL OFF (rdr 1e15, rdi stays 1e15: rl0 floats)
  fvm = 2 : pure CM (V0 AC 0, I2 AC 100 nA),  real DRL on

Usage (python3.6, stdlib only):
  f2v_netlist.py <base.scs> <out.scs> nominal  [dec]
  f2v_netlist.py <base.scs> <out.scs> mc <numruns> <seed> <firstrun> [dec]
  f2v_netlist.py <base.scs> <out.scs> ref [dec]       (archived F2 fixture netlist: dc + ac + noise only)
No PDK model content is read or written; the model include lines are kept as in the base netlist."""
import sys, re

base, out, kind = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(base).read().split('\n')
body = []
for l in lines:
    if l.startswith('simulatorOptions'): break
    body.append(l)
txt = '\n'.join(body)

def setp(txt, name, expr):
    new, n = re.subn(r'(?<=[ \t])%s=[^ \t\n\\]+' % name, '%s=%s' % (name, expr), txt, count=1)
    if n != 1: raise SystemExit('parameter %s not found' % name)
    return new

if kind != 'ref':
    txt = setp(txt, 'aecg', '((1-fvm)*(2-fvm)/2)')
    txt = setp(txt, 'aint', '(1e-7*fvm*(3-fvm)/2)')
    txt = setp(txt, 'rdr', '(1e6+(1e15-1e6)*fvm*(2-fvm))')
    txt = setp(txt, 'iint', '0')
    txt = setp(txt, 'dcc', 'dccv')
    txt = txt.replace('\nparameters ', '\nparameters fvm=0 dccv=0\nparameters ', 1)

opts = ('simulatorOptions options reltol=1e-6 vabstol=1e-6 iabstol=1e-18 temp=27 tnom=25 scalem=1.0 scale=1.0 \\\n'
        '    gmin=1e-18 rforce=1 maxnotes=5 maxwarns=5 digits=5 cols=80 pivrel=1e-3\n')
dec = None
sv = ('save out o oa oa1 p n inp inn vRight vLeft vRL net5 cm drlr rl0 vref ib ibd pref vcas net1 net013 net6 '
      'VDD:p VDDD:p VPP:p VPN:p IPRD:in MP2:d MP1:d MP0:d XA.MT:d XD.MT:d\n')
if kind == 'nominal':
    dec = sys.argv[4] if len(sys.argv) > 4 else '50'
    ana = (
        'dcop dc write="spectre.dc" maxiters=150 maxsteps=10000\n'
        'opinfo info what=oppoint where=rawfile\n'
        'sdcc sweep param=dccv values=[0 0.01] {\n'
        '  swm sweep param=fvm values=[0 1 2] {\n'
        '    dcm dc\n'
        '    acm ac start=1m stop=100k dec=%s\n'
        '    acx ac values=[10 60 100]\n'
        '  }\n'
        '}\n'
        'nz50 (out 0) noise start=1m stop=100k dec=%s iprobe=V0\n'
        'nz100 (out 0) noise start=1m stop=100k dec=100 iprobe=V0\n'
        'stbm stb start=1m stop=10M dec=20 probe=IPRB\n'
        'stbd stb start=1m stop=10M dec=20 probe=IPRD\n' % (dec, dec))
    save = sv + 'saveOptions options save=selected\n'
elif kind == 'mc':
    n, seed, first = sys.argv[4], sys.argv[5], sys.argv[6]
    dec = sys.argv[7] if len(sys.argv) > 7 else '20'
    ana = (
        'mc1 montecarlo numruns=%s seed=%s firstrun=%s variations=mismatch savefamilyplots=yes donominal=no {\n'
        '  dcop dc maxiters=150 maxsteps=10000\n'
        '  swm sweep param=fvm values=[0 1 2] {\n'
        '    dcm dc\n'
        '    acm ac start=1m stop=100k dec=%s\n'
        '    acx ac values=[10 60 100]\n'
        '  }\n'
        '  nz (out 0) noise start=1m stop=100k dec=%s iprobe=V0\n'
        '  stbm stb start=1m stop=10M dec=10 probe=IPRB\n'
        '  stbd stb start=1m stop=10M dec=10 probe=IPRD\n'
        '}\n' % (n, seed, first, dec, dec))
    save = sv + 'saveOptions options save=selected\n'
elif kind == 'ref':
    dec = sys.argv[4] if len(sys.argv) > 4 else '50'
    ana = ('dcop dc write="spectre.dc" maxiters=150 maxsteps=10000\n'
           'acr ac start=1m stop=100k dec=%s\n'
           'acrx ac values=[10 60 100]\n'
           'nzr (out 0) noise start=1m stop=100k dec=%s iprobe=VSP\n' % (dec, dec))
    save = 'save out o inpr innr ep en VDD:p VDDD:p\nsaveOptions options save=selected\n'
else:
    raise SystemExit('kind?')
open(out, 'w').write(txt.rstrip() + '\n\n// ---- f2v analyses (tools/f2v_netlist.py, kind=%s) ----\n' % kind + opts + ana + save)
print('wrote', out)
