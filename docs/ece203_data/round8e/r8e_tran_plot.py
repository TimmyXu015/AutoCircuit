"""R8E Stage D figure: R7F G0 (60p/0.5p) vs R8E B35 (210p/1.75p) 60 ms 2 kHz chopped tran, 1 mV 100 Hz DM input.
Left: output DM 40-60 ms. Right: output DM minus its 100/200/300 Hz least-squares fit (deterministic chopper residual, not noise), 40-45 ms."""
import sys, os, numpy as np
sys.path.insert(0, '../round7a'); from r7a_sys_analysis import load, fit
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
runs = [('R7F G0 (60p/0.5p)', '../round7f/raw/stageC/T_gain_g0_load10p_tran.csv.gz', '#7a7a7a'), ('R8E B35 (210p/1.75p)', 'raw/c35/T_c35_tran.csv.gz', '#d45500')]
fig, ax = plt.subplots(1, 2, figsize=(14, 4.2))
for lab, fn, col in runs:
    d = load(fn); t = d['t_s']; v = d['outp_V'] - d['outn_V']
    s = (t >= 0.04) & (t <= 0.06); ax[0].plot(1e3 * t[s], 1e3 * v[s], color=col, lw=1.2, label=lab)
    tt = np.arange(0.04, 0.06, 1e-6); y = np.interp(tt, t, v); c, f = fit(tt, y); r = y - f
    w = tt <= 0.045; ax[1].plot(1e3 * tt[w], 1e6 * r[w], color=col, lw=0.8, label='%s residual rms %.0f uV' % (lab, 1e6 * np.sqrt(np.mean(r ** 2))))
ax[0].set_xlabel('t (ms)'); ax[0].set_ylabel('outp-outn (mV)'); ax[0].set_title('chopped 2 kHz, 1 mV 100 Hz input', fontsize=10); ax[0].legend(frameon=False, fontsize=8)
ax[1].set_xlabel('t (ms)'); ax[1].set_ylabel('uV'); ax[1].set_title('output minus 100/200/300 Hz fit (deterministic residual, not noise)', fontsize=10); ax[1].legend(frameon=False, fontsize=8)
for a in ax: a.spines[['top', 'right']].set_visible(False); a.grid(True, color='#e6e6e6', lw=0.6)
fig.tight_layout(); fig.savefig('r8e_tran.png', dpi=120)
