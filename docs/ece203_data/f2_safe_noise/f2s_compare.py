"""F2S comparison: run the unchanged F2V nominal analysis (../f2_final_scout/f2v_nominal.py) on every case run directory and collect one row per
case: gates, the four noise methods in both bands, noise groups (output power in uV at out / G10), OTA1 OP (Id, gm/Id, VDSAT, margin,
Cgg) and area. Usage: python3 f2s_compare.py <runs root holding s_<case>/> case[:n_w,n_l,p_w,p_l,t_w,t_l[,note]] ...
Writes cases/<case>/ (full F2V outputs per case), f2s_cases.csv, f2s_groups.csv, f2s_op.csv, f2s_compare.txt."""
import sys, os, csv, subprocess, math
HERE = os.path.dirname(os.path.abspath(__file__)); NOMPY = os.path.join(HERE, '..', 'f2_final_scout', 'f2v_nominal.py')
sys.path.insert(0, os.path.join(HERE, '..', 'f2_final_scout')); import f2v_psf as P
root = sys.argv[1]
rows, grows, oprows, out = [], [], [], []
GATES = [('Gpost_10Hz_dB', 38, 42), ('Gpost_60Hz_dB', 38, 42), ('Gpost_100Hz_dB', 38, 42), ('fL', 0.09, 0.11), ('fH', 225, 275),
         ('CMRR60_on', 85, None), ('Zin_worst', 100e6, None), ('P_total', None, 4e-6), ('C_designed_total', None, 1e-9), ('PM_stbm', 60, None), ('PM_stbd', 60, None)]
for arg in sys.argv[2:]:
    case, _, req = arg.partition(':')
    sz = req.split(',') if req else []
    d = os.path.join(HERE, 'cases', case); os.makedirs(d, exist_ok=True)
    subprocess.run([sys.executable, NOMPY, os.path.join(root, 's_' + case)], cwd=d, check=True, stdout=subprocess.DEVNULL)
    s = {r['quantity']: float(r['value']) for r in csv.DictReader(open(os.path.join(d, 'f2v_nominal_summary.csv')))}
    r = dict(case=case, sizes='M1/M2 %s/%s, M3/M4 %s/%s, MT %s/%s' % tuple(sz[:6]) if len(sz) >= 6 else '', note=sz[6] if len(sz) > 6 else '')
    for k in ('Gpost_10Hz', 'Gpost_60Hz', 'Gpost_100Hz'): r[k + '_dB'] = 20 * math.log10(s[k])
    r.update(Gpost_plateau_dB=20 * math.log10(s['Gpost_plateau']), fL=s['fL'], fH=s['fH'], CMRR60_on=s['CMRR60_on'], CMRR60_off=s['CMRR60_off'],
             CMRR60_on_dcc1pct_info=s['CMRR60_on_dcc1pct'], Zin10_P=s['Zin10_P'], Zin10_N=s['Zin10_N'], Zin_worst=min(s['Zin10_P'], s['Zin10_N']),
             P_total=s['P_total'], I_VDD=s['I_VDD'], I_fwd=s['I_forward_NEF'], C_designed_total=s['C_designed_total'], PM_stbm=s['PM_stbm'],
             UGF_main=None, PM_stbd=s['PM_stbd'], GM_stbm=s['GM_stbm'], out_DC=s['out_DC'])
    for k in ('M1_out_over_G10', 'M1_out_over_G100', 'M1_out_over_Gplateau', 'M2_native_in_V0ref', 'M3_post_deembedded'):
        for b in ('full', '0.1-250'): r['%s_%s_uV' % (k, b)] = s['noise_%s_uV_%s' % (k, b)]
    r['NEF_0.1-250_M1'] = s['NEF_0.1-250_M1']; r['NEF_full_M1'] = s['NEF_full_M1']
    # gates
    fails = []
    for k, lo, hi in GATES:
        v = r[k]
        if (lo is not None and v < lo) or (hi is not None and v > hi): fails.append(k)
    r['gate_fails'] = ' '.join(fails) or 'none'
    # noise groups in uV-equivalent at the input (sqrt(group out power)/G10), full and band
    g10 = s['Gpost_10Hz']
    src = list(csv.DictReader(open(os.path.join(d, 'f2v_noise_sources.csv'))))
    def grp(nm):
        if nm in ('XA.M1', 'XA.M2'): return 'input pair'
        if nm in ('XA.M3', 'XA.M4'): return 'mirror'
        if nm.startswith('XA.'): return 'OTA1 other'
        if nm in ('R4', 'R5', 'R6', 'R7', 'R8', 'R9', 'R1', 'R2', 'R3'): return 'fixture R'
        return 'rest'
    gs = {}
    for x in src:
        for b in ('full', '0.1-250'):
            gs.setdefault((grp(x['source']), b), [0.0, 0.0])
            gs[(grp(x['source']), b)][0] += float(x['out_V2_' + b])
            if x.get('flicker_V2_' + b): gs[(grp(x['source']), b)][1] += float(x['flicker_V2_' + b])
    for (gname, b), (pw, fl) in sorted(gs.items()):
        grows.append(dict(case=case, group=gname, band=b, out_power_V2=pw, input_eq_uV=1e6 * math.sqrt(pw) / g10, flicker_share=fl / pw if pw else 0))
        r['grp_%s_%s_uV' % (gname.replace(' ', '_'), b)] = 1e6 * math.sqrt(pw) / g10
    # OTA1 OP
    op = P.read(os.path.join(root, 's_' + case, 'psf', 'opinfo.info'))['sig']
    area = 0.0
    for dev in ('XA.M1', 'XA.M2', 'XA.M3', 'XA.M4', 'XA.MT', 'XA.MC', 'XA.MREF', 'X2.MCS', 'X2.MCL'):
        v = op[dev][0]
        o = dict(case=case, dev=dev, ids=v['ids'], gm=v['gm'], gm_over_id=abs(v['gm'] / v['ids']), vgs=v['vgs'], vds=v['vds'], vth=v['vth'], vdsat=v['vdsat'],
                 margin=abs(v['vds']) - abs(v['vdsat']), region=int(v['region']), cgg=v.get('cgg'), gds=v.get('gds'))
        oprows.append(o)
    nl = open(os.path.join(root, 's_' + case, 'input.scs')).read().replace('\\\n', ' ')
    import re
    ota = re.search(r'subckt (ece203_\w*ota\w*)(.*?)\nends', nl, re.S).group(2)
    for w, l in re.findall(r'pfet l=(\S+) w=(\S+)|nfet l=(\S+) w=(\S+)', ota) and []: pass
    for m in re.finditer(r'\s(\w+) \([^)]*\) [np]fet l=([\d.]+)u w=([\d.]+)u', ota):
        area += float(m.group(2)) * float(m.group(3))
    r['ota1_area_um2'] = area
    O = {o['dev']: o for o in oprows if o['case'] == case}
    r.update(M1_id=O['XA.M1']['ids'], M1_gmid=O['XA.M1']['gm_over_id'], M1_cgg_pF=1e12 * O['XA.M1']['cgg'], M3_gmid=O['XA.M3']['gm_over_id'],
             M2_margin=O['XA.M2']['margin'], M4_margin=O['XA.M4']['margin'], M1_margin=O['XA.M1']['margin'], MT_margin=O['XA.MT']['margin'],
             MT_id=O['XA.MT']['ids'], min_margin=min(o['margin'] for o in O.values()))
    rows.append(r)
