#!/usr/bin/env python3
"""Compact the psfascii output of an f2v Monte Carlo run on the server (python3.6, stdlib only).
Usage: f2v_extract.py <psf dir> <out dir>. Writes per-iteration CSVs (mc_dc.csv, mc_acx.csv, mc_acm.csv.gz, mc_nz.csv.gz, mc_stb.csv)."""
import sys, os, re, gzip, glob
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', 'ece203_data', 'f2_final_scout'))
import f2v_psf as P
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
its = sorted({re.match(r'mc1-(\d+)_', os.path.basename(f)).group(1) for f in glob.glob(src + '/mc1-*_dcop.dc')})
DCN = ['out', 'o', 'oa', 'oa1', 'p', 'n', 'inp', 'inn', 'vRight', 'vLeft', 'net5', 'cm', 'drlr', 'vref', 'ib', 'ibd', 'pref',
       'VDD:p', 'VDDD:p', 'MP2:d', 'MP1:d', 'MP0:d', 'XA.MT:d', 'XD.MT:d']
ACN = ['out', 'vRight', 'vLeft', 'inp', 'inn', 'net1', 'net013', 'net5', 'VPP:p', 'VPN:p']
def cs(z): return '%.9g,%.9g' % (z.real, z.imag)
with open(dst + '/mc_dc.csv', 'w') as fdc, open(dst + '/mc_acx.csv', 'w') as fx, gzip.open(dst + '/mc_acm.csv.gz', 'wt') as fa, \
        gzip.open(dst + '/mc_nz.csv.gz', 'wt') as fn, open(dst + '/mc_stb.csv', 'w') as fs:
    fdc.write('iter,analysis,' + ','.join(DCN) + '\n')
    fx.write('iter,mode,freq,' + ','.join('%s_re,%s_im' % (n, n) for n in ACN) + '\n')
    fa.write('iter,mode,freq,' + ','.join('%s_re,%s_im' % (n, n) for n in ACN[:3]) + '\n')
    fn.write('iter,freq,out_asd,in_asd,gain\n')
    fs.write('iter,loop,gainMargin_dB,gainMarginFreq_Hz,phaseMargin_deg,phaseMarginFreq_Hz\n')
    for it in its:
        b = '%s/mc1-%s_' % (src, it)
        for ana in ['dcop'] + ['swm-%03d_dcm' % m for m in range(3)]:
            fnm = b + ana + '.dc'
            if not os.path.exists(fnm): continue
            d = P.read(fnm)['sig']
            fdc.write('%s,%s,' % (it, ana) + ','.join('%.12g' % d[k][0] if k in d else '' for k in DCN) + '\n')
        for m in range(3):
            fnm = b + 'swm-%03d_acx.ac' % m
            if os.path.exists(fnm):
                a = P.read(fnm)
                for k, f in enumerate(a['x']):
                    fx.write('%s,%d,%g,' % (it, m, f) + ','.join(cs(a['sig'][n][k]) for n in ACN) + '\n')
            fnm = b + 'swm-%03d_acm.ac' % m
            if os.path.exists(fnm):
                a = P.read(fnm)
                for k, f in enumerate(a['x']):
                    fa.write('%s,%d,%.9g,' % (it, m, f) + ','.join(cs(a['sig'][n][k]) for n in ACN[:3]) + '\n')
        if os.path.exists(b + 'nz.noise'):
            z = P.read(b + 'nz.noise')
            for k, f in enumerate(z['x']):
                fn.write('%s,%.9g,%.9g,%.9g,%.9g\n' % (it, f, z['sig']['out'][k], z['sig']['in'][k], z['sig']['gain'][k]))
        for loop in ('stbm', 'stbd'):
            fnm = b + loop + '.margin.stb'
            if os.path.exists(fnm):
                s = P.read(fnm)['sig']
                fs.write('%s,%s,' % (it, loop) + ','.join('%.9g' % s[k][0] if k in s else '' for k in ('gainMargin', 'gainMarginFreq', 'phaseMargin', 'phaseMarginFreq')) + '\n')
print('extracted', len(its), 'iterations ->', dst)
