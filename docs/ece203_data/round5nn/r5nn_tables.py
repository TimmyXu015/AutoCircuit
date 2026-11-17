# Round 5N-N tables + plot. T3 reference = R5N-L T_l36 (same circuit, M1/M2 40/32 um); M1 cgg of T3 = R5N P2 tail x4
# (identical M1/M2 size and bias, docs/ece203_data/round5n/raw/r5n_bias_pilot2.csv). Run from the repo root.
import csv, math, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt, numpy as np
D='docs/ece203_data/round5nn/'; R=D+'raw/'; L='docs/ece203_data/round5nl/raw/'
rows=lambda f:list(csv.DictReader(open(f)))
nn={r['case']:r for r in rows(R+'r5nn_cases.csv')}; sp={r['tag']:r for r in rows(R+'r5nn_noise_split.csv')}
t3=[r for r in rows(L+'r5nl_cases.csv') if r['tag']=='T_l36'][0]; sp['T3']=[r for r in rows(L+'r5nl_noise_split.csv') if r['tag']=='T_l36'][0]
op={}
for tag,f in (('T3',L+'T_l36_ota1_dcop.csv'),('N1',R+'N1_ota1_dcop.csv'),('N2',R+'N2_ota1_dcop.csv')):
    op[tag]={r['inst']:r for r in rows(f)}
cggT3=float([r for r in rows('docs/ece203_data/round5n/raw/r5n_bias_pilot2.csv') if r['tag']=='P2_tail4_n16p16_t4'][0]['cgg_M1'])
CC=50e-12; CFB=0.5e-12
def psd(f,fr):
    d=[(float(x['f_Hz']),float(x['deemb_in_V_rtHz'])) for x in csv.DictReader(open(f))]
    i=min(range(len(d)),key=lambda k:abs(math.log(d[k][0]/fr))); return d[i][1]
cases=[('T3',40,32,t3,L+'T_l36_noise.csv',cggT3),('N1',45,36,nn.get('N1'),R+'N1_noise.csv',None),('N2',50,40,nn.get('N2'),R+'N2_noise.csv',None)]
out=[]; base=None
for tag,w,l,r,nf,cg in cases:
    s=sp[tag]; o=op[tag]; cgg=cg if cg else float(r['m1_cgg'])
    ng=(CC+CFB+cgg)/CC
    if base is None: base=dict(ng=ng,infn=float(s['OTA1_input_fn_uV']),area=w*l)
    pred_int=base['infn']/base['ng']*math.sqrt(base['area']/(w*l))
    m=lambda i:float(o[i]['sat_margin_V'])
    out.append(dict(case=tag,M1M2_W_um=w,M1M2_L_um=l,M1_area_um2=w*l,OTA1_area_um2='%.0f'%(2*8*36+2*w*l+40+128+8),
        noise_deemb_uV='%.3f'%(float(r['noise_deemb_in'])*1e6),noise_app_uV='%.3f'%(float(r['noise_app_in'])*1e6),
        meets_3uV_both='yes' if float(r['noise_deemb_in'])<3e-6 and float(r['noise_app_in'])<3e-6 else 'no',
        input_fn_uV=s['OTA1_input_fn_uV'],input_fn_pct=s['OTA1_input_fn_pct'],mirror_fn_uV=s['OTA1_mirror_fn_uV'],mirror_fn_pct=s['OTA1_mirror_fn_pct'],
        input_th_uV=s['OTA1_input_thermal_uV'],mirror_th_uV=s['OTA1_mirror_thermal_uV'],
        M1_cgg_pF='%.2f'%(cgg*1e12),cap_noise_gain='%.4f'%ng,input_fn_intrinsic_uV='%.3f'%(float(s['OTA1_input_fn_uV'])/ng),
        input_fn_intrinsic_pred_1oversqrtA_uV='%.3f'%pred_int,mirror_fn_intrinsic_uV='%.3f'%(float(s['OTA1_mirror_fn_uV'])/ng),
        psd_nV_0p1_1_10_100_250=' / '.join('%.0f'%(psd(nf,f)*1e9) for f in (0.1,1,10,100,250)),
        H100='%.3f'%float(r['Hout_100']),H100_dB='%.2f'%float(r['Hout_100_dB']),fL_Hz='%.4f'%float(r['fL_out']),fH_Hz='%.1f'%float(r['fH_out']),
        Zin_P_10_MOhm='%.0f'%(float(r['Zin_amp_P_10'])/1e6),Zin_N_10_MOhm='%.0f'%(float(r['Zin_amp_N_10'])/1e6),
        M1_Id_nA='%.1f'%(float(o['XA.M1']['id_A'])*1e9),M1_gm_uS='%.3f'%(float(o['XA.M1']['gm_S'])*1e6),M1_gm_over_Id=o['XA.M1']['gm_over_id'],
        M1_VGS_V='%.4f'%float(o['XA.M1']['vgs_V']),M1_VDS_V='%.4f'%float(o['XA.M1']['vds_V']),M1_Vth_V='%.4f'%float(o['XA.M1']['vth_V']),
        M1_margin_V='%.3f'%m('XA.M1'),M2_VDS_V='%.4f'%float(o['XA.M2']['vds_V']),M2_margin_V='%.4f'%m('XA.M2'),
        M3_margin_V='%.3f'%m('XA.M3'),M4_margin_V='%.4f'%m('XA.M4'),MC_margin_V='%.3f'%m('XA.MC'),MT_margin_V='%.3f'%m('XA.MT'),
        I_VDD_nA='%.1f'%(float(r['I_VDD'])*1e9),I_VDDD_nA_subset='%.1f'%(float(r['I_VDDD'])*1e9),P_total_uW='%.3f'%(float(r['I_VDD'])*1.8e6)))
