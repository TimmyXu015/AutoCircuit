import csv, math, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
D='docs/ece203_data/round6a/'
C=['#2a78d6','#eb6834','#1baf7a','#eda100','#e87ba4']
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False})
# ---- connection diagram ----
fig,ax=plt.subplots(figsize=(12,5.6)); ax.set_xlim(0,12); ax.set_ylim(0,6); ax.axis('off')
def box(x,y,w,h,t,c='#f4f4f4',ec='#555'):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle='round,pad=0.04',fc=c,ec=ec,lw=1.2)); ax.text(x+w/2,y+h/2,t,ha='center',va='center',fontsize=8.5)
def arr(x1,y1,x2,y2,c='#333',ls='-',t=None,tx=0,ty=0.12):
    ax.annotate('',xy=(x2,y2),xytext=(x1,y1),arrowprops=dict(arrowstyle='->',color=c,lw=1.3,ls=ls))
    if t: ax.text((x1+x2)/2+tx,(y1+y2)/2+ty,t,fontsize=7.5,color=c,ha='center')
box(0.2,2.3,1.6,1.4,'body + 3 electrodes\n(R4 model)\nd_body: 0.1 uA 60 Hz')
box(2.4,2.3,1.6,1.4,'Cc 50p x2\n(Cc 1% mismatch)\nCfb 0.5p / Rfb')
box(4.4,2.6,1.0,0.8,'input\ncommutator',c='#fff3d6')
box(5.8,2.2,1.9,1.6,'FD OTA1\n(NMOS pair 10u/8u,\nboth-side cascode,\nPMOS loads @ vg)\nd_ota: 1 nA/side',c='#e6f0fb')
box(8.1,2.6,1.0,0.8,'output\ncommutator',c='#fff3d6')
box(9.6,2.5,2.1,1.0,'Vop / Von -> Vod\n(gain 94.6, no LP)')
box(5.8,0.3,1.9,1.1,'CMFB: 2 NMOS DD pairs\nvs ref vrc, diode MD -> vg',c='#e3f5ec')
box(2.3,4.75,1.8,0.85,'CM sense\n(rcm 10G, ccm 1p) -> cm')
box(4.6,4.5,1.6,1.0,'DRL OTA\n(R4 5T, real)',c='#e3f5ec')
box(0.2,4.5,1.6,1.0,'right-leg electrode\n(1 MOhm + 1 MOhm)')
arr(1.8,3.0,2.4,3.0); arr(4.0,3.0,4.4,3.0); arr(5.4,3.0,5.8,3.0); arr(7.7,3.0,8.1,3.0); arr(9.1,3.0,9.6,3.0)
arr(6.75,2.2,6.75,1.4,t='op, on (sense)',tx=0.6,ty=0)
arr(6.1,1.4,6.1,2.2,c=C[2],t='vg',tx=-0.25,ty=0)
arr(1.0,3.7,3.2,4.5,t='inp / inn',tx=-0.6,ty=0.05)
arr(4.0,5.0,4.6,5.0,t='cm',ty=0.1)
arr(4.6,4.62,1.8,4.62,c=C[2],t='drlr',ty=-0.3,tx=-0.6)
arr(1.0,4.5,1.0,3.7,c=C[2])
ax.annotate('',xy=(5.8,0.85),xytext=(3.2,4.5),arrowprops=dict(arrowstyle='->',color=C[1],lw=1.4,ls='--',connectionstyle='arc3,rad=0.25'))
ax.text(3.0,0.25,'Stage C (H2) only:\nR(cm->vrc) 0.98 TOhm,\nR(vrc->VREF) 10 GOhm\n= CMFB reference\nfeed-forward (kff 0.0101)',fontsize=7.5,color=C[1])
ax.text(8.3,0.6,'Stage A diagnostics:\nideal u_body source at the right leg,\nAC-only ideal u_OTAcm at vg;\nH0 = one error e_in + a*e_out\ndrives both actuators',fontsize=7.5,color='#555')
ax.text(0.2,5.75,'ECE203 Round 6A: DRL (input / body CM) and FD-OTA CMFB (output CM), two independent loops + one coordinated variant',fontsize=10)
fig.savefig(D+'r6a_connection.png',dpi=140,bbox_inches='tight'); plt.close(fig)
# ---- overview ----
fig,ax=plt.subplots(1,3,figsize=(14,4.3))
cmp=list(csv.DictReader(open(D+'comparison.csv')))
labs=['open plant','ideal indep.','ideal H0','B real indep.','C real H2']
cols=[('dbody_ein60_V','d_body\n-> e_in\n(60 Hz)'),('dbody_eout60_V','d_body\n-> e_out\n(60 Hz)'),('dota_ein1_V','d_ota\n-> e_in\n(1 Hz)'),('dota_eout1_V','d_ota\n-> e_out\n(1 Hz)')]
a=ax[0]; import numpy as np; x=np.arange(len(cols)); w=0.16
for i,r in enumerate(cmp):
    v=[max(float(r[c]),1e-16) for c,_ in cols]
    a.bar(x+(i-2)*w,v,width=w-0.02,color=C[i],label=labs[i])
