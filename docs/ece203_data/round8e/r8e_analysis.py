"""R8E analysis (pre-registered in r8e_plan.md). Reads raw/static (r7cStageB1 B_<case>*.csv + r7eLp L_<case>*.csv) and raw/<case>/
(r8cPeriodic B_pss_* / B_pac_*, r8Periodic C_pnoise_s*, r7eStageC T_*). Writes r8e_design_budget.csv, r8e_static_gates.csv,
r8e_pac.csv, r8e_pnoise_convergence.csv, r8e_gates.txt and figures. fL_flat / fH_flat: plateau = mean |H| over the 5-10 Hz grid
points; lower / upper -3 dB crossings, log-log interpolation (fL as in R8C r8c_lib.fl_flat)."""
import os, sys, csv, math
sys.path.insert(0, '../round8c'); sys.path.insert(0, '../round8')
from r8c_lib import read, fl_flat, interp, plateau
import r8_spec
from r8e_budget import budget
CASES = [('g0', 'G0 (R8B, 60p/0.5p)', 1.0), ('c2', 'A2 (120p/1p)', 2.0), ('c35', 'B35 (210p/1.75p)', 3.5)]
ex = os.path.exists; out = []; G = {}
def say(s=''): out.append(s); print(s)
def kv(p): return next(csv.DictReader(open(p))) if ex(p) else {}
def kv2(p): return {r['key']: r['value'] for r in csv.DictReader(open(p))} if ex(p) else {}
def num(x):
    try: return float(x)
    except Exception: return float('nan')
def gate(lst, c, m): lst.append(bool(c)); say('  %s  %s' % ('PASS' if c else 'FAIL', m))
def fh_flat(f, m):
    P = plateau(f, m); thr = P / math.sqrt(2); pts = sorted(zip(f, m))
    for (f1, m1), (f2, m2) in zip(pts, pts[1:]):
        if f1 >= 10.0 and m1 >= thr > m2:
            a = (math.log(thr) - math.log(m1)) / (math.log(m2) - math.log(m1)); return math.exp(math.log(f1) + a * (math.log(f2) - math.log(f1)))
    return None
