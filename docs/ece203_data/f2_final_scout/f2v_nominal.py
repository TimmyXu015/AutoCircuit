"""F2 final validation scout -- nominal analysis (stage A noise + stage B checks) of the standalone Spectre runs.
Usage: python3 f2v_nominal.py <nominal run dir> <ref run dir>   (run dirs contain input.scs and psf/; see tools/f2v_run.sh)
Writes f2v_nominal_summary.csv, f2v_noise_bands.csv, f2v_noise_sources.csv, f2v_noise_psd.csv, f2v_gain_curve.csv,
f2v_dcop_devices.csv, f2v_caps.csv, f2v_nominal.txt (all definitions spelled out in the text file)."""
import sys, re, csv, math
import numpy as np
import f2v_psf as P

NOM = sys.argv[1]; REF = sys.argv[2] if len(sys.argv) > 2 else None
k_B, q, T = 1.380649e-23, 1.602176634e-19, 300.15            # 27 C
UT = k_B * T / q
out = []; say = out.append; summ = []
def put(key, val, unit='', note=''):
    summ.append(dict(quantity=key, value=val, unit=unit, note=note))

def rd(run, name): return P.read('%s/psf/%s' % (run, name))
def arr(d, n): return np.array(d['sig'][n])
def trapz(y, x):
    return float(np.sum((y[1:] + y[:-1]) * np.diff(x)) / 2)
def loglog_int(y, x):
    """exact integral of a piecewise power law through the points (independent check of trapz)"""
    tot = 0.0
    for i in range(len(x) - 1):
        x0, x1, y0, y1 = x[i], x[i + 1], y[i], y[i + 1]
        if y0 <= 0 or y1 <= 0: tot += (y0 + y1) / 2 * (x1 - x0); continue
        a = math.log(y1 / y0) / math.log(x1 / x0)
        tot += (y0 * x0 * ((x1 / x0) ** (a + 1) - 1) / (a + 1)) if abs(a + 1) > 1e-9 else y0 * x0 * math.log(x1 / x0)
    return tot
def band(f, y, lo, hi, fn=trapz):
    """integral of y over [lo, hi] with log-interpolated end points"""
    ly = np.log(np.maximum(y, 1e-300)); lf = np.log(f)
    inner = (f > lo) & (f < hi)
    xs = np.concatenate([[lo], f[inner], [hi]])
    ys = np.exp(np.interp(np.log(xs), lf, ly))
    return fn(ys, xs)
def corners(f, h):
    """plateau = max |h|; fL / fH = log-interpolated crossings of max/sqrt2 below / above the peak"""
    m = np.abs(h); k = int(np.argmax(m)); lvl = m[k] / math.sqrt(2)
    def cross(i0, i1, step):
        i = i0
        while i != i1 and m[i] > lvl: i += step
        if i == i1: return float('nan')
        j = i - step
        return float(np.exp(np.interp(np.log(lvl), np.log([m[i], m[j]][::(1 if m[i] < m[j] else -1)]), np.log([f[i], f[j]][::(1 if m[i] < m[j] else -1)]))))
    return m[k], f[k], cross(k, 0, -1), cross(k, len(f) - 1, 1)

