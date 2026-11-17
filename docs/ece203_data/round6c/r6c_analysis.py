# Round 6C-I analysis: Stage A loop metrics from the stb CSV, Stage B/C tran metrics (sine fits, CM 200 Hz, edge glitches).
# Usage (from this folder): python3 r6c_analysis.py <raw_dir>   -> writes r6c_*.csv here
import csv, gzip, os, math, cmath, sys, bisect
R=sys.argv[1] if len(sys.argv)>1 else 'raw'
def rows(f): return list(csv.DictReader(open(f)))
def cols(fn):
    if not os.path.exists(fn) and os.path.exists(fn+'.gz'): fn=fn+'.gz'
    r=csv.reader(gzip.open(fn,'rt') if fn.endswith('.gz') else open(fn)); h=next(r); c=list(zip(*[[float(x) for x in row] for row in r])); return {k:c[i] for i,k in enumerate(h)}
# ---------- Stage A: loop gain ----------
def lg(fn):
    d=[(float(r['f_Hz']),float(r['abs_LG'])*cmath.exp(1j*math.radians(float(r['ph_LG'])))) for r in rows(fn)]; return d
def at(d,f): return min(d,key=lambda x:abs(math.log(x[0]/f)))[1]
def loopmetrics(fn):
    d=lg(fn); plateau=abs(at(d,10.0)); out={'LG_1mHz':abs(d[0][1]),'LG_10Hz':plateau}
    p3=None; ugf=pm=None; gmf=gm=None
    for (f0,a),(f1,b) in zip(d,d[1:]):
        if p3 is None and f0>=10 and abs(a)>=plateau/math.sqrt(2)>abs(b): p3=f1
        if ugf is None and abs(a)>=1>abs(b): ugf=f1; pm=math.degrees(cmath.phase(b))
        # gain margin: where the return-ratio phase (DC reference -180) reaches 0 deg, i.e. cmath phase crosses 0 from +
        if ugf and gmf is None and math.degrees(cmath.phase(a))>0>=math.degrees(cmath.phase(b)) and f1>ugf: gmf=f1; gm=-20*math.log10(abs(b))
    out.update(f_dom_3dB=p3,UGF=ugf,PM=pm,GBW_from_dom=(plateau*p3 if p3 else None),f_phase_minus180_rel=gmf,GM_dB=gm)
    # excess phase beyond a single dominant pole at the UGF (= poles/zeros above the dominant one)
    if ugf: out['excess_phase_at_UGF_deg']=90.0-pm
    for f in (1e5,1e6,1e7): out['excess_phase_%gHz'%f]=90.0-math.degrees(cmath.phase(at(d,f)))+(0 if math.degrees(cmath.phase(at(d,f)))>-90 else 0)
    return out
