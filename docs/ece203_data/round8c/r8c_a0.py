"""R8C Stage A0: zero-cost recomputation of fL_flat from the archived R8B data (read-only).
Inputs: ../round8b/raw/gateA/A_off_ac.csv (static AC, chopper OFF, 1 mHz-100 kHz),
        ../round8b/raw/gateC/B_pac_pac.csv (PAC sideband 0, chopper ON, 0.1-250 Hz),
        ../round8b/raw/gateC/B_pac_netlist.scs (definition checks).
Outputs: r8c_a0_fl.csv, r8c_a0_checks.txt, r8c_a0.png"""
import math, re, os
from r8c_lib import read, fl_flat, interp
R = '../round8b/raw'
off = read(f'{R}/gateA/A_off_ac.csv'); on = read(f'{R}/gateC/B_pac_pac.csv')
fo = [r['f_Hz'] for r in off]; mo = [r['abs_Hoff'] for r in off]; po = [r['ph_Hoff'] for r in off]
fn = [r['f_Hz'] for r in on]; mn = [r['abs_Hon'] for r in on]; pn = [r['ph_Hon'] for r in on]
rows = []
for name, f, m in (('OFF static AC (R8B gate A)', fo, mo), ('ON PAC sb0 (R8B gate C)', fn, mn)):
    for how in ('mean', 'max'):
        fl, P = fl_flat(f, m, how)
        rows.append((name, how, P, fl))
with open('r8c_a0_fl.csv', 'w') as fh:
    fh.write('case,plateau_def,plateau_VV,fL_flat_Hz\n')
    for r in rows: fh.write('%s,%s,%.6g,%s\n' % (r[0], r[1], r[2], '%.6g' % r[3] if r[3] else 'none'))
    fh.write('\nf_Hz,absHoff,absHon,Hon_over_Hoff,phHoff_deg,phHon_deg\n')
    for f, m, p in zip(fn, mn, pn):
        a = interp(fo, mo, f); b = interp(fo, po, f)
        fh.write('%.6g,%.6g,%.6g,%.6g,%.6g,%.6g\n' % (f, a, m, m / a, b, p))
for r in rows: print('%-28s %-4s plateau %.4f  fL %s' % (r[0], r[1], r[2], r[3]))
# definition checks from the archived PAC netlist
net = open(f'{R}/gateC/B_pac_netlist.scs').read().replace('\\\n', ' ')
chk = []
def c(ok, msg): chk.append(('PASS' if ok else 'FAIL') + '  ' + msg)
c(re.search(r'^pac\s+pac\s+sweeptype=relative\s+relharmnum=0', net, re.M) is not None, 'PAC sweeptype=relative relharmnum=0 (sideband 0 = baseband input)')
for ck in ('VCKBB', 'VCKB', 'VCKAB', 'VCKA'):
    m = re.search(r'^%s \(.*?\) vsource (.*?)(?=^\S)' % ck, net, re.M | re.S)
    c(m is not None and 'pacmag=0' in m.group(1), f'{ck} pacmag=0 (clock carries no PAC stimulus)')
mp = re.search(r'^VSP \(ep0 body\) vsource (.*?)(?=^\S)', net, re.M | re.S).group(1)
mn_ = re.search(r'^VSN \(en0 body\) vsource (.*?)(?=^\S)', net, re.M | re.S).group(1)
c('pacmag=pacd' in mp and 'pacphase=0' in mp, 'VSP pacmag=pacd pacphase=0')
c('pacmag=pacd' in mn_ and 'pacphase=180' in mn_, 'VSN pacmag=pacd pacphase=180')
c(re.search(r'\bpacd=1(\.0)?\b', net) is not None, 'pacd=1 -> ep-en = 2 V nominal')
vd = [r['abs_vd_pac'] for r in on]; c(all(abs(x - 2) < 1e-9 for x in vd), 'measured |V(ep)-V(en)| sideband 0 = 2.000 V at all %d points (transfer divides by the measured value)' % len(vd))
c(all(abs(r['ph_vd_pac']) < 1e-6 for r in on), 'measured phase of V(ep)-V(en) = 0 deg')
sv = re.search(r'^save (.*?)(?=^\S)', net, re.M | re.S).group(1).split()
c('outp' in sv and 'outn' in sv, 'outp and outn saved; transfer = (outp-outn)/(ep-en) (ece203_r8_noise.il r8Periodic)')
c('readpss="/tmp/lix015_r8b/pss_converged.pss"' in net, 'PAC run reads the converged PSS')
conv = open(f'{R}/gateC/B_pac_convergence_lines.txt').read()
c('achieved in 1 shooting-Newton' in conv, 'PSS re-check in the PAC run: "achieved in 1 shooting-Newton iterations"')
open('r8c_a0_checks.txt', 'w').write('\n'.join(chk) + '\n')
print('\n'.join(chk))
# plot
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
fig, ax = plt.subplots(1, 3, figsize=(15, 4.2))
off_c, on_c = '#7a7a7a', '#d45500'
for a in ax: a.grid(True, which='both', color='#e6e6e6', lw=0.6); a.set_xscale('log'); a.set_xlim(0.01, 300); a.spines[['top', 'right']].set_visible(False)
ax[0].loglog(fo, mo, color=off_c, lw=2, label='OFF static AC'); ax[0].loglog(fn, mn, color=on_c, lw=2, label='ON PAC sideband 0')
for name, how, P, fl in rows:
    if how == 'mean' and fl:
        col = off_c if name.startswith('OFF') else on_c
        ax[0].axhline(P / math.sqrt(2), color=col, lw=0.8, ls=':'); ax[0].axvline(fl, color=col, lw=0.8, ls='--')
        ax[0].annotate('fL %.3f Hz' % fl, (fl, P / math.sqrt(2)), textcoords='offset points', xytext=(4, -14), color='#333', fontsize=9)
ax[0].set_title('|H| (outp-outn)/(ep-en)'); ax[0].set_xlabel('f (Hz)'); ax[0].set_ylabel('V/V'); ax[0].legend(frameon=False)
ax[1].semilogx(fo, po, color=off_c, lw=2, label='OFF'); ax[1].semilogx(fn, pn, color=on_c, lw=2, label='ON'); ax[1].set_title('phase'); ax[1].set_xlabel('f (Hz)'); ax[1].set_ylabel('deg'); ax[1].legend(frameon=False)
ratio = [m / interp(fo, mo, f) for f, m in zip(fn, mn)]
ax[2].semilogx(fn, ratio, color='#333', lw=2); ax[2].set_ylim(0, 1.1); ax[2].set_title('|Hon| / |Hoff|'); ax[2].set_xlabel('f (Hz)')
fig.suptitle('R8C A0 - recomputed from archived R8B data (no new simulation)', fontsize=11); fig.tight_layout(); fig.savefig('r8c_a0.png', dpi=130)
