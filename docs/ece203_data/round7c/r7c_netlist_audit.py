#!/usr/bin/env python3
"""R7C netlist audit (task section 1). Usage: r7c_netlist_audit.py PR_NETLIST REF_NETLIST
Checks the pseudo-R bench: no RFN/RFP, exactly two ece203_ss_pr_cell instances XPRN (n fp) / XPRP (p fn), the subckt holds one
pfet33x-family thick-oxide device (model name pfet33*) sized by prw/prl, parameters prw/prl present; CFN/CFP and all XCI/XCO/XA/XC/XD/XCD
present; VDD/VDDD independent sources to ground; and a structural diff vs the reference (ideal-Rfb) netlist."""
import sys, re, difflib
pr, ref = open(sys.argv[1]).read(), open(sys.argv[2]).read()
def inst(txt, name):
    return [l for l in txt.splitlines() if re.match(r'^%s \(' % re.escape(name), l)]
chk = []
def ok(c, msg): chk.append((bool(c), msg)); return c
ok(not inst(pr, 'RFN') and not inst(pr, 'RFP'), 'RFN/RFP absent in the pseudo-R netlist')
ok(len(inst(ref, 'RFN')) == 1 and len(inst(ref, 'RFP')) == 1, 'RFN/RFP present in the reference netlist')
xn, xp = inst(pr, 'XPRN'), inst(pr, 'XPRP')
ok(len(xn) == 1 and len(xp) == 1, 'exactly one XPRN and one XPRP')
ok(xn and re.match(r'^XPRN \(n fp\) ece203_ss_pr_cell', xn[0]), 'XPRN: A=n B=fp, cell ece203_ss_pr_cell (pins A B order): %s' % (xn[0] if xn else '-'))
ok(xp and re.match(r'^XPRP \(p fn\) ece203_ss_pr_cell', xp[0]), 'XPRP: A=p B=fn: %s' % (xp[0] if xp else '-'))
sub = re.search(r'^subckt ece203_ss_pr_cell (.*?)\n(.*?)^ends', pr, re.M | re.S)
ok(sub is not None, 'subckt ece203_ss_pr_cell present')
if sub:
    body = sub.group(2)
    dev = re.findall(r'^\s*(\w+) \(([^)]*)\) (\w+) (.*)', body, re.M)
    ok(len(dev) == 1, 'one device in the pseudo-R subckt: %s' % [d[:3] for d in dev])
    if dev:
        ok(dev[0][2].startswith('pfet33'), 'thick-oxide model %s (pfet33x family, not pfet)' % dev[0][2])
        ok(dev[0][1].split() == ['B', 'B', 'A', 'B'], 'terminals D G S B = B B A B: %s' % dev[0][1])
        ok('w=prw' in body.replace('(', '').replace(')', '') and 'l=prl' in body.replace('(', '').replace(')', ''), 'sized by prw / prl')
par = ' '.join(re.findall(r'^parameters (.*?)(?<!\\)$', pr, re.M | re.S))
ok(re.search(r'\bprw=', pr) and re.search(r'\bprl=', pr), 'prw/prl declared: %s' % re.findall(r'\bpr[wl]=\S+', pr))
for n in ('CFN', 'CFP', 'XCI', 'XCO', 'XA', 'XC', 'XD', 'XCD', 'CLBP', 'CLBN'):
    ok(len(inst(pr, n)) == 1, '%s present: %s' % (n, inst(pr, n)[0][:90] if inst(pr, n) else '-'))
ok(inst(pr, 'VDD') and inst(pr, 'VDD')[0].startswith('VDD (vdd 0) vsource') and inst(pr, 'VDDD')[0].startswith('VDDD (vddd 0) vsource'),
   'VDD / VDDD independent sources to ground')
for c, m in chk:
    print('%s  %s' % ('PASS' if c else 'FAIL', m))
# structural diff (comments, parameter block continuation lines, analyses and psf paths removed)
def norm(t):
    out = []; skip = False
    for l in t.splitlines():
        if l.startswith('//') or 'psf' in l or l.startswith(('simulatorOptions', 'tran ', 'ac ', 'dc ', 'stb ', 'dcOp ', 'save', 'finalTimeOP', 'modelParameter', 'element ', 'outputParameter', 'designParamVals', 'primitives', 'subckts ')):
            skip = l.endswith('\\'); continue
        if l.startswith('parameters'):
            skip = l.endswith('\\'); continue
        if skip:
            skip = l.endswith('\\'); continue
        out.append(l)
    return out
d = [l for l in difflib.unified_diff(norm(ref), norm(pr), lineterm='', n=0) if l[:1] in '+-' and not l.startswith(('+++', '---'))]
print('--- structural diff (reference -> pseudo-R), %d lines' % len(d))
for l in d:
    print(l)
print('AUDIT', 'PASS' if all(c for c, _ in chk) else 'FAIL')