# ---------------- AC (pure DM, CM DRL off / on), dcc 0 and 1 % ----------------
res = {}
for di, dname in ((0, 'dcc0'), (1, 'dcc1pct')):
    acm = [rd(NOM, 'sdcc-%03d_swm-%03d_acm.ac' % (di, m)) for m in range(3)]
    acx = [rd(NOM, 'sdcc-%03d_swm-%03d_acx.ac' % (di, m)) for m in range(3)]
    f = np.array(acm[0]['x'])
    s0 = acm[0]
    vpost = arr(s0, 'vRight') - arr(s0, 'vLeft'); vsrc = arr(s0, 'net1') - arr(s0, 'net013')
    Hpost = arr(s0, 'out') / vpost; Hsrc = arr(s0, 'out') / vsrc
    pk, fpk, fL, fH = corners(f, Hpost); pks, _, fLs, fHs = corners(f, Hsrc)
    X = [dict((n, np.array(a['sig'][n])) for n in a['sig']) for a in acx]; fx = np.array(acx[0]['x'])
    Hx = X[0]['out'] / (X[0]['vRight'] - X[0]['vLeft']); Hxs = X[0]['out'] / (X[0]['net1'] - X[0]['net013'])
    i60 = list(fx).index(60.0); i10 = list(fx).index(10.0)
    vcm_off = (X[1]['vRight'][i60] + X[1]['vLeft'][i60]) / 2; vcm_on = (X[2]['vRight'][i60] + X[2]['vLeft'][i60]) / 2
    out_off, out_on = X[1]['out'][i60], X[2]['out'][i60]
    adm60 = abs(Hx[i60])
    r = dict(f=f, Hpost=Hpost, Hsrc=Hsrc, fx=fx, Hx=Hx, Hxs=Hxs, pk=pk, fpk=fpk, fL=fL, fH=fH, fLs=fLs, fHs=fHs, pks=pks,
             vcm_off=vcm_off, vcm_on=vcm_on, out_off=out_off, out_on=out_on, adm60=adm60,
             vdm_cm_off=X[1]['vRight'][i60] - X[1]['vLeft'][i60], vdm_cm_on=X[2]['vRight'][i60] - X[2]['vLeft'][i60],
             body_off=X[1]['net5'][i60], body_on=X[2]['net5'][i60],
             cmrr_on=20 * math.log10(adm60 * abs(vcm_off) / abs(out_on)), cmrr_off=20 * math.log10(adm60 * abs(vcm_off) / abs(out_off)),
             cmrr_on_own=20 * math.log10(adm60 * abs(vcm_on) / abs(out_on)),
             zin_p=abs(X[0]['inp'][i10] / X[0]['VPP:p'][i10]), zin_n=abs(X[0]['inn'][i10] / X[0]['VPN:p'][i10]),
             zin_d=abs((X[0]['inp'][i10] - X[0]['inn'][i10]) / X[0]['VPP:p'][i10]),
             zin_p_ph=math.degrees(np.angle(X[0]['inp'][i10] / X[0]['VPP:p'][i10])))
    res[dname] = r
r0 = res['dcc0']
with open('f2v_gain_curve.csv', 'w') as fh:
    fh.write('freq_Hz,Hpost_mag,Hpost_deg,Hsrc_mag,post_over_src_mag\n')
    for i in range(len(r0['f'])):
        fh.write('%.6g,%.6g,%.4f,%.6g,%.6g\n' % (r0['f'][i], abs(r0['Hpost'][i]), math.degrees(np.angle(r0['Hpost'][i])), abs(r0['Hsrc'][i]),
                                                abs(r0['Hpost'][i] / r0['Hsrc'][i]) ** -1 if False else abs(r0['Hsrc'][i] / r0['Hpost'][i])))
say('== B. AC, professor ECG_tb copy + frozen F2, TT 27 C, real DRL on, pure DM (V0 AC 1 V, I2 AC 0)')
for dname, r in res.items():
    say('  [%s] Gpost = |out/(vRight-vLeft)|: 10 Hz %.4f (%.3f dB), 60 Hz %.4f (%.3f dB), 100 Hz %.4f (%.3f dB); plateau max %.4f (%.3f dB) at %.3g Hz'
        % (dname, abs(r['Hx'][0]), 20 * math.log10(abs(r['Hx'][0])), abs(r['Hx'][1]), 20 * math.log10(abs(r['Hx'][1])), abs(r['Hx'][2]),
           20 * math.log10(abs(r['Hx'][2])), r['pk'], 20 * math.log10(r['pk']), r['fpk']))
    say('  [%s] Gsrc = |out/V0|: 10/60/100 Hz %.4f / %.4f / %.4f ; post/src = %.4f / %.4f / %.4f'
        % (dname, abs(r['Hxs'][0]), abs(r['Hxs'][1]), abs(r['Hxs'][2]), *[abs(r['Hxs'][k] / r['Hx'][k]) for k in range(3)]))
    say('  [%s] corners from the Gpost plateau max: fL %.5f Hz, fH %.2f Hz (Gsrc: fL %.5f, fH %.2f)' % (dname, r['fL'], r['fH'], r['fLs'], r['fHs']))
    say('  [%s] CMRR60 (100 nA AC into body, V0 AC 0): vcm_post,off = |(vRight+vLeft)/2| = %.4g V, vcm_post,on = %.4g V; out_off %.4g V, out_on %.4g V; '
        'Adm60 %.4f' % (dname, abs(r['vcm_off']), abs(r['vcm_on']), abs(r['out_off']), abs(r['out_on']), r['adm60']))
    say('  [%s]   CMRR_on = 20log10(Adm60*|vcm_off|/|out_on|) = %.2f dB ; CMRR_off = 20log10(Adm60*|vcm_off|/|out_off|) = %.2f dB ; '
        '(info: own-reference CMRR_on with vcm_on = %.2f dB); body60 off/on %.4g / %.4g V; CM->DM residual at the electrodes |vRight-vLeft| off/on %.2g / %.2g V '
        '(at the 6-significant-digit psfascii AC resolution of ~1e-6 V, i.e. not resolved)'
        % (dname, r['cmrr_on'], r['cmrr_off'], r['cmrr_on_own'], abs(r['body_off']), abs(r['body_on']), abs(r['vdm_cm_off']), abs(r['vdm_cm_on'])))
    say('  [%s] Zin @10 Hz (historical definition, amplifier input after the electrode): |v(inp)/i(VPP)| %.4g Ohm (phase %.1f deg), '
        '|v(inn)/i(VPN)| %.4g Ohm, differential |v(inp)-v(inn)|/|i(VPP)| %.4g Ohm' % (dname, r['zin_p'], r['zin_p_ph'], r['zin_n'], r['zin_d']))
