import csv, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
R='docs/ece203_data/round5/'
C=['#2a78d6','#eb6834','#1baf7a','#eda100','#e87ba4','#008300']
def rd(fn,*cols):
    r=list(csv.DictReader(open(fn))); return [[float(x[c]) for x in r] for c in cols]
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#e3e3e3','grid.linewidth':0.6})
fig,ax=plt.subplots(2,2,figsize=(12,8.2))
a=ax[0,0]
for i,(fn,lab) in enumerate([('stageA/A_LP_ac.csv','A: C OTA + LP (R4 chain)'),('stageA/A_LP_idealBUF_ac.csv','A: + ideal x1 buffer'),('stageB/B1_CD_LP_ac.csv','B1: + real CD'),('stageB/B2_CS_cm0p5_LP_ac.csv','B2: + real CS (Miller 0.5p)')]):
    f,h=rd(R+fn,'f_Hz','abs_Hout'); a.semilogx(f,[20*__import__('math').log10(x) for x in h],color=C[i],lw=2,label=lab)
f,h=rd(R+'stageE/E_cs_dm_ac.csv','f_Hz','abs_Hout'); a.semilogx(f,[20*__import__('math').log10(x) for x in h],color=C[4],lw=2,ls='--',label='E: real ECG arch + CS')
a.set_xlim(0.01,3000); a.set_ylim(10,42); a.axvspan(225,275,color='#f0f0f0',zorder=0); a.set_xlabel('f (Hz)'); a.set_ylabel('|H_dm| at out (dB)')
a.set_title('(a) Gain: the LP loading loss disappears with OTA2',loc='left'); a.legend(frameon=False,fontsize=8,loc='lower center')
a=ax[0,1]
for i,(fn,col,lab) in enumerate([('stageB/B1_CD_LP_noise.csv','deemb_in_V_rtHz','static CD (noise) 16.7 uV'),('stageD/D1_pss_pnoise_pnoise.csv','deemb_in_V_rtHz','D1 demod after OTA1 12.2 uV'),('stageD/D2_pss_pnoise_pnoise.csv','deemb_in_V_rtHz','D2 demod after OTA2 11.8 uV'),('stageD/D2_pss_pnoise_sb50_pnoise.csv','deemb_in_V_rtHz','D2, 50 sidebands 14.3 uV')]):
    f,n=rd(R+fn,'f_Hz',col); m=[(x,y*1e9) for x,y in zip(f,n) if 0.1<=x<=250]
    a.loglog([p[0] for p in m],[p[1] for p in m],color=[C[0],C[1],C[2],C[2]][i],lw=2,ls='-' if i<3 else ':',label=lab)
a.set_xlabel('f (Hz)'); a.set_ylabel('input-referred PSD (nV/rtHz)'); a.set_title('(b) Pointwise de-embedded input noise, 0.1-250 Hz (S2 bench)',loc='left'); a.legend(frameon=False,fontsize=8)
a=ax[1,0]
sp={r['tag']:r for r in csv.DictReader(open(R+'stageD/r5_demod_noise_split.csv'))}
cats=['OTA1_input_fn','OTA1_mirror_fn','OTA1_input_thermal','OTA1_mirror_thermal','OTA2_fn','Rfb']
labs=['OTA1 input 1/f','OTA1 mirror 1/f','OTA1 input thermal','OTA1 mirror thermal','OTA2 1/f','Rfb']
cases=[('B1_CD_LP','static CD'),('D1_pss_pnoise','D1'),('D2_pss_pnoise','D2')]
import numpy as np
y=np.arange(len(cats)); w=0.26
for j,(t,l) in enumerate(cases):
    v=[float(sp[t][c+'_in_uVrms']) for c in cats]
    a.barh(y+(j-1)*w,v,height=w-0.03,color=C[j],label=l)
    for yy,vv in zip(y+(j-1)*w,v):
        if vv>0: a.text(vv+0.15,yy,'%.2g'%vv,va='center',fontsize=7,color='#444')
a.set_yticks(y); a.set_yticklabels(labs); a.invert_yaxis(); a.set_xlabel('referred to ECG input (uVrms, 0.1-250 Hz)')
a.set_title('(c) Source groups: OTA2 1/f is 0.04 uV, except D1 (1.16 uV)',loc='left'); a.legend(frameon=False,fontsize=8,loc='lower right')
a=ax[1,1]
for i,(fn,lab) in enumerate([('stageD/D1_pss_pnoise_pss_td.csv','D1'),('stageD/D2_pss_pnoise_pss_td.csv','D2')]):
    t,fb,o=rd(R+fn,'t_s','fb_V','out_V')
    a.plot([x*1e6 for x in t],fb,color=C[i+1],lw=1.5,label=lab+' fb (before LP)')
    a.plot([x*1e6 for x in t],o,color=C[i+1],lw=2.2,ls='--',label=lab+' out (after LP)')
a.set_xlabel('t within one 4 kHz period (us)'); a.set_ylabel('V'); a.set_title('(d) PSS steady state: 0.36-0.39 V pp at fb, 33 mV pp at out',loc='left'); a.legend(frameon=False,fontsize=8,ncol=2)
fig.suptitle('ECE203 Round 5 - output stage, stage noise and demodulator placement (Spectre, tt 27 C)',x=0.01,ha='left',fontsize=11)
fig.tight_layout(); fig.savefig(R+'r5_overview.png',dpi=140)
