"""R8C analysis (pre-registered in r8c_plan.md). Reads raw/stageA and raw/stageB (whatever exists), writes the gate tables and figures.
Definitions: r8c_lib.fl_flat (plateau = mean |H| over 5-10 Hz grid points; fL = first downward crossing of plateau/sqrt(2) below 5 Hz,
log-log interpolation). Transfers are differential node voltages divided by the measured V(ep)-V(en) (AC, or PAC sideband 0)."""
import os, math, csv
from r8c_lib import read, fl_flat, interp
A, B = 'raw/stageA', 'raw/stageB'
PAIRS = [('out', 'outp-outn'), ('buf', 'bufp-bufn'), ('f', 'fp-fn'), ('pn', 'p-n'), ('in', 'ia-ibx'), ('o', 'op-on')]
FREQS = [0.01, 0.03, 0.1, 0.3, 1, 3, 10, 100]
def ex(p): return os.path.exists(p)
def kv(p):
    if not ex(p): return {}
    with open(p) as fh: return {r['key']: r['value'] for r in csv.DictReader(fh)}
def curve(p, col):
    rows = read(p); f = [r['f_Hz'] for r in rows]
    return f, [r.get('abs_' + col) for r in rows], [r.get('ph_' + col) for r in rows]
def conv_ok(p): return ex(p) and 'steady-state solution was achieved' in open(p).read()
def num(x):
    try: return float(x)
    except Exception: return float('nan')
out = []
def say(s=''): out.append(s); print(s)
G = {}
# ---------------- Stage A ----------------
offA = f'{A}/A1_off_mos_ac.csv'; m1 = f'{A}/A1_pac_mos_m1_pac.csv'; m3 = f'{A}/A1_pac_mos_m3_pac.csv'
r8b_on = read('../round8b/raw/gateC/B_pac_pac.csv'); r8b_off = read('../round8b/raw/gateA/A_off_ac.csv')
fl_rows = []
def flrow(case, f, m):
    fl, P = fl_flat(f, m); H100 = interp(f, m, 100.0); fl_rows.append((case, P, fl, H100)); return fl, P, H100
flrow('R8B archived OFF static AC', [r['f_Hz'] for r in r8b_off], [r['abs_Hoff'] for r in r8b_off])
flrow('R8B archived ON PAC sb0', [r['f_Hz'] for r in r8b_on], [r['abs_Hon'] for r in r8b_on])
if ex(offA):
    f, m, _ = curve(offA, 'out'); G['fl_off_mos'], _, G['h100_off_mos'] = flrow('A1 OFF static AC (MOS)', f, m)
for tag, p in (('m1', m1), ('m3', m3)):
    if ex(p):
        f, m, _ = curve(p, 'H0_out'); G['fl_on_mos_' + tag], _, G['h100_on_mos_' + tag] = flrow(f'A1 ON PAC sb0 maxsideband {tag[1]} (MOS)', f, m)
with open('r8c_stageA_fl.csv', 'w') as fh:
    fh.write('case,plateau_5_10Hz_VV,fL_flat_Hz,absH_100Hz\n')
    for c, P, fl, h in fl_rows: fh.write('%s,%.6g,%s,%s\n' % (c, P, '%.6g' % fl if fl else 'none', '%.6g' % h if h else 'n/a'))
