# Round 5N: per-source noise referred to the ECG input, sub-band de-embedding (15 log bins 0.1-250 Hz,
# V^2_out(source, bin) / |Hdm(fc)|^2 summed). Groups by instance prefix.
import csv, math, sys, glob, os
bins=[0.1,0.168,0.282,0.473,0.794,1.33,2.24,3.76,6.31,10.6,17.8,29.9,50.2,84.3,141.6,250.0]
G=['OTA1_input_fn','OTA1_input_thermal','OTA1_mirror_fn','OTA1_mirror_thermal','OTA1_other','OTA2','pseudoR','electrodes_R','DRL_and_bias','other']
def grp(dev,par):
    d=dev.replace('/','.').lstrip('.'); th='fn' if par=='fn' else 'thermal'
    if d.startswith('XA.'):
        n=d.split('.')[1]
        if n in('M1','M2'): return 'OTA1_input_'+th
        if n in('M3','M4'): return 'OTA1_mirror_'+th
        return 'OTA1_other'
    if d.startswith('X2.'): return 'OTA2'
    if d.startswith('XPP') or d.startswith('XPN'): return 'pseudoR'
    if d[:3] in ('REP','REN','RSP','RSN','RER','RSR'): return 'electrodes_R'
    if d.startswith('XD') or d.startswith('MP') or d[:2] in ('RV','RC') or d.startswith('RCM') or d.startswith('RDR'): return 'DRL_and_bias'
    return 'other'
def readH(tag): return [(float(x['f_Hz']),float(x['abs_Hout'])) for x in csv.DictReader(open(tag+'_ac.csv'))]
def interp(H,f):
    for i in range(1,len(H)):
        if H[i][0]>=f:
            a,b=H[i-1],H[i]; t=(math.log(f)-math.log(a[0]))/(math.log(b[0])-math.log(a[0])); return math.exp(math.log(a[1])+t*(math.log(b[1])-math.log(a[1])))
    return H[-1][1]
def parse(fn):
    r=[]
    for line in open(fn):
        p=line.split()
        if len(p)>=3:
            try: r.append((p[0],p[1],float(p[2])))
            except ValueError: pass
    return r
out=[]
for tag in sys.argv[2:]:
    H=readH(tag); acc={g:0.0 for g in G}; top={}
    for k in range(15):
        fc=math.sqrt(bins[k]*bins[k+1]); h=interp(H,fc)
        for dev,par,v in parse('%s_ns_b%02d.txt'%(tag,k)):
            g=grp(dev,par); acc[g]+=v/h**2; top[(dev,par)]=top.get((dev,par),0)+v/h**2
    tot=sum(acc.values())
    r={'tag':tag,'total_in_uVrms':'%.4g'%(math.sqrt(tot)*1e6)}
    for g in G: r[g+'_uV']='%.3g'%(math.sqrt(acc[g])*1e6); r[g+'_pct']='%.3g'%(100*acc[g]/tot)
    t3=sorted(top.items(),key=lambda x:-x[1])[:4]
    r['top4']=' | '.join('%s %s %.2g%%'%(k[0],k[1],100*v/tot) for k,v in t3)
    out.append(r); print(tag, r['total_in_uVrms'], ' '.join('%s=%s(%s%%)'%(g,r[g+'_uV'],r[g+'_pct']) for g in G if float(r[g+'_pct'])>0.5), '| top:', r['top4'])
w=csv.DictWriter(open(sys.argv[1],'w',newline=''),fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
