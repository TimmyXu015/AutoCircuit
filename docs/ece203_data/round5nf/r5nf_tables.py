# Round 5N-F tables, raw-data noise check and plot. N2 reference = R5N-N N2 (docs/ece203_data/round5nn/raw). Run from repo root.
import csv, math, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt, numpy as np
D='docs/ece203_data/round5nf/'; R=D+'raw/'; N='docs/ece203_data/round5nn/raw/'
rows=lambda f:list(csv.DictReader(open(f)))
cs={r['case']:r for r in rows(R+'r5nf_cases.csv')}; cs['N2']=[r for r in rows(N+'r5nn_cases.csv') if r['case']=='N2'][0]
sp={r['tag']:r for r in rows(R+'r5nf_noise_split.csv')}; sp['N2']=[r for r in rows(N+'r5nn_noise_split.csv') if r['tag']=='N2'][0]
src={'N2':(N,36),'F1':(R,40),'F2':(R,42)}
def load(f,c): return [(float(r['f_Hz']),float(r[c])) for r in csv.DictReader(open(f))]
def interp(d,f):
    for i in range(1,len(d)):
        if d[i][0]>=f:
            a,b=d[i-1],d[i]; t=(math.log(f)-math.log(a[0]))/(math.log(b[0])-math.log(a[0])); return math.exp(math.log(a[1])+t*(math.log(b[1])-math.log(a[1])))
    return d[-1][1]
def integ(d,f1=0.1,f2=250.0,n=20000):
    fs=[f1*(f2/f1)**(k/n) for k in range(n+1)]; return sum(0.5*(interp(d,fs[i])**2+interp(d,fs[i+1])**2)*(fs[i+1]-fs[i]) for i in range(n))
def spectre_totals(f):
    tot=tin=None
    for l in open(f):
        if l.startswith('Total Summarized Noise'): tot=float(l.split('=')[1])
        if l.startswith('Total Input Referred Noise'): tin=float(l.split('=')[1])
    return tot,tin
out=[]; chk=[]
for t in ('N2','F1','F2'):
    d,L=src[t]; r=cs[t]; s=sp[t]; op={x['inst']:x for x in rows(d+t+'_ota1_dcop.csv')}
    o=load(d+t+'_noise.csv','out_V_rtHz'); de=load(d+t+'_noise.csv','deemb_in_V_rtHz'); h100=interp(load(d+t+'_ac.csv','abs_Hout'),100.0)
    orms=math.sqrt(integ(o)); tot,tin=spectre_totals(d+t+'_noisesummary_0p1_250.txt')
    chk.append(dict(case=t,skill_deemb_uV='%.4f'%(float(r['noise_deemb_in'])*1e6),recomputed_deemb_uV='%.4f'%(math.sqrt(integ(de))*1e6),
        spectre_total_input_referred_uV='%.4f'%(math.sqrt(tin)*1e6),skill_app_uV='%.4f'%(float(r['noise_app_in'])*1e6),
        recomputed_app_uV='%.4f'%(orms/h100*1e6),spectre_total_summarized_over_H100_uV='%.4f'%(math.sqrt(tot)/h100*1e6),
        H100_from_ac_csv='%.4f'%h100,out_rms_recomputed_uV='%.2f'%(orms*1e6),spectre_total_summarized_V2='%.5e'%tot))
    m=lambda i:float(op[i]['sat_margin_V'])
    out.append(dict(case=t,M3M4_W_um=8,M3M4_L_um=L,M1M2_WL_um='50/40',OTA1_area_um2='%.0f'%(2*8*L+2*50*40+40+128+8),
        noise_deemb_uV='%.3f'%(float(r['noise_deemb_in'])*1e6),noise_app_uV='%.3f'%(float(r['noise_app_in'])*1e6),
        both_below_3uV='yes' if max(float(r['noise_deemb_in']),float(r['noise_app_in']))<3e-6 else 'no',
        both_below_2p95uV='yes' if max(float(r['noise_deemb_in']),float(r['noise_app_in']))<2.95e-6 else 'no',
        input_fn_uV=s['OTA1_input_fn_uV'],mirror_fn_uV=s['OTA1_mirror_fn_uV'],input_th_uV=s['OTA1_input_thermal_uV'],mirror_th_uV=s['OTA1_mirror_thermal_uV'],
        mirror_fn_pct=s['OTA1_mirror_fn_pct'],input_fn_pct=s['OTA1_input_fn_pct'],
        psd_nV_0p1_1_10_100_250=' / '.join('%.0f'%(interp(de,f)*1e9) for f in (0.1,1,10,100,250)),
        H100='%.3f'%float(r['Hout_100']),H100_dB='%.2f'%float(r['Hout_100_dB']),fL_Hz='%.4f'%float(r['fL_out']),fH_Hz='%.1f'%float(r['fH_out']),
        Zin_P_10_MOhm='%.0f'%(float(r['Zin_amp_P_10'])/1e6),Zin_N_10_MOhm='%.0f'%(float(r['Zin_amp_N_10'])/1e6),
        M1_VDS_V='%.4f'%float(op['XA.M1']['vds_V']),M1_margin_V='%.3f'%m('XA.M1'),M2_VDS_V='%.4f'%float(op['XA.M2']['vds_V']),M2_margin_V='%.4f'%m('XA.M2'),
        M3_gm_uS='%.3f'%(float(op['XA.M3']['gm_S'])*1e6),M3_gm_over_Id=op['XA.M3']['gm_over_id'],M3_VSG_V='%.4f'%-float(op['XA.M3']['vgs_V']),M3_margin_V='%.3f'%m('XA.M3'),
        M4_VSD_V='%.4f'%-float(op['XA.M4']['vds_V']),M4_VDSAT_V='%.4f'%-float(op['XA.M4']['vdsat_V']),M4_margin_V='%.4f'%m('XA.M4'),
        MC_margin_V='%.3f'%m('XA.MC'),MT_margin_V='%.3f'%m('XA.MT'),MREF_margin_V='%.3f'%m('XA.MREF'),OTA1_min_margin='%.4f (%s)'%(float(r['margin_A']),r['worst_A']),
        OTA2_min_margin_V='%.3f'%float(r['margin_X2']),
        I_VDD_nA='%.1f'%(float(r['I_VDD'])*1e9),I_VDDD_nA_subset='%.1f'%(float(r['I_VDDD'])*1e9),P_total_uW='%.3f'%(float(r['I_VDD'])*1.8e6)))