a.set_yscale('log'); a.set_xticks(x); a.set_xticklabels([l for _,l in cols],fontsize=7.5); a.set_ylabel('|error| (V)')
a.set_title('(a) Two independent disturbances, 2 CM errors',loc='left'); a.legend(frameon=False,fontsize=7,ncol=3,loc='upper center',bbox_to_anchor=(0.5,-0.2)); a.grid(axis='y',color='#e3e3e3',lw=0.6)
a=ax[1]
t=[];b=[];c=[]
for r in csv.DictReader(open(D+'cm_step_60hz.csv')): t.append(float(r['t_s'])*1e3); b.append(float(r['B_e_out_V'])*1e3); c.append(float(r['C_e_out_V'])*1e3)
a.plot(t,b,color=C[3],lw=1.5,label='B independent'); a.plot(t,c,color=C[4],lw=1.5,label='C H2 feed-forward')
a.axvline(60,color='#999',lw=0.8,ls=':'); a.text(61,max(b)-0.1,'1 nA/side OTA CM step',fontsize=7.5,color='#666')
a.set_xlabel('t (ms)'); a.set_ylabel('e_out = Vocm - VREF (mV)'); a.set_title('(b) Real MOS tran: body 60 Hz + OTA CM step',loc='left'); a.legend(frameon=False,fontsize=8); a.grid(color='#e3e3e3',lw=0.6)
a=ax[2]
r=list(csv.DictReader(open(D+'stageD/D2_vos1m_chen1_tran_dec.csv')))
tt=[float(x['t_s'])*1e3 for x in r]; op=[float(x['op_V']) for x in r]; on=[float(x['on_V']) for x in r]
cm=[(p+n)/2 for p,n in zip(op,on)]; vd=[float(x['fp_V'])-float(x['fn_V']) for x in r]
m=[i for i,v in enumerate(tt) if v>=18.5]
a.plot([tt[i] for i in m],[op[i] for i in m],color=C[0],lw=1.3,label='Vop (OTA out)'); a.plot([tt[i] for i in m],[on[i] for i in m],color=C[1],lw=1.3,label='Von (OTA out)')
a.plot([tt[i] for i in m],[cm[i] for i in m],color=C[2],lw=2,label='Vocm')
a.set_xlabel('t (ms)'); a.set_ylabel('V'); a.set_title('(c) Ideal 2 kHz FD chopper + 1 mV OTA offset (tran, not settled)',loc='left',fontsize=8.5)
a.legend(frameon=False,fontsize=7.5); a.grid(color='#e3e3e3',lw=0.6)
fig.tight_layout(); fig.savefig(D+'r6a_overview.png',dpi=140); plt.close(fig)