def conv(p): return ex(p) and 'steady-state solution was achieved' in open(p).read()
dB = lambda x: 20 * math.log10(x)
# ---------------- budget + static ----------------
S = 'raw/static'; brow = []; srow = []
for key, lab, k in CASES:
    nl = f'{S}/L_{key}_netlist.scs'
    if not ex(nl): continue
    tot, rows, par = budget(nl); G[key] = {'budget_pF': tot * 1e12, 'cc': par.get('cc'), 'cfb': par.get('cfb')}
    for r in rows: brow.append((key, r[0], r[1], '%.6g' % (r[2] * 1e12), r[3]))
    b = kv(f'{S}/B_{key}.csv'); l = kv(f'{S}/L_{key}.csv')
    f, mo = [], []
    if ex(f'{S}/L_{key}_dm_ac.csv'):
        rr = read(f'{S}/L_{key}_dm_ac.csv'); f = [x['f_Hz'] for x in rr]; mo = [x['abs_Hout'] for x in rr]
    fl = fl_flat(f, mo)[0] if f else None; fh = fh_flat(f, mo) if f else None
    r = dict(case=key, label=lab, k=k, cc_pF=1e12 * par['cc'], cfb_pF=1e12 * par['cfb'], budget_pF=tot * 1e12, status=b.get('status'),
             fL_off=fl, fH_off=fh, plateau_off=plateau(f, mo) if f else None, H100_off=num(l.get('Hout100')), H100_off_dB=dB(num(l.get('Hout100'))),
             Zin10_off=num(b.get('Zin_dm_src_10')), CMRR60_pre=num(b.get('CMRR60_pre')), CMRR60_out=num(l.get('CMRR60_out')),
             cmfb_pm=num(b.get('cmfb_pm')), drl_pm=num(b.get('drl_pm')), P_uW=num(b.get('P_uW')), op_cm=num(b.get('op_cm')), fp_cm=num(b.get('fp_cm')),
             minA=num(b.get('minA')), worstA=b.get('worstA'), minC=num(b.get('minC')), Hpre100=num(b.get('Hpre100')), fH_flat_r7e=num(l.get('fH_flat')),
             outp=num(l.get('outp')), bufp=num(l.get('bufp')))
    srow.append(r); G[key].update(r)
    if key != 'g0':
        say(f'== Stage A static gates {key} ({lab})'); g = []
        au = f'r8e_netlist_audit_{key}.txt'
        gate(g, ex(au) and 'AUDIT FAIL' not in open(au).read() and open(au).read().count('AUDIT PASS') >= 2, 'netlist audit vs G0 (only cc, cfb values differ): %s' % au)
        gate(g, abs(r['cc_pF'] / 1e12 * 1e12 - {'c2': 120, 'c35': 210}[key]) < 1e-6 and abs(r['cfb_pF'] - {'c2': 1.0, 'c35': 1.75}[key]) < 1e-9, 'netlisted cc %.4g pF, cfb %.4g pF' % (r['cc_pF'], r['cfb_pF']))
        gate(g, r['Zin10_off'] >= 1e8, 'Zin(10 Hz) %.4g MOhm >= 100' % (r['Zin10_off'] / 1e6))
        gate(g, r['cmfb_pm'] >= 60 and r['drl_pm'] >= 60, 'PM CMFB %.2f / DRL %.2f deg >= 60' % (r['cmfb_pm'], r['drl_pm']))
        gate(g, r['CMRR60_pre'] >= 85, 'CMRR60 %.2f dB >= 85 (out %.2f dB)' % (r['CMRR60_pre'], r['CMRR60_out']))
        gate(g, r['P_uW'] < 4, 'P %.4f uW < 4' % r['P_uW'])
        gate(g, tot * 1e12 < 1000, 'design capacitance %.2f pF < 1000 (netlist)' % (tot * 1e12))
        gate(g, abs(r['op_cm'] - 0.9) <= 1e-3 and r['minA'] >= 0.05, 'bias: op/on CM %+.3f mV vs 0.9 V, min XA margin %.4f V (%s) >= 0.05' % (1e3 * (r['op_cm'] - 0.9), r['minA'], r['worstA']))
        r['static_hard'] = 'PASS' if all(g) else 'FAIL'; G[key]['static_hard'] = r['static_hard']
        say('  hard gates: ' + r['static_hard'])
        say('  info: fL_OFF %.4f Hz (not gated), fH_OFF %.1f Hz (225-275: %s), H100_OFF %.3f = %.2f dB (38-42: %s)' %
            (fl or float('nan'), fh or float('nan'), 'in' if fh and 225 <= fh <= 275 else 'OUT', r['H100_off'], r['H100_off_dB'], 'in' if 38 <= r['H100_off_dB'] <= 42 else 'static gain caution'))
with open('r8e_design_budget.csv', 'w') as fh_:
    fh_.write('case,element,expr,value_pF,status\n'); [fh_.write(','.join(x) + '\n') for x in brow]
cols = list(srow[0].keys()) if srow else []
cols += [c for c in ('static_hard',) if c not in cols]
with open('r8e_static_gates.csv', 'w') as fh_:
    w = csv.DictWriter(fh_, cols, restval=''); w.writeheader()
    for r in srow: w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
