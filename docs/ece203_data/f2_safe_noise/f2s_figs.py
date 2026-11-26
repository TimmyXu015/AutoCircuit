"""F2S figures (run after f2s_compare.py and, for the MC figure, f2v_mc.py with tag w100 in this folder)."""
import csv, os, math
import numpy as np, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
HERE = os.path.dirname(os.path.abspath(__file__))
B, O, A, Y, INK, GRID = '#2a78d6', '#eb6834', '#1baf7a', '#e8a33d', '#3a3a38', '#e4e3de'
plt.rcParams.update({'font.size': 9, 'axes.edgecolor': GRID, 'axes.labelcolor': INK, 'xtick.color': INK, 'ytick.color': INK, 'axes.grid': True,
                     'grid.color': GRID, 'grid.linewidth': 0.6, 'axes.spines.top': False, 'axes.spines.right': False, 'lines.linewidth': 1.6, 'legend.frameon': False})
rd = lambda f: list(csv.DictReader(open(os.path.join(HERE, f))))
rows = rd('f2s_cases.csv'); names = [r['case'] for r in rows]; x = np.arange(len(rows))
f = lambda k: np.array([float(r[k]) for r in rows])
fig, ax = plt.subplots(3, 1, figsize=(8.5, 9), sharex=True)
w = 0.38
a = ax[0]; a.bar(x - w / 2 - 0.01, f('M1_out_over_G10_full_uV'), w, color=B, label='M1 full band / Gpost(10 Hz)')
a.bar(x + w / 2 + 0.01, f('M1_out_over_G100_full_uV'), w, color=O, label='M1 full band / Gpost(100 Hz) (guard)')
for v, ls, t in ((3.0, (0, (4, 3)), '3 µV spec'), (2.6, (0, (1, 2)), '2.6 µV target')):
    a.axhline(v, color=INK, lw=1, ls=ls); a.text(-0.55, v + 0.015, t, fontsize=8, color=INK, ha='left')
for i in range(len(rows)): a.text(i - w / 2, f('M1_out_over_G10_full_uV')[i] + 0.02, '%.3f' % f('M1_out_over_G10_full_uV')[i], ha='center', fontsize=7, color=INK, rotation=90)
a.set_ylim(2.3, 3.45); a.set_ylabel('input-referred noise [µVrms]'); a.legend(fontsize=8, loc='upper right', ncol=2)
a.set_title('F2S nominal configurations (TT 27 °C, instructor ECG_tb, 1 mHz–100 kHz)', fontsize=10, color=INK)
a = ax[1]
for k, c, lab in (('grp_input_pair_full_uV', B, 'input pair M1/M2'), ('grp_mirror_full_uV', O, 'mirror M3/M4'), ('grp_fixture_R_full_uV', A, 'fixture R (electrodes + body)')):
    a.plot(x, f(k), 'o-', color=c, label=lab, ms=6)
a.set_ylabel('group noise, √P_group / G10 [µVrms]'); a.legend(fontsize=8, ncol=3, loc='upper center', bbox_to_anchor=(0.5, 1.12))
a = ax[2]; a.plot(x, f('CMRR60_on'), 'o-', color=B, label='CMRR60 DRL on [dB] (left)', ms=6); a.axhline(85, color=INK, lw=1, ls=(0, (4, 3)))
a.set_ylabel('CMRR60 on [dB]'); a.set_ylim(84.5, 88)
a2 = a.twinx(); a2.plot(x, f('PM_stbm'), 's--', color=O, label='main-loop PM [deg] (right)', ms=5); a2.set_ylabel('main-loop PM [deg]', color=O); a2.spines['right'].set_visible(True)
a2.set_ylim(55, 80); a.legend(loc='lower left', fontsize=8); a2.legend(loc='lower right', fontsize=8)
a.set_xticks(x, names)
fig.tight_layout(); fig.savefig(os.path.join(HERE, 'fig_f2s_cases.png'), dpi=150); plt.close(fig)
# winner vs baseline: output ASD and cumulative M1
fig, ax = plt.subplots(2, 1, figsize=(7.5, 6.5), sharex=True)
for case, c in (('B0', B), ('P2', A), ('P2S60', O)):
    p = os.path.join(HERE, 'cases', case, 'f2v_noise_psd.csv')
    if not os.path.exists(p): continue
    z = list(csv.DictReader(open(p))); fz = np.array([float(r['freq_Hz']) for r in z])
    g10 = [float(r['value']) for r in csv.DictReader(open(os.path.join(HERE, 'cases', case, 'f2v_nominal_summary.csv'))) if r['quantity'] == 'Gpost_10Hz'][0]
    ax[0].loglog(fz, [float(r['out_asd_V_rtHz']) * 1e9 for r in z], color=c, label=case)
    ax[1].semilogx(fz, [float(r['cum_out_rms_from_1mHz_V']) / g10 * 1e6 for r in z], color=c, label=case)
