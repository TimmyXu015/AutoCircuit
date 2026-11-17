# Round 6D Stage A plot. Usage (from this folder): python3 r6d_plots.py <raw_dir>  -> r6d_stageA.png
import csv, math, sys, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
R=sys.argv[1] if len(sys.argv)>1 else 'raw'
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#e6e6e6','grid.linewidth':0.6})
def rows(f): return list(csv.DictReader(open(f)))
cases=[('A_ref','REF (no load)','Hpre','#555555','-'),('A_direct_1p','DIRECT 1 pF on fp/fn','Hpre','#eda100','--'),('A_direct_10p','DIRECT 10 pF on fp/fn','Hpre','#eb6834','-'),
       ('A_buf_1p','BUFFERED 1 pF on bufp/bufn','Hbuf','#6fa8e8','--'),('A_buf_10p','BUFFERED 10 pF on bufp/bufn','Hbuf','#2a78d6','-')]
fig,ax=plt.subplots(1,3,figsize=(15,4.3))
for tag,lab,key,c,ls in cases:
    d=rows('%s/%s_dm_ac.csv'%(R,tag)); f=[float(r['f_Hz']) for r in d]
    ax[0].semilogx(f,[float(r['abs_'+key]) for r in d],color=c,ls=ls,lw=2,label=lab+(' : (bufp-bufn)/(ep-en)' if key=='Hbuf' else ' : (fp-fn)/(ep-en)'))
    ax[1].semilogx(f,[float(r['ph_'+key]) for r in d],color=c,ls=ls,lw=2)
    s=rows('%s/%s_stb_cmfb.csv'%(R,tag)); ax[2].semilogx([float(r['f_Hz']) for r in s],[20*math.log10(float(r['abs_LG'])) for r in s],color=c,ls=ls,lw=2,label=lab)
ax[0].set_xlim(1,1e5); ax[0].set_ylim(0,100); ax[0].set_xlabel('f (Hz)'); ax[0].set_ylabel('|gain| to the delivered output (V/V)')
ax[0].set_title('(a) Delivered DM gain, TG static phase A (AC)',loc='left'); ax[0].legend(frameon=False,fontsize=7,loc='lower left')
ax[0].annotate('follower 0.842 x',(100,79.6),textcoords='offset points',xytext=(10,-18),fontsize=7.5,color='#2a78d6')
ax[0].text(2.2e3,58,'DIRECT 10 pF: f-3dB 423 Hz',fontsize=7.5,color='#eb6834')
ax[1].set_xlim(1,1e5); ax[1].set_ylim(-100,10); ax[1].set_xlabel('f (Hz)'); ax[1].set_ylabel('phase (deg)'); ax[1].set_title('(b) Phase of the delivered gain',loc='left')
ax[1].axvline(100,color='#aaa',lw=0.8); ax[1].text(105,2,'100 Hz',fontsize=7.5,color='#666')
ax[2].axhline(0,color='#888',lw=0.8); ax[2].set_xlim(1e-3,1e8); ax[2].set_ylim(-80,70); ax[2].set_xlabel('f (Hz)'); ax[2].set_ylabel('|CMFB return ratio| (dB)')
ax[2].set_title('(c) CMFB loop (/IPRC): PM 87.8 / 89.3 / 90.1 / 88.0 / 87.8 deg',loc='left'); ax[2].legend(frameon=False,fontsize=7,loc='lower left')
fig.tight_layout(); fig.savefig('r6d_stageA.png',dpi=150)