for dname, r in res.items():
    tag = '' if dname == 'dcc0' else '_dcc1pct'
    for k, ff in enumerate((10, 60, 100)):
        put('Gpost_%dHz%s' % (ff, tag), abs(r['Hx'][k]), 'V/V', '%.3f dB' % (20 * math.log10(abs(r['Hx'][k]))))
        put('Gsrc_%dHz%s' % (ff, tag), abs(r['Hxs'][k]), 'V/V')
    put('Gpost_plateau%s' % tag, r['pk'], 'V/V', 'at %.3g Hz' % r['fpk'])
    put('fL%s' % tag, r['fL'], 'Hz', 'Gpost plateau max / sqrt2'); put('fH%s' % tag, r['fH'], 'Hz', 'Gpost plateau max / sqrt2')
    put('CMRR60_on%s' % tag, r['cmrr_on'], 'dB', 'Adm60 * |vcm_post,off| / |out_on|'); put('CMRR60_off%s' % tag, r['cmrr_off'], 'dB', 'Adm60 * |vcm_post,off| / |out_off|')
    put('vcm_post_off_60%s' % tag, abs(r['vcm_off']), 'V', '100 nA AC'); put('out60_on%s' % tag, abs(r['out_on']), 'V'); put('out60_off%s' % tag, abs(r['out_off']), 'V')
    put('Zin10_P%s' % tag, r['zin_p'], 'Ohm', 'v(inp)/i(VPP)'); put('Zin10_N%s' % tag, r['zin_n'], 'Ohm', 'v(inn)/i(VPN)'); put('Zin10_diff%s' % tag, r['zin_d'], 'Ohm')

# ---------------- DC operating point, power ----------------
dc = rd(NOM, 'dcop.dc')['sig']; g = lambda n: dc[n][0]
I_VDD, I_VDDD, I_MP2, I_MP1, I_MP0 = -g('VDD:p'), -g('VDDD:p'), -g('MP2:d'), -g('MP1:d'), -g('MP0:d')
VDD = 1.8
say('== B. DC operating point (dcop): out %.5f V, o %.5f, oa1 %.5f, p %.6f, n %.6f, inp/inn %.6f, body %.6f, drlr %.6f, vref %.6f, vcas %.4f, ib %.4f, pref %.4f'
    % (g('out'), g('o'), g('oa1'), g('p'), g('n'), g('inp'), g('net5'), g('drlr'), g('vref'), g('vcas'), g('ib'), g('pref')))
say('  supplies in the netlist: VDD (vdd 0) dc=1.8 is the only source of power; VDDD (vddd vdd) dc=0 is a 0 V meter in series (DRL OTA supply), '
    'so I(VDD) already contains I(VDDD). IREF (pref 0) isource 100 nA is the one ideal bias reference (allowed); RV1/RV2 (vref divider) and RC1/RC2 '
    '(vcas divider) are ideal resistors from vdd (their current is inside I(VDD)). EDRL (ideal vcvs) hangs on RDRI = 1e15 Ohm (inactive leftover).')