say('== Stage A fL_flat'); [say('  %-40s plateau %.4f  fL %s  H100 %s' % (c, P, '%.4f' % fl if fl else 'none', '%.4f' % h if h else 'n/a')) for c, P, fl, h in fl_rows]
gA = []
def gate(lst, ok, msg): lst.append(bool(ok)); say('  %s  %s' % ('PASS' if ok else 'FAIL', msg))
if ex(m1) and ex(m3) and ex(offA):
    say('== Stage A gate')
    gate(gA, conv_ok(f'{A}/A1_pac_mos_m1_convergence_lines.txt') and conv_ok(f'{A}/A1_pac_mos_m3_convergence_lines.txt'), 'PSS explicitly converged in both PAC runs (readpss re-check)')
    gate(gA, abs(G['h100_on_mos_m1'] / 83.25 - 1) <= 0.02, 'ON |H(100)| %.4f within 2 %% of 83.25' % G['h100_on_mos_m1'])
    gate(gA, G['fl_on_mos_m1'] and abs(G['fl_on_mos_m1'] - 0.34) <= 0.04, 'ON fL_flat %.4f Hz within 0.34 +- 0.04' % (G['fl_on_mos_m1'] or float('nan')))
    f1, a1, _ = curve(m1, 'H0_out'); f3, a3, _ = curve(m3, 'H0_out')
    d = [abs(interp(f3, a3, x) / interp(f1, a1, x) - 1) for x in (0.1, 0.3, 1, 10, 100)]
    dall = max(abs(y / x - 1) for x, y in zip(a1, a3))
    gate(gA, max(d) <= 0.02, 'maxsideband 1 vs 3, sideband-0 |H| at 0.1/0.3/1/10/100 Hz: max diff %.3g %% (all %d points: %.3g %%)' % (100 * max(d), len(a1), 100 * dall))
    fo = [r['f_Hz'] for r in r8b_on]; mo = [r['abs_Hon'] for r in r8b_on]
    dr = max(abs(interp(f1, a1, x) / y - 1) for x, y in zip(fo, mo) if x >= f1[0])
    gate(gA, dr <= 0.02, 'new PAC (m1) vs archived R8B PAC 0.1-250 Hz: max diff %.3g %%' % (100 * dr))
    fv, av, pv = curve(m1, 'vd_pac')
    gate(gA, all(abs(x - 2) < 1e-6 for x in av) and all(abs(x) < 1e-6 for x in pv), 'measured V(ep)-V(en) sideband 0 = 2 V at 0 deg at all points')
    gate(gA, abs(G['h100_off_mos'] / 85.666 - 1) <= 1e-4, 'A1 OFF |H(100)| %.5f = R8B 85.666' % G['h100_off_mos'])
    au = f'r8c_netlist_audit_A.txt'
    gate(gA, ex(au) and open(au).read().count('AUDIT PASS') == 3, 'netlist audit (A1 OFF, A1 PAC m1, m3 vs R8B): %s' % (au if ex(au) else 'missing'))
    G['stageA'] = 'PASS' if all(gA) else 'FAIL'; say('  Stage A: ' + G['stageA'])
# node transfer table (OFF vs ON MOS, and linear when present)
def node_table(name, offp, onp, rows):
    for key, lab in PAIRS:
        fo_, mo_, _ = curve(offp, key) if ex(offp) else ([], [], [])
        fn_, mn_, _ = curve(onp, 'H0_' + key) if ex(onp) else ([], [], [])
        r = [name, lab]
        for x in FREQS:
            a = interp(fo_, mo_, x) if fo_ else None; b = interp(fn_, mn_, x) if fn_ else None
            r += ['%.5g' % a if a is not None else '', '%.5g' % b if b is not None else '']
        flo = fl_flat(fo_, mo_)[0] if fo_ else None; fln = fl_flat(fn_, mn_)[0] if fn_ else None
        r += ['%.5g' % flo if flo else 'none', '%.5g' % fln if fln else 'none']
        rows.append(r)
rows = []
node_table('MOS pseudo-R (R8B cell)', offA, m1, rows)
for case in ('l0', 'l1'):
    if ex(f'{B}/B0_off_{case}_ac.csv'): node_table(f'linear R {case}', f'{B}/B0_off_{case}_ac.csv', f'{B}/B1_pac_{case}_pac.csv', rows)
with open('r8c_node_transfer.csv', 'w') as fh:
    fh.write('case,node,' + ','.join('OFF_%g,ON_sb0_%g' % (x, x) for x in FREQS) + ',fL_flat_OFF_Hz,fL_flat_ON_Hz\n')
    for r in rows: fh.write(','.join(r) + '\n')
