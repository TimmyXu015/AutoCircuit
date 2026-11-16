import csv
D='docs/ece203_data/round5/stageD/'
st={r['tag']:r for r in csv.DictReader(open(D+'r5_stageD.csv'))}
fu={r['tag']:r for r in csv.DictReader(open(D+'r5_stageD_followup.csv'))}
sp={r['tag']:r for r in csv.DictReader(open(D+'r5_demod_noise_split.csv'))}
f=lambda x,fmt='%.4g',k=1: fmt%(float(x)*k)
psd=lambda p:' / '.join('%.0f'%(float(p[k])*1e9) for k in ['in_0p1','in_1','in_10','in_100','in_250'])
rows=[dict(case='static (chen 0, B1 CD bench)',evidence='Spectre noise (real MOS)',demod_position='none',
  H100='85.47',H100_vs_static='1',step_gain_tran=f(st['D0_static_tran']['step_gain']),step_ratio='1',
  out_dc_V='0.90186',out_ripple_pp_V='0',fb_ripple_pp_V='0',oa1_range_V='1.3131 (DC)',oa2_range_V='0.90186 (DC)',
  out_rms_mV='1.464',app_in_uV='17.13',deemb_in_uV='16.69',subband_sum_uV=sp['B1_CD_LP']['sum_in_uVrms'],
  OTA2_fn_in_uV=sp['B1_CD_LP']['OTA2_fn_in_uVrms'],OTA1_fn_in_uV='12.43 / 10.93',
  in_PSD_nV_0p1_1_10_100_250='23113 / 6156 / 1764 / 545 / 353',I_OTA2_nA='53.6',loop_PM_deg='73.4',noisetype='n/a',gate='baseline')]
for tag,pt,lab,pos in [('D1_chop4k_tran','D1_pss_pnoise','D1 4 kHz sb30','after OTA1 (around vr1 1.31308 V)'),('D2_chop4k_tran','D2_pss_pnoise','D2 4 kHz sb30','after OTA2 (around VREF)')]:
    t=st[tag]; p=fu.get(pt) or t; s=sp[pt]; r=float(p['pac100'])/85.4749
    rows.append(dict(case=lab,evidence='Spectre tran+PSS/PAC/PNoise; real MOS + ideal relays/EINV/clock',demod_position=pos,
      H100=f(p['pac100']),H100_vs_static='%.4f'%r,step_gain_tran=f(t['step_gain']),step_ratio='%.4f'%float(t['step_ratio']),
      out_dc_V=f(p['pss_out_avg'],'%.5g'),out_ripple_pp_V=f(p['pss_out_pp']),fb_ripple_pp_V=f(p['pss_fb_pp']),
      oa1_range_V='%.4g..%.4g'%(float(p['pss_oa1_min']),float(p['pss_oa1_max'])),oa2_range_V='%.4g..%.4g'%(float(p['pss_oa2_min']),float(p['pss_oa2_max'])),
      out_rms_mV=f(p['out_rms'],k=1e3),app_in_uV=f(p['app_in'],k=1e6),deemb_in_uV=f(p['deemb_in'],k=1e6),
      subband_sum_uV=s['sum_in_uVrms'],OTA2_fn_in_uV=s['OTA2_fn_in_uVrms'],OTA1_fn_in_uV='%s / %s'%(s['OTA1_input_fn_in_uVrms'],s['OTA1_mirror_fn_in_uVrms']),
      in_PSD_nV_0p1_1_10_100_250=psd(p),I_OTA2_nA='%.1f'%(-float(t['I_VDD2'])*1e9),loop_PM_deg='n/a (periodic)',noisetype='absent in netlist -> Spectre default',
      gate='PAC %.3f PASS; tran step %.3f %s'%(r,float(t['step_ratio']),'PASS' if abs(float(t['step_ratio'])-1)<0.1 else 'marginal (unsettled baseline)')))
p=fu['D2_pss_pnoise_sb50']; s=sp['D2_pss_pnoise_sb50']
rows.append(dict(case='D2 4 kHz sb50 (convergence check)',evidence='Spectre PSS/PAC/PNoise',demod_position='after OTA2',H100=f(p['pac100']),
  H100_vs_static='%.4f'%(float(p['pac100'])/85.4749),step_gain_tran='-',step_ratio='-',out_dc_V=f(p['pss_out_avg'],'%.5g'),out_ripple_pp_V=f(p['pss_out_pp']),
  fb_ripple_pp_V=f(p['pss_fb_pp']),oa1_range_V='same',oa2_range_V='same',out_rms_mV=f(p['out_rms'],k=1e3),app_in_uV=f(p['app_in'],k=1e6),
  deemb_in_uV=f(p['deemb_in'],k=1e6),subband_sum_uV=s['sum_in_uVrms'],OTA2_fn_in_uV=s['OTA2_fn_in_uVrms'],OTA1_fn_in_uV='%s / %s'%(s['OTA1_input_fn_in_uVrms'],s['OTA1_mirror_fn_in_uVrms']),
  in_PSD_nV_0p1_1_10_100_250=psd(p),I_OTA2_nA='-',loop_PM_deg='-',noisetype='default',gate='deemb +21% vs sb30 -> not converged'))
w=csv.DictWriter(open('docs/ece203_data/round5/r5_demod_placement.csv','w',newline=''),fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
for r in rows: print(r['case'],'|',r['H100'],r['H100_vs_static'],r['out_ripple_pp_V'],r['fb_ripple_pp_V'],r['app_in_uV'],r['deemb_in_uV'],r['OTA2_fn_in_uV'],r['I_OTA2_nA'],r['in_PSD_nV_0p1_1_10_100_250'],r['gate'])
