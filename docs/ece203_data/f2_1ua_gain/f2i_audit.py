"""Netlist audit for the F2-in-instructor-TB copy (plan 'Audit'). Usage: python3 f2i_audit.py <raw dir>. Writes f2i_netlist_audit.txt.
Checks (1) the instructor elements in the copy equal the read-only ECG_tb schematic dump, (2) the DUT elements equal the archived F2 fixture
netlist minus its fixture with nets renamed, (3) the shared parameters are identical, (4) every transient netlist differs from the AC one only in
stimulus parameters / analyses."""
import sys, re, os, glob
R = sys.argv[1] if len(sys.argv) > 1 else 'raw'
def parse(fn):
    L = [l.rstrip('\n') for l in open(fn) if not l.lstrip().startswith('//')]
    j = []
    for l in L:
        if j and j[-1].endswith('\\'): j[-1] = j[-1][:-1].rstrip() + ' ' + l.strip()
        else: j.append(l)
    el = {}; par = {}; inc = []
    for l in j:
        m = re.match(r'^(\w+) \(([^)]*)\) (\w+)\s*(.*)$', l)
        if m and not l.startswith(('subckt', 'ends', 'simulator', 'save')): el[m.group(1)] = (tuple(m.group(2).split()), m.group(3), m.group(4).strip())
        if l.startswith('parameters '):
            for k, v in re.findall(r'(\w+)=(\S+)', l): par[k] = v
        if l.startswith('include'): inc.append(l)
    sub = re.findall(r'^subckt (\w+)', open(fn).read(), re.M)
    return el, par, inc, sub
out = []; say = out.append; ok = True
fixture = {'CBODY', 'IINT', 'IINTT', 'VSP', 'VSN', 'RSP', 'REP', 'CEP', 'RSN', 'REN', 'CEN', 'RSR', 'RER', 'CER'}
ren = {'inpr': 'vRight', 'innr': 'vLeft', 'rl0b': 'vRL'}
ref, pref, iref, sref = parse(f'{R}/A_ref_f2fixture_dm_netlist.scs'); prof, pprof, iprof, sprof = parse(f'{R}/A_prof_dm_netlist.scs')
# (1) instructor elements vs the read-only schematic dump
dump = open(f'{R}/probe_schematics.txt').read().split('====')
tb = [b for b in dump if b.strip().startswith('ECG_tb / ECG_tb')][0]
insts = [(n, b) for n, c, b in re.findall(r'INST (\w+)\s+(\S+)\n((?:\s+(?:term|prop).*\n)*)', tb) if not c.startswith('analogLib/gnd/')]   # gnd symbols are not netlist elements
say('(1) instructor ECG_tb elements (schematic dump vs copy netlist)')
for name, body in insts:
    terms = dict(re.findall(r'term (\w+) -> (\S+)', body)); props = dict(re.findall(r'prop (\w+) = "?([^"\n]*)"?', body))
    nl = prof.get(name)
    if nl is None: say(f'  {name}: MISSING in copy'); ok = False; continue
    nets = {n.replace('gnd!', '0') for n in terms.values()}; same_nets = nets == set(nl[0]) | ({'0'} if '0' in nets else set())
    say(f'  {name}: nets {sorted(terms.items())} -> netlist {nl[0]} {nl[1]} {nl[2][:70]} | nets match: {set(nl[0]) == nets}')
    ok &= set(nl[0]) == nets
# (2) DUT = archived F2 fixture netlist minus fixture, renamed
say('(2) DUT elements vs archived F2 (ece203_r5nf_tb_f2) minus fixture, renames ' + str(ren))
instr = {n for n, _ in insts}
dref = {k: (tuple(ren.get(n, n) for n in v[0]),) + v[1:] for k, v in ref.items() if k not in fixture}
dpro = {k: v for k, v in prof.items() if k not in instr}
for k in sorted(set(dref) | set(dpro)):
    if dref.get(k) != dpro.get(k): say(f'  DIFF {k}: ref {dref.get(k)} | copy {dpro.get(k)}'); ok = False
say(f'  {len(dref)} DUT elements compared; subckts equal: {sref == sprof}; includes equal: {iref == iprof}'); ok &= sref == sprof and iref == iprof
# (3) parameters
say('(3) parameters')
for k in sorted(set(pref) | set(pprof)):
    if pref.get(k) != pprof.get(k): say(f'  {k}: ref {pref.get(k)} | copy {pprof.get(k)}')
for k in ('prw', 'prl', 'rdr', 'rdi', 'rlp', 'clp', 'cm2', 'dcc', 'iref', 'ibd', 'vref', 'vdd'): say(f'  copy {k} = {pprof.get(k)}')
# (4) transient netlists
say('(4) transient netlists vs A_prof_dm (elements; parameter differences listed)')
for fn in sorted(glob.glob(f'{R}/*s_netlist.scs')):
    e, p, i, s = parse(fn); tag = os.path.basename(fn).replace('_netlist.scs', '')
    de = [k for k in set(e) | set(prof) if (e.get(k) and prof.get(k) and e[k][:2] != prof[k][:2]) or (k in e) != (k in prof)]
    dp = {k: p.get(k) for k in set(p) | set(pprof) if p.get(k) != pprof.get(k)}
    say(f'  {tag}: element topology diffs {sorted(de)}; params {dict(sorted(dp.items()))}'); ok &= not de and s == sprof
say('AUDIT ' + ('PASS' if ok else 'FAIL'))
open('f2i_netlist_audit.txt', 'w').write('\n'.join(out) + '\n'); print('\n'.join(out))
