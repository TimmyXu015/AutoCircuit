"""R8D Stage A gate (pre-registered in r8d_plan.md): ideal TG master + unit bench. Reads raw/stageA."""
import csv, gzip, re, os, math
A = 'raw/stageA'; out = []; ok = []
def say(s): out.append(s); print(s)
def gate(c, m): ok.append(bool(c)); say('  %s  %s' % ('PASS' if c else 'FAIL', m))
kv = {r['key']: r['value'] for r in csv.DictReader(open(f'{A}/A_unit_static.csv'))}
f = lambda k: float(kv[k])
probe = open(f'{A}/A_switch_probe.txt').read()
say('== Stage A: ideal TG surrogate')
gate(all(t in probe for t in ('"N+"', '"N-"', '"NC+"', '"NC-"')) and all(re.search(r'param %s ' % p, probe) for p in ('vt1', 'vt2', 'ro', 'rc')),
     'analogLib switch read in Cadence: terminals N+ N- NC+ NC-, CDF params vt1 vt2 ro rc')
net = open(f'{A}/A_unit_netlist.scs').read().replace('\\\n', ' ')
m = re.search(r'subckt ece203_r8d_ideal_tg (.*?)\nends', net, re.S)
body = [' '.join(l.split()) for l in m.group(1).splitlines()[1:] if l.strip()] if m else []
want = {'SA1': ('INP', 'OUTP', 'CKA'), 'SA2': ('INN', 'OUTN', 'CKA'), 'SB1': ('INP', 'OUTN', 'CKB'), 'SB2': ('INN', 'OUTP', 'CKB')}
found = {}
for l in body:
    q = re.match(r'(\w+) \((\S+) (\S+) (\S+) (\S+)\) relay (.*)', l)
    if q: found[q.group(1)] = (q.group(2), q.group(3), q.group(4), q.group(5), q.group(6))
SI = {'T': 1e12, 'G': 1e9, 'M': 1e6, 'K': 1e3, 'k': 1e3, 'm': 1e-3, 'u': 1e-6, 'n': 1e-9, 'p': 1e-12, 'f': 1e-15}
def si(v):
    try: return float(v)
    except ValueError: return float(v[:-1]) * SI[v[-1]]
def prm(s, k): r = re.search(r'\b%s=(\S+)' % k, s); return si(r.group(1)) if r else None   # numeric (netlister writes 800.0m, 100e+18, 1.68K)
def near(a, b): return a is not None and abs(a / b - 1) < 1e-9
gate(len(body) == 4 and set(found) == set(want), 'subckt ece203_r8d_ideal_tg has exactly 4 relays %s (lines %d)' % (sorted(found), len(body)))
for n, (a, b, ck) in want.items():
    g = found.get(n)
    gate(g and g[:4] == (a, b, ck, 'GND') and near(prm(g[4], 'vt1'), 0.8) and near(prm(g[4], 'vt2'), 1.0) and near(prm(g[4], 'ropen'), 1e20) and near(prm(g[4], 'rclosed'), 1680),
         '%s: %s' % (n, ' '.join(g[:4]) + ' relay ' + g[4] if g else 'missing'))
say('    subckt: ' + ' | '.join(body))
gate(f('ron_A') and abs(f('ron_A') / 1680 - 1) <= 0.005 and abs(f('ron_B') / 1680 - 1) <= 0.005, 'Ron phase A %.2f / phase B %.2f Ohm (1.68 kOhm +- 0.5 %%; real TG at 0.9 V: 1681)' % (f('ron_A'), f('ron_B')))
gate(abs(f('vod_A') / 0.01 - 1) <= 1e-4 and abs(f('vod_B') / 0.01 + 1) <= 1e-4, 'static polarity 10 mV: A %+.6f, B %+.6f' % (f('vod_A') / 0.01, f('vod_B') / 0.01))
gate(abs(f('vod_A_0p1mV') / 1e-4 - 1) <= 1e-3 and abs(f('vod_B_0p1mV') / 1e-4 + 1) <= 1e-3, 'static polarity 0.1 mV: A %+.5f, B %+.5f' % (f('vod_A_0p1mV') / 1e-4, f('vod_B_0p1mV') / 1e-4))
rl = min(f('Roff_lower_bound_P'), 1e30)
gate(rl >= 1e15, 'both phases off (inputs +-0.1 V, 1 TOhm to vcm): outp-vcm %.3g V, outn-vcm %.3g V -> Roff >= %.3g Ohm (>> 3.128 TOhm)' % (f('off_outp_minus_vcm'), f('off_outn_minus_vcm'), rl))
# tran smoke
rows = list(csv.DictReader(gzip.open(f'{A}/A_unit_tran.csv.gz', 'rt')))
t = [float(r['t_s']) for r in rows]; ip = [float(r['inp_V']) for r in rows]; inn = [float(r['inn_V']) for r in rows]
op = [float(r['outp_V']) for r in rows]; on = [float(r['outn_V']) for r in rows]; ca = [float(r['cka_V']) for r in rows]; cb = [float(r['ckb_V']) for r in rows]
gate(t[-1] >= 1.999e-3, 'tran reached %.4g s (2 ms smoke, <= 2 ms)' % t[-1])
def at(x, y, tt):
    for i in range(1, len(x)):
        if x[i] >= tt: a = (tt - x[i - 1]) / (x[i] - x[i - 1]); return y[i - 1] + a * (y[i] - y[i - 1])