# ---------------- Stage B ----------------
moff = kv(f'{A}/A1_off_mos.csv')
def cm(d, a, b): return (num(d.get('dc_' + a)) + num(d.get('dc_' + b))) / 2
def pw(d): return 1.8 * (num(d.get('I_VDD')) + num(d.get('I_VDDD')))
for case in ('l0', 'l1'):
    bo = f'{B}/B0_off_{case}_ac.csv'
    if not (ex(bo) and moff): continue
    d = kv(f'{B}/B0_off_{case}.csv'); f, m, _ = curve(bo, 'out')
    fl, P, h100 = flrow(f'B0 OFF static AC (linear R {case})', f, m); G['fl_off_' + case] = fl
    say(f'== Stage B0 gate ({case})'); gB0 = []
    gate(gB0, fl and 0.07 <= fl <= 0.15, 'OFF fL_flat %.4f Hz in 0.07-0.15 (MOS %.4f)' % (fl or float('nan'), G.get('fl_off_mos', float('nan'))))
    gate(gB0, abs(h100 / G['h100_off_mos'] - 1) <= 0.05, 'OFF |H(100)| %.4f within 5 %% of MOS %.4f (%+.3f %%)' % (h100, G['h100_off_mos'], 100 * (h100 / G['h100_off_mos'] - 1)))
    for a, b in (('p', 'n'), ('ia', 'ibx'), ('fp', 'fn'), ('op', 'on'), ('bufp', 'bufn'), ('outp', 'outn')):
        dv = 1e3 * (cm(d, a, b) - cm(moff, a, b)); gate(gB0, abs(dv) <= 1.0, 'DC CM (%s,%s) %+.4f mV vs MOS' % (a, b, dv))
    dp = pw(d) / pw(moff) - 1; gate(gB0, abs(dp) <= 0.02, 'power %.4f uW vs MOS %.4f uW (%+.3f %%)' % (1e6 * pw(d), 1e6 * pw(moff), 100 * dp))
    G['B0_' + case] = 'PASS' if all(gB0) else 'FAIL'; say(f'  B0 {case}: ' + G['B0_' + case])
    if not all(gB0) and fl and case == 'l0':
        say('  registered correction rule: R_l1 = 3.128T x fL_OFF,lin(l0) / fL_OFF,MOS = %.4g TOhm' % (3.128 * fl / G['fl_off_mos']))
    pac = f'{B}/B1_pac_{case}_pac.csv'
    if ex(pac):
        f, m, _ = curve(pac, 'H0_out'); fln, _, h100n = flrow(f'B1 ON PAC sb0 (linear R {case})', f, m)
        Qr = fln / fl if fln and fl else None; Qm = G['fl_on_mos_m1'] / G['fl_off_mos']
        cls = ('pseudo-R nonlinearity / periodic admittance = main suspect' if Qr <= 1.4 else
               'TG / other periodic switching coupling = main suspect' if Qr >= 2.7 else 'both mechanisms may contribute (not separable here)') if Qr else 'n/a'
        G['Q_' + case] = Qr; G['Q_mos'] = Qm; G['class_' + case] = cls
        say(f'== Stage B1 ({case}): PSS conv %s | fL_ON,lin %.4f Hz, fL_OFF,lin %.4f Hz -> Q_R = %.3f ; Q_MOS = %.3f ; H100 ON lin %.4f' %
            (conv_ok(f'{B}/B1_pac_{case}_convergence_lines.txt'), fln or float('nan'), fl, Qr or float('nan'), Qm, h100n))
        say('  pre-registered reading: ' + cls)
        # operating-state check: PSS waveforms MOS vs linear
        tm = read(f'{A}/A1_pac_mos_m1_pss_td.csv'); tl = read(f'{B}/B1_pac_{case}_pss_td.csv'); rip = []
        for n in ('p', 'n', 'ia', 'ibx', 'fp', 'fn', 'op', 'on', 'outp', 'outn'):
            k = n + '_V'
            if k in tm[0] and k in tl[0]:
                xm = [r[k] for r in tm]; xl = [r[k] for r in tl]
                ppm, ppl = max(xm) - min(xm), max(xl) - min(xl); mm, ml = sum(xm) / len(xm), sum(xl) / len(xl)
                rip.append((n, ppm, ppl, mm, ml))
        with open(f'r8c_pss_ripple_{case}.csv', 'w') as fh:
            fh.write('node,pp_MOS_V,pp_linear_V,pp_ratio,mean_MOS_V,mean_linear_V,mean_diff_mV\n')
            for n, a, b, c, e in rip: fh.write('%s,%.6g,%.6g,%.4g,%.7g,%.7g,%.4g\n' % (n, a, b, b / a if a else float('nan'), c, e, 1e3 * (e - c)))
        bad = [n for n, a, b, c, e in rip if n in ('p', 'n', 'fp', 'fn') and ((a and abs(b / a - 1) > 0.30) or abs(1e3 * (e - c)) > 1.0)]
        G['state_' + case] = 'operating state preserved (p/n/fp/fn pp within 30 %, mean within 1 mV)' if not bad else 'surrogate does NOT preserve the operating state at %s -> causal reading downgraded' % bad
        say('  ' + G['state_' + case])
        for n, a, b, c, e in rip: say('    %-5s pp MOS %.4g V  lin %.4g V  (x%.3f)  mean %+.4f mV' % (n, a, b, b / a if a else float('nan'), 1e3 * (e - c)))
