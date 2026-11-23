"""R8D Stage B/C analysis (pre-registered in r8d_plan.md). Reads raw/stageB (R8D runs) and, read-only, the R8C MM PAC
(../round8c/raw/stageA/A1_pac_mos_m1_*) as the MM ON reference. fL_flat = ../round8c/r8c_lib.py (plateau mean 5-10 Hz / sqrt2)."""
import os, sys, csv, math
sys.path.insert(0, '../round8c'); from r8c_lib import read, fl_flat, interp
B = 'raw/stageB'; MMON = '../round8c/raw/stageA/A1_pac_mos_m1'
CASES = [('mm', 'MM (real XCI, real XCO)'), ('ii', 'II (ideal XCI, ideal XCO)'), ('im', 'IM (ideal XCI, real XCO)'), ('mi', 'MI (real XCI, ideal XCO)')]
NODES_DC = ['op', 'on', 'p', 'n', 'ia', 'ibx', 'fp', 'fn', 'vg', 'ib', 'pref', 'bufp', 'bufn', 'outp', 'outn']
ex = os.path.exists
def kv(p): return {r['key']: r['value'] for r in csv.DictReader(open(p))} if ex(p) else {}
def num(x):
    try: return float(x)
    except Exception: return float('nan')
def curve(p, col):
    rows = read(p); return [r['f_Hz'] for r in rows], [r.get('abs_' + col) for r in rows]
def conv(p): return ex(p) and 'steady-state solution was achieved' in open(p).read()
def dcop(p):
    return {r['inst']: r for r in csv.DictReader(open(p))} if ex(p) else {}
