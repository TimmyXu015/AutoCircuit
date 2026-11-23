#!/usr/bin/env python3
"""R7F LP loading model used for the registered L1 correction (and checked afterwards against the measured L1 corners).
Hout(f) = Hbuf_R7D(f) * T(f): the measured R7D buffered response (CD driving only CLB 10 pF) times the extra divider of a CD Thevenin
source resistance Ro -> buf node (CLB 10 pF) -> RLP -> CLP (+ Cl). Ro is the single fitted parameter.
fH_flat = falling -3 dB relative to |Hout(10 Hz)| (same as r7eLp).  Usage: python3 r7f_lp_model.py"""
import os
import numpy as np
here = os.path.dirname(os.path.abspath(__file__))
d0 = np.genfromtxt(os.path.join(here, '..', 'round7d', 'raw', 'stageB', 'B_bias_a0_dm_ac.csv'), delimiter=',', names=True)
f = d0['f_Hz']; Hb = d0['abs_Hbuf'] * np.exp(1j * np.radians(d0['ph_Hbuf']))
def T(R, C, Cl, Ro, Clb=10e-12):
    w = 2j * np.pi * f; Zrc = R + 1 / (w * (C + Cl)); Zb = 1 / (w * Clb); Zl = 1 / (1 / Zrc + 1 / Zb)
    return (Zl / (Zl + Ro)) / (Zb / (Zb + Ro)) * (1 / (w * (C + Cl))) / Zrc
def fh(H):
    m = np.abs(H); ref = m[np.argmin(abs(f - 10))]; db = 20 * np.log10(m / ref); i = np.where((f > 10) & (db <= -3))[0][0]
    return 10 ** np.interp(-3, [db[i], db[i - 1]], [np.log10(f[i]), np.log10(f[i - 1])])
meas = [(31.8e6, 20e-12, 0, 247.56), (31.8e6, 20e-12, 10e-12, 165.47), (4.77e6, 133e-12, 0, 236.30), (4.77e6, 133e-12, 10e-12, 219.87)]
ros = np.arange(0.20e6, 0.36e6, 0.002e6)
err = [sum((fh(Hb * T(R, C, Cl, ro)) - m) ** 2 for R, C, Cl, m in meas) for ro in ros]; Ro = ros[int(np.argmin(err))]
print('fitted Ro = %.3f MOhm' % (Ro / 1e6))
for R, C, Cl, m in meas: print('  R %5.2fM C %4.0fp Cl %2.0fp: model %.2f Hz, measured %.2f Hz' % (R / 1e6, C * 1e12, Cl * 1e12, fh(Hb * T(R, C, Cl, Ro)), m))
tau = 4.77e6 * 133e-12
best = max((fh(Hb * T(tau / C, C, 10e-12, Ro)), C) for C in np.arange(60e-12, 400e-12, 2e-12))
print('R*C fixed at %.4f ms: best loaded fH %.2f Hz (C %.0f pF)' % (tau * 1e3, best[0], best[1] * 1e12))
for R, C in ((4.0e6, 148e-12),):
    for ro in (Ro - 0.05e6, Ro, Ro + 0.05e6):
        print('L1 R %.2fM C %.0fp (R C %.3f ms, (R+Ro) C %.3f ms) Ro %.3fM: unloaded %.1f Hz, +10 pF %.1f Hz' % (R / 1e6, C * 1e12, R * C * 1e3, (R + ro) * C * 1e3, ro / 1e6, fh(Hb * T(R, C, 0, ro)), fh(Hb * T(R, C, 10e-12, ro))))
