"""R8 shared spectrum loader: output PSD from <base>_noise.csv / _pnoise.csv (column Sout_V_rtHz; the SKILL-written
deemb column is NOT used: OCEAN wrote it on a different x grid) and |H(f)| from the matching transfer file
(<base>_ac.csv column abs_Hoff for OFF, <pnoise base>_pac.csv column abs_Hon for ON), log-log interpolated onto the noise grid."""
import os
import numpy as np
trapz = getattr(np, 'trapezoid', None) or getattr(np, 'trapz')
def load(base):
    off = os.path.exists(base + '_noise.csv')
    d = np.genfromtxt(base + ('_noise.csv' if off else '_pnoise.csv'), delimiter=',', names=True)
    h = np.genfromtxt(base + ('_ac.csv' if off else '_pac.csv'), delimiter=',', names=True)
    hk = 'abs_Hoff' if off else 'abs_Hon'
    f = d['f_Hz']; so = d['Sout_V_rtHz']
    H = np.exp(np.interp(np.log(f), np.log(h['f_Hz']), np.log(h[hk])))
    H100 = float(np.exp(np.interp(np.log(100.0), np.log(h['f_Hz']), np.log(h[hk]))))
    return f, so, H, H100
def rms(f, s, a=0.1, b=250.0):
    m = (f >= a * (1 - 1e-9)) & (f <= b * (1 + 1e-9)); return float(np.sqrt(trapz(s[m] ** 2, f[m])))