# ---------------- ON PSS / PAC ----------------
prow = []
for key, lab, k in CASES:
    base = '../round8c/raw/stageA/A1_pac_mos_m1' if key == 'g0' else f'raw/{key}/B_pac_{key}'
    if not ex(base + '_pac.csv'): continue
    rr = read(base + '_pac.csv'); f = [x['f_Hz'] for x in rr]; m = [x['abs_H0_out'] for x in rr]
    r = dict(case=key, label=lab, source='R8C A1 (0.01-250 Hz)' if key == 'g0' else 'R8E PAC 0.01-1000 Hz')
    r['fL_on'] = fl_flat(f, m)[0]; r['plateau_on'] = plateau(f, m); r['fH_on'] = fh_flat(f, m)
    r['H100_on'] = interp(f, m, 100.0); r['H100_on_dB'] = dB(r['H100_on']); r['ph100_on'] = interp(f, [x['ph_H0_out'] for x in rr], 100.0)
    for x in (0.1, 1, 10, 250): r['H_%g' % x] = interp(f, m, x)
    for nd in ('pn', 'f', 'buf'): r['fL_on_' + nd] = fl_flat(f, [x['abs_H0_' + nd] for x in rr])[0]
    r['Zin0_10'] = interp(f, [x['abs_Zin0'] for x in rr], 10.0) if 'abs_Zin0' in rr[0] else None
    r['vd_ok'] = all(abs(x['abs_vd_pac'] - 2) < 1e-6 for x in rr)
    cl = (base + '_convergence_lines.txt'); r['pss_converged'] = conv(cl); r['pss_reused_1it'] = ex(cl) and 'achieved in 1 shooting-Newton' in open(cl).read()
    if key != 'g0':
        ps = [p for p in (f'raw/{key}/B_pss_b1_{key}_convergence_lines.txt', f'raw/{key}/B_pss_b2_{key}_convergence_lines.txt') if ex(p)]
        r['pss_file_run'] = ';'.join(os.path.basename(p) + ('=converged' if conv(p) else '=NOT converged') for p in ps)
    if 'fL_off' in G.get(key, {}) and G[key]['fL_off']: r['Q'] = r['fL_on'] / G[key]['fL_off']
    r['fL_on_model'] = 0.338068 / k
    td = read(base + '_pss_td.csv')
    for n in ('p', 'fp', 'op', 'outp'):
        x = [q[n + '_V'] for q in td]; r['pss_%s_min' % n] = min(x); r['pss_%s_max' % n] = max(x)
    prow.append(r); G.setdefault(key, {}).update({'on_' + a: b for a, b in r.items()})
    if key != 'g0':
        say(f'== Stage B ON gates {key} ({lab})'); g = []
        gate(g, r['pss_converged'] and r['vd_ok'], 'PSS explicitly converged (%s; PAC run: %s), PAC input 2 V at 0 deg' % (r.get('pss_file_run'), 'reused, 1 iteration' if r['pss_reused_1it'] else 're-converged'))
        gate(g, 0.09 <= r['fL_on'] <= 0.11, 'fL_ON %.4f Hz in 0.09-0.11 (model 0.338/k = %.4f; Q = %.3f)' % (r['fL_on'], r['fL_on_model'], r.get('Q', float('nan'))))
        gate(g, r['fH_on'] and 225 <= r['fH_on'] <= 275, 'fH_ON %.2f Hz in 225-275' % (r['fH_on'] or float('nan')))
        gate(g, 38 <= r['H100_on_dB'] <= 42, 'H100_ON %.4f = %.3f dB in 38-42' % (r['H100_on'], r['H100_on_dB']))
        gate(g, r['Zin0_10'] is not None and r['Zin0_10'] >= 1e8, 'PAC sb0 Zin(10 Hz) %s MOhm >= 100' % ('%.4g' % (r['Zin0_10'] / 1e6) if r['Zin0_10'] else 'n/a'))
        r['on_gates'] = 'PASS' if all(g) else 'FAIL'; G[key]['on_gates'] = r['on_gates']; say('  ON gates: ' + r['on_gates'])
cols = []; [cols.append(c) for r in prow for c in r if c not in cols]
with open('r8e_pac.csv', 'w') as fh_:
    w = csv.DictWriter(fh_, cols, restval=''); w.writeheader()
    for r in prow: w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
# ---------------- PNoise ----------------
nrow = []
for key, lab, k in CASES:
    for sb in (30, 60, 90, 120):
        b = f'raw/{key}/C_pnoise_s{sb}'
        if not ex(b + '_pnoise.csv'): continue
        f, so, H, H100 = r8_spec.load(b); si = so / H
        app = r8_spec.rms(f, so) / H100; de = r8_spec.rms(f, si)
        d = {x: float(math.exp(__import__('numpy').interp(math.log(x), __import__('numpy').log(f), __import__('numpy').log(si)))) for x in (1.0, 10.0, 100.0)}
        cl = b + '_convergence_lines.txt'
        nrow.append(dict(case=key, sb=sb, out_rms=r8_spec.rms(f, so), H100=H100, app_uV=1e6 * app, deemb_uV=1e6 * de, in1=d[1.0], in10=d[10.0], in100=d[100.0],
                         pss_reused=ex(cl) and 'achieved in 1 shooting-Newton' in open(cl).read()))
