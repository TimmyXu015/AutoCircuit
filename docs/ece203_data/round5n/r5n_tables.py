import csv, math
D='docs/ece203_data/round5n/'; R=D+'raw/'
def rows(f): return list(csv.DictReader(open(R+f)))
allc=rows('r5n_prw_scan.csv')+rows('r5n_area_cases.csv')+rows('r5n_bias_pilot.csv')+rows('r5n_bias_pilot2.csv')
sp={r['tag']:r for r in rows('r5n_noise_split.csv')}
def psd(tag,f):
    d=[(float(x['f_Hz']),float(x['deemb_in_V_rtHz'])) for x in csv.DictReader(open(R+tag+'_noise.csv'))]
    i=min(range(len(d)),key=lambda k:abs(math.log(d[k][0]/f))); return d[i][1]
# prw scan
with open(D+'r5n_prw_scan.csv','w',newline='') as fo:
    w=csv.writer(fo); w.writerow(['case','prw_um','prl_um','pr_netlist_check','H10','H60','H100','H100_dB','fL_Hz','fH_Hz','Zin_P_10Hz_ohm','Zin_N_10Hz_ohm','margin_A_V','worst_A','I_VDD_nA','noise_app_uV','noise_deemb_uV','fL_status'])
    for r in rows('r5n_prw_scan.csv'):
        fl=float(r['fL_out'])
        w.writerow([r['tag'],'%g'%(float(r['prw'])*1e6),'2',r['pr_w_netlist']+' '+r['pr_par'],'%.4g'%float(r['Hout_10']),'%.4g'%float(r['Hout_60']),'%.4g'%float(r['Hout_100']),'%.2f'%float(r['Hout_100_dB']),
                    '%.4f'%fl,'%.1f'%float(r['fH_out']),'%.3g'%float(r['Zin_amp_P_10']),'%.3g'%float(r['Zin_amp_N_10']),'%.3f'%float(r['margin_A']),r['worst_A'],'%.1f'%(float(r['I_VDD'])*1e9),
                    '%.2f'%(float(r['noise_app_in'])*1e6),'%.2f'%(float(r['noise_deemb_in'])*1e6),'PASS' if 0.09<=fl<=0.11 else 'FAIL'])
# tradeoff
short={'A0_replica_prw3u_n1p1':('A','A0 replica prw3u'),'A_prw3.5u_n1p1':('A','prw3.5u'),'A_prw4u_n1p1':('A','B0 = baseline (prw4u)'),'A_prw4.5u_n1p1':('A','prw4.5u'),
       'B_n4p1':('B','B1 4x/1x'),'B_n1p4':('B','B2 1x/4x'),'B_n4p4':('B','B3 4x/4x'),'B_n16p4':('B','B4 16x/4x'),'B_n4p16':('B','B5 4x/16x'),'B_n16p16':('B','B6 16x/16x'),
       'P1_tail2_n16p16_t2':('pilot','B6 + tail x2'),'P2_tail4_n16p16_t4':('pilot','B6 + tail x4')}
out=[]
for r in allc:
    t=r['tag']; st,sh=short[t]; s=sp.get(t,{k:'' for k in ['total_in_uVrms','OTA1_input_fn_uV','OTA1_mirror_fn_uV','OTA1_input_thermal_uV','OTA1_mirror_thermal_uV']})
    out.append(dict(stage='A' if st=='A' else st,case=t,case_short=sh,n_area=r['n_area'],p_area=r['p_area'],tail='4' if 't4' in t else ('2' if 't2' in t else '1'),prw_um='%g'%(float(r['prw'])*1e6),
        ota1_area_um2='%.0f'%float(r['ota1_area_um2']),ota1_area_x='%.2f'%(float(r['ota1_area_um2'])/256.0),cgg_M1_pF='%.3f'%(float(r['cgg_M1'])*1e12),cgg_M3_pF='%.3f'%(float(r['cgg_M3'])*1e12),
        H100='%.3f'%float(r['Hout_100']),H100_dB='%.2f'%float(r['Hout_100_dB']),fL_Hz='%.4f'%float(r['fL_out']),fH_Hz='%.1f'%float(r['fH_out']),Zin_N_10Hz_ohm='%.3g'%float(r['Zin_amp_N_10']),
        margin_A_V='%.3f'%float(r['margin_A']),worst_A=r['worst_A'],margin_X2_V='%.3f'%float(r['margin_X2']),I_VDD_nA='%.1f'%(float(r['I_VDD'])*1e9),P_uW='%.3f'%(float(r['I_VDD'])*1.8e6),
        noise_app_uV='%.3f'%(float(r['noise_app_in'])*1e6),noise_deemb_uV='%.3f'%(float(r['noise_deemb_in'])*1e6),subband_sum_uV=s['total_in_uVrms'],
        input_fn_uV=s['OTA1_input_fn_uV'],mirror_fn_uV=s['OTA1_mirror_fn_uV'],input_th_uV=s['OTA1_input_thermal_uV'],mirror_th_uV=s['OTA1_mirror_thermal_uV'],
        psd_nV_0p1_1_10_100_250=' / '.join('%.0f'%(psd(t,f)*1e9) for f in (0.1,1,10,100,250)),valid=r['valid'],
        meets_3uV='yes' if float(r['noise_deemb_in'])*1e6<3.0 else 'no'))