w=csv.DictWriter(open(D+'r5nn_input_pair.csv','w',newline=''),fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
for o in out: print(o)
# plot
C=['#2a78d6','#eb6834','#1baf7a','#eda100','#9a9a9a']
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#e6e6e6','grid.linewidth':0.6})
fig,ax=plt.subplots(1,2,figsize=(11,4.4)); a=ax[0]
groups=[('OTA1_input_fn','input pair 1/f'),('OTA1_mirror_fn','PMOS mirror 1/f'),('OTA1_input_thermal','input thermal'),('OTA1_mirror_thermal','mirror thermal'),('rest','everything else')]
tags=['T3','N1','N2']; lab=['T3  40/32','N1  45/36','N2  50/40']; x=np.arange(3); bot=np.zeros(3)
for gi,(g,l) in enumerate(groups):
    v=[]
    for t in tags:
        s=sp[t]
        v.append(sum(float(s[k+'_uV'])**2 for k in ['OTA1_other','OTA2','pseudoR','electrodes_R','DRL_and_bias','other']) if g=='rest' else float(s[g+'_uV'])**2)
    a.bar(x,v,bottom=bot,color=C[gi],width=0.55,label=l,edgecolor='white',linewidth=2); bot+=np.array(v)
for i,o in enumerate(out): a.text(i,bot[i]+0.15,'%s / %s uV'%(o['noise_deemb_uV'],o['noise_app_uV']),ha='center',fontsize=8)
a.axhline(9.0,color='#c0392b',lw=1,ls='--'); a.text(1.5,9.15,'(3 uV)^2',ha='center',color='#c0392b',fontsize=8)
a.set_xticks(x); a.set_xticklabels(lab); a.set_ylim(0,13.5); a.set_ylabel('input-referred noise power, 0.1-250 Hz (uV^2)')
a.set_title('(a) Noise power by source (labels: de-embedded / output RMS / H100)',loc='left',fontsize=9); a.legend(frameon=False,fontsize=7.5,loc='upper center',ncol=3)
a=ax[1]; A=[o['M1_area_um2'] for o in out]
a.plot(A,[float(o['input_fn_uV']) for o in out],'o-',color=C[0],lw=2,label='input-pair 1/f (simulated, at ECG input)')
a.plot(A,[float(o['input_fn_intrinsic_uV']) for o in out],'s--',color=C[0],lw=1.5,alpha=0.7,label='same / capacitive noise gain')
a.plot(A,[float(o['input_fn_intrinsic_pred_1oversqrtA_uV']) for o in out],':',color='#444',lw=1.2,label='1/sqrt(WL) from T3')
a.plot(A,[float(o['mirror_fn_uV']) for o in out],'o-',color=C[1],lw=2,label='mirror 1/f (simulated)')
for o in out: a.annotate('cgg %s pF'%o['M1_cgg_pF'],(o['M1_area_um2'],float(o['mirror_fn_uV'])),textcoords='offset points',xytext=(-20,8),fontsize=7.5,color='#555')
a.set_xlabel('M1/M2 gate area per device (um^2)'); a.set_ylabel('uVrms referred to ECG input'); a.set_ylim(1.4,2.6)
a.set_title('(b) Input-pair 1/f falls as 1/sqrt(WL); larger cgg raises every OTA1 term',loc='left',fontsize=9); a.legend(frameon=False,fontsize=7.5,loc='lower left')
fig.tight_layout(); fig.savefig(D+'r5nn_input_pair.png',dpi=150)
