"""Figures for the F2 final validation scout (run after f2v_nominal.py and f2v_mc.py in this folder)."""
import csv, math
import numpy as np, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
B, O, A, INK, GRID, MUTED = '#2a78d6', '#eb6834', '#1baf7a', '#3a3a38', '#e4e3de', '#9a9992'
plt.rcParams.update({'font.size': 9, 'axes.edgecolor': GRID, 'axes.labelcolor': INK, 'xtick.color': INK, 'ytick.color': INK, 'axes.grid': True,
                     'grid.color': GRID, 'grid.linewidth': 0.6, 'axes.spines.top': False, 'axes.spines.right': False, 'lines.linewidth': 1.6, 'legend.frameon': False})
rd = lambda f: list(csv.DictReader(open(f)))
nz = rd('f2v_noise_psd.csv'); f = np.array([float(r['freq_Hz']) for r in nz])
col = lambda k: np.array([float(r[k]) for r in nz])
summ = {r['quantity']: float(r['value']) for r in rd('f2v_nominal_summary.csv')}
G10 = summ['Gpost_10Hz']
fig, ax = plt.subplots(3, 1, figsize=(7.5, 9), sharex=True)
ax[0].loglog(f, col('out_asd_V_rtHz') * 1e9, color=B); ax[0].set_ylabel('output ASD at out [nV/√Hz]')
ax[0].set_title('Nominal F2 in instructor ECG_tb, TT 27 °C, DRL on, interference off (Spectre noise 1 mHz–100 kHz, 50 pts/dec)', fontsize=9, color=INK)
ax[1].loglog(f, col('in_V0ref_asd_V_rtHz') * 1e9, color=O, label='Spectre native "in" (referred to V0 = source, incl. 2/3 body divider)')
ax[1].loglog(f, col('in_post_asd_V_rtHz') * 1e9, color=B, label='post-electrode, pointwise S_out/|Hpost(f)|²')
ax[1].loglog(f, col('out_asd_V_rtHz') / G10 * 1e9, color=A, label='S_out / G10² (course method: constant midband gain)')
ax[1].set_ylabel('input-referred ASD [nV/√Hz]'); ax[1].legend(fontsize=7.5, loc='upper center')
ax[1].set_ylim(1, 1e5)
for a in ax: a.axvspan(0.1, 250, color='#cde2fb', lw=0, zorder=0)
cum = col('cum_out_rms_from_1mHz_V') / G10 * 1e6
ax[2].semilogx(f, cum, color=A); ax[2].axhline(3.0, color=INK, lw=1, ls=(0, (4, 3)))
ax[2].text(1.5e-3, 3.03, '3 µVrms spec', fontsize=8, color=INK)
ax[2].set_ylabel('cumulative √∫S_out df / G10 [µVrms]\n(from 1 mHz)'); ax[2].set_xlabel('frequency [Hz] (shaded: 0.1–250 Hz)')
ax[2].text(1e5, cum[-1] - 0.25, '%.3f µV at 100 kHz' % cum[-1], ha='right', fontsize=8, color=INK)
fig.tight_layout(); fig.savefig('fig_f2v_noise.png', dpi=150); plt.close(fig)
g = rd('f2v_gain_curve.csv'); fg = np.array([float(r['freq_Hz']) for r in g])
fig, ax = plt.subplots(2, 1, figsize=(7.5, 5.5), sharex=True)
ax[0].semilogx(fg, 20 * np.log10([float(r['Hpost_mag']) for r in g]), color=B, label='Gpost = out/(vRight−vLeft)')
ax[0].semilogx(fg, 20 * np.log10([float(r['Hsrc_mag']) for r in g]), color=O, label='Gsrc = out/V0')
ax[0].axhspan(38, 42, color='#cde2fb', lw=0, zorder=0); ax[0].set_ylim(0, 45); ax[0].set_ylabel('gain [dB]'); ax[0].legend(fontsize=8)
ax[0].set_title('Nominal DM gain (shaded 38–42 dB); fL %.4f Hz, fH %.1f Hz from the Gpost plateau' % (summ['fL'], summ['fH']), fontsize=9, color=INK)
ax[1].semilogx(fg, [1 / float(r['post_over_src_mag']) for r in g], color=A); ax[1].set_ylabel('|(vRight−vLeft)/V0|'); ax[1].set_xlabel('frequency [Hz]')
fig.tight_layout(); fig.savefig('fig_f2v_gain.png', dpi=150); plt.close(fig)
mc = [r for r in rd('f2v_mc_n100_samples.csv') if r['status'] == 'ok']
panels = [('Gpost_10_dB', 'gain @10 Hz [dB]', 38, 42), ('fL', 'fL [Hz]', 0.09, 0.11), ('fH', 'fH [Hz]', 225, 275),
          ('nz_M1_G10_full_uV', 'noise 1 mHz–100 kHz, out/G10 [µV]', None, 3.0), ('nz_M1_G10_band_uV', 'noise 0.1–250 Hz, out/G10 [µV]', None, 3.0),
          ('CMRR_on_dB', 'CMRR60 DRL on (course) [dB]', 85, None), ('P_total_uW', 'total power [µW]', None, 4.0), ('PM_main', 'main-loop PM [deg] (no spec)', None, None)]
fig, ax = plt.subplots(4, 2, figsize=(8, 10)); ax = ax.ravel()
for a, (k, nm, lo, hi) in zip(ax, panels):
    v = np.array([float(r[k]) for r in mc])
    a.hist(v, bins=20, color=B, edgecolor='white', linewidth=0.8)
    for lim in (lo, hi):
        if lim is not None and v.min() - 3 * v.std() <= lim <= v.max() + 3 * v.std(): a.axvline(lim, color=O, lw=1.5)
    npass = sum((lo is None or x >= lo) and (hi is None or x <= hi) for x in v)
    a.set_title('%s\nmean %.4g, σ %.3g, min %.4g, max %.4g%s' % (nm, v.mean(), v.std(ddof=1), v.min(), v.max(),
                ', pass %d/%d' % (npass, len(v)) if (lo is not None or hi is not None) else ''), fontsize=8, color=INK)
    a.set_ylabel('samples')
fig.suptitle('Mismatch MC, N = 100 valid / 100 attempted, seed 12345, TT 27 °C (orange: spec limit, when inside the range shown)', fontsize=9, color=INK)
fig.tight_layout(); fig.savefig('fig_f2v_mc_hist.png', dpi=150); plt.close(fig)
print('figs ok')