with open('r8c_fl_summary.csv', 'w') as fh:
    fh.write('case,plateau_5_10Hz_VV,fL_flat_Hz,absH_100Hz\n')
    for c, P, fl, h in fl_rows: fh.write('%s,%.6g,%s,%s\n' % (c, P, '%.6g' % fl if fl else 'none', '%.6g' % h if h else 'n/a'))
open('r8c_gates.txt', 'w').write('\n'.join(out) + '\n')
# ---------------- figures ----------------
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
MOS_OFF, MOS_ON, LIN_OFF, LIN_ON = '#7a7a7a', '#d45500', '#2a78b5', '#1b9e77'
def style(a, t, yl=None):
    a.set_xscale('log'); a.grid(True, which='both', color='#e6e6e6', lw=0.6); a.spines[['top', 'right']].set_visible(False); a.set_title(t, fontsize=10); a.set_xlabel('f (Hz)')
    if yl: a.set_ylabel(yl)
if ex(offA) and ex(m1):
    fig, ax = plt.subplots(2, 3, figsize=(15, 8))
    for i, (key, lab) in enumerate(PAIRS):
        a = ax.flat[i]; f, mm, _ = curve(offA, key); a.loglog(f, mm, color=MOS_OFF, lw=2, label='OFF static AC')
        f, mm, _ = curve(m1, 'H0_' + key); a.loglog(f, mm, color=MOS_ON, lw=2, label='ON PAC sideband 0')
        if ex(m3): f3_, mm3, _ = curve(m3, 'H0_' + key); a.loglog(f3_, mm3, color='#333', lw=0.8, ls='--', label='ON, maxsideband 3')
        if key in ('in', 'o', 'pn'):
            f, mp, _ = curve(m1, 'Hp1_' + key); a.loglog(f, mp, color=MOS_ON, lw=1, ls=':', label='ON sideband +1 (carrier band)')
        style(a, '|%s| / |ep-en|' % lab, 'V/V'); a.set_xlim(0.01, 300)
    ax.flat[0].legend(frameon=False, fontsize=8); ax.flat[3].legend(frameon=False, fontsize=8)
    fig.suptitle('R8C Stage A - MOS pseudo-R (R8B cell): node transfers, chopper OFF vs ON', fontsize=11); fig.tight_layout(); fig.savefig('r8c_stageA_nodes.png', dpi=120)
