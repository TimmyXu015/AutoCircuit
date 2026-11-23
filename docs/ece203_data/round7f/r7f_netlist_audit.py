#!/usr/bin/env python3
"""R7F netlist audit + designed-capacitance budget.
Usage: r7f_netlist_audit.py NEW REF [--changed A,B] [--added A,B] [--param name=value ...]
- top-level instance lines (continuations joined, order-free): every instance must be identical except the ones listed as
  --changed (present in both, line differs) or --added (only in NEW); nothing may be removed;
- the 'parameters' block must be identical except the --param entries, which must have exactly the given value in NEW;
- every subckt must be byte-identical;
- prints the capacitor budget of NEW (values evaluated with its parameters): design caps vs test/model caps."""
import sys, re
args = sys.argv[1:]; new, ref = open(args[0]).read(), open(args[1]).read()
opt = {'--changed': [], '--added': [], '--param': []}; k = None
for a in args[2:]:
    if a in opt: k = a; continue
    opt[k] += a.split(',') if k != '--param' else [a]
def joined(t):
    out = []; ls = t.splitlines(); i = 0
    while i < len(ls):
        s = ls[i]
        while s.endswith('\\') and i + 1 < len(ls):
            i += 1; s = s[:-1] + ' ' + ls[i].strip()
        out.append(' '.join(s.split())); i += 1
    return out
def parts(t):
    L = joined(t); top = {}; subs = {}; params = {}; cur = None
    for l in L:
        if l.startswith('subckt '): cur = l.split()[1]; subs[cur] = [l]; continue
        if cur:
            subs[cur].append(l)
            if l.startswith('ends'): cur = None
            continue
        if l.startswith('parameters '):
            for kv in l.split()[1:]:
                a, b = kv.split('=', 1); params[a] = b
            continue
        m = re.match(r'^(\w+) \(', l)
        if m and not re.match(r'^(simulatorOptions|modelParameter|element|outputParameter|designParamVals|primitives|subckts|finalTimeOP|dcOp|dcOpInfo|tran|ac|dc|stb|saveOptions)\b', l):
            top[m.group(1)] = l
    return top, subs, params
tn, sn, pn = parts(new); tr, sr, pr = parts(ref); chk = []
def ok(c, m): chk.append((bool(c), m)); print('%s  %s' % ('PASS' if c else 'FAIL', m))
removed = sorted(set(tr) - set(tn)); added = sorted(set(tn) - set(tr)); changed = sorted(n for n in set(tn) & set(tr) if tn[n] != tr[n])
ok(not removed, 'nothing removed: %s' % removed)
ok(added == sorted(opt['--added']), 'added = %s (expected %s)' % (added, sorted(opt['--added'])))
ok(changed == sorted(opt['--changed']), 'changed = %s (expected %s)' % (changed, sorted(opt['--changed'])))
for n in added + changed: print('    NEW %s' % tn[n]); n in tr and print('    REF %s' % tr[n])
pexp = dict(p.split('=', 1) for p in opt['--param'])
pdiff = sorted(k for k in set(pn) | set(pr) if pn.get(k) != pr.get(k))
ok(sorted(pdiff) == sorted(pexp), 'parameter differences = %s (expected %s)' % ({k: (pr.get(k), pn.get(k)) for k in pdiff}, sorted(pexp)))
for k_, v in pexp.items(): ok(k_ in pn and float(pn[k_]) == float(v), 'parameter %s = %s in NEW (%s)' % (k_, v, pn.get(k_)))
ok(sorted(sn) == sorted(sr) and all(sn[s] == sr[s] for s in sn), 'all subckts identical: %s' % sorted(sn))
# capacitor budget
units = {'f': 1e-15, 'p': 1e-12, 'n': 1e-9, 'u': 1e-6, 'm': 1e-3, 'M': 1e6, 'k': 1e3}
def num(x):
    m = re.match(r'^([-+0-9.eE]+)([fpnumMk]?)$', x); return float(m.group(1)) * units.get(m.group(2), 1.0)
env = {k_: num(v) if re.match(r'^[-+0-9.eE]+[fpnumMk]?$', v) else v for k_, v in pn.items()}
caps = []
for n, l in tn.items():
    m = re.match(r'^(\w+) \(([^)]*)\) capacitor c=(\S+)', l)
    if m:
        expr = m.group(3)
        try: val = num(expr)
        except Exception: val = eval(expr, {}, env)
        caps.append((n, m.group(2), val))
for s, ls in sn.items():
    for l in ls:
        if ' capacitor ' in l: caps.append(('%s/%s' % (s, l.split()[0]), 'subckt', None))
role = {'CCP': 'design: input coupling Cc', 'CCN': 'design: input coupling Cc', 'CFP': 'design: feedback Cfb', 'CFN': 'design: feedback Cfb',
        'CLP_P': 'design: output LP C', 'CLP_N': 'design: output LP C', 'CLBP': 'design (task: CD output load 10 pF)', 'CLBN': 'design (task: CD output load 10 pF)',
        'CCMP': 'design: DRL CM-sense coupling', 'CCMN': 'design: DRL CM-sense coupling',
        'COUTP': 'test: downstream stress load', 'COUTN': 'test: downstream stress load', 'CCX': 'test: 1 % Cc mismatch aid (cc*dcc)',
        'CEP': 'external: electrode', 'CEN': 'external: electrode', 'CER': 'external: electrode', 'CBODY': 'external: body model',
        'CHP': 'test: STB/AC aid', 'CVG': 'test: probe aid (1 aF)'}
tot = 0.0; print('--- capacitor budget of NEW')
for n, nodes, v in sorted(caps):
    r = role.get(n, 'UNCLASSIFIED')
    print('    %-8s %-14s %12s  %s' % (n, nodes, '%.4g pF' % (v * 1e12) if v is not None else '?', r))
    if r.startswith('design') and v is not None: tot += v
print('    designed capacitance total (Cc + Cfb + CLB + CLP + DRL CM caps) = %.2f pF  (< 1000 pF: %s)' % (tot * 1e12, tot < 1e-9))
ok(not any(role.get(n, 'UNCLASSIFIED') == 'UNCLASSIFIED' for n, _, _ in caps), 'every capacitor classified')
print('AUDIT', 'PASS' if all(c for c, _ in chk) else 'FAIL')
