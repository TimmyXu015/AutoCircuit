#!/usr/bin/env python3
r"""R8C netlist audit. NEW vs REF instance-by-instance (analysis statements excluded), parameter block, subckts.
Usage: r8c_netlist_audit.py NEW REF --removed A,B --added C,D [--expect NAME=REGEX ...] [--allow name=value ...]
  --removed / --added : exact expected instance sets (empty = none)
  --expect NAME=REGEX : the NEW line of NAME must match REGEX (e.g. RPRP=^RPRP \(p fn\) resistor r=3.128T$)
  --allow name=value  : allowed parameter-block differences (value in NEW)
  --subremoved S      : subckt definitions expected to be absent from NEW (no longer instantiated)
Also prints the analysis statements of both netlists, for the record."""
import sys, re
def parts(t):
    L = []; ls = t.splitlines(); i = 0
    while i < len(ls):
        s = ls[i]
        while s.endswith('\\') and i + 1 < len(ls): i += 1; s = s[:-1] + ' ' + ls[i].strip()
        L.append(' '.join(s.split())); i += 1
    top = {}; subs = {}; par = {}; ana = []; cur = None
    for k, l in enumerate(L):
        if l.startswith('subckt '): cur = l.split()[1]; subs[cur] = [l]; continue
        if cur:
            subs[cur].append(l); cur = None if l.startswith('ends') else cur; continue
        if l.startswith('parameters '):
            par.update(kv.split('=', 1) for kv in l.split()[1:]); continue
        if re.match(r'^(pss|pac|pnoise|noise|ac|dc|tran|stb) +(pss|pac|pnoise|noise|ac|dc|tran|stb)\b', l) or l.startswith('+'):
            ana.append(l); continue
        m = re.match(r'^(\w+) \(', l)
        if m: top[m.group(1)] = l
    return top, subs, par, ana
args = sys.argv[1:]; new, ref = open(args[0]).read(), open(args[1]).read()
opt = {'--removed': [], '--added': [], '--expect': [], '--allow': [], '--subremoved': []}; k = 2; key = None
while k < len(args):
    if args[k] in opt: key = args[k]
    else: opt[key].append(args[k])
    k += 1
want_rem = sorted(x for a in opt['--removed'] for x in a.split(',') if x)
want_add = sorted(x for a in opt['--added'] for x in a.split(',') if x)
tn, sn, pn, an = parts(new); tr, sr, pr, ar = parts(ref); ok = []
def chk(c, m): ok.append(bool(c)); print('%s  %s' % ('PASS' if c else 'FAIL', m))
rem = sorted(set(tr) - set(tn)); add = sorted(set(tn) - set(tr)); chg = sorted(n for n in set(tn) & set(tr) if tn[n] != tr[n])
chk(rem == want_rem, 'removed = %s (expected %s)' % (rem, want_rem))
for n in rem: print('    REF %s' % tr[n])
chk(add == want_add, 'added = %s (expected %s)' % (add, want_add))
for n in add: print('    NEW %s' % tn[n])
chk(not chg, 'changed = %s' % chg)
for n in chg: print('    REF %s\n    NEW %s' % (tr[n], tn[n]))
for e in opt['--expect']:
    name, rx = e.split('=', 1); chk(name in tn and re.search(rx, tn[name]), '%s matches /%s/: %s' % (name, rx, tn.get(name)))
allow = dict(a.split('=', 1) for a in opt['--allow'])
diff = {k: (pr.get(k), pn.get(k)) for k in set(pn) | set(pr) if pn.get(k) != pr.get(k)}
chk(set(diff) == set(allow) and all(float(pn[k]) == float(v) for k, v in allow.items()), 'parameter differences %s (allowed %s)' % (diff, allow))
sub_rem = sorted(x for a in opt['--subremoved'] for x in a.split(',') if x)
chk(sorted(set(sr) - set(sn)) == sub_rem and not set(sn) - set(sr) and all(sn[s] == sr[s] for s in sn), 'subckts identical: %s (expected removed %s, removed %s)' % (sorted(sn), sub_rem, sorted(set(sr) - set(sn))))
for n in ('EOC', 'CHP'): chk(n not in tn, '%s absent (fixture stays removed)' % n)
print('analysis NEW: ' + ' | '.join(an)); print('analysis REF: ' + ' | '.join(ar))
print('AUDIT', 'PASS' if all(ok) else 'FAIL')