if any(ex(f'{B}/B0_off_{c}_ac.csv') for c in ('l0', 'l1')):
    fig, ax = plt.subplots(1, 3, figsize=(15, 4.3))
    f, mm, _ = curve(offA, 'out'); ax[0].loglog(f, mm, color=MOS_OFF, lw=2, label='MOS pseudo-R, OFF')
    f, mm, _ = curve(m1, 'H0_out'); ax[0].loglog(f, mm, color=MOS_ON, lw=2, label='MOS pseudo-R, ON')
    for c, ls in (('l0', '-'), ('l1', '--')):
        if ex(f'{B}/B0_off_{c}_ac.csv'): f, mm, _ = curve(f'{B}/B0_off_{c}_ac.csv', 'out'); ax[0].loglog(f, mm, color=LIN_OFF, lw=2, ls=ls, label=f'linear R {c}, OFF')
        if ex(f'{B}/B1_pac_{c}_pac.csv'): f, mm, _ = curve(f'{B}/B1_pac_{c}_pac.csv', 'H0_out'); ax[0].loglog(f, mm, color=LIN_ON, lw=2, ls=ls, label=f'linear R {c}, ON')
    style(ax[0], '|(outp-outn)/(ep-en)|', 'V/V'); ax[0].set_xlim(0.01, 300); ax[0].legend(frameon=False, fontsize=8)
    labs, vals, cols = [], [], []
    for c, P, fl, h in fl_rows:
        if c.startswith(('A1', 'B0', 'B1')) and fl and 'maxsideband 3' not in c:
            labs.append(c.replace(' (MOS)', '\nMOS').replace(' (linear R ', '\nlinear ').replace(')', '').replace('static AC', '').replace('PAC sb0', '').replace('maxsideband 1', ''))
            vals.append(fl); cols.append(MOS_OFF if 'A1 OFF' in c else MOS_ON if 'A1 ON' in c else LIN_OFF if 'OFF' in c else LIN_ON)
    ax[1].bar(range(len(vals)), vals, color=cols); ax[1].set_xticks(range(len(vals))); ax[1].set_xticklabels(labs, fontsize=7)
    for i, v in enumerate(vals): ax[1].annotate('%.3f' % v, (i, v), ha='center', va='bottom', fontsize=8)
    ax[1].set_ylabel('fL_flat (Hz)'); ax[1].set_title('fL_flat (plateau 5-10 Hz, -3 dB)', fontsize=10); ax[1].spines[['top', 'right']].set_visible(False)
    qs = [('MOS', G.get('Q_mos'), MOS_ON)] + [(f'linear {c}', G.get('Q_' + c), LIN_ON) for c in ('l0', 'l1') if G.get('Q_' + c)]
    ax[2].bar(range(len(qs)), [q[1] or 0 for q in qs], color=[q[2] for q in qs]); ax[2].set_xticks(range(len(qs))); ax[2].set_xticklabels([q[0] for q in qs])
    for i, q in enumerate(qs): ax[2].annotate('%.2f' % (q[1] or 0), (i, q[1] or 0), ha='center', va='bottom', fontsize=9)
    ax[2].axhspan(0, 1.4, color='#eeeeee', zorder=0); ax[2].axhline(1.4, color='#999', lw=0.8, ls=':'); ax[2].axhline(2.7, color='#999', lw=0.8, ls=':')
    ax[2].set_ylabel('Q = fL_ON / fL_OFF'); ax[2].set_title('Q (pre-registered bands 1.4 / 2.7)', fontsize=10); ax[2].spines[['top', 'right']].set_visible(False)
    fig.suptitle('R8C Stage B - MOS pseudo-R vs linear-R surrogate (diagnostic cell)', fontsize=11); fig.tight_layout(); fig.savefig('r8c_stageB.png', dpi=120)