if nrow:
    say('== Stage C PNoise')
    for i, r in enumerate(nrow):
        prev = nrow[i - 1] if i and nrow[i - 1]['case'] == r['case'] else None
        if prev:
            r['d_app_pct'] = 100 * (r['app_uV'] / prev['app_uV'] - 1); r['d_deemb_pct'] = 100 * (r['deemb_uV'] / prev['deemb_uV'] - 1)
            r['d_in1_pct'] = 100 * (r['in1'] / prev['in1'] - 1); r['d_in10_pct'] = 100 * (r['in10'] / prev['in10'] - 1); r['d_in100_pct'] = 100 * (r['in100'] / prev['in100'] - 1)
            r['converged_vs_prev'] = abs(r['d_app_pct']) <= 5 and abs(r['d_deemb_pct']) <= 5 and max(abs(r['d_in1_pct']), abs(r['d_in10_pct']), abs(r['d_in100_pct'])) <= 10
        say('  %s S%-3d app %.4f uV  deemb %.4f uV  in 1/10/100 Hz %.1f/%.1f/%.1f nV/rtHz  %s  PSS reused: %s' % (r['case'], r['sb'], r['app_uV'], r['deemb_uV'], 1e9 * r['in1'], 1e9 * r['in10'], 1e9 * r['in100'],
            ('d %+.2f/%+.2f %% dens %+.2f/%+.2f/%+.2f %% conv %s' % (r['d_app_pct'], r['d_deemb_pct'], r['d_in1_pct'], r['d_in10_pct'], r['d_in100_pct'], r['converged_vs_prev'])) if prev else '', r['pss_reused']))
    cols = []; [cols.append(c) for r in nrow for c in r if c not in cols]
    with open('r8e_pnoise_convergence.csv', 'w') as fh_:
        w = csv.DictWriter(fh_, cols, restval=''); w.writeheader()
        for r in nrow: w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
