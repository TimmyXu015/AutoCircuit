# Round 6B system tran analysis: 100 Hz gain by least-squares sine fit (+linear drift) over 20 ms windows,
# residual ripple, phase-wise settling, CM behaviour (incl. 200 Hz signal-synchronous component).
import csv, math, sys
def load(fn):
    r=csv.reader(open(fn)); h=next(r); cols=list(zip(*[[float(x) for x in row] for row in r]))
    return {k:cols[i] for i,k in enumerate(h)}
def lsq(t,y,f,harm=(1,)):
    # fit y = c0 + c1*t + sum a_k sin + b_k cos  (normal equations, small)
    basis=[lambda x:1.0, lambda x:x]
    for k in harm:
        basis+= [ (lambda kk: (lambda x: math.sin(2*math.pi*kk*f*x)))(k), (lambda kk: (lambda x: math.cos(2*math.pi*kk*f*x)))(k)]
    n=len(basis); A=[[0.0]*n for _ in range(n)]; b=[0.0]*n
    for x,v in zip(t,y):
        phi=[g(x) for g in basis]
        for i in range(n):
            b[i]+=phi[i]*v
            for j in range(n): A[i][j]+=phi[i]*phi[j]
    # gauss
    M=[row[:]+[bb] for row,bb in zip(A,b)]
    for i in range(n):
        p=max(range(i,n),key=lambda r:abs(M[r][i])); M[i],M[p]=M[p],M[i]
        for r in range(n):
            if r!=i:
                fct=M[r][i]/M[i][i]
                for c in range(i,n+1): M[r][c]-=fct*M[i][c]
    c=[M[i][n]/M[i][i] for i in range(n)]
    fit=[sum(ci*g(x) for ci,g in zip(c,basis)) for x in t]
    return c,fit
def analyse(fn,fch,t0=0.040,t1=0.060,label=''):
    d=load(fn); t=d['t_s']
    idx=[i for i,x in enumerate(t) if t0<=x<=t1]
    # uniform resample (1 us) to avoid weighting dense edge regions
    import bisect
    def res(arr):
        out=[];tt=[];x=t0
        while x<=t1:
            i=bisect.bisect_left(t,x); i=min(max(i,1),len(t)-1); a,b=t[i-1],t[i]; u=(x-a)/(b-a) if b>a else 0
            out.append(arr[i-1]+u*(arr[i]-arr[i-1])); tt.append(x); x+=1e-6
        return tt,out
    tt,vid=res(d['vid_V']); _,vod=res(d['vod_V']); _,ocm=res(d['ocm_V']); _,icm=res(d['icm_V'])
    ci,_=lsq(tt,vid,100.0); co,fit=lsq(tt,vod,100.0)
    ai=complex(ci[3],ci[2]); ao=complex(co[3],co[2])   # cos + j sin
    g=ao/ai
    resid=[v-f for v,f in zip(vod,fit)]
    cc,cfit=lsq(tt,ocm,100.0,harm=(1,2))
    a200=math.hypot(cc[4],cc[5]); a100=math.hypot(cc[2],cc[3])
    cres=[v-f for v,f in zip(ocm,cfit)]
    return dict(case=label,fch=fch,window_ms='%g-%g'%(t0*1e3,t1*1e3),gain_100Hz=abs(g),gain_phase_deg=math.degrees(math.atan2(g.imag,g.real)),
                vod_drift_V_per_s=co[1],vod_offset_V=co[0]+co[1]*(t0+t1)/2,
                vod_ripple_pp_mV=(max(resid)-min(resid))*1e3,vod_ripple_rms_uV=math.sqrt(sum(x*x for x in resid)/len(resid))*1e6,
                ocm_avg_V=sum(ocm)/len(ocm),ocm_100Hz_mV=a100*1e3,ocm_200Hz_mV=a200*1e3,ocm_resid_pp_mV=(max(cres)-min(cres))*1e3,
                icm_pp_mV=(max(icm)-min(icm))*1e3)
if __name__=='__main__':
    out=[]
    for fn,f,lab in [(a.split(':')[0],float(a.split(':')[1]),a.split(':')[2]) for a in sys.argv[2:]]:
        for w in [(0.020,0.040),(0.040,0.060)]:
            r=analyse(fn,f,w[0],w[1],lab); out.append(r); print({k:(round(v,6) if isinstance(v,float) else v) for k,v in r.items()})
    w=csv.DictWriter(open(sys.argv[1],'w',newline=''),fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