A=rows(R+'/r6c_stageA.csv'); outA=[]
for r in A:
    t=r['tag']; m=loopmetrics(R+'/%s_stb_cmfb.csv'%t); dr=loopmetrics(R+'/%s_stb_drl.csv'%t)
    o=dict(case=t,cmfb=r['cmfb'],op_V=r['op'],on_V=r['on'],vout_cm_V=r['ocm'],vout_cm_err_mV='%.3f'%((float(r['ocm'])-0.9)*1e3),vg_V=r['vg'],
           Hdm100=r['Hdm100'],Hdm100_vs_R6B_94p56_pct='%.3f'%((float(r['Hdm100'])/94.5581-1)*100),CMRR60_dB=r['CMRR60_dB'],
           M3M4_VSD_V=r['m3_vsd'],M3M4_VDSAT_V=r['m3_vdsat'],M3M4_margin_V=r['m3_margin'],OTA_min_margin=r['minA']+' ('+r['worstA']+')',
           I_VDD_nA='%.1f'%(float(r['I_VDD'])*1e9),I_VDDD_nA='%.1f'%(float(r['I_VDDD'])*1e9),
           cmfb_LG_10Hz='%.1f'%m['LG_10Hz'],cmfb_LG_1mHz='%.1f'%m['LG_1mHz'],cmfb_f_dom_Hz='%.4g'%m['f_dom_3dB'],cmfb_UGF_Hz=r['cmfb_ugf'],cmfb_PM_deg=r['cmfb_pm'],
           cmfb_excess_phase_at_UGF_deg='%.1f'%m['excess_phase_at_UGF_deg'],cmfb_GM_dB=('%.1f'%m['GM_dB'] if m['GM_dB'] else 'n/a'),cmfb_GM_f_Hz=('%.4g'%m['f_phase_minus180_rel'] if m['f_phase_minus180_rel'] else 'n/a'),
           drl_UGF_Hz=r['drl_ugf'],drl_PM_deg=r['drl_pm'],drl_LG60=r['drl_lg60'],
           dist_eo_mV_per_nA_1Hz='%.4f'%(float(r['dz_eo_1'])*1e3),dist_eo_mV_per_nA_1kHz='%.4f'%(float(r['dz_eo_1k'])*1e3),dist_eo_mV_per_nA_100kHz='%.4f'%(float(r['dz_eo_100k'])*1e3),
           dist_vod_uV_per_nA_1Hz='%.3g'%(float(r['dz_vod_1'])*1e6),
           step_eo_mV='%.4f'%(float(r['st_eo_step'])*1e3),step_vg_mV='%.4f'%(float(r['st_vg_step'])*1e3),step_t90_us='%.3f'%(float(r['st_t90'])*1e6),
           step_overshoot_pct='%.2f'%((float(r['st_eo_pk'])/float(r['st_eo_step'])-1)*100),step_vod_peak_uV='%.3g'%(float(r['st_vod_pk'])*1e6),step_end_pp_uV='%.3g'%(float(r['st_eo_pp_end'])*1e6))
    outA.append(o)
# ---------- Stage B/C: tran ----------
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
    out=[];tt=[];x=t0
    while x<=t1+1e-12:
        i=bisect.bisect_left(t,x); i=min(max(i,1),len(t)-1); a,b=t[i-1],t[i]; u=(x-a)/(b-a) if b>a else 0
        out.append(arr[i-1]+u*(arr[i]-arr[i-1])); tt.append(x); x+=dt
    return tt,out
def window(d,t0,t1,dt):
    t=d['t_s']; g={k:resamp(t,d[k],t0,t1,dt)[1] for k in ('vid_V','vod_V','ocm_V','vg_V','op_V','on_V')}; tt=resamp(t,d['vid_V'],t0,t1,dt)[0]
    ci,_=lsq(tt,g['vid_V'],100.0); co,fit=lsq(tt,g['vod_V'],100.0); gain=complex(co[3],co[2])/complex(ci[3],ci[2])
    res=[v-f for v,f in zip(g['vod_V'],fit)]
    cc,cf=lsq(tt,g['ocm_V'],100.0,harm=(1,2)); cres=[v-f for v,f in zip(g['ocm_V'],cf)]
    cg,_=lsq(tt,g['vg_V'],100.0,harm=(1,2))
    return dict(window_ms='%g-%g'%(t0*1e3,t1*1e3),gain_100Hz=abs(gain),gain_phase_deg=math.degrees(cmath.phase(gain)),
        vod_ripple_rms_uV=math.sqrt(sum(x*x for x in res)/len(res))*1e6,vod_ripple_pp_mV=(max(res)-min(res))*1e3,
        ocm_avg_V=sum(g['ocm_V'])/len(tt),ocm_dev_from_0p9_mV=(sum(g['ocm_V'])/len(tt)-0.9)*1e3,ocm_100Hz_mV=math.hypot(cc[2],cc[3])*1e3,ocm_200Hz_mV=math.hypot(cc[4],cc[5])*1e3,
        ocm_pp_mV=(max(g['ocm_V'])-min(g['ocm_V']))*1e3,ocm_resid_pp_mV=(max(cres)-min(cres))*1e3,ocm_drift_mV_per_s=cc[1]*1e3,
        vg_avg_V=sum(g['vg_V'])/len(tt),vg_pp_mV=(max(g['vg_V'])-min(g['vg_V']))*1e3,vg_200Hz_mV=math.hypot(cg[4],cg[5])*1e3,
        vg_min_V=min(g['vg_V']),vg_max_V=max(g['vg_V']),op_min_V=min(g['op_V']),op_max_V=max(g['op_V']),on_min_V=min(g['on_V']),on_max_V=max(g['on_V']),
        vod_out_pp_V=max(g['vod_V'])-min(g['vod_V']))