out = []; S = {}
def say(s=''): out.append(s); print(s)
def gate(lst, c, m): lst.append(bool(c)); say('  %s  %s' % ('PASS' if c else 'FAIL', m))
mm_off = kv(f'{B}/B_off_mm.csv'); mm_op = dcop(f'{B}/B_off_mm_dcop.csv')
def pw(d): return 1.8 * (num(d.get('I_VDD')) + num(d.get('I_VDDD')))
for key, lab in CASES:
    r = {'case': key, 'label': lab}
    offp = f'{B}/B_off_{key}_ac.csv'
    if ex(offp):
        f, m = curve(offp, 'out'); r['fL_off'], r['plateau_off'] = fl_flat(f, m); r['H100_off'] = interp(f, m, 100.0)
        d = kv(f'{B}/B_off_{key}.csv'); r['P_uW'] = 1e6 * pw(d)
        op = dcop(f'{B}/B_off_{key}_dcop.csv'); r['I_MD'] = num(op.get('XC.MD', {}).get('id_A'))
        if key != 'mm' and mm_off:
            say(f'== OFF gate {key}'); g = []
            gate(g, r['fL_off'] and abs(r['fL_off'] / 0.0943 - 1) <= 0.15, 'fL_flat OFF %.4f Hz within 0.0943 +- 15 %%' % (r['fL_off'] or float('nan')))
            gate(g, abs(r['H100_off'] / 85.67 - 1) <= 0.05, '|Hout(100)| OFF %.4f within 85.67 +- 5 %% (%+.3f %%)' % (r['H100_off'], 100 * (r['H100_off'] / 85.67 - 1)))
            dd = {n: 1e3 * (num(d.get('dc_' + n)) - num(mm_off.get('dc_' + n))) for n in NODES_DC}
            worst = max(dd, key=lambda n: abs(dd[n]))
            gate(g, all(abs(v) <= 2.0 for v in dd.values()), 'DC of %d key nodes within 2 mV of MM (worst %s %+.4f mV)' % (len(dd), worst, dd[worst]))
            dp = pw(d) / pw(mm_off) - 1; dmd = r['I_MD'] / num(mm_op['XC.MD']['id_A']) - 1
            gate(g, abs(dp) <= 0.05 and abs(dmd) <= 0.05, 'power %.4f uW (%+.3f %%), CMFB XC.MD current %+.3f %% vs MM' % (1e6 * pw(d), 100 * dp, 100 * dmd))
            vs = [num(d.get('dc_' + n)) for n in ('op', 'on', 'fp', 'fn', 'bufp', 'bufn', 'outp', 'outn', 'p', 'n')]
            gate(g, all(0.1 <= v <= 1.7 for v in vs), 'no clipping/floating: op/on/fp/fn/buf/out/p/n DC in 0.1-1.7 V (min %.4f, max %.4f)' % (min(vs), max(vs)))
            r['OFF_gate'] = 'PASS' if all(g) else 'FAIL'; say(f'  OFF {key}: ' + r['OFF_gate'])
            with open(f'r8d_dc_{key}.csv', 'w') as fh:
                fh.write('node,MM_V,%s_V,diff_mV\n' % key)
                for n in NODES_DC: fh.write('%s,%.7g,%.7g,%.4g\n' % (n, num(mm_off.get('dc_' + n)), num(d.get('dc_' + n)), dd[n]))
    pac = MMON + '_pac.csv' if key == 'mm' else f'{B}/B_pac_{key}_pac.csv'
    cl = MMON + '_convergence_lines.txt' if key == 'mm' else f'{B}/B_pac_{key}_convergence_lines.txt'
    if ex(pac):
        f, m = curve(pac, 'H0_out'); r['fL_on'], r['plateau_on'] = fl_flat(f, m); r['H100_on'] = interp(f, m, 100.0); r['H0p1_on'] = interp(f, m, 0.1)
        r['pss_converged'] = conv(cl)
        fv, av = curve(pac, 'vd_pac'); r['vd_ok'] = all(abs(x - 2) < 1e-6 for x in av)
        for nd in ('pn', 'f', 'buf'):
            ff, mmn = curve(pac, 'H0_' + nd); r['fL_on_' + nd] = fl_flat(ff, mmn)[0]
        td = read((MMON if key == 'mm' else f'{B}/B_pac_{key}') + '_pss_td.csv')
        for n in ('p', 'n', 'fp', 'fn', 'op', 'on', 'ia', 'ibx'):
            x = [q[n + '_V'] for q in td]; r['pp_' + n] = max(x) - min(x); r['mean_' + n] = sum(x) / len(x)
        dmo = [q['outp_V'] - q['outn_V'] for q in td]; dmf = [q['fp_V'] - q['fn_V'] for q in td]
        r['dm_out_pp'] = max(dmo) - min(dmo); r['dm_f_pp'] = max(dmf) - min(dmf)
        if r.get('fL_off') and r.get('fL_on'): r['Q'] = r['fL_on'] / r['fL_off']; r['dG_model_pS'] = 1e12 * (r['Q'] - 1) / 3.128e12
    S[key] = r
# ON checks vs MM and II classification
mm = S.get('mm', {})
for key, lab in CASES[1:]:
    r = S.get(key, {})
    if 'fL_on' not in r: continue
    say(f'== ON {key}: PSS converged {r["pss_converged"]}, input 2 V check {r["vd_ok"]}; fL_ON %.4f Hz, fL_OFF %.4f Hz, Q = %.3f (MM %.3f); H100 ON %.4f' % (r['fL_on'], r.get('fL_off', float('nan')), r.get('Q', float('nan')), mm.get('Q', float('nan')), r['H100_on']))
    alt = []
    if abs(r['H100_on'] / 83.251 - 1) > 0.10: alt.append('H100_ON %+.1f %% vs 83.251' % (100 * (r['H100_on'] / 83.251 - 1)))
    for n in ('p', 'n', 'fp', 'fn'):
        ratio = r['pp_' + n] / mm['pp_' + n] if mm.get('pp_' + n) else float('nan'); dmean = 1e3 * (r['mean_' + n] - mm['mean_' + n])
        if not (0.7 <= ratio <= 1.3) or abs(dmean) > 2.0: alt.append('%s pp x%.3f, mean %+.3f mV' % (n, ratio, dmean))
    r['altered'] = '; '.join(alt)
    say('  ' + ('surrogate ALTERED operation / attribution downgraded: ' + r['altered'] if alt else 'operation not altered (H100 within 10 %; p/n/fp/fn PSS pp within 30 %, mean within 2 mV of MM)'))
    for n in ('p', 'fp', 'op', 'ia'):
        say('    %-3s pp MM %.4g mV  %s %.4g mV (x%.3f)  mean %+.3f mV' % (n, 1e3 * mm['pp_' + n], key, 1e3 * r['pp_' + n], r['pp_' + n] / mm['pp_' + n], 1e3 * (r['mean_' + n] - mm['mean_' + n])))
