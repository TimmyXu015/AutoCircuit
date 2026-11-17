import csv, sys, bisect, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
U=sys.argv[1]; S=sys.argv[2]; O=sys.argv[3]
C=['#2a78d6','#eb6834','#1baf7a','#eda100','#e87ba4','#6250d6']
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#e6e6e6','grid.linewidth':0.6})
def load(fn,t0,t1):
    r=csv.reader(open(fn)); h=next(r); rows=[[float(x) for x in row] for row in r if t0<=float(row[0])<=t1]
    return {k:[x[i] for x in rows] for i,k in enumerate(h)}
fig,ax=plt.subplots(2,2,figsize=(13,8))
# (a) unit 2 kHz: vid and vod across edges near the +peak
d=load(U+'/U2_2k_vcm0p9_tran.csv',2.0e-3,3.6e-3)
t=[x*1e3 for x in d['t_s']]
a=ax[0,0]
a.plot(t,[(p-n)*1e3 for p,n in zip(d['inp_V'],d['inn_V'])],color=C[0],lw=1.6,label='Vin,diff (100 Hz, 1 mV pp)')
a.plot(t,[(p-n)*1e3 for p,n in zip(d['outp_V'],d['outn_V'])],color=C[1],lw=1.4,label='Vout,diff (TG output)')
a.plot(t,[c/1.8*0.4-1.2 for c in d['cka_V']],color='#888',lw=0.8,label='CKA (scaled)')
a.plot(t,[c/1.8*0.4-1.7 for c in d['ckb_V']],color='#bbb',lw=0.8,label='CKB (scaled)')
a.set_xlabel('t (ms)'); a.set_ylabel('mV'); a.set_title('(a) Unit, real MOS TG commutator @2 kHz: +1 / -1 per phase',loc='left'); a.legend(frameon=False,fontsize=7.5,loc='upper right')
# (b) zoom one edge: settling + CM
d=load(U+'/U2_2k_vcm0p9_tran.csv',2.4998e-3,2.5012e-3)
t=[(x-2.5e-3)*1e6 for x in d['t_s']]
a=ax[0,1]
a.plot(t,[(p-n)*1e3 for p,n in zip(d['outp_V'],d['outn_V'])],color=C[1],lw=1.6,label='Vout,diff (mV)')
a.plot(t,[((p+n)/2-0.9)*1e3 for p,n in zip(d['outp_V'],d['outn_V'])],color=C[2],lw=1.6,label='Vout,cm - 0.9 V (mV)')
a.set_xlabel('t - 2.5 ms (us), B->A edge'); a.set_ylabel('mV'); a.set_title('(b) Unit edge zoom (1 pF loads): settles < 0.4 us, CM spike 0.72 mV',loc='left'); a.legend(frameon=False,fontsize=8)
# (c) system 2 kHz / 4 kHz: vod vs gain*vid
a=ax[1,0]
for i,(fn,lab,g) in enumerate([(S+'/S1_tg2k_tran_tran.csv','2 kHz',93.227),(S+'/S2_tg4k_tran_tran.csv','4 kHz',92.342)]):
    d=load(fn,0.040,0.050); t=[x*1e3 for x in d['t_s']]
    a.plot(t,[(v-g*w)*1e3 for v,w in zip(d['vod_V'],d['vid_V'])],color=C[i+1],lw=1.0,label='%s: Vod - G*Vin (G = %.2f)'%(lab,g))
a.set_xlabel('t (ms)'); a.set_ylabel('mV'); a.set_title('(c) FD OTA + real TG choppers: residual after the 100 Hz gain',loc='left'); a.legend(frameon=False,fontsize=8)
# (d) system output CM
a=ax[1,1]
for i,(fn,lab) in enumerate([(S+'/S1_tg2k_tran_tran.csv','2 kHz'),(S+'/S2_tg4k_tran_tran.csv','4 kHz')]):
    d=load(fn,0.040,0.050); t=[x*1e3 for x in d['t_s']]
    a.plot(t,d['ocm_V'],color=C[i+1],lw=0.9,label='Vocm (OTA out), %s'%lab)
a.set_xlabel('t (ms)'); a.set_ylabel('V'); a.set_title('(d) Output CM: edge glitches (TG feedthrough at op/on) + 200 Hz',loc='left'); a.legend(frameon=False,fontsize=8)
fig.tight_layout(); fig.savefig(O+'/r6b_overview.png',dpi=140); plt.close(fig)
# connection diagram
fig,ax=plt.subplots(figsize=(12,4.2)); ax.set_xlim(0,12); ax.set_ylim(0,4.7); ax.axis('off')
def box(x,y,w,h,t,c='#f4f4f4'):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle='round,pad=0.04',fc=c,ec='#555',lw=1.2)); ax.text(x+w/2,y+h/2,t,ha='center',va='center',fontsize=8.5)
def arr(x1,y1,x2,y2,t=None,c='#333'):
    ax.annotate('',xy=(x2,y2),xytext=(x1,y1),arrowprops=dict(arrowstyle='->',color=c,lw=1.3))
    if t: ax.text((x1+x2)/2,(y1+y2)/2+0.12,t,fontsize=7.5,ha='center',color=c)
box(0.2,1.5,1.7,1.2,'electrodes/body\n+ Cc 50p (p, n)\nRfb ideal')
box(2.4,1.4,1.9,1.4,'XCI: ece203_r6b_tgchop\n4 TG = 8 MOS\nN 1u/0.18u, P 2u/0.18u',c='#fff3d6')
box(4.8,1.4,2.0,1.4,'R6A FD OTA1\n(unchanged)\nVOS (0 / 100 uV)',c='#e6f0fb')
box(7.3,1.4,1.9,1.4,'XCO: ece203_r6b_tgchop\n(same cell)',c='#fff3d6')
box(9.7,1.5,2.1,1.2,'fp / fn -> Cfb 0.5p\n+ Rfb -> back to n / p\nVod = fp - fn')
box(4.8,0.1,2.0,0.8,'R6A DD-pair CMFB\n(senses op/on)',c='#e3f5ec')
box(2.4,3.2,6.8,0.8,'ideal clocks: CKA/CKAB, CKB/CKBB 0/1.8 V, 2-phase non-overlap (~10 ns dead time), 2 or 4 kHz',c='#f0f0f0')
arr(1.9,2.1,2.4,2.1,'p, n'); arr(4.3,2.1,4.8,2.1,'ia, ibx'); arr(6.8,2.1,7.3,2.1,'op, on'); arr(9.2,2.1,9.7,2.1,'fp, fn')
arr(5.5,1.4,5.5,0.9); arr(6.1,0.9,6.1,1.4,c=C[2]); ax.text(6.2,1.1,'vg',color=C[2],fontsize=7.5)
arr(3.3,3.2,3.3,2.8); arr(8.2,3.2,8.2,2.8)
ax.text(0.2,0.3,'R4 DRL OTA (real) still drives the right leg (not drawn)',fontsize=7.5,color='#666')
ax.text(0.2,4.45,'ECE203 Round 6B: real MOS TG differential chopper around the R6A fully differential OTA',fontsize=10)
fig.savefig(O+'/r6b_connection.png',dpi=140,bbox_inches='tight'); plt.close(fig)
