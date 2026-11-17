import csv, sys, math, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
D=sys.argv[1]; O=sys.argv[2]
C=['#2a78d6','#eb6834','#1baf7a','#eda100','#e87ba4','#6250d6']
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#e6e6e6','grid.linewidth':0.6})
tr=list(csv.DictReader(open(D+'/r5n_noise_tradeoff.csv')))
fig,ax=plt.subplots(1,3,figsize=(15,4.6))
a=ax[0]
pts=[r for r in tr if r['stage']=='B' or r['case']=='A_prw4u_n1p1']
for r in pts:
    x=float(r['ota1_area_um2']); y=float(r['noise_deemb_uV'])
    a.scatter([x],[y],color=C[0],s=36,zorder=3)
    a.annotate(r['case_short'],(x,y),textcoords='offset points',xytext=(5,4),fontsize=7.5)
for r in [r for r in tr if r['stage']=='pilot']:
    x=float(r['ota1_area_um2']); y=float(r['noise_deemb_uV'])
    a.scatter([x],[y],color=C[1],marker='s',s=36,zorder=3); a.annotate(r['case_short'],(x,y),textcoords='offset points',xytext=(5,-10),fontsize=7.5,color=C[1])
a.axhline(3.0,color='#c0392b',lw=1,ls='--'); a.text(260,3.15,'spec 3 uVrms',color='#c0392b',fontsize=8)
a.set_xscale('log'); a.set_yscale('log'); a.set_xlabel('OTA1 gate-area sum (um^2, estimate)'); a.set_ylabel('input-referred noise 0.1-250 Hz (uVrms, de-embedded)')
a.set_title('(a) Noise vs OTA1 area (Spectre; squares = tail-current pilots)',loc='left',fontsize=9)
a=ax[1]
sp={r['tag']:r for r in csv.DictReader(open(D+'/r5n_noise_split.csv'))}
tags=[('A_prw4u_n1p1','B0 1x/1x'),('B_n4p4','B3 4x/4x'),('B_n16p16','B6 16x/16x'),('P2_tail4_n16p16_t4','B6 + tail x4')]
groups=[('OTA1_input_fn','input pair 1/f'),('OTA1_mirror_fn','PMOS mirror 1/f'),('OTA1_input_thermal','input thermal'),('OTA1_mirror_thermal','mirror thermal'),('rest','everything else')]
import numpy as np
x=np.arange(len(tags)); bottom=np.zeros(len(tags))
for gi,(g,l) in enumerate(groups):
    v=[]
    for t,_ in tags:
        r=sp[t]
        if g=='rest': v.append(sum(float(r[k+'_uV'])**2 for k in ['OTA1_other','OTA2','pseudoR','electrodes_R','DRL_and_bias','other']))
        else: v.append(float(r[g+'_uV'])**2)
    a.bar(x,v,bottom=bottom,color=C[gi],width=0.6,label=l,edgecolor='white',linewidth=1); bottom+=np.array(v)
for i,b in enumerate(bottom): a.text(i,b+3,'%.2f uV'%math.sqrt(b),ha='center',fontsize=8)
a.axhline(9.0,color='#c0392b',lw=1,ls='--'); a.text(0.45,13,'(3 uVrms)^2 = 9 uV^2',color='#c0392b',fontsize=8)
a.set_xticks(x); a.set_xticklabels([l for _,l in tags],fontsize=8); a.set_ylabel('noise power referred to input (uV^2)'); a.set_ylim(0,300)
a.set_title('(b) Where the noise power sits (sub-band de-embedded)',loc='left',fontsize=9); a.legend(frameon=False,fontsize=7.5,loc='upper right')
a=ax[2]
pr=[r for r in tr if r['stage']=='A']
a.plot([float(r['prw_um']) for r in pr],[float(r['fL_Hz']) for r in pr],'o-',color=C[2],lw=2)
for r in pr: a.annotate('%.3f Hz'%float(r['fL_Hz']),(float(r['prw_um']),float(r['fL_Hz'])),textcoords='offset points',xytext=(5,-12),fontsize=8)
a.axhspan(0.09,0.11,color='#e3f5ec',zorder=0); a.text(3.02,0.104,'spec 0.09-0.11 Hz',fontsize=8,color='#2e7d32')
a.set_xlabel('pseudo-R width prw (um), L = 2 um'); a.set_ylabel('fL (Hz)'); a.set_title('(c) fL fix: pseudo-R width (gain 91.7-91.9x, fH 249 Hz)',loc='left',fontsize=9)
fig.tight_layout(); fig.savefig(O+'/r5n_noise_area.png',dpi=140)
