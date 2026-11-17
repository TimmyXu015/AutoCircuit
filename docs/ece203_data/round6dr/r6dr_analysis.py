# R6D-R Stage B analysis (setting C: tran cmin 1e-17 F), same metric definitions as docs/ece203_data/round6d/r6d_analysis.py
# (copied, Stage A part removed, currents/power and sink headroom added). Writes r6dr_stageB_summary.csv and r6dr_ab_summary.csv.
# Usage (from this folder): python3 r6dr_analysis.py <dir with F_C_*_tran.csv(.gz)>
import csv, gzip, os, math, cmath, sys, bisect
RB=sys.argv[1] if len(sys.argv)>1 else 'raw'
def rows(f): return list(csv.DictReader(open(f)))
def cols(fn):
    if not os.path.exists(fn) and os.path.exists(fn+'.gz'): fn=fn+'.gz'
    r=csv.reader(gzip.open(fn,'rt') if fn.endswith('.gz') else open(fn)); h=next(r); c=list(zip(*[[float(x) for x in row] for row in r])); return {k:c[i] for i,k in enumerate(h)}
F=lambda x:float(x) if x not in ('n/a','',None) else None
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
cases=[('F_C_ref','REF',0),('F_C_direct_1p','DIRECT',1),('F_C_buf_1p','BUFFERED',1),('F_C_direct_10p','DIRECT',10),('F_C_buf_10p','BUFFERED',10)]
for tag,bench,cl in cases:
    fn=RB+'/%s_tran.csv'%tag
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
        if 'i_vdd_A' in d:
            iv=R_(d['i_vdd_A']); idd=R_(d['i_vddd_A']); m['I_VDD_nA']=-sum(iv)/len(iv)*1e9; m['I_VDDD_nA']=-sum(idd)/len(idd)*1e9
            m['P_total_uW_excl_ideal_CMFB']=(m['I_VDD_nA']+m['I_VDDD_nA'])*1.8e-3
        if hasb: m['sink_margin_min_V']=min(m['bufp_min_V'],m['bufn_min_V'])-0.1   # MKP/MKN VDS = buf; margin = VDS - max(VDSAT 0.05, 0.1)
        outB.append({k:(('%.6g'%v) if isinstance(v,float) else v) for k,v in m.items()})

keys=[]; [keys.append(k) for r in outB for k in r if k not in keys]
w=csv.DictWriter(open('r6dr_stageB_summary.csv','w',newline=''),fieldnames=keys,restval='n/a'); w.writeheader(); w.writerows(outB)
# DIRECT vs BUFFERED at the same load (40-60 ms window); "delivered output" = fp-fn for DIRECT, bufp-bufn for BUFFERED
S={(r['case'],r['window_ms']):r for r in outB}; ab=[]
def g(c,k): return S[(c,'40-60')].get(k,'n/a')
for cl in (1,10):
    D,B='F_C_direct_%dp'%cl,'F_C_buf_%dp'%cl
    if (D,'40-60') not in S or (B,'40-60') not in S: continue
    for lab,kd,kb in (('delivered 100 Hz gain','Hpre_gain','Hbuf_gain'),('delivered phase (deg)','Hpre_phase_deg','Hbuf_phase_deg'),
                      ('delivered H3 (dBc)','Hpre_H3_dBc','Hbuf_H3_dBc'),('delivered residual rms (uV)','Hpre_resid_rms_uV','Hbuf_resid_rms_uV'),
                      ('delivered residual / signal pp (%)',None,None),
                      ('edge error max (mV)','Hpre_edge_err_max_mV','Hbuf_edge_err_max_mV'),('settle to 1 % max (us)','Hpre_settle1pct_max_us','Hbuf_settle1pct_max_us'),
                      ('settle to 1 % median (us)','Hpre_settle1pct_median_us','Hbuf_settle1pct_median_us'),
                      ('original fp/fn gain Hpre','Hpre_gain','Hpre_gain'),('fp/fn CM avg (V)','fpfn_cm_avg_V','fpfn_cm_avg_V'),
                      ('delivered CM avg (V)','fpfn_cm_avg_V','buf_cm_avg_V'),('delivered CM edge spike (mV)','fpfn_cm_edge_glitch_pos_mV','buf_cm_edge_glitch_pos_mV'),
                      ('op/on CM 200 Hz (uV)','opon_cm_200Hz_uV','opon_cm_200Hz_uV'),('vg range (V)',None,None),('P total excl. ideal CMFB (uW)','P_total_uW_excl_ideal_CMFB','P_total_uW_excl_ideal_CMFB')):
        if lab=='delivered residual / signal pp (%)':
            dv=float(g(D,'Hpre_resid_pp_mV'))/(float(g(D,'Hpre_pp_V'))*1e3)*100; bv=float(g(B,'Hbuf_resid_pp_mV'))/(float(g(B,'Hbuf_pp_V'))*1e3)*100
            ab.append(dict(CL_pF=cl,metric=lab,DIRECT='%.4g'%dv,BUFFERED='%.4g'%bv)); continue
        if lab=='vg range (V)':
            ab.append(dict(CL_pF=cl,metric=lab,DIRECT='%s..%s'%(g(D,'vg_min_V'),g(D,'vg_max_V')),BUFFERED='%s..%s'%(g(B,'vg_min_V'),g(B,'vg_max_V')))); continue
        ab.append(dict(CL_pF=cl,metric=lab,DIRECT=g(D,kd),BUFFERED=g(B,kb)))
if ab:
    w=csv.DictWriter(open('r6dr_ab_summary.csv','w',newline=''),fieldnames=list(ab[0].keys())); w.writeheader(); w.writerows(ab)
    for r in ab: print(r)
