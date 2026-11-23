#!/usr/bin/env python3
"""R7E Stage C analysis = the R7D metrics (r7d_analysis: R7A windows 20-40 / 40-60 ms, pseudo-R and bias terms) plus the
filtered output:
- Hout = (outp - outn) / vid with the same least-squares fit (DC + drift + 100/200/300 Hz) -> gain, phase, H2, H3, residual RMS,
  per-TG-edge DM error max/mean (same edge_settle definition as Hpre/Hbuf), and Hout/Hbuf (complex, 100 Hz).
- out CM (outp+outn)/2: average, 100/200 Hz components, pp, TG-edge glitch (same glitch definition as op/on CM).
- clock spurs: FFT of each 20 ms window (1 us resampling, rectangular, the window holds exactly 40 periods of 2 kHz and 2 of 100 Hz,
  so all of them fall on bins): largest single-sided bin within +-500 Hz of 2/4/6 kHz and the RMS of every bin >= 1 kHz, for buf DM and out DM.
Usage: python3 r7e_analysis.py OUT.csv STAGE_A_IV.csv tag=tran.csv.gz [tag=...]"""
import sys, os, csv, math, cmath
import numpy as np
here = os.path.dirname(os.path.abspath(__file__))
for d in ('round7d', 'round7c', 'round7a'): sys.path.insert(0, os.path.join(here, '..', d))
from r7a_sys_analysis import load, analyse, fit, amp, edge_settle, glitch
from r7c_analysis import iv, extra
from r7d_analysis import bias

def spur(tt, y):
    n = len(y); Y = np.fft.rfft(y) / n * 2; f = np.fft.rfftfreq(n, tt[1] - tt[0]); a = np.abs(Y)
    pick = lambda f0: a[(f >= f0 - 500.0) & (f <= f0 + 500.0)].max()   # largest bin within +-500 Hz (the edge error is modulated by the 100 Hz signal: sidebands at k*4 kHz +- 100 Hz)
    hf = f >= 1000.0
    return pick(2000.0), pick(4000.0), pick(6000.0), math.sqrt(np.sum(a[hf] ** 2) / 2)

def outmetrics(fn):
    d = load(fn); t = d['t_s']; rows = []
    if 'outp_V' not in d:   # reference without the LP: buf-side spurs only
        for w0, w1 in ((0.020, 0.040), (0.040, 0.060)):
            tt = np.arange(w0, w1, 1e-6); s2, s4, s6, hf = spur(tt, np.interp(tt, t, d['bufp_V'] - d['bufn_V']))
            rows.append({'buf_dm_2k_uV': s2 * 1e6, 'buf_dm_4k_uV': s4 * 1e6, 'buf_dm_6k_uV': s6 * 1e6, 'buf_dm_ge1k_rms_uV': hf * 1e6})
        return rows
    vout = d['outp_V'] - d['outn_V']; vbuf = d['bufp_V'] - d['bufn_V']; cm = (d['outp_V'] + d['outn_V']) / 2
    for w0, w1 in ((0.020, 0.040), (0.040, 0.060)):
        tt = np.arange(w0, w1, 1e-6); R = lambda a: np.interp(tt, t, a); m = {}
        cin, _ = fit(tt, R(d['vid_V']), harm=(1,)); ain = amp(cin, 1)
        y = R(vout); c, f = fit(tt, y); g = amp(c, 1) / ain; res = y - f
        cb, _ = fit(tt, R(vbuf)); gb = amp(cb, 1) / ain
        m['Hout_gain'] = abs(g); m['Hout_phase_deg'] = math.degrees(cmath.phase(g))
        m['Hout_H2_dBc'] = 20 * math.log10(abs(amp(c, 2)) / abs(amp(c, 1))); m['Hout_H3_dBc'] = 20 * math.log10(abs(amp(c, 3)) / abs(amp(c, 1)))
        m['Hout_resid_rms_uV'] = float(np.sqrt(np.mean(res ** 2))) * 1e6
        m['Hout_over_Hbuf'] = abs(g / gb); m['Hout_over_Hbuf_phase_deg'] = math.degrees(cmath.phase(g / gb))
        sel = (t >= w0) & (t <= w1); tn = t[sel]
        fn_ = c[0] + c[1] * tn + sum(c[2 * k] * np.sin(2 * np.pi * k * 100 * tn) + c[2 * k + 1] * np.cos(2 * np.pi * k * 100 * tn) for k in (1, 2, 3))
        pk, pm, tsx, tsm = edge_settle(tn, vout[sel] - fn_, abs(amp(c, 1)), w0, w1)
        m['Hout_edge_err_max_mV'] = pk * 1e3; m['Hout_edge_err_mean_mV'] = pm * 1e3; m['Hout_settle1pct_max_us'] = tsx * 1e6
        yc = R(cm); cc, _ = fit(tt, yc, harm=(1, 2))
        m['out_cm_avg_V'] = float(yc.mean()); m['out_cm_100Hz_uV'] = abs(amp(cc, 1)) * 1e6; m['out_cm_200Hz_uV'] = abs(amp(cc, 2)) * 1e6
        m['out_cm_pp_mV'] = float(cm[sel].max() - cm[sel].min()) * 1e3
        gp, gn, gr, _ = glitch(tn, cm[sel], w0, w1); m['out_cm_edge_pos_mV'] = gp * 1e3; m['out_cm_edge_neg_mV'] = gn * 1e3
        for lab, a in (('buf', vbuf), ('out', vout)):
            s2, s4, s6, hf = spur(tt, R(a))
            m[lab + '_dm_2k_uV'] = s2 * 1e6; m[lab + '_dm_4k_uV'] = s4 * 1e6; m[lab + '_dm_6k_uV'] = s6 * 1e6; m[lab + '_dm_ge1k_rms_uV'] = hf * 1e6
        for k in ('outp_V', 'outn_V'):
            m[k[:-2] + '_min_V'] = float(d[k][sel].min()); m[k[:-2] + '_max_V'] = float(d[k][sel].max())
        rows.append(m)
    return rows

