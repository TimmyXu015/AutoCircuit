# Round 6B unit TG chopper analysis from raw Spectre tran (inp, inn, outp, outn, clocks, currents).
import csv, sys, math
def load(fn):
    r=csv.reader(open(fn)); h=next(r); cols=list(zip(*[[float(x) for x in row] for row in r]))
    return {k:cols[i] for i,k in enumerate(h)}
def analyse(fn, fch, vcm):
    d=load(fn); t=d['t_s']; vid=[a-b for a,b in zip(d['inp_V'],d['inn_V'])]; vod=[a-b for a,b in zip(d['outp_V'],d['outn_V'])]
    cm=[(a+b)/2 for a,b in zip(d['outp_V'],d['outn_V'])]
    tch=1/fch; import bisect
    def at(arr,tt):
        i=bisect.bisect_left(t,tt); i=min(max(i,1),len(t)-1); a,b=t[i-1],t[i]; u=(tt-a)/(b-a) if b>a else 0
        return arr[i-1]+u*(arr[i]-arr[i-1])
    gA=[];gB=[];err=[]
    k=0
    while (k+1)*tch<=t[-1]:
        for ph,frac,lst,sg in (('A',0.45,gA,1),('B',0.95,gB,-1)):
            tt=k*tch+frac*tch; vi=at(vid,tt); vo=at(vod,tt)
            if abs(vi)>0.3e-3: lst.append(vo/vi); err.append(vo-sg*vi)
        k+=1
    # feedthrough / settling: after each edge, max |vod - sign*vid| in the first 2 us, and time until < 1 uV
    ft=[];cmsp=[];tset=[]
    edges=[k*tch/2 for k in range(1,int(t[-1]/(tch/2)))]
    for e in edges:
        sg = 1 if (round(e/(tch/2))%2==0) else -1   # after an edge at k*tch/2: even k -> phase A
        i0=bisect.bisect_left(t,e-20e-9); i1=bisect.bisect_left(t,e+2e-6)
        ft.append(max(abs(vod[i])-abs(vid[i]) for i in range(i0,i1))); cmsp.append(max(abs(cm[i]-vcm) for i in range(i0,i1)))
        ts=None
        for i in range(i1-1,i0,-1):
            if abs(vod[i]-sg*vid[i])>1e-6: ts=t[i]-e; break
        tset.append(ts if ts is not None else 0.0)
    tq=lambda c: sum(c)/len(c)
    iv=d['i_vdd_A']; ia=d['i_cka_A']
    # charge per edge from clock source current
    return dict(file=fn.split('/')[-1],fch=fch,vcm=vcm,n_phaseA=len(gA),gainA_mean=tq(gA),gainA_min=min(gA),gainA_max=max(gA),
                n_phaseB=len(gB),gainB_mean=tq(gB),gainB_min=min(gB),gainB_max=max(gB),
                settled_err_max_uV=max(abs(x) for x in err)*1e6,edge_dm_overshoot_max_mV=max(ft)*1e3,
                edge_cm_spike_max_mV=max(cmsp)*1e3,settle_to_1uV_max_ns=max(tset)*1e9,
                i_vdd_avg_A=tq(iv),i_cka_rms_A=math.sqrt(tq([x*x for x in ia])))
if __name__=='__main__':
    rows=[]
    for fn,f,v in [(sys.argv[1]+'/U2_2k_vcm0p9_tran.csv',2000,0.9),(sys.argv[1]+'/U3_4k_vcm0p9_tran.csv',4000,0.9),(sys.argv[1]+'/U4_2k_vcm1p05_tran.csv',2000,1.05)]:
        try: rows.append(analyse(fn,f,v)); print(rows[-1])
        except Exception as e: print(fn,e)
    w=csv.DictWriter(open(sys.argv[2],'w',newline=''),fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
