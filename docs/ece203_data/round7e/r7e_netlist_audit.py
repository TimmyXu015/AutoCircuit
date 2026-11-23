#!/usr/bin/env python3
"""R7E netlist audit. Usage: r7e_netlist_audit.py R7E_NETLIST R7D_NETLIST [--load]
Checks: RLP_P (bufp outp) 31.8M, CLP_P (outp 0) 20p, RLP_N (bufn outn) 31.8M, CLP_N (outn 0) 20p; with --load also COUTP (outp 0)
10p and COUTN (outn 0) 10p; CLBP/CLBN still (bufp 0)/(bufn 0) clb=10p; CFN/CFP/XPRN/XPRP still on fp/fn (nothing on outp/outn
other than the LP and the optional load); IREF/MP0-2 and VDD/VDDD unchanged; every other top-level line and every subckt identical."""
import sys, re, difflib
new, old = open(sys.argv[1]).read(), open(sys.argv[2]).read(); load = '--load' in sys.argv
def cont(txt, name):
    ls = txt.splitlines(); out = []
    for i, l in enumerate(ls):
        if re.match(r'^%s \(' % re.escape(name), l):
            s = l
            while s.endswith('\\'):
                i += 1; s = s[:-1] + ' ' + ls[i].strip()
            out.append(s)
    return out
chk = []
def ok(c, m): chk.append((bool(c), m))
exp = [('RLP_P', r'^RLP_P \(bufp outp\) resistor r=31\.8M'), ('CLP_P', r'^CLP_P \(outp 0\) capacitor c=20p'),
       ('RLP_N', r'^RLP_N \(bufn outn\) resistor r=31\.8M'), ('CLP_N', r'^CLP_N \(outn 0\) capacitor c=20p')]
if load: exp += [('COUTP', r'^COUTP \(outp 0\) capacitor c=10p'), ('COUTN', r'^COUTN \(outn 0\) capacitor c=10p')]
for n, p in exp:
    l = cont(new, n); ok(len(l) == 1 and re.match(p, l[0]), '%s: %s' % (n, l[0] if l else '-'))
if not load: ok(not cont(new, 'COUTP') and not cont(new, 'COUTN'), 'no COUTP/COUTN in the unloaded case')
for n, p in (('CLBP', r'^CLBP \(bufp 0\) capacitor c=clb'), ('CLBN', r'^CLBN \(bufn 0\) capacitor c=clb'),
             ('CFN', r'^CFN \(fp n\)'), ('CFP', r'^CFP \(fn p\)'), ('XPRN', r'^XPRN \(n fp\)'), ('XPRP', r'^XPRP \(p fn\)'),
             ('IREF', r'^IREF \(pref 0\) isource dc=100n'), ('VDD', r'^VDD \(vdd 0\) vsource dc=vdd'), ('VDDD', r'^VDDD \(vddd 0\) vsource dc=vdd')):
    l = cont(new, n); ok(len(l) == 1 and re.match(p, l[0]) and cont(old, n) == l, '%s unchanged: %s' % (n, l[0][:70] if l else '-'))
users = sorted(set(m.group(1) for m in re.finditer(r'^(\w+) \(([^)]*)\)', new, re.M) if re.search(r'\bout[pn]\b', m.group(2))))
allowed = sorted(['RLP_P', 'CLP_P', 'RLP_N', 'CLP_N'] + (['COUTP', 'COUTN'] if load else []))
ok(users == allowed, 'only the LP (and load) parts touch outp/outn: %s' % users)
for c, m in chk: print('%s  %s' % ('PASS' if c else 'FAIL', m))
def top(t):
    out = []; skip = False; insub = False
    for l in t.splitlines():
        if l.startswith('subckt'): insub = True
        if insub:
            if l.startswith('ends'): insub = False
            continue
        if skip: skip = l.endswith('\\'); continue
        if l.startswith(('//', 'parameters', 'simulatorOptions', 'tran ', 'ac ', 'dc ', 'stb ', 'dcOp', 'save', 'finalTimeOP', 'modelParameter', 'element ', 'outputParameter', 'designParamVals', 'primitives', 'subckts ', 'include', 'saveOptions')) or 'psf' in l:
            skip = l.endswith('\\'); continue
        out.append(l)
    return sorted(out)
d = [l for l in difflib.unified_diff(top(old), top(new), lineterm='', n=0) if l[:1] in '+-' and not l.startswith(('+++', '---'))]
print('--- top-level diff (sorted lines, R7D -> R7E), %d lines' % len(d))
for l in d: print(l)
added = sorted(l[1:].split()[0] for l in d if l.startswith('+')); removed = [l for l in d if l.startswith('-')]
ok(not removed and added == allowed, 'diff = exactly %s added, nothing removed' % allowed); print('%s  %s' % ('PASS' if chk[-1][0] else 'FAIL', chk[-1][1]))
subs = lambda t: sorted(re.findall(r'^subckt (\w+)', t, re.M))
same = subs(new) == subs(old) and all(re.search(r'^subckt %s .*?^ends' % s, old, re.M | re.S).group(0) == re.search(r'^subckt %s .*?^ends' % s, new, re.M | re.S).group(0) for s in subs(new))
ok(same, 'all subckts identical: %s' % subs(new)); print('%s  %s' % ('PASS' if same else 'FAIL', chk[-1][1]))
print('AUDIT', 'PASS' if all(c for c, _ in chk) else 'FAIL')
