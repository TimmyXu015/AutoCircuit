#!/usr/bin/env python3
"""R8B netlist audit: NEW (R8B cell) vs REF (R8 run on the R7F cell, same analysis). Instances removed must be exactly EOC and CHP;
nothing added or changed; parameter block identical; subckts identical; node ocx must not appear anywhere else in NEW.
Usage: r8b_netlist_audit.py NEW REF"""
import sys, re
def parts(t):
    L = []; ls = t.splitlines(); i = 0
    while i < len(ls):
        s = ls[i]
        while s.endswith('\\') and i + 1 < len(ls): i += 1; s = s[:-1] + ' ' + ls[i].strip()
        L.append(' '.join(s.split())); i += 1
    top = {}; subs = {}; par = {}; cur = None
    for l in L:
        if l.startswith('subckt '): cur = l.split()[1]; subs[cur] = [l]; continue
        if cur:
            subs[cur].append(l); cur = None if l.startswith('ends') else cur; continue
        if l.startswith('parameters '):
            par.update(kv.split('=', 1) for kv in l.split()[1:]); continue
        m = re.match(r'^(\w+) \(', l)
        if m: top[m.group(1)] = l
    return top, subs, par
new, ref = open(sys.argv[1]).read(), open(sys.argv[2]).read()
tn, sn, pn = parts(new); tr, sr, pr = parts(ref); ok = []
def chk(c, m): ok.append(bool(c)); print('%s  %s' % ('PASS' if c else 'FAIL', m))
rem = sorted(set(tr) - set(tn)); add = sorted(set(tn) - set(tr)); chg = sorted(n for n in set(tn) & set(tr) if tn[n] != tr[n])
chk(rem == ['CHP', 'EOC'], 'removed = %s' % rem)
for n in rem: print('    REF %s' % tr[n])
chk(not add, 'added = %s' % add); chk(not chg, 'changed = %s' % chg)
chk(pn == pr, 'parameters identical (%d)' % len(pn))
chk(sorted(sn) == sorted(sr) and all(sn[s] == sr[s] for s in sn), 'subckts identical: %s' % sorted(sn))
users = [n for n, l in tn.items() if re.search(r'\(([^)]*\b)?ocx\b', l)]
chk(not users, 'node ocx unused in NEW (%s)' % users)
for n in ('RHP', 'EB2'): chk(n in tn and tn[n] == tr[n], '%s kept: %s' % (n, tn.get(n)))
print('AUDIT', 'PASS' if all(ok) else 'FAIL')