keys = []
for r in rows:
    for k in r:
        if k not in keys: keys.append(k)
for fn, data in (('f2s_cases.csv', rows), ('f2s_groups.csv', grows), ('f2s_op.csv', oprows)):
    with open(os.path.join(HERE, fn), 'w') as fh:
        w = csv.DictWriter(fh, keys if fn == 'f2s_cases.csv' else list(data[0])); w.writeheader(); [w.writerow(x) for x in data]
say = out.append
say('%-4s %-40s %8s %8s %8s %8s | %7s %7s %7s | %6s %6s %6s %6s | %7s %7s %6s %6s %6s %5s %5s %6s %s' % (
    'case', 'sizes', 'M1/G10', 'M1/G100', 'M3band', 'M2band', 'pair', 'mirror', 'fixR', 'G10dB', 'fL', 'fH', 'CMRR', 'ZinMin', 'P_uW', 'PMm', 'PMd', 'area', 'M2mg', 'M4mg', 'Cgg', 'gates'))
for r in rows:
    say('%-4s %-40s %8.4f %8.4f %8.4f %8.4f | %7.4f %7.4f %7.4f | %6.3f %6.4f %6.1f %6.2f | %7.1f %7.4f %6.2f %6.2f %6.0f %5.3f %5.3f %6.2f %s' % (
        r['case'], r['sizes'], r['M1_out_over_G10_full_uV'], r['M1_out_over_G100_full_uV'], r['M3_post_deembedded_0.1-250_uV'], r['M2_native_in_V0ref_0.1-250_uV'],
        r['grp_input_pair_full_uV'], r['grp_mirror_full_uV'], r['grp_fixture_R_full_uV'], r['Gpost_10Hz_dB'], r['fL'], r['fH'], r['CMRR60_on'],
        r['Zin_worst'] / 1e6, r['P_total'] * 1e6, r['PM_stbm'], r['PM_stbd'], r['ota1_area_um2'], r['M2_margin'], r['M4_margin'], r['M1_cgg_pF'], r['gate_fails']))
open(os.path.join(HERE, 'f2s_compare.txt'), 'w').write('\n'.join(out) + '\n'); print('\n'.join(out))