open('r8e_gates.txt', 'w').write('\n'.join(out) + '\n')
# ---------------- figures ----------------
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
COL = {'g0': '#7a7a7a', 'c2': '#2a78b5', 'c35': '#d45500'}
if srow:
    fig, ax = plt.subplots(1, 3, figsize=(15, 4.4))
    for key, lab, k in CASES:
        if ex(f'{S}/L_{key}_dm_ac.csv'):
            rr = read(f'{S}/L_{key}_dm_ac.csv'); ax[0].loglog([x['f_Hz'] for x in rr], [x['abs_Hout'] for x in rr], color=COL[key], ls='--', lw=1.2, label=lab + ' OFF')
        base = '../round8c/raw/stageA/A1_pac_mos_m1' if key == 'g0' else f'raw/{key}/B_pac_{key}'
        if ex(base + '_pac.csv'):
            rr = read(base + '_pac.csv'); ax[0].loglog([x['f_Hz'] for x in rr], [x['abs_H0_out'] for x in rr], color=COL[key], lw=2, label=lab + ' ON')
    ax[0].axvspan(0.09, 0.11, color='#eeeeee', zorder=0); ax[0].set_xlim(0.01, 1000); ax[0].set_ylim(1, 200); ax[0].set_xlabel('f (Hz)'); ax[0].set_ylabel('V/V')
    ax[0].set_title('|(outp-outn)/(ep-en)|, OFF static AC (dashed) / ON PAC sb0', fontsize=10); ax[0].legend(frameon=False, fontsize=7)
    ks = [r['case'] for r in srow]; xx = range(len(ks)); w = 0.38
    ax[1].bar([i - w / 2 for i in xx], [G[c]['fL_off'] or 0 for c in ks], w, color='#bbbbbb', label='OFF')
    ax[1].bar([i + w / 2 for i in xx], [G[c].get('on_fL_on', 0) or 0 for c in ks], w, color=[COL[c] for c in ks], label='ON')
    for i, c in enumerate(ks):
        ax[1].annotate('%.3f' % (G[c]['fL_off'] or 0), (i - w / 2, G[c]['fL_off'] or 0), ha='center', va='bottom', fontsize=8)
        if G[c].get('on_fL_on'): ax[1].annotate('%.3f' % G[c]['on_fL_on'], (i + w / 2, G[c]['on_fL_on']), ha='center', va='bottom', fontsize=8)
    ax[1].axhspan(0.09, 0.11, color='#dff0d8', zorder=0); ax[1].set_xticks(list(xx)); ax[1].set_xticklabels([c.upper() for c in ks]); ax[1].set_ylabel('fL_flat (Hz)')
    ax[1].set_title('fL_flat OFF (grey) / ON; band 0.09-0.11 Hz', fontsize=10)
    items = [('H100 ON (dB)', lambda c: G[c].get('on_H100_on_dB')), ('Zin10 OFF (100 MOhm)', lambda c: G[c]['Zin10_off'] / 1e8), ('C budget (100 pF)', lambda c: G[c]['budget_pF'] / 100)]
    for j, (lab_, fn) in enumerate(items):
        for i, c in enumerate(ks):
            v = fn(c)
            if v: ax[2].bar(j * (len(ks) + 1) + i, v, color=COL[c]); ax[2].annotate('%.3g' % v, (j * (len(ks) + 1) + i, v), ha='center', va='bottom', fontsize=7)
    ax[2].set_xticks([j * (len(ks) + 1) + (len(ks) - 1) / 2 for j in range(3)]); ax[2].set_xticklabels([i[0] for i in items], fontsize=8)
    ax[2].set_title('gain / input impedance / capacitance (G0 grey, A2 blue, B35 orange)', fontsize=9)
    for a in ax: a.spines[['top', 'right']].set_visible(False); a.grid(True, which='both', color='#e6e6e6', lw=0.6)
    fig.tight_layout(); fig.savefig('r8e_frequency.png', dpi=120)
if nrow:
    fig, ax = plt.subplots(1, 2, figsize=(12, 4.2))
    for key in sorted({r['case'] for r in nrow}):
        rs = [r for r in nrow if r['case'] == key]
        ax[0].plot([r['sb'] for r in rs], [r['app_uV'] for r in rs], 'o-', color=COL[key], label=key.upper() + ' app')
        ax[0].plot([r['sb'] for r in rs], [r['deemb_uV'] for r in rs], 's--', color=COL[key], label=key.upper() + ' de-embedded')
        b = f'raw/{key}/C_pnoise_s{rs[-1]["sb"]}'; f, so, H, H100 = r8_spec.load(b); ax[1].loglog(f, 1e9 * so / H, color=COL[key], lw=2, label='%s S%d' % (key.upper(), rs[-1]['sb']))
    ax[0].plot([90], [3.141], 'x', color='#7a7a7a', label='R8B G0 S90 app'); ax[0].plot([90], [3.994], '+', color='#7a7a7a', label='R8B G0 S90 de-emb')
    ax[0].axhline(3.0, color='#999', ls=':', lw=0.8); ax[0].set_xlabel('PNoise maxsideband'); ax[0].set_ylabel('uVrms 0.1-250 Hz input-referred'); ax[0].legend(frameon=False, fontsize=7)
    r8b = '../round8b/raw/gateD/C_pnoise_s90'
    if ex(r8b + '_pnoise.csv'): f, so, H, H100 = r8_spec.load(r8b); ax[1].loglog(f, 1e9 * so / H, color='#7a7a7a', lw=1.5, label='R8B G0 S90')
    ax[1].set_xlabel('f (Hz)'); ax[1].set_ylabel('nV/rtHz (de-embedded, input)'); ax[1].legend(frameon=False, fontsize=8)
    for a in ax: a.spines[['top', 'right']].set_visible(False); a.grid(True, which='both', color='#e6e6e6', lw=0.6)
    fig.tight_layout(); fig.savefig('r8e_pnoise.png', dpi=120)
