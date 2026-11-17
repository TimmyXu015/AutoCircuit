# Round 6D analysis. Usage (from this folder): python3 r6d_analysis.py <raw_dir>
# Stage A: r6d_stageA.csv + stb CSVs -> r6d_stageA_summary.csv
# Stage B: B_*_tran.csv(.gz) -> r6d_stageB_summary.csv (per 20 ms window), r6d_ab_summary.csv (DIRECT vs BUFFERED)
import csv, gzip, os, math, cmath, sys, bisect
R=sys.argv[1] if len(sys.argv)>1 else 'raw'
def rows(f): return list(csv.DictReader(open(f)))
def cols(fn):
    if not os.path.exists(fn) and os.path.exists(fn+'.gz'): fn=fn+'.gz'
    r=csv.reader(gzip.open(fn,'rt') if fn.endswith('.gz') else open(fn)); h=next(r); c=list(zip(*[[float(x) for x in row] for row in r])); return {k:c[i] for i,k in enumerate(h)}
F=lambda x:float(x) if x not in ('n/a','',None) else None
# ---------- Stage A ----------
def lg(fn): return [(float(r['f_Hz']),float(r['abs_LG'])*cmath.exp(1j*math.radians(float(r['ph_LG'])))) for r in rows(fn)]
def at(d,f): return min(d,key=lambda x:abs(math.log(x[0]/f)))[1]
def acurve(fn,key):
    d=rows(fn); return [(float(r['f_Hz']),float(r['abs_'+key])*cmath.exp(1j*math.radians(float(r['ph_'+key])))) for r in d] if ('abs_'+key) in d[0] else None
def f3db(c,ref_f=10.0):
    ref=abs(at(c,ref_f))
    for (f0,a),(f1,b) in zip(c,c[1:]):
        if f0>=ref_f and abs(a)>=ref/math.sqrt(2)>abs(b):
            y=ref/math.sqrt(2); u=(math.log(abs(a))-math.log(y))/(math.log(abs(a))-math.log(abs(b)))
            return math.exp(math.log(f0)+u*(math.log(f1)-math.log(f0)))   # log-log interpolation on the 20/decade AC grid
    return None
outA=[]
for r in rows(R+'/r6d_stageA.csv'):
    t=r['tag']; m=lg(R+'/%s_stb_cmfb.csv'%t); hp=acurve(R+'/%s_dm_ac.csv'%t,'Hpre'); hb=acurve(R+'/%s_dm_ac.csv'%t,'Hbuf')
    o=dict(case=t,bench=r['bench'],CL_pF='%g'%(float(r['cl'])*1e12),fp_cm_V=r['fp_cm'],fp_cm_err_mV='%.3f'%((float(r['fp_cm'])-0.9)*1e3),op_cm_V=r['op_cm'],
           buf_cm_V=r['buf_cm'],vg_V=r['vg'],I_VDD_nA='%.1f'%(float(r['I_VDD'])*1e9),I_VDDD_nA_subset='%.1f'%(float(r['I_VDDD'])*1e9),
           Hpre100=r['Hpre100'],Hpre100_ph_deg=r['Hpre100_ph'],Hpre100_vs_REF_pct=None,Hpre1k=r['Hpre1k'],Hpre_f3dB_Hz=('%.4g'%f3db(hp) if f3db(hp) else 'n/a'),
           Hbuf100=r['Hbuf100'],Hbuf100_ph_deg=r['Hbuf100_ph'],Hbuf_f3dB_Hz=('%.4g'%f3db(hb) if hb and f3db(hb) else 'n/a'),
           Acd100=r['Acd100'],Acd100_ph_deg=r['Acd100_ph'],Acd1k=r['Acd1k'],Acd10k=r['Acd10k'],CMRR60_pre_dB=r['CMRR60_pre'],CMRR60_buf_dB=r['CMRR60_buf'],
           cmfb_UGF_Hz=r['cmfb_ugf'],cmfb_PM_deg=r['cmfb_pm'],cmfb_LG10=('%.1f'%abs(at(m,10.0))),drl_UGF_Hz=r['drl_ugf'],drl_PM_deg=r['drl_pm'],drl_LG60=r['drl_lg60'],
           MSP_Id_nA=(('%.2f'%(float(r['msp_id'])*1e9)) if F(r['msp_id']) else 'n/a'),MSP_gm_uS=(('%.3f'%(float(r['msp_gm'])*1e6)) if F(r['msp_gm']) else 'n/a'),
           MSP_VGS_V=r['msp_vgs'],MSP_VDS_V=r['msp_vds'],MSP_VDSAT_V=r['msp_vdsat'],MSP_margin_V=r['msp_margin'],
           MKP_Id_nA=(('%.2f'%(float(r['mkp_id'])*1e9)) if F(r['mkp_id']) else 'n/a'),MKP_VGS_V=r['mkp_vgs'],MKP_VDS_V=r['mkp_vds'],MKP_VDSAT_V=r['mkp_vdsat'],MKP_margin_V=r['mkp_margin'],
           MSN_Id_nA=(('%.2f'%(float(r['msn_id'])*1e9)) if F(r['msn_id']) else 'n/a'),MSN_margin_V=r['msn_margin'],MKN_Id_nA=(('%.2f'%(float(r['mkn_id'])*1e9)) if F(r['mkn_id']) else 'n/a'),MKN_margin_V=r['mkn_margin'],
           OTA_min_margin=r['minA']+' ('+r['worstA']+')')
    outA.append(o)