if __name__ == '__main__':
    ivv, ivi = iv(sys.argv[2]); rows = []
    for a in sys.argv[3:]:
        tag, fn = a.split('=', 1); base = analyse(tag, fn); ex = extra(tag, fn, ivv, ivi); bi = bias(fn); om = outmetrics(fn)
        for b, e, c, o in zip(base, ex, bi, om):
            b.update(e); b.update(c); b.update(o); rows.append(b)
    keys = []; [keys.append(k) for r in rows for k in r if k not in keys]
    with open(sys.argv[1], 'w', newline='') as f:
        w = csv.DictWriter(f, keys, restval='n/a', lineterminator='\n'); w.writeheader()
        for r in rows:
            w.writerow({k: ('%.6g' % v if isinstance(v, float) else v) for k, v in r.items()})
    for r in rows:
        print(r['case'], r['window_ms'], 'Hpre %.5g Hbuf %.5g ph %.3f | edge pre %.2f buf %.2f mV resid pre %.0f buf %.0f uV | opon cm %.6f 200Hz %.2f uV | P %.4g uW'
              % (r['Hpre_gain'], r['Hbuf_gain'], r['Hbuf_phase_deg'], r['Hpre_edge_err_max_mV'], r['Hbuf_edge_err_max_mV'], r['Hpre_resid_rms_uV'], r['Hbuf_resid_rms_uV'],
                 r['opon_cm_avg_V'], r['opon_cm_200Hz_uV'], r.get('P_total_uW', float('nan'))))
        if 'Hout_gain' in r:
            print('   OUT: Hout %.5g (%.3f dB) ph %.3f H2 %.1f H3 %.1f resid %.0f uV edge max %.3f mean %.3f mV | Hout/Hbuf %.5f ph %.3f | out cm %.6f 200Hz %.2f uV edge %+.3f/%.3f | 2k spur buf %.1f out %.1f uV, >=1k rms buf %.1f out %.1f uV'
                  % (r['Hout_gain'], 20 * math.log10(r['Hout_gain']), r['Hout_phase_deg'], r['Hout_H2_dBc'], r['Hout_H3_dBc'], r['Hout_resid_rms_uV'], r['Hout_edge_err_max_mV'],
                     r['Hout_edge_err_mean_mV'], r['Hout_over_Hbuf'], r['Hout_over_Hbuf_phase_deg'], r['out_cm_avg_V'], r['out_cm_200Hz_uV'], r['out_cm_edge_pos_mV'],
                     r['out_cm_edge_neg_mV'], r['buf_dm_2k_uV'], r['out_dm_2k_uV'], r['buf_dm_ge1k_rms_uV'], r['out_dm_ge1k_rms_uV']))
