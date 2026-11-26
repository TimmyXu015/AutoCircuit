"""F2S netlist audit: each case netlist (ADE netlist of Project/ece203_f2s_tb_<case>) vs the F2V audited netlist
(A_prof_dm_netlist.scs of Project/ece203_f2_1ua_prof_tb). Allowed differences: the OTA1 subckt name (XA master) and, inside it, the
w / l and CDF-derived ad / as / pd / ps of devices whose size the case changes. Also checks realised W/L == requested (no clipping).
Usage: python3 f2s_audit.py <F2V base netlist> <case netlist dir> case[:n_w,n_l,p_w,p_l,t_w,t_l] ...   -> f2s_netlist_audit.txt"""
import sys, re
def parse(fn):
    txt = open(fn).read().replace('\\\n', ' ')
    lines = [l for l in txt.split('\n') if not l.lstrip().startswith('//')]
    sub, cur, top, params = {}, None, {}, {}
    for l in lines:
        m = re.match(r'subckt (\w+)', l)
        if m: cur = m.group(1); sub[cur] = {}; continue
        if l.startswith('ends'): cur = None; continue
        m = re.match(r'\s*(\w+) \(([^)]*)\) (\w+)\s*(.*)$', l)
        if m and not l.startswith(('simulator', 'save')):
            p = dict(re.findall(r'(\w+)=(\S+)', m.group(4)))
            (sub[cur] if cur else top)[m.group(1)] = (m.group(2).split(), m.group(3), p)
        if l.startswith('parameters'): params.update(dict(re.findall(r'(\w+)=(\S+)', l)))
    return sub, top, params
def num(v):
    v = v.strip()
    m = re.match(r'^([-+0-9.eE]+)([a-zA-Z]*)$', v)
    if not m: return v
    sc = {'': 1, 'u': 1e-6, 'n': 1e-9, 'p': 1e-12, 'f': 1e-15, 'm': 1e-3, 'k': 1e3, 'M': 1e6}
    return float(m.group(1)) * sc.get(m.group(2), float('nan'))
base, cdir = sys.argv[1], sys.argv[2]
bsub, btop, bpar = parse(base)
out = []; say = out.append; allok = True
bota = bsub['ece203_r5nf_ota_f2']
for arg in sys.argv[3:]:
    case, _, req = arg.partition(':')
    req = [float(x) for x in req.split(',')] if req else None
    sub, top, par = parse('%s/%s_netlist.scs' % (cdir, case))
    ok = True; notes = []
    ota_name = top['XA'][1]
    # top level: identical except the XA master name
    for k in sorted(set(btop) | set(top)):
        a, b = btop.get(k), top.get(k)
        if k == 'XA':
            if a[0] != b[0]: ok = False; notes.append('XA nets differ')
            continue
        if a != b: ok = False; notes.append('top %s differs: %s | %s' % (k, a, b))
    for k in sorted(set(bpar) | set(par)):
        if bpar.get(k) != par.get(k): ok = False; notes.append('parameter %s %s -> %s' % (k, bpar.get(k), par.get(k)))
    for s in sorted(set(bsub) | set(sub)):
        if s in ('ece203_r5nf_ota_f2', ota_name): continue
        if bsub.get(s) != sub.get(s): ok = False; notes.append('subckt %s differs' % s)
    ota = sub[ota_name]; changed = []
    for d in sorted(set(bota) | set(ota)):
        a, b = bota.get(d), ota.get(d)
        if a is None or b is None or a[0] != b[0] or a[1] != b[1]: ok = False; notes.append('OTA device %s topology differs' % d); continue
        dk = sorted(k for k in set(a[2]) | set(b[2]) if a[2].get(k) != b[2].get(k))
        if dk:
            if not set(dk) <= {'w', 'l', 'ad', 'as', 'pd', 'ps'}: ok = False; notes.append('OTA %s non-geometry params differ %s' % (d, dk))
            w, l = num(b[2]['w']), num(b[2]['l'])
            adok = abs(num(b[2]['ad']) - w * 0.54e-6) < 1e-18 and abs(num(b[2]['pd']) - 2 * (w + 0.54e-6)) < 1e-12
            changed.append('%s w %s l %s (was %s/%s; ad/pd consistent %s)' % (d, b[2]['w'], b[2]['l'], a[2]['w'], a[2]['l'], adok))
            ok &= adok
    if req:
        want = {'M1': req[0:2], 'M2': req[0:2], 'M3': req[2:4], 'M4': req[2:4], 'MT': req[4:6], 'MC': [10, 4], 'MREF': [2, 4]}
        for d, (w, l) in want.items():
            rw, rl = num(ota[d][2]['w']) * 1e6, num(ota[d][2]['l']) * 1e6
            if abs(rw - w) > 1e-6 * w or abs(rl - l) > 1e-6 * l: ok = False; notes.append('%s realised %g/%g != requested %g/%g' % (d, rw, rl, w, l))
    say('%s (OTA %s): %s; changed: %s%s' % (case, ota_name, 'PASS' if ok else 'FAIL', '; '.join(changed) or 'none',
                                            (' | ' + ' | '.join(notes)) if notes else ''))
    allok &= ok
say('AUDIT ' + ('PASS' if allok else 'FAIL'))
open('f2s_netlist_audit.txt', 'w').write('\n'.join(out) + '\n'); print('\n'.join(out))
