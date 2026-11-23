#!/usr/bin/env python3
"""R7D netlist audit. Usage: r7d_netlist_audit.py R7D_NETLIST R7C_NETLIST
Checks: IB/IBD present in R7C and absent in R7D; exactly one IREF (pref 0) isource dc=100n; MP0 (pref pref vdd vdd),
MP1 (ib pref vdd vdd), MP2 (ibd pref vddd vddd) PMOS (model pfet*) L=4u; no other isource with a non-zero dc value
(IINT / IINTT / IZN / IZP are stimulus sources with dc=0 or ac/pulse/sine only, listed); VDD and VDDD independent 1.8 V
sources to ground; every other top-level instance line identical to R7C (structural diff printed)."""
import sys, re, difflib
new, old = open(sys.argv[1]).read(), open(sys.argv[2]).read()
def inst(txt, name):
    return [l for l in txt.splitlines() if re.match(r'^%s \(' % re.escape(name), l)]
def cont(txt, name):  # instance line with continuation lines joined
    ls = txt.splitlines(); out = []
    for i, l in enumerate(ls):
        if re.match(r'^%s \(' % re.escape(name), l):
            s = l
            while s.endswith('\\'):
                i += 1; s = s[:-1] + ' ' + ls[i].strip()
            out.append(s)
    return out
chk = []
def ok(c, msg): chk.append((bool(c), msg))
ok(inst(old, 'IB') and inst(old, 'IBD'), 'R7C has IB / IBD: %s | %s' % (inst(old, 'IB'), inst(old, 'IBD')))
ok(not inst(new, 'IB') and not inst(new, 'IBD'), 'IB / IBD absent in R7D')
ir = cont(new, 'IREF')
ok(len(ir) == 1 and re.match(r'^IREF \(pref 0\) isource dc=100n', ir[0]), 'IREF pref -> gnd, dc 100n: %s' % ir)
for n, t in (('MP0', 'pref pref vdd vdd'), ('MP1', 'ib pref vdd vdd'), ('MP2', 'ibd pref vddd vddd')):
    l = cont(new, n)
    ok(len(l) == 1 and re.match(r'^%s \(%s\) pfet\w* l=4u' % (n, t), l[0]), '%s D G S B = %s, PMOS L 4u: %s' % (n, t, l[0][:80] if l else '-'))
isrc = [l for l in (cont(new, m.group(1)) for m in re.finditer(r'^(\w+) \([^)]*\) isource', new, re.M))]
others = [l[0] for l in isrc if not l[0].startswith('IREF ')]
nonzero = [l for l in others if re.search(r'\bdc=(?!0\b)', l)]
ok(not nonzero, 'no other isource with non-zero dc (stimulus sources: %s)' % [l.split()[0] for l in others])
ok(cont(new, 'VDD')[0].startswith('VDD (vdd 0) vsource dc=vdd') and cont(new, 'VDDD')[0].startswith('VDDD (vddd 0) vsource dc=vdd'), 'VDD / VDDD independent sources to ground (vdd = 1.8)')
ok(re.search(r'\bvdd=1\.8\b', new), 'parameter vdd=1.8')
for c, m in chk:
    print('%s  %s' % ('PASS' if c else 'FAIL', m))
def top(t):
    out = []; skip = False; insub = False
    for l in t.splitlines():
        if l.startswith('subckt'): insub = True
        if insub:
            if l.startswith('ends'): insub = False
            continue
        if skip:
            skip = l.endswith('\\'); continue
        if l.startswith(('//', 'parameters', 'simulatorOptions', 'tran ', 'ac ', 'dc ', 'stb ', 'dcOp', 'save', 'finalTimeOP', 'modelParameter', 'element ', 'outputParameter', 'designParamVals', 'primitives', 'subckts ', 'include', 'saveOptions')) or 'psf' in l:
            skip = l.endswith('\\'); continue
        out.append(l)
    return out
d = [l for l in difflib.unified_diff(top(old), top(new), lineterm='', n=0) if l[:1] in '+-' and not l.startswith(('+++', '---'))]
print('--- top-level structural diff (R7C -> R7D), %d lines' % len(d))
for l in d: print(l)
subs = lambda t: sorted(re.findall(r'^subckt (\w+)', t, re.M))
ok(subs(new) == subs(old), 'same subckt set: %s' % subs(new)); print('%s  %s' % ('PASS' if chk[-1][0] else 'FAIL', chk[-1][1]))
for s in subs(new):
    a = re.search(r'^subckt %s .*?^ends' % s, old, re.M | re.S).group(0); b = re.search(r'^subckt %s .*?^ends' % s, new, re.M | re.S).group(0)
    ok(a == b, 'subckt %s identical' % s); print('%s  %s' % ('PASS' if a == b else 'FAIL', 'subckt %s identical' % s))
print('AUDIT', 'PASS' if all(c for c, _ in chk) else 'FAIL')