say('  I(VDD) %.5g A -> P_total = 1.8 V * I(VDD) = %.5g W ; I(VDDD) (DRL OTA, inside) %.4g A ; DRL bias mirror MP2 %.4g A ; IREF branch MP0 %.4g A ; OTA bias MP1 %.4g A'
    % (I_VDD, VDD * I_VDD, I_VDDD, I_MP2, I_MP0, I_MP1))
I_fwd = I_VDD - I_VDDD - I_MP2
say('  forward-path current for NEF = I(VDD) - I(VDDD) - I(MP2) = %.5g A (DRL OTA and its bias mirror excluded; shared IREF branch, vref / vcas dividers '
    'and CS stage included)' % I_fwd)
put('I_VDD', I_VDD, 'A', 'includes the DRL supply meter VDDD'); put('P_total', VDD * I_VDD, 'W'); put('I_VDDD_DRL', I_VDDD, 'A'); put('I_MP2_DRLbias', I_MP2, 'A')
put('I_forward_NEF', I_fwd, 'A', 'I_VDD - I_VDDD - I_MP2'); put('out_DC', g('out'), 'V')
# per-device region / margin
op = rd(NOM, 'opinfo.info')['sig']
rows = []
for k, v in op.items():
    v = v[0]
    if isinstance(v, dict) and v.get('_type') == 'bsim3v3':
        rows.append(dict(inst=k, region=int(v['region']), ids=v['ids'], vgs=v['vgs'], vds=v['vds'], vth=v['vth'], vdsat=v['vdsat'],
                         margin=abs(v['vds']) - abs(v['vdsat']), gm=v['gm'], gm_over_id=abs(v['gm'] / v['ids']) if v['ids'] else float('nan')))
with open('f2v_dcop_devices.csv', 'w') as fh:
    w = csv.DictWriter(fh, list(rows[0])); w.writeheader(); [w.writerow(r) for r in rows]
reg = {0: 'off', 1: 'triode', 2: 'saturation', 3: 'subthreshold', 4: 'breakdown'}
say('  MOS regions (Spectre estimate): ' + ', '.join('%s %s' % (r['inst'], reg[r['region']]) for r in rows))
say('  smallest |vds|-|vdsat| among non-pseudo-R devices: ' + ', '.join('%s %.3f V' % (r['inst'], r['margin']) for r in sorted([r for r in rows if not r['inst'].startswith('XP')], key=lambda r: r['margin'])[:4]))

# ---------------- STB ----------------
for loop, nm in (('stbm', 'main loop (probe IPRB, oa -> o)'), ('stbd', 'DRL loop (probe IPRD, rl0 -> vRL)')):
    m = rd(NOM, loop + '.margin.stb')['sig']
    say('== B. STB %s: PM %.2f deg at %.4g Hz, GM %.2f dB at %.4g Hz' % (nm, m['phaseMargin'][0], m['phaseMarginFreq'][0], m['gainMargin'][0], m['gainMarginFreq'][0]))
    put('PM_' + loop, m['phaseMargin'][0], 'deg', 'UGF %.4g Hz' % m['phaseMarginFreq'][0]); put('GM_' + loop, m['gainMargin'][0], 'dB')

# ---------------- capacitance tally ----------------
net = open('%s/input.scs' % NOM).read().replace('\\\n', ' ')
params = dict(re.findall(r'(\w+)=([^\s\\]+)', ' '.join(l for l in net.split('\n') if l.startswith('parameters'))))
def ev(e, extra={}):
    env = {}
    for k_, v_ in params.items():
        try: env[k_] = float(v_)
        except ValueError: pass
    env.update({'fvm': 0, 'dccv': 0, 'dcc': 0}); env.update(extra)
    e = re.sub(r'(\d)([pnuf])\b', lambda mm: mm.group(1) + {'p': 'e-12', 'n': 'e-9', 'u': 'e-6', 'f': 'e-15'}[mm.group(2)], e)
    return float(eval(e, {}, env))
caps = []; cur = None
for l in net.split('\n'):
    ms = re.match(r'subckt (\w+)', l); me = re.match(r'ends', l)
    if ms: cur = ms.group(1)
    elif me: cur = None
    mc = re.match(r'\s*(\w+) \(([^)]*)\) capacitor c=(\S+)', l)
    if mc: caps.append(dict(inst=(cur + ':' if cur else '') + mc.group(1), nets=mc.group(2), expr=mc.group(3), value=ev(mc.group(3))))