ref=[o for o in outA if o['bench']=='REF'][0]
for o in outA: o['Hpre100_vs_REF_pct']='%.3f'%((float(o['Hpre100'])/float(ref['Hpre100'])-1)*100)
# ---------- Stage B ----------
def lsq(t,y,f,harm=(1,)):
    basis=[lambda x:1.0, lambda x:x]
    for k in harm: basis+=[(lambda kk:(lambda x:math.sin(2*math.pi*kk*f*x)))(k),(lambda kk:(lambda x:math.cos(2*math.pi*kk*f*x)))(k)]
    n=len(basis); Am=[[0.0]*n for _ in range(n)]; b=[0.0]*n
    for x,v in zip(t,y):
        phi=[g(x) for g in basis]
        for i in range(n):
            b[i]+=phi[i]*v
            for j in range(n): Am[i][j]+=phi[i]*phi[j]
    M=[row[:]+[bb] for row,bb in zip(Am,b)]
    for i in range(n):
        p=max(range(i,n),key=lambda q:abs(M[q][i])); M[i],M[p]=M[p],M[i]
        for q in range(n):
            if q!=i:
                fc=M[q][i]/M[i][i]
                for c in range(i,n+1): M[q][c]-=fc*M[i][c]
    c=[M[i][n]/M[i][i] for i in range(n)]
    return c,[sum(ci*g(x) for ci,g in zip(c,basis)) for x in t]
def resamp(t,arr,t0,t1,dt):
    out=[];x=t0
    while x<=t1+1e-12:
        i=bisect.bisect_left(t,x); i=min(max(i,1),len(t)-1); a,b=t[i-1],t[i]; u=(x-a)/(b-a) if b>a else 0
        out.append(arr[i-1]+u*(arr[i]-arr[i-1])); x+=dt
    return out