def glitches(d,t0,t1,tch=500e-6):
    # every TG edge (phase change at k*tch/2, A-off then B-on 10 ns later): local CM baseline = straight line between the
    # mean of ocm over [te-20us, te-1us] and over [te+40us, te+60us] (removes the slow 100/200 Hz CM components);
    # glitch = largest +/- excursion from that line in [te-50ns, te+40us]; recovery = last time the excursion exceeds
    # 1 mV / 0.1 mV, measured from the edge
    t=d['t_s']; o=d['ocm_V']; vg=d['vg_V']; pos=[]; neg=[]; rec1=[]; rec01=[]; vgx=[]
    def mean(a,b):
        i,j=bisect.bisect_left(t,a),bisect.bisect_left(t,b); return sum(o[i:j])/max(1,j-i),(t[i]+t[j-1])/2
    k=math.ceil((t0+30e-6)/(tch/2))
    while k*tch/2+70e-6<=t1:
        te=k*tch/2; m0,c0=mean(te-20e-6,te-1e-6); m1,c1=mean(te+40e-6,te+60e-6)
        i0=bisect.bisect_left(t,te-50e-9); i1=bisect.bisect_left(t,te+40e-6)
        seg=[(t[i]-te,o[i]-(m0+(m1-m0)*(t[i]-c0)/(c1-c0))) for i in range(i0,i1)]
        pos.append(max(v for _,v in seg)); neg.append(min(v for _,v in seg))
        rec1.append(max([dt for dt,v in seg if abs(v)>1e-3],default=0.0)); rec01.append(max([dt for dt,v in seg if abs(v)>1e-4],default=0.0))
        vgx.append(max(vg[i0:i1])-min(vg[i0:i1]))
        k+=1
    return dict(edges=len(pos),glitch_pos_max_mV=max(pos)*1e3,glitch_pos_mean_mV=sum(pos)/len(pos)*1e3,glitch_neg_max_mV=min(neg)*1e3,
                recover_1mV_max_us=max(rec1)*1e6,recover_0p1mV_max_us=max(rec01)*1e6,vg_edge_excursion_max_mV=max(vgx)*1e3)
outT=[]
for st,tags in (('B',('B_old','B_ideal')),('C',('C_old','C_ideal'))):
    for tg in tags:
        try: d=cols(R+'/%s_tran.csv'%tg)
        except FileNotFoundError: continue
        for w in ((0.020,0.040),(0.040,0.060)):
            m=dict(stage=st,case=tg); m.update(window(d,w[0],w[1],1e-6))
            if st=='C': m.update(glitches(d,w[0],w[1]))
            outT.append({k:(('%.6g'%v) if isinstance(v,float) else v) for k,v in m.items()})
for name,data in (('r6c_stageA_summary.csv',outA),('r6c_tran_summary.csv',outT)):
    keys=[]; [keys.append(k) for r in data for k in r if k not in keys]
    w=csv.DictWriter(open(name,'w',newline=''),fieldnames=keys); w.writeheader(); w.writerows(data)