fixture = {'C0', 'C1', 'C2', 'C3'}
with open('f2v_caps.csv', 'w') as fh:
    w = csv.DictWriter(fh, ['inst', 'nets', 'expr', 'value', 'counted']); w.writeheader()
    for c in caps: c['counted'] = c['inst'] not in fixture; w.writerow(c)
ctot = sum(c['value'] for c in caps if c['counted'])
say('== B. designed capacitance (all capacitor elements except the instructor fixture C0..C3; subckt caps counted once per instance): %.4g pF ; '
    % (ctot * 1e12) + ', '.join('%s %.4gp' % (c['inst'], c['value'] * 1e12) for c in caps if c['counted'] and c['value'] > 0))
put('C_designed_total', ctot, 'F', 'excludes instructor fixture C0..C3')

# ---------------- A. noise ----------------
say('== A. noise: analysis (out 0) noise 1 mHz..100 kHz, iprobe=V0 (instructor ECG source), real DRL on, interference off (I2 AC 0, '
    'isource has no noise), all fixture resistors (2 k + 1 M electrodes, 200 Ohm body) noisy. Spectre "out" = output ASD V/sqrt(Hz) at node out; '
    '"in" = out / |gain|, gain = out/V0 (SOURCE-referred).')
bands = [('full 1mHz-100kHz', 1e-3, 1e5), ('0.1-250 Hz', 0.1, 250.0), ('below 0.1 Hz', 1e-3, 0.1), ('above 250 Hz', 250.0, 1e5), ('0.5-150 Hz', 0.5, 150.0)]
nrows = []; nzres = {}
import os
for nzn in ('nz50', 'nz100'):
    if not os.path.exists('%s/psf/%s.noise' % (NOM, nzn)): continue   # nz100 only kept for the convergence check of a winner
    z = rd(NOM, nzn + '.noise'); fz = np.array(z['x']); So = arr(z, 'out') ** 2; Si = arr(z, 'in') ** 2; gz = arr(z, 'gain')
    # post-electrode transfer on the noise grid: complex log-interp of Hpost from the AC run (identical grid for nz50)
    Hp = np.exp(np.interp(np.log(fz), np.log(r0['f']), np.log(np.abs(r0['Hpost']))))
    Hs = np.exp(np.interp(np.log(fz), np.log(r0['f']), np.log(np.abs(r0['Hsrc']))))
    Spost = So / Hp ** 2
    g10, g100, gpk = abs(r0['Hx'][0]), abs(r0['Hx'][2]), r0['pk']
    nzres[nzn] = dict(f=fz, So=So, Si=Si, Spost=Spost, gain=gz, Hs=Hs, Hp=Hp)
    for bn, lo, hi in bands:
        po = band(fz, So, lo, hi); po2 = band(fz, So, lo, hi, loglog_int)
        pi = band(fz, Si, lo, hi); pp = band(fz, Spost, lo, hi)
        nrows.append(dict(grid=nzn, band=bn, lo=lo, hi=hi, out_rms_V=math.sqrt(po), out_rms_powerlaw_V=math.sqrt(po2),
                          M1_out_over_G10_uV=1e6 * math.sqrt(po) / g10, M1_out_over_G100_uV=1e6 * math.sqrt(po) / g100,
                          M1_out_over_Gplateau_uV=1e6 * math.sqrt(po) / gpk,
                          M2_native_in_V0ref_uV=1e6 * math.sqrt(pi), M3_post_deembedded_uV=1e6 * math.sqrt(pp)))
with open('f2v_noise_bands.csv', 'w') as fh:
    w = csv.DictWriter(fh, list(nrows[0])); w.writeheader(); [w.writerow(r) for r in nrows]
z50 = nzres['nz50']
chk = np.max(np.abs(np.sqrt(z50['Si']) * z50['gain'] / np.sqrt(z50['So']) - 1))
chk2 = np.max(np.abs(z50['gain'] / z50['Hs'] - 1))
say('  checks: Spectre in*gain/out - 1 max %.2e ; Spectre noise gain vs AC |out/V0| max rel diff %.2e (same DC op and source)' % (chk, chk2))
for r in nrows:
    say('  [%s] %-16s out %.4g uVrms (power-law integ %.4g) | M1 out/G10 %.4f uV, out/G100 %.4f, out/Gplateau %.4f | M2 native (V0-ref) %.4f uV | '
        'M3 post-electrode pointwise %.4f uV' % (r['grid'], r['band'], 1e6 * r['out_rms_V'], 1e6 * r['out_rms_powerlaw_V'], r['M1_out_over_G10_uV'],
                                                  r['M1_out_over_G100_uV'], r['M1_out_over_Gplateau_uV'], r['M2_native_in_V0ref_uV'], r['M3_post_deembedded_uV']))
    for k_, v_ in r.items():
        if k_.endswith('uV') and r['grid'] == 'nz50' and r['band'] in ('full 1mHz-100kHz', '0.1-250 Hz'):
            put('noise_%s_%s' % (k_, r['band'].split()[0]), v_, 'uVrms', '%g..%g Hz' % (r['lo'], r['hi']))