ii = S.get('ii', {})
if 'Q' in ii:
    Q = ii['Q']
    if Q <= 1.4 and 0.08 <= ii['fL_on'] <= 0.13: cls = 'II recovers (fL_ON in 0.08-0.13 Hz, Q <= 1.4): real MOS TG non-idealities are NECESSARY -> Stage C (IM + MI)'
    elif Q >= 2.7: cls = 'II keeps Q >= 2.7: MOS-TG-specific parasitics are NOT necessary -> STOP (periodic switching itself)'
    else: cls = 'II intermediate (Q %.3f): both mechanisms may contribute -> Stage C allowed' % Q
    S['ii']['class'] = cls; say('== II pre-registered reading: ' + cls)
# 2x2 factorial (descriptive), only if all four have Q
if all('Q' in S.get(k, {}) for k in ('mm', 'ii', 'im', 'mi')):
    for resp in ('Q', 'fL_on'):
        y = {k: S[k][resp] for k in ('mm', 'ii', 'im', 'mi')}
        e_xci = ((y['mm'] - y['im']) + (y['mi'] - y['ii'])) / 2; e_xco = ((y['mm'] - y['mi']) + (y['im'] - y['ii'])) / 2
        inter = ((y['mm'] - y['im']) - (y['mi'] - y['ii'])) / 2
        say('== 2x2 (%s): MM %.4g IM %.4g MI %.4g II %.4g | effect of idealising XCI %.4g, XCO %.4g, interaction %.4g' % (resp, y['mm'], y['im'], y['mi'], y['ii'], e_xci, e_xco, inter))
        S['factorial_' + resp] = (e_xci, e_xco, inter)
cols = ['case', 'label', 'OFF_gate', 'fL_off', 'plateau_off', 'H100_off', 'P_uW', 'I_MD', 'pss_converged', 'vd_ok', 'fL_on', 'plateau_on', 'H100_on', 'H0p1_on', 'Q', 'dG_model_pS',
        'fL_on_pn', 'fL_on_f', 'fL_on_buf', 'pp_p', 'pp_n', 'pp_fp', 'pp_fn', 'pp_op', 'pp_ia', 'mean_p', 'mean_fp', 'dm_out_pp', 'dm_f_pp', 'altered', 'class']
with open('r8d_matrix_summary.csv', 'w') as fh:
    w = csv.writer(fh); w.writerow(cols)
    for key, _ in CASES:
        if key in S: w.writerow([('%.6g' % S[key][c]) if isinstance(S[key].get(c), float) else S[key].get(c, '') for c in cols])