for o in outA: print(o)
for o in outT: print(o)
# ---------- A/B summary (old vs new) ----------
a={r['case']:r for r in outA}; tr={(r['case'],r['window_ms']):r for r in outT}
def g(d,k): return float(d[k])
ab=[]
def add(stage,metric,unit,o,n,better):
    ab.append(dict(stage=stage,metric=metric,unit=unit,old_DDpair=o,new_ideal=n,ratio_new_over_old=('%.4g'%(float(n)/float(o)) if float(o)!=0 else 'n/a'),better=better))
add('A','Vout,cm DC','V',a['A_old']['vout_cm_V'],a['A_ideal']['vout_cm_V'],'closer to 0.900')
add('A','Hdm(100 Hz)','V/V',a['A_old']['Hdm100'],a['A_ideal']['Hdm100'],'equal')
add('A','CMRR60','dB',a['A_old']['CMRR60_dB'],a['A_ideal']['CMRR60_dB'],'equal')
add('A','CMFB loop gain at 10 Hz','V/V',a['A_old']['cmfb_LG_10Hz'],a['A_ideal']['cmfb_LG_10Hz'],'higher')
add('A','CMFB UGF','Hz',a['A_old']['cmfb_UGF_Hz'],a['A_ideal']['cmfb_UGF_Hz'],'higher')
add('A','CMFB PM','deg',a['A_old']['cmfb_PM_deg'],a['A_ideal']['cmfb_PM_deg'],'higher')
add('A','DRL PM','deg',a['A_old']['drl_PM_deg'],a['A_ideal']['drl_PM_deg'],'equal')
add('A','e_out per 1 nA/side output-CM current (1 Hz)','mV/nA',a['A_old']['dist_eo_mV_per_nA_1Hz'],a['A_ideal']['dist_eo_mV_per_nA_1Hz'],'lower')
add('A','output-CM step t90','us',a['A_old']['step_t90_us'],a['A_ideal']['step_t90_us'],'lower')
for st,o,n in (('B','B_old','B_ideal'),('C','C_old','C_ideal')):
    O=tr[(o,'40-60')]; N=tr[(n,'40-60')]
    add(st,'100 Hz DM gain (40-60 ms sine fit)','V/V',O['gain_100Hz'],N['gain_100Hz'],'equal/higher')
    add(st,'Vout,cm average - 0.9 V','mV',O['ocm_dev_from_0p9_mV'],N['ocm_dev_from_0p9_mV'],'closer to 0')
    add(st,'Vout,cm 200 Hz component','mV',O['ocm_200Hz_mV'],N['ocm_200Hz_mV'],'lower')
    add(st,'Vout,cm peak-to-peak','mV',O['ocm_pp_mV'],N['ocm_pp_mV'],'lower')
    add(st,'VCMFB peak-to-peak','mV',O['vg_pp_mV'],N['vg_pp_mV'],'info')
    add(st,'Vod residual after 100 Hz fit (rms)','uV',O['vod_ripple_rms_uV'],N['vod_ripple_rms_uV'],'lower')
    if st=='C':
        add(st,'TG-edge CM glitch, positive peak (max over edges)','mV',O['glitch_pos_max_mV'],N['glitch_pos_max_mV'],'lower')
        add(st,'TG-edge CM glitch, negative peak','mV',O['glitch_neg_max_mV'],N['glitch_neg_max_mV'],'closer to 0')
        add(st,'TG-edge recovery to 1 mV (max over edges)','us',O['recover_1mV_max_us'],N['recover_1mV_max_us'],'lower')
        add(st,'TG-edge recovery to 0.1 mV (max over edges)','us',O['recover_0p1mV_max_us'],N['recover_0p1mV_max_us'],'lower')
w=csv.DictWriter(open('r6c_ab_summary.csv','w',newline=''),fieldnames=list(ab[0].keys())); w.writeheader(); w.writerows(ab)
for r in ab: print(r)