tch = 500e-6; gA = []; gB = []
for k in range(4):
    for frac, lst in ((0.45, gA), (0.95, gB)):
        tt = k * tch + frac * tch; vid = at(t, ip, tt) - at(t, inn, tt)
        if abs(vid) > 2e-4: lst.append((at(t, op, tt) - at(t, on, tt)) / vid)
gate(gA and gB and all(abs(g - 1) < 1e-3 for g in gA) and all(abs(g + 1) < 1e-3 for g in gB), 'chopped 2 kHz per-phase vod/vid: A %s, B %s' % (['%.5f' % g for g in gA], ['%.5f' % g for g in gB]))
ov = max(min(a, b) for a, b in zip(ca, cb))
gate(ov < 0.8, 'no overlap: max over time of min(V(cka), V(ckb)) = %.4g V (< 0.8 V relay-open threshold)' % ov)
# dead time: interval around each edge where both clocks < 0.8 V
dts = []; inside = False
for i in range(1, len(t)):
    both = ca[i] < 0.8 and cb[i] < 0.8
    if both and not inside: t0 = t[i]; inside = True
    if not both and inside: dts.append(t[i] - t0); inside = False
gate(dts and min(dts) >= 5e-9, 'dead times (both < 0.8 V): %d intervals, min %.3g ns, max %.3g ns' % (len(dts), 1e9 * min(dts or [0]), 1e9 * max(dts or [0])))
vidmax = max(abs(a - b) for a, b in zip(ip, inn)); vodmax = max(abs(a - b) for a, b in zip(op, on))
gate(vodmax <= 1.02 * vidmax, 'no spike: max|vod| %.4g mV vs max|vid| %.4g mV' % (1e3 * vodmax, 1e3 * vidmax))
cmd = max(abs((a + b) / 2 - 0.9) for a, b in zip(op, on))
say('    output CM deviation max %.3g uV (ideal: no charge injection)' % (1e6 * cmd))
say('Stage A: ' + ('PASS' if all(ok) else 'FAIL'))
open('r8d_stageA_gate.txt', 'w').write('\n'.join(out) + '\n')
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
fig, ax = plt.subplots(1, 2, figsize=(13, 4))
ms = lambda v: [1e3 * x for x in v]
ax[0].plot(ms(t), [1e3 * (a - b) for a, b in zip(ip, inn)], color='#7a7a7a', lw=1.5, label='vid = inp-inn (mV)')
ax[0].plot(ms(t), [1e3 * (a - b) for a, b in zip(op, on)], color='#d45500', lw=1, label='vod = outp-outn (mV)')
ax[0].set_xlabel('t (ms)'); ax[0].set_ylabel('mV'); ax[0].set_title('ideal TG unit, 2 kHz, vd 1 mV @100 Hz', fontsize=10); ax[0].legend(frameon=False, fontsize=8)
w = [i for i, x in enumerate(t) if 0.24999e-3 <= x <= 0.25005e-3]
ax[1].plot([1e9 * (t[i] - 0.25e-3) for i in w], [ca[i] for i in w], color='#2a78b5', lw=1.5, label='cka')
ax[1].plot([1e9 * (t[i] - 0.25e-3) for i in w], [cb[i] for i in w], color='#1b9e77', lw=1.5, label='ckb')
ax[1].axhline(0.8, color='#999', lw=0.8, ls=':'); ax[1].axhline(1.0, color='#999', lw=0.8, ls=':')
ax[1].set_xlabel('t - 250 us (ns)'); ax[1].set_ylabel('V'); ax[1].set_title('A->B edge: relay thresholds 0.8 / 1.0 V', fontsize=10); ax[1].legend(frameon=False, fontsize=8)
for a in ax: a.grid(True, color='#e6e6e6', lw=0.6); a.spines[['top', 'right']].set_visible(False)
fig.tight_layout(); fig.savefig('r8d_stageA.png', dpi=120)