open('r8d_gates.txt', 'w').write('\n'.join(out) + '\n')
# figures
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
COL = {'mm': '#d45500', 'ii': '#2a78b5', 'im': '#1b9e77', 'mi': '#8c564b'}
if any(ex(f'{B}/B_off_{k}_ac.csv') for k in ('ii', 'im', 'mi')):
    fig, ax = plt.subplots(1, 3, figsize=(15, 4.3))
    for key, lab in CASES:
        if ex(f'{B}/B_off_{key}_ac.csv'):
            f, m = curve(f'{B}/B_off_{key}_ac.csv', 'out'); ax[0].loglog(f, m, color=COL[key], lw=2 if key == 'mm' else 1.2, ls='--', label=lab.split(' ')[0] + ' OFF')
        pac = MMON + '_pac.csv' if key == 'mm' else f'{B}/B_pac_{key}_pac.csv'
        if ex(pac): f, m = curve(pac, 'H0_out'); ax[0].loglog(f, m, color=COL[key], lw=2 if key == 'mm' else 1.2, label=lab.split(' ')[0] + ' ON (PAC sb0)')
    ax[0].set_xlim(0.01, 300); ax[0].set_title('|(outp-outn)/(ep-en)|', fontsize=10); ax[0].set_ylabel('V/V')
    ks = [k for k, _ in CASES if 'fL_off' in S.get(k, {})]
    xx = range(len(ks)); wdt = 0.38
    ax[1].bar([i - wdt / 2 for i in xx], [S[k]['fL_off'] for k in ks], wdt, color='#bbbbbb', label='OFF')
    ax[1].bar([i + wdt / 2 for i in xx], [S[k].get('fL_on', 0) or 0 for k in ks], wdt, color=[COL[k] for k in ks], label='ON')
    for i, k in enumerate(ks):
        ax[1].annotate('%.3f' % S[k]['fL_off'], (i - wdt / 2, S[k]['fL_off']), ha='center', va='bottom', fontsize=8)
        if S[k].get('fL_on'): ax[1].annotate('%.3f' % S[k]['fL_on'], (i + wdt / 2, S[k]['fL_on']), ha='center', va='bottom', fontsize=8)
    ax[1].set_xticks(list(xx)); ax[1].set_xticklabels([k.upper() for k in ks]); ax[1].set_ylabel('fL_flat (Hz)'); ax[1].set_title('fL_flat OFF (grey) / ON', fontsize=10)
    qk = [k for k in ks if 'Q' in S[k]]
    ax[2].bar(range(len(qk)), [S[k]['Q'] for k in qk], color=[COL[k] for k in qk])
    for i, k in enumerate(qk): ax[2].annotate('%.2f' % S[k]['Q'], (i, S[k]['Q']), ha='center', va='bottom', fontsize=9)
    ax[2].axhline(1.4, color='#999', lw=0.8, ls=':'); ax[2].axhline(2.7, color='#999', lw=0.8, ls=':')
    ax[2].set_xticks(range(len(qk))); ax[2].set_xticklabels([k.upper() for k in qk]); ax[2].set_ylabel('Q = fL_ON / fL_OFF'); ax[2].set_title('Q (pre-registered bands 1.4 / 2.7)', fontsize=10)
    for a in ax:
        a.spines[['top', 'right']].set_visible(False); a.grid(True, which='both', color='#e6e6e6', lw=0.6)
    ax[0].set_xlabel('f (Hz)'); ax[0].legend(frameon=False, fontsize=7)
    fig.suptitle('R8D - XCI / XCO TG idealisation (real MOS pseudo-R and everything else unchanged)', fontsize=11); fig.tight_layout(); fig.savefig('r8d_matrix.png', dpi=120)
    # PSS waveforms p and fp, MM vs cases
    fig, ax = plt.subplots(1, 3, figsize=(15, 4))
    for key, lab in CASES:
        p = (MMON if key == 'mm' else f'{B}/B_pac_{key}') + '_pss_td.csv'
        if not ex(p): continue
        td = read(p); t = [1e6 * q['t_s'] for q in td]
        for a, n in zip(ax, ('p', 'fp', 'op')):
            a.plot(t, [1e3 * (q[n + '_V'] - 0.9) for q in td], color=COL[key], lw=1.5 if key == 'mm' else 1, label=key.upper())
    for a, n in zip(ax, ('p', 'fp', 'op')):
        a.set_title('PSS V(%s) - 0.9 V, one 500 us period' % n, fontsize=10); a.set_xlabel('t (us)'); a.set_ylabel('mV'); a.legend(frameon=False, fontsize=8)
        a.spines[['top', 'right']].set_visible(False); a.grid(True, color='#e6e6e6', lw=0.6)
    fig.tight_layout(); fig.savefig('r8d_pss_waveforms.png', dpi=120)