for name,data in (('r5nf_final_noise.csv',out),('r5nf_noise_check.csv',chk)):
    w=csv.DictWriter(open(D+name,'w',newline=''),fieldnames=list(data[0].keys())); w.writeheader(); w.writerows(data)
for o in out: print(o)
for c in chk: print(c)
C=['#2a78d6','#eb6834','#1baf7a','#eda100','#9a9a9a']
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#e6e6e6','grid.linewidth':0.6})
fig,ax=plt.subplots(1,3,figsize=(15,4.4),gridspec_kw={'width_ratios':[1.3,1,1]}); a=ax[0]
groups=[('OTA1_input_fn','input pair 1/f'),('OTA1_mirror_fn','PMOS mirror 1/f'),('OTA1_input_thermal','input thermal'),('OTA1_mirror_thermal','mirror thermal'),('rest','everything else')]
tags=['N2','F1','F2']; x=np.arange(3); bot=np.zeros(3)
for gi,(g,l) in enumerate(groups):
    v=[sum(float(sp[t][k+'_uV'])**2 for k in ['OTA1_other','OTA2','pseudoR','electrodes_R','DRL_and_bias','other']) if g=='rest' else float(sp[t][g+'_uV'])**2 for t in tags]
    a.bar(x,v,bottom=bot,color=C[gi],width=0.55,label=l,edgecolor='white',linewidth=2); bot+=np.array(v)
for i,o in enumerate(out): a.text(i,bot[i]+0.12,'%s / %s uV'%(o['noise_deemb_uV'],o['noise_app_uV']),ha='center',fontsize=8)
a.axhline(9.0,color='#c0392b',lw=1,ls='--'); a.text(1.5,9.1,'(3 uV)^2',color='#c0392b',fontsize=8,ha='center')
a.set_xticks(x); a.set_xticklabels(['N2  M3/M4 8/36','F1  8/40','F2  8/42']); a.set_ylim(0,12.5); a.set_ylabel('input-referred noise power, 0.1-250 Hz (uV^2)')
a.set_title('(a) Noise power by source (labels: de-embedded / output RMS / H100)',loc='left',fontsize=9); a.legend(frameon=False,fontsize=7.5,loc='upper center',ncol=3)
a=ax[1]; Ls=[o['M3M4_L_um'] for o in out]
a.plot(Ls,[float(o['noise_deemb_uV']) for o in out],'o-',color=C[0],lw=2,label='pointwise de-embedded')
a.plot(Ls,[float(o['noise_app_uV']) for o in out],'s-',color=C[1],lw=2,label='output RMS / |H100|')
a.axhline(3.0,color='#c0392b',lw=1,ls='--'); a.axhline(2.95,color='#c0392b',lw=0.8,ls=':')
a.text(36.2,3.005,'3.00 uV spec',color='#c0392b',fontsize=7.5); a.text(36.2,2.938,'2.95 uV preferred',color='#c0392b',fontsize=7.5)
for o in out:
    for k,dy in (('noise_deemb_uV',-12),('noise_app_uV',6)): a.annotate(o[k],(o['M3M4_L_um'],float(o[k])),textcoords='offset points',xytext=(4,dy),fontsize=7.5)
a.set_xticks(Ls); a.set_xlabel('M3/M4 L (um), W = 8 um'); a.set_ylabel('input-referred noise (uVrms)'); a.set_ylim(2.82,3.08); a.set_xlim(35.5,43)
a.set_title('(b) Both noise definitions vs mirror L',loc='left',fontsize=9); a.legend(frameon=False,fontsize=7.5,loc='lower left')
a=ax[2]
a.plot(Ls,[float(o['M4_VSD_V']) for o in out],'o-',color=C[0],lw=2,label='M4 VSD')
a.plot(Ls,[float(o['M4_VDSAT_V']) for o in out],'s-',color=C[1],lw=2,label='M4 |VDSAT|')
a.plot(Ls,[float(o['M4_margin_V']) for o in out],'^-',color=C[2],lw=2,label='M4 margin = VSD - |VDSAT|')
a.axhline(0.05,color='#c0392b',lw=1,ls='--'); a.text(36.2,0.056,'50 mV risk line',color='#c0392b',fontsize=7.5)
for o in out: a.annotate('%.1f mV'%(float(o['M4_margin_V'])*1e3),(o['M3M4_L_um'],float(o['M4_margin_V'])),textcoords='offset points',xytext=(4,6),fontsize=7.5)
a.set_xticks(Ls); a.set_xlabel('M3/M4 L (um)'); a.set_ylabel('V'); a.set_ylim(0,0.42); a.set_xlim(35.5,43)
a.set_title('(c) M4 headroom (tightest OTA1 device in F1/F2)',loc='left',fontsize=9); a.legend(frameon=False,fontsize=7.5,loc='center right')
fig.tight_layout(); fig.savefig(D+'r5nf_final_noise.png',dpi=150)