w=csv.DictWriter(open(D+'r5n_noise_tradeoff.csv','w',newline=''),fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
for o in out: print(o['case_short'],o['ota1_area_um2'],o['noise_deemb_uV'],o['input_fn_uV'],o['mirror_fn_uV'],o['P_uW'],o['margin_A_V'],o['psd_nV_0p1_1_10_100_250'])
# final spec matrix
def g(f,tag):
    for r in rows(f):
        if r['tag']==tag: return r
bd=g('r5n_signoff_baseline_dm.csv','C_baseline_dm_noise_n1p1'); xd=g('r5n_signoff_best_dm.csv','C_best_dm_noise_n16p16_t4')
bo=g('r5n_signoff_baseline_drl.csv','C_baseline_off_dcc1'); br=g('r5n_signoff_baseline_drl.csv','C_baseline_real_dcc1')
xo=g('r5n_signoff_best_drl.csv','C_best_off_dcc1'); xr=g('r5n_signoff_best_drl.csv','C_best_real_dcc1')
bs=rows('r5n_signoff_baseline_mainstb.csv')[0]; xs=rows('r5n_signoff_best_mainstb.csv')[0]
f=lambda x,fmt: fmt%float(x)
def st(ok): return 'PASS (sim)' if ok else 'FAIL'
M=[['metric','target','r5n_submission_baseline (OTA1 1x/1x, prw 4u)','status','r5n_low_noise_best (OTA1 16x/16x, tail x4, prw 4u)','status','R5 final (reference)']]
def add(m,t,bv,bok,xv,xok,ref): M.append([m,t,bv,bok,xv,xok,ref])
add('|Hdm(100 Hz)| at out','38-42 dB','%s (%s dB); H10 %s, H60 %s'%(f(bd['Hout_100'],'%.2f'),f(bd['Hout_100_dB'],'%.2f'),f(bd['Hout_10'],'%.2f'),f(bd['Hout_60'],'%.2f')),st(38<=float(bd['Hout_100_dB'])<=42),
    '%s (%s dB); H10 %s, H60 %s'%(f(xd['Hout_100'],'%.2f'),f(xd['Hout_100_dB'],'%.2f'),f(xd['Hout_10'],'%.2f'),f(xd['Hout_60'],'%.2f')),st(38<=float(xd['Hout_100_dB'])<=42),'91.91 (39.27 dB)')
add('fL','0.09-0.11 Hz',f(bd['fL_out'],'%.4f Hz'),st(0.09<=float(bd['fL_out'])<=0.11),f(xd['fL_out'],'%.4f Hz'),st(0.09<=float(xd['fL_out'])<=0.11),'0.0773 Hz (FAIL)')
add('fH','225-275 Hz',f(bd['fH_out'],'%.1f Hz'),st(225<=float(bd['fH_out'])<=275),f(xd['fH_out'],'%.1f Hz'),st(225<=float(xd['fH_out'])<=275),'249.1 Hz')
add('CMRR60, Cc 1% mismatch, DRL ON','>85 dB',f(br['CMRR60_dB'],'%.2f dB'),st(float(br['CMRR60_dB'])>85),f(xr['CMRR60_dB'],'%.2f dB'),st(float(xr['CMRR60_dB'])>85),'95.42 dB')
add('CMRR60, DRL OFF (reference)','report',f(bo['CMRR60_dB'],'%.2f dB'),'reported',f(xo['CMRR60_dB'],'%.2f dB'),'reported','64.75 dB')
add('body 0.1 uA@60 Hz, DRL ON: |Vbody| / out / tran o range','no clipping','%s V / %s V / %s..%s V'%(f(br['body60'],'%.4f'),f(br['out60'],'%.4f'),f(br['tr_o_min'],'%.4f'),f(br['tr_o_max'],'%.4f')),'PASS (sim)',
    '%s V / %s V / %s..%s V'%(f(xr['body60'],'%.4f'),f(xr['out60'],'%.4f'),f(xr['tr_o_min'],'%.4f'),f(xr['tr_o_max'],'%.4f')),'PASS (sim)','37.4 mV / 2.1 mV / 0.895-0.900')
add('body 0.1 uA@60 Hz, DRL OFF: tran o range','report','%s..%s V (rail)'%(f(bo['tr_o_min'],'%.3f'),f(bo['tr_o_max'],'%.3f')),'clips (DRL off)','%s..%s V (rail)'%(f(xo['tr_o_min'],'%.3f'),f(xo['tr_o_max'],'%.3f')),'clips (DRL off)','clips')
add('|Zin(10 Hz)| worst input','>100 MOhm',f(min(float(bd['Zin_amp_P_10']),float(bd['Zin_amp_N_10'])),'%.3g Ohm'),st(min(float(bd['Zin_amp_P_10']),float(bd['Zin_amp_N_10']))>1e8),
    f(min(float(xd['Zin_amp_P_10']),float(xd['Zin_amp_N_10'])),'%.3g Ohm'),st(min(float(xd['Zin_amp_P_10']),float(xd['Zin_amp_N_10']))>1e8),'159 MOhm')
add('total power @1.8 V (VDD incl. DRL, OTA2, bias)','<4 uW','%s nA -> %s uW'%(f(float(bd['I_VDD'])*1e9,'%.1f'),f(float(bd['I_VDD'])*1.8e6,'%.3f')),st(float(bd['I_VDD'])*1.8<4e-6),
    '%s nA -> %s uW'%(f(float(xd['I_VDD'])*1e9,'%.1f'),f(float(xd['I_VDD'])*1.8e6,'%.3f')),st(float(xd['I_VDD'])*1.8<4e-6),'1.408 uW')
add('main loop stb (/IPRB)','PM >= 55 deg','UGF %s Hz, PM %s deg, LG10 %s'%(f(bs['ugf'],'%.4g'),f(bs['pm'],'%.1f'),f(bs['lg10'],'%.4g')),st(float(bs['pm'])>=55),
    'UGF %s Hz, PM %s deg, LG10 %s'%(f(xs['ugf'],'%.4g'),f(xs['pm'],'%.1f'),f(xs['lg10'],'%.4g')),st(float(xs['pm'])>=55),'87.6 deg')
add('DRL loop stb (/IPRD)','report','UGF %s Hz, PM %s deg, LG60 %s'%(f(br['ugf'],'%.4g'),f(br['pm'],'%.1f'),f(br['lg60'],'%.4g')),'reported',
    'UGF %s Hz, PM %s deg, LG60 %s'%(f(xr['ugf'],'%.4g'),f(xr['pm'],'%.1f'),f(xr['lg60'],'%.4g')),'reported','90.1 deg')
add('noise 0.1-250 Hz, pointwise de-embedded','<3 uVrms',f(float(bd['noise_deemb_in'])*1e6,'%.2f uVrms'),'FAIL',f(float(xd['noise_deemb_in'])*1e6,'%.2f uVrms'),'FAIL','16.58 uVrms')
add('noise 0.1-250 Hz, out RMS / |H100|','<3 uVrms','%s uVrms (out %s mVrms)'%(f(float(bd['noise_app_in'])*1e6,'%.2f'),f(float(bd['noise_out_rms'])*1e3,'%.3f')),'FAIL',
    '%s uVrms (out %s mVrms)'%(f(float(xd['noise_app_in'])*1e6,'%.2f'),f(float(xd['noise_out_rms'])*1e3,'%.3f')),'FAIL','17.15 uVrms')
add('OTA1 headroom (min sat margin)','> 0 (R5: 0.094 V)','%s V (%s)'%(f(bd['margin_A'],'%.3f'),bd['worst_A']),'PASS (sim)','%s V (%s)'%(f(xd['margin_A'],'%.3f'),xd['worst_A']),'PASS (sim)','0.094 V (XA.M2)')
add('designed capacitors','<1 nF','143.5 pF','PASS','143.5 pF (+ OTA1 gate cap: M1/M2 cgg 4.8 pF each, M3/M4 0.74 pF each; not designed capacitors)','PASS','143.5 pF')
add('OTA1 transistor area (sum W*L)','report','256 um^2','reported','2992 um^2 (11.7x)','reported','256 um^2')
add('chopper / PSS / MC / PVT','not in scope','NOT RUN','-','NOT RUN','-','-')
csv.writer(open(D+'r5n_final_spec_matrix.csv','w',newline='')).writerows(M)
for m in M: print(' | '.join(m[:6]))
