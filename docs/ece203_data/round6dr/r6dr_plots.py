# R6D-R plots (setting C). Usage (from this folder): python3 r6dr_plots.py <dir with F_C_*_tran.csv(.gz)> -> r6dr_stageB.png
import csv, gzip, os, sys, bisect, matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
D=sys.argv[1] if len(sys.argv)>1 else 'raw'
plt.rcParams.update({'font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#e6e6e6','grid.linewidth':0.6})
def cols(fn):
    if not os.path.exists(fn) and os.path.exists(fn+'.gz'): fn=fn+'.gz'
    r=csv.reader(gzip.open(fn,'rt') if fn.endswith('.gz') else open(fn)); h=next(r); c=list(zip(*[[float(x) for x in row] for row in r])); return {k:c[i] for i,k in enumerate(h)}
def win(t,y,a,b): i,j=bisect.bisect_left(t,a),bisect.bisect_right(t,b); return t[i:j],y[i:j]
S={r['case']:r for r in csv.DictReader(open('r6dr_stageB_summary.csv')) if r['window_ms']=='40-60'}
ref=cols(D+'/F_C_ref_tran.csv'); d10=cols(D+'/F_C_direct_10p_tran.csv'); b10=cols(D+'/F_C_buf_10p_tran.csv')
dm=lambda d,a,b:[x-y for x,y in zip(d[a],d[b])]
tr=[('REF  fp-fn (no load)',ref,dm(ref,'fp_V','fn_V'),'#555555',1.2),('DIRECT 10 pF  fp-fn',d10,dm(d10,'fp_V','fn_V'),'#eb6834',1.6),
    ('BUFFERED 10 pF  bufp-bufn',b10,dm(b10,'bufp_V','bufn_V'),'#2a78d6',1.6),('BUFFERED 10 pF  fp-fn (core node)',b10,dm(b10,'fp_V','fn_V'),'#9ec5f0',1.0)]
fig,ax=plt.subplots(2,2,figsize=(14,8.2))
for lab,d,y,c,lw in tr:
    t,v=win(d['t_s'],y,0.040,0.050); ax[0][0].plot([x*1e3 for x in t],[u*1e3 for u in v],color=c,lw=lw,label=lab)
    t,v=win(d['t_s'],y,0.0425-20e-6,0.0425+80e-6); ax[0][1].plot([(x-0.0425)*1e6 for x in t],[u*1e3 for u in v],color=c,lw=lw,label=lab)
ax[0][0].set_title('(a) 2 kHz TG chopper, 100 Hz 1 mV input: delivered DM output, 40-50 ms',loc='left'); ax[0][0].set_xlabel('t (ms)'); ax[0][0].set_ylabel('mV'); ax[0][0].legend(frameon=False,fontsize=7.5,loc='upper right')
ax[0][1].set_title('(b) Same, TG edge at 42.5 ms (DM peak)',loc='left'); ax[0][1].set_xlabel('t - 42.5 ms (us)'); ax[0][1].set_ylabel('mV')
cases=[('F_C_ref','REF'),('F_C_direct_1p','DIRECT\n1 pF'),('F_C_buf_1p','BUFFERED\n1 pF'),('F_C_direct_10p','DIRECT\n10 pF'),('F_C_buf_10p','BUFFERED\n10 pF')]
col=['#555555','#eda100','#6fa8e8','#eb6834','#2a78d6']
refg=float(S['F_C_ref']['Hpre_gain'])
core=[(float(S[c]['Hpre_gain'])/refg-1)*100 for c,_ in cases]
lag=[float(S[c]['Hbuf_phase_deg']) if S[c].get('Hbuf_phase_deg','n/a')!='n/a' else float(S[c]['Hpre_phase_deg']) for c,_ in cases]
x=range(len(cases))
ax[1][0].bar(x,lag,color=col,width=0.6,edgecolor='white',linewidth=2)
for i,v in enumerate(lag): ax[1][0].text(i,v+0.3,'%.2f'%v,ha='center',fontsize=8)
ax[1][0].set_xticks(list(x)); ax[1][0].set_xticklabels([l for _,l in cases]); ax[1][0].set_ylabel('phase lag at 100 Hz (deg)')
ax[1][0].set_title('(c) Delivered-output phase lag at 100 Hz (sine fit, 40-60 ms)',loc='left')
res=[float(S[c]['Hbuf_resid_rms_uV']) if S[c].get('Hbuf_resid_rms_uV','n/a')!='n/a' else float(S[c]['Hpre_resid_rms_uV']) for c,_ in cases]
ax[1][1].bar(x,res,color=col,width=0.6,edgecolor='white',linewidth=2)
for i,(v,g) in enumerate(zip(res,core)): ax[1][1].text(i,v+15,'%.0f uV\ncore gain %+.2f %%'%(v,g),ha='center',fontsize=7.5)
ax[1][1].set_xticks(list(x)); ax[1][1].set_xticklabels([l for _,l in cases]); ax[1][1].set_ylabel('delivered residual after 100 Hz fit (uV rms)'); ax[1][1].set_ylim(0,1150)
ax[1][1].set_title('(d) Delivered residual (chopper edge errors) and core fp/fn gain vs REF',loc='left')
fig.tight_layout(); fig.savefig('r6dr_stageB.png',dpi=150)