with open('f2v_noise_psd.csv', 'w') as fh:
    fh.write('freq_Hz,out_asd_V_rtHz,in_V0ref_asd_V_rtHz,in_post_asd_V_rtHz,gain_out_over_V0,Hpost_mag,cum_out_rms_from_1mHz_V\n')
    cum = np.concatenate([[0], np.cumsum((z50['So'][1:] + z50['So'][:-1]) * np.diff(z50['f']) / 2)])
    for i in range(len(z50['f'])):
        fh.write('%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g\n' % (z50['f'][i], math.sqrt(z50['So'][i]), math.sqrt(z50['Si'][i]), math.sqrt(z50['Spost'][i]),
                                                       z50['gain'][i], z50['Hp'][i], math.sqrt(cum[i])))
# source contributions (output-referred V^2/Hz 'total' field), integrated per band
z = rd(NOM, 'nz50.noise'); fz = np.array(z['x'])
def group(nm):
    if nm in ('XA.M1', 'XA.M2'): return 'OTA1 input pair XA.M1/M2'
    if nm in ('XA.M3', 'XA.M4'): return 'OTA1 PMOS mirror XA.M3/M4'
    if nm.startswith('XA.'): return 'OTA1 other (tail/cascode/ref)'
    if nm.startswith('XD.') or nm in ('MP2', 'RDRR', 'RDRI'): return 'DRL OTA + its bias + RDRR'
    if nm.startswith('XP'): return 'pseudo-resistors XPP/XPN'
    if nm.startswith('X2.'): return 'CS second stage X2'
    if nm in ('R4', 'R5', 'R6', 'R7', 'R8', 'R9'): return 'electrode resistors (2k + 1M, instructor)'
    if nm in ('R1', 'R2', 'R3'): return 'body loop 200 Ohm (instructor)'
    if nm in ('RLP',): return 'output LP resistor RLP'
    if nm in ('MP0', 'MP1', 'RV1', 'RV2', 'RC1', 'RC2', 'RCMN', 'RCMP'): return 'bias / dividers / CM sense R'
    return 'other ' + nm
srows = []; gt = {}
for nm, vals in z['sig'].items():
    if nm in ('out', 'in', 'gain') or not isinstance(vals[0], list): continue
    tot = np.array([v[-1] for v in vals])
    fn_ = np.array([v[z['trace'][nm].index('fn')] if (z['trace'].get(nm) and 'fn' in z['trace'][nm]) else 0.0 for v in vals])
    r = dict(source=nm, group=group(nm))
    for bn, lo, hi in bands[:2]:
        r['out_V2_' + bn.split()[0]] = band(fz, tot, lo, hi); r['flicker_V2_' + bn.split()[0]] = band(fz, np.maximum(fn_, 1e-300), lo, hi) if fn_.any() else 0.0
    srows.append(r)
    for bn in ('full', '0.1-250'):
        gt.setdefault((r['group'], bn), 0.0); gt[(r['group'], bn)] += r['out_V2_' + bn]
srows.sort(key=lambda r: -r['out_V2_full'])
with open('f2v_noise_sources.csv', 'w') as fh:
    w = csv.DictWriter(fh, list(srows[0])); w.writeheader(); [w.writerow(r) for r in srows]
P_full = band(fz, arr(z, 'out') ** 2, 1e-3, 1e5); P_band = band(fz, arr(z, 'out') ** 2, 0.1, 250.0)
say('  source sum / total output power: full %.6f, 0.1-250 %.6f' % (sum(r['out_V2_full'] for r in srows) / P_full, sum(r['out_V2_0.1-250'] for r in srows) / P_band))
for bn, Ptot in (('full', P_full), ('0.1-250', P_band)):
    say('  groups (%s band, %% of output noise power): ' % bn + ', '.join('%s %.1f%%' % (gname, 100 * v / Ptot)
        for (gname, b), v in sorted(gt.items(), key=lambda kv: -kv[1]) if b == bn and v / Ptot > 0.001))
