import csv, math
D='docs/ece203_data/round5nl/'; R=D+'raw/'
cases=list(csv.DictReader(open(R+'r5nl_cases.csv'))); sp={r['tag']:r for r in csv.DictReader(open(R+'r5nl_noise_split.csv'))}
def psd(tag,f):
    d=[(float(x['f_Hz']),float(x['deemb_in_V_rtHz'])) for x in csv.DictReader(open(R+tag+'_noise.csv'))]
    i=min(range(len(d)),key=lambda k:abs(math.log(d[k][0]/f))); return d[i][1]
out=[]; m16=float(sp['P2ref_l16']['OTA1_mirror_fn_uV'])
for r in cases:
    t=r['tag']; L=float(r['m3_L_um']); s=sp[t]
    out.append(dict(case=t,M3M4_W_um=8,M3M4_L_um='%g'%L,H100='%.3f'%float(r['Hout_100']),H100_dB='%.2f'%float(r['Hout_100_dB']),fL_Hz='%.4f'%float(r['fL_out']),fH_Hz='%.1f'%float(r['fH_out']),
        noise_deemb_uV='%.3f'%(float(r['noise_deemb_in'])*1e6),noise_app_uV='%.3f'%(float(r['noise_app_in'])*1e6),out_rms_mV='%.4f'%(float(r['noise_out_rms'])*1e3),
        input_fn_uV=s['OTA1_input_fn_uV'],mirror_fn_uV=s['OTA1_mirror_fn_uV'],input_th_uV=s['OTA1_input_thermal_uV'],mirror_th_uV=s['OTA1_mirror_thermal_uV'],
        mirror_fn_pred_1overL_uV='%.2f'%(m16*16/L),mirror_fn_pct=s['OTA1_mirror_fn_pct'],input_fn_pct=s['OTA1_input_fn_pct'],
        psd_nV_0p1_1_10_100_250=' / '.join('%.0f'%(psd(t,f)*1e9) for f in (0.1,1,10,100,250)),
        M3_Id_nA='%.1f'%(abs(float(r['m3_id']))*1e9),M3_gm_uS='%.3f'%(float(r['m3_gm'])*1e6),M3_gm_over_Id='%.2f'%float(r['m3_gmid']),M3_VSG_V='%.4f'%float(r['m3_vsg']),M3_VSD_V='%.4f'%float(r['m3_vsd']),
        M3_Vth_V='%.4f'%float(r['m3_vth']),M3_Vdsat_V='%.4f'%float(r['m3_vdsat']),M3_sat_margin_V='%.3f'%float(r['m3_margin']),
        M1_Id_nA='%.1f'%(float(r['m1_id'])*1e9),M1_gm_over_Id='%.2f'%float(r['m1_gmid']),M1_VGS_V='%.4f'%float(r['m1_vgs']),M1_VDS_V='%.4f'%float(r['m1_vds']),M1_sat_margin_V='%.3f'%float(r['m1_margin']),
        M2_VDS_V='%.4f'%float(r['m2_vds']),M2_sat_margin_V='%.3f'%float(r['m2_margin']),OTA1_min_margin_V='%.3f (%s)'%(float(r['margin_A']),r['worst_A']),
        I_VDD_nA='%.1f'%(float(r['I_VDD'])*1e9),I_VDDD_nA_subset='%.1f'%(float(r['I_VDDD'])*1e9),P_total_uW='%.3f'%(float(r['I_VDD'])*1.8e6),
        OTA1_area_um2='%.0f'%float(r['ota1_area_um2']),valid=r['valid'],meets_3uV='yes' if float(r['noise_deemb_in'])<3e-6 else 'no'))
w=csv.DictWriter(open(D+'r5nl_mirror_length.csv','w',newline=''),fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
for o in out: print(o['M3M4_L_um'],o['noise_deemb_uV'],o['noise_app_uV'],o['mirror_fn_uV'],o['mirror_fn_pred_1overL_uV'],o['M3_gm_uS'],o['M3_gm_over_Id'],o['M3_VSG_V'],o['M1_VDS_V'],o['psd_nV_0p1_1_10_100_250'],o['OTA1_area_um2'])
# exponent
L=[float(o['M3M4_L_um']) for o in out]; m=[float(o['mirror_fn_uV']) for o in out]
n=len(L); xs=[math.log(x) for x in L]; ys=[math.log(y) for y in m]; mx=sum(xs)/n; my=sum(ys)/n
b=sum((x-mx)*(y-my) for x,y in zip(xs,ys))/sum((x-mx)**2 for x in xs); print('mirror 1/f ~ L^%.3f'%b)
gm=[float(o['M3_gm_uS']) for o in out]; ys=[math.log(y) for y in gm]; my=sum(ys)/n
print('gm3 ~ L^%.3f'%(sum((x-mx)*(y-my) for x,y in zip(xs,ys))/sum((x-mx)**2 for x in xs)))
