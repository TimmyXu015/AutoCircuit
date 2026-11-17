# Round 6C-I plots. Usage: python3 r6c_plots.py <raw_dir>  -> r6c_stageA.png, r6c_stageBC.png (here)
import csv, gzip, os, math, sys, bisect, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
R=sys.argv[1] if len(sys.argv)>1 else 'raw'
TE=0.0425
C={'old':'#eb6834','ideal':'#2a78d6'}; LAB={'old':'old: real DD-pair CMFB','ideal':'new: ideal linear CMFB (a0 1, fp 30 MHz)'}
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#e6e6e6','grid.linewidth':0.6})
def cols(fn):
    if not os.path.exists(fn) and os.path.exists(fn+'.gz'): fn=fn+'.gz'
    r=csv.reader(gzip.open(fn,'rt') if fn.endswith('.gz') else open(fn)); h=next(r); c=list(zip(*[[float(x) for x in row] for row in r])); return {k:c[i] for i,k in enumerate(h)}
def win(d,k,t0,t1):
    t=d['t_s']; i,j=bisect.bisect_left(t,t0),bisect.bisect_right(t,t1); return t[i:j],d[k][i:j]
fig,ax=plt.subplots(1,3,figsize=(15,4.2))
for v in ('old','ideal'):
    d=cols('%s/A_%s_stb_cmfb.csv'%(R,v))
    ax[0].semilogx(d['f_Hz'],[20*math.log10(x) for x in d['abs_LG']],color=C[v],lw=2,label=LAB[v])
    ph=[d['ph_LG'][0]]
    for q in d['ph_LG'][1:]:
        while q-ph[-1]>180: q-=360
        while q-ph[-1]<-180: q+=360
        ph.append(q)
    ax[1].semilogx(d['f_Hz'],ph,color=C[v],lw=2,label=LAB[v])
    s=cols('%s/A_%s_step_tran.csv'%(R,v)); t,eo=win(s,'e_out_V',0.99e-3,1.012e-3); _,vg=win(s,'vg_V',0.99e-3,1.012e-3)
    e0=eo[0]; g0=vg[0]
    ax[2].plot([(x-1e-3)*1e6 for x in t],[(y-e0)*1e3 for y in eo],color=C[v],lw=2,label='e_out, '+v)
    ax[2].plot([(x-1e-3)*1e6 for x in t],[(y-g0)*1e3 for y in vg],color=C[v],lw=1.2,ls='--',label='VCMFB (vg), '+v)
ax[0].axhline(0,color='#888',lw=0.8); ax[0].set_xlabel('f (Hz)'); ax[0].set_ylabel('|CMFB loop gain| (dB)'); ax[0].set_xlim(1e-3,1e8); ax[0].set_ylim(-90,70)
ax[0].set_title('(a) CMFB return ratio at /IPRC (stb, DRL closed)',loc='left'); ax[0].legend(frameon=False,fontsize=7.5,loc='lower left')
ax[0].annotate('UGF 350 kHz, PM 74.0',(3.5e5,0),textcoords='offset points',xytext=(-115,18),fontsize=7.5,color=C['old'])
ax[0].annotate('UGF 546 kHz, PM 87.8',(5.46e5,0),textcoords='offset points',xytext=(8,8),fontsize=7.5,color=C['ideal'])
ax[1].set_xlabel('f (Hz)'); ax[1].set_ylabel('unwrapped phase (deg); PM = phase(UGF) + 360'); ax[1].set_xlim(1e-3,1e8); ax[1].set_ylim(-450,-90); ax[1].axhline(-360,color='#888',lw=0.8); ax[1].text(2e-3,-352,'-360 (PM reference)',fontsize=7.5,color='#666')
ax[1].set_title('(b) Loop phase',loc='left')
ax[2].set_xlabel('time after the 1 nA/side output-CM step (us)'); ax[2].set_ylabel('change (mV)')
ax[2].set_title('(c) 1 nA/side output-CM step: e_out and VCMFB',loc='left'); ax[2].legend(frameon=False,fontsize=7.5,loc='lower right')
fig.tight_layout(); fig.savefig('r6c_stageA.png',dpi=150)
# ---------- B / C ----------
fig,ax=plt.subplots(2,2,figsize=(14,8))
for v in ('old','ideal'):
    b=cols('%s/B_%s_tran.csv'%(R,v)); t,o=win(b,'ocm_V',0.040,0.060)
    ax[0][0].plot([x*1e3 for x in t],[(y-0.9)*1e3 for y in o],color=C[v],lw=1.6,label=LAB[v])
    c=cols('%s/C_%s_tran.csv'%(R,v)); t,o=win(c,'ocm_V',0.040,0.050)
    ax[0][1].plot([x*1e3 for x in t],[(y-0.9)*1e3 for y in o],color=C[v],lw=0.8,label=LAB[v])
    t,o=win(c,'ocm_V',TE-30e-9,TE+400e-9); _,g=win(c,'vg_V',TE-30e-9,TE+400e-9); o0=o[0]; g0=g[0]
    ax[1][0].plot([(x-TE)*1e9 for x in t],[(y-o0)*1e3 for y in o],color=C[v],lw=1.8,label='Vout,cm, '+v)
    ax[1][0].plot([(x-TE)*1e9 for x in t],[(y-g0)*1e3 for y in g],color=C[v],lw=1.1,ls='--',label='VCMFB, '+v)
    t,o=win(c,'ocm_V',TE-5e-6,TE+60e-6); o0=o[0]
    ax[1][1].plot([(x-TE)*1e6 for x in t],[(y-o0)*1e3 for y in o],color=C[v],lw=1.4,label=LAB[v])
ax[0][0].set_title('(a) Stage B, TG static: Vout,cm with 100 Hz 1 mV DM input',loc='left'); ax[0][0].set_xlabel('t (ms)'); ax[0][0].set_ylabel('Vout,cm - 0.9 V (mV)'); ax[0][0].legend(frameon=False,fontsize=7.5,loc='center right')
ax[0][0].annotate('old: avg -24.6 mV, 200 Hz 3.59 mV',(50,-24.6),textcoords='offset points',xytext=(-60,40),fontsize=7.5,color=C['old'])
ax[0][0].annotate('new: avg +0.06 mV, 200 Hz 0.0001 mV',(50,0.06),textcoords='offset points',xytext=(-60,-14),fontsize=7.5,color=C['ideal'])
ax[0][1].set_title('(b) Stage C, 2 kHz TG chopper: Vout,cm (spikes = TG edges)',loc='left'); ax[0][1].set_xlabel('t (ms)'); ax[0][1].set_ylabel('Vout,cm - 0.9 V (mV)'); ax[0][1].set_ylim(-35,75); ax[0][1].legend(frameon=True,facecolor='white',edgecolor='white',framealpha=1,fontsize=7.5,loc='upper right')
ax[1][0].set_title('(c) TG edge at 42.5 ms (DM peak): change from pre-edge level',loc='left'); ax[1][0].set_xlabel('t - 42.5 ms (ns)'); ax[1][0].set_ylabel('mV'); ax[1][0].legend(frameon=False,fontsize=7.5,loc='upper right')
ax[1][1].set_title('(d) Same edge over 60 us: Vout,cm change from pre-edge level',loc='left'); ax[1][1].set_xlabel('t - 42.5 ms (us)'); ax[1][1].set_ylabel('mV'); ax[1][1].set_ylim(-5,5); ax[1][1].legend(frameon=False,fontsize=7.5,loc='lower right')
fig.tight_layout(); fig.savefig('r6c_stageBC.png',dpi=150)