def amp(c,k): return complex(c[2*k+1],c[2*k])   # cos + j sin of harmonic k (1-based index into harm list)
def edge_settle(t,e,amp_ref,t0,t1,tch=500e-6):
    # per TG edge: peak |error| after the edge and the time until |error| stays < 1 % of the 100 Hz amplitude
    k=math.ceil((t0+1e-6)/(tch/2)); pk=[]; ts=[]
    while k*tch/2+tch/2<=t1:
        te=k*tch/2; i0=bisect.bisect_left(t,te-50e-9); i1=bisect.bisect_left(t,te+tch/2-1e-6)
        seg=[(t[i]-te,e[i]) for i in range(i0,i1)]; pk.append(max(abs(v) for _,v in seg))
        ts.append(max([dt for dt,v in seg if abs(v)>0.01*amp_ref],default=0.0)); k+=1
    return max(pk),sum(pk)/len(pk),max(ts),sorted(ts)[len(ts)//2]
def cm_glitch(t,o,t0,t1,tch=500e-6):
    k=math.ceil((t0+30e-6)/(tch/2)); pos=[];neg=[];rec=[]
    def mean(a,b):
        i,j=bisect.bisect_left(t,a),bisect.bisect_left(t,b); return sum(o[i:j])/max(1,j-i),(t[i]+t[j-1])/2
    while k*tch/2+70e-6<=t1:
        te=k*tch/2; m0,c0=mean(te-20e-6,te-1e-6); m1,c1=mean(te+40e-6,te+60e-6)
        i0=bisect.bisect_left(t,te-50e-9); i1=bisect.bisect_left(t,te+40e-6)
        seg=[(t[i]-te,o[i]-(m0+(m1-m0)*(t[i]-c0)/(c1-c0))) for i in range(i0,i1)]
        pos.append(max(v for _,v in seg)); neg.append(min(v for _,v in seg)); rec.append(max([dt for dt,v in seg if abs(v)>1e-3],default=0.0)); k+=1
    return max(pos),min(neg),max(rec)
outB=[]
cases=[('B_ref','REF',0),('B_direct_1p','DIRECT',1),('B_buf_1p','BUFFERED',1),('B_direct_10p','DIRECT',10),('B_buf_10p','BUFFERED',10)]
for tag,bench,cl in cases:
    fn=R+'/%s_tran.csv'%tag
    if not (os.path.exists(fn) or os.path.exists(fn+'.gz')): continue
    d=cols(fn); t=d['t_s']; hasb='bufp_V' in d
    vpre=[a-b for a,b in zip(d['fp_V'],d['fn_V'])]; cpre=[(a+b)/2 for a,b in zip(d['fp_V'],d['fn_V'])]; cop=[(a+b)/2 for a,b in zip(d['op_V'],d['on_V'])]
    if hasb: vbuf=[a-b for a,b in zip(d['bufp_V'],d['bufn_V'])]; cbuf=[(a+b)/2 for a,b in zip(d['bufp_V'],d['bufn_V'])]
    for w0,w1 in ((0.020,0.040),(0.040,0.060)):
        dt=1e-6; tt=[w0+i*dt for i in range(int(round((w1-w0)/dt))+1)]
        R_=lambda a:resamp(t,a,w0,w1,dt)
        vid=R_(d['vid_V']); ci,_=lsq(tt,vid,100.0); ain=amp(ci,1)
        m=dict(case=tag,bench=bench,CL_pF=cl,window_ms='%g-%g'%(w0*1e3,w1*1e3))
        def dm(name,arr,label):
            y=R_(arr); c,fit=lsq(tt,y,100.0,harm=(1,2,3)); g=amp(c,1)/ain; a1=abs(amp(c,1))
            res=[v-f for v,f in zip(y,fit)]
            m[label+'_gain']=abs(g); m[label+'_phase_deg']=math.degrees(cmath.phase(g))
            m[label+'_H3_dBc']=20*math.log10(abs(amp(c,3))/a1); m[label+'_H2_dBc']=20*math.log10(max(abs(amp(c,2)),1e-30)/a1)
            m[label+'_resid_rms_uV']=math.sqrt(sum(x*x for x in res)/len(res))*1e6; m[label+'_resid_pp_mV']=(max(res)-min(res))*1e3
            m[label+'_pp_V']=max(y)-min(y)
            # edge settling on the full-resolution error vs the same fit (evaluated at native time points)
            i0,i1=bisect.bisect_left(t,w0),bisect.bisect_right(t,w1); tn=t[i0:i1]
            fitn=[c[0]+c[1]*x+sum(c[2*k]*math.sin(2*math.pi*k*100*x)+c[2*k+1]*math.cos(2*math.pi*k*100*x) for k in (1,2,3)) for x in tn]
            en=[v-f for v,f in zip(arr[i0:i1],fitn)]
            pk,pm,tsmax,tsmed=edge_settle(tn,en,a1,w0,w1)
            m[label+'_edge_err_max_mV']=pk*1e3; m[label+'_edge_err_mean_mV']=pm*1e3; m[label+'_settle1pct_max_us']=tsmax*1e6; m[label+'_settle1pct_median_us']=tsmed*1e6
            return g
        def cmm(arr,label):
            y=R_(arr); c,_=lsq(tt,y,100.0,harm=(1,2))
            m[label+'_avg_V']=sum(y)/len(y); m[label+'_200Hz_uV']=abs(amp(c,2))*1e6; m[label+'_pp_mV']=(max(y)-min(y))*1e3; m[label+'_drift_mV_per_s']=c[1]*1e3
            i0,i1=bisect.bisect_left(t,w0),bisect.bisect_right(t,w1); gp,gn,gr=cm_glitch(t[i0:i1],arr[i0:i1],w0,w1)
            m[label+'_edge_glitch_pos_mV']=gp*1e3; m[label+'_edge_glitch_neg_mV']=gn*1e3; m[label+'_edge_recover_1mV_us']=gr*1e6
        gpre=dm('pre',vpre,'Hpre'); cmm(cpre,'fpfn_cm'); cmm(cop,'opon_cm')
        if hasb:
            gbuf=dm('buf',vbuf,'Hbuf'); m['Acd_100Hz']=abs(gbuf/gpre); m['Acd_phase_deg']=math.degrees(cmath.phase(gbuf/gpre)); cmm(cbuf,'buf_cm')
            for k in ('bufp_V','bufn_V'):
                y=d[k][bisect.bisect_left(t,w0):bisect.bisect_right(t,w1)]; m[k[:-2]+'_min_V']=min(y); m[k[:-2]+'_max_V']=max(y)
        for k in ('fp_V','fn_V','op_V','on_V','vg_V','drlr_V'):
            y=d[k][bisect.bisect_left(t,w0):bisect.bisect_right(t,w1)]; m[k[:-2]+'_min_V']=min(y); m[k[:-2]+'_max_V']=max(y)
        y=R_(d['drlr_V']); m['drlr_avg_V']=sum(y)/len(y)
        outB.append({k:(('%.6g'%v) if isinstance(v,float) else v) for k,v in m.items()})
for name,data in (('r6d_stageA_summary.csv',outA),('r6d_stageB_summary.csv',outB)):
    if not data: continue
    keys=[]; [keys.append(k) for r in data for k in r if k not in keys]
    w=csv.DictWriter(open(name,'w',newline=''),fieldnames=keys,restval='n/a'); w.writeheader(); w.writerows(data)
for o in outA: print(o)
for o in outB: print({k:o[k] for k in o if any(s in k for s in ('case','window','gain','phase','H3','resid_rms','settle1pct_max','edge_err_max','cm_avg','200Hz','glitch_pos','Acd'))})