ax[0].set_ylabel('output ASD [nV/√Hz]'); ax[0].legend(fontsize=8); ax[0].set_title('Baseline F2 (B0) vs mirror-only P2 vs winner P2S60', fontsize=10, color=INK)
ax[1].axhline(3.0, color=INK, lw=1, ls=(0, (4, 3))); ax[1].axhline(2.6, color=INK, lw=1, ls=(0, (1, 2)))
ax[1].set_ylabel('cumulative √∫S_out df / G10 [µVrms]'); ax[1].set_xlabel('frequency [Hz]'); ax[1].legend(fontsize=8)
for a in ax: a.axvspan(0.1, 250, color='#cde2fb', lw=0, zorder=0)
fig.tight_layout(); fig.savefig(os.path.join(HERE, 'fig_f2s_winner_noise.png'), dpi=150); plt.close(fig)
# MC histograms of the winner
if os.path.exists(os.path.join(HERE, 'f2v_mc_w100_samples.csv')):
    mc = [r for r in rd('f2v_mc_w100_samples.csv') if r['status'] == 'ok']
    panels = [('Gpost_10_dB', 'gain @10 Hz [dB]', 38, 42), ('fL', 'fL [Hz]', 0.09, 0.11), ('fH', 'fH [Hz]', 225, 275),
              ('nz_M1_G10_full_uV', 'noise M1 full / G10 [µV]', None, 3.0), ('nz_M1_G100_full_uV', 'noise M1 full / G100 [µV]', None, 3.0),
              ('CMRR_on_dB', 'CMRR60 DRL on [dB]', 85, None), ('P_total_uW', 'total power [µW]', None, 4.0), ('PM_main', 'main-loop PM [deg] (guard 60)', 60, None)]
    fig, ax = plt.subplots(4, 2, figsize=(8, 10)); ax = ax.ravel()
    for a, (k, nm, lo, hi) in zip(ax, panels):
        v = np.array([float(r[k]) for r in mc]); a.hist(v, bins=20, color=B, edgecolor='white', linewidth=0.8)
        for lim in (lo, hi):
            if lim is not None and v.min() - 3 * v.std() <= lim <= v.max() + 3 * v.std(): a.axvline(lim, color=O, lw=1.5)
        npass = sum((lo is None or q >= lo) and (hi is None or q <= hi) for q in v)
        a.set_title('%s\nmean %.4g, σ %.3g, min %.4g, max %.4g%s' % (nm, v.mean(), v.std(ddof=1), v.min(), v.max(),
                    ', pass %d/%d' % (npass, len(v)) if (lo is not None or hi is not None) else ''), fontsize=8, color=INK); a.set_ylabel('samples')
    fig.suptitle('Winner P2S60 mismatch MC, N = %d valid, seed 12345, TT 27 °C (orange: limit, when inside the range shown)' % len(mc), fontsize=9, color=INK)
    fig.tight_layout(); fig.savefig(os.path.join(HERE, 'fig_f2s_winner_mc_hist.png'), dpi=150); plt.close(fig)
print('figs ok')