# where the full-band output power comes from (by decade)
dec_edges = [1e-3, 1e-2, 1e-1, 1, 10, 100, 250, 1e3, 1e4, 1e5]
say('  output noise power by frequency slice (%% of full band): ' + ', '.join('%g-%g Hz %.1f%%' % (a, b, 100 * band(fz, arr(z, 'out') ** 2, a, b) / P_full) for a, b in zip(dec_edges[:-1], dec_edges[1:])))
# NEF
for bn, lo, hi in (('0.1-250 Hz', 0.1, 250.0), ('full 1mHz-100kHz', 1e-3, 1e5)):
    r = [x for x in nrows if x['grid'] == 'nz50' and x['band'] == bn][0]
    for meth, vni in (('M1 out/G10', r['M1_out_over_G10_uV']), ('M3 post pointwise', r['M3_post_deembedded_uV'])):
        bw = (hi - lo) if bn.startswith('0.1') else (r0['fH'] - r0['fL']) * math.pi / 2
        nef = vni * 1e-6 * math.sqrt(2 * I_fwd / (math.pi * UT * 4 * k_B * T * bw))
        say('  NEF (%s, %s) = Vni * sqrt(2 I_fwd / (pi UT 4kT BW)), Vni %.4f uV, I_fwd %.4g A, T 300.15 K, UT %.4f mV, BW %.2f Hz%s -> %.3f'
            % (bn, meth, vni, I_fwd, UT * 1e3, bw, ' (= pi/2 (fH-fL), full-band noise)' if not bn.startswith('0.1') else ' (= 250 - 0.1)', nef))
        put('NEF_%s_%s' % (bn.split()[0], meth.split()[0]), nef, '', 'BW %.2f Hz' % bw)
# ---------------- reference: archived F2 fixture (optional) ----------------
if REF:
    a = rd(REF, 'acr.ac'); ax = rd(REF, 'acrx.ac'); zr = rd(REF, 'nzr.noise')
    fr = np.array(a['x']); Hr = arr(a, 'out') / (arr(a, 'ep') - arr(a, 'en'))
    Hrx = arr(ax, 'out') / (arr(ax, 'ep') - arr(ax, 'en'))
    Sr = arr(zr, 'out') ** 2; fzr = np.array(zr['x'])
    Hrp = np.exp(np.interp(np.log(fzr), np.log(fr), np.log(np.abs(Hr))))
    pkr, _, fLr, fHr = corners(fr, Hr)
    say('== Reference: archived F2 fixture (Project/ece203_r5nf_tb_f2 netlist, f2i job A_ref), H = out/(ep-en): 10/60/100 Hz %.4f / %.4f / %.4f (100 Hz %.3f dB), '
        'fL %.4f fH %.2f' % (abs(Hrx[0]), abs(Hrx[1]), abs(Hrx[2]), 20 * math.log10(abs(Hrx[2])), fLr, fHr))
    for bn, lo, hi in bands[:2]:
        po = band(fzr, Sr, lo, hi); pp = band(fzr, Sr / Hrp ** 2, lo, hi)
        say('  ref noise %s: out/H100 %.4f uV (historical "app" 2.930 for 0.1-250), out/H10 %.4f uV, pointwise de-embedded %.4f uV (historical 2.880 for 0.1-250)'
            % (bn, 1e6 * math.sqrt(po) / abs(Hrx[2]), 1e6 * math.sqrt(po) / abs(Hrx[0]), 1e6 * math.sqrt(pp)))
        put('ref_noise_out_over_H100_' + bn.split()[0], 1e6 * math.sqrt(po) / abs(Hrx[2]), 'uVrms'); put('ref_noise_deemb_' + bn.split()[0], 1e6 * math.sqrt(pp), 'uVrms')

with open('f2v_nominal_summary.csv', 'w') as fh:
    w = csv.DictWriter(fh, ['quantity', 'value', 'unit', 'note']); w.writeheader(); [w.writerow(r) for r in summ]
open('f2v_nominal.txt', 'w').write('\n'.join(out) + '\n'); print('\n'.join(out))
