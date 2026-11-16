import csv, math, os, sys
bins=[0.1,0.168,0.282,0.473,0.794,1.33,2.24,3.76,6.31,10.6,17.8,29.9,50.2,84.3,141.6,250.0]
G=['OTA1_input_fn','OTA1_input_thermal','OTA1_mirror_fn','OTA1_mirror_thermal','OTA1_other','OTA2_fn','OTA2_thermal','Rfb','other']
def grp(dev,par):
    d=dev.replace('/','.').lstrip('.')
    th='fn' if par=='fn' else 'thermal'
    if d.startswith('XA.'):
        n=d.split('.')[1]
        if n in('M1','M2'): return 'OTA1_input_'+th
        if n in('M3','M4'): return 'OTA1_mirror_'+th
        return 'OTA1_other'
    if d.startswith('X2.'): return 'OTA2_'+th
    if d.startswith('RF'): return 'Rfb'
    return 'other'
def readH(fn):
    return [(float(x['f_Hz']),float(x['abs_Hout'])) for x in csv.DictReader(open(fn))]
def interp(H,f):
    for i in range(1,len(H)):
        if H[i][0]>=f:
            a,b=H[i-1],H[i]; t=(math.log(f)-math.log(a[0]))/(math.log(b[0])-math.log(a[0]))
            return math.exp(math.log(a[1])+t*(math.log(b[1])-math.log(a[1])))
    return H[-1][1]
def parse(fn):
    r=[]
    for line in open(fn):
        p=line.split()
        if len(p)>=3:
            try: r.append((p[0],p[1],float(p[2])))
            except ValueError: pass
    return r
cases=[('static (B1 CD, noise)','stageAB/ece203_r5/B1_CD_LP'),('D1 chop4k demod after OTA1 (pnoise sb30)','stageD/ece203_r5/D1_pss_pnoise'),
       ('D2 chop4k demod after OTA2 (pnoise sb30)','stageD/ece203_r5/D2_pss_pnoise'),('D2 sideband check (pnoise sb50)','stageD/ece203_r5/D2_pss_pnoise_sb50')]
rows=[]
for lab,base in cases:
    H=readH(base+'_ac.csv'); acc={g:0.0 for g in G}; outp={g:0.0 for g in G}
    for k in range(15):
        fc=math.sqrt(bins[k]*bins[k+1]); h=interp(H,fc)
        for dev,par,v in parse(base+'_ns_b%02d.txt'%k):
            g=grp(dev,par); acc[g]+=v/h**2; outp[g]+=v
    tot=sum(acc.values()); to=sum(outp.values())
    r={'case':lab,'tag':os.path.basename(base),'sum_in_uVrms':'%.4g'%(math.sqrt(tot)*1e6),'sum_out_mVrms':'%.4g'%(math.sqrt(to)*1e3)}
    for g in G: r[g+'_in_uVrms']='%.4g'%(math.sqrt(acc[g])*1e6); r[g+'_pct_in']='%.3g'%(100*acc[g]/tot)
    rows.append(r)
    print(lab,'| sum',r['sum_in_uVrms'],'uV |',' '.join('%s=%s(%s%%)'%(g,r[g+'_in_uVrms'],r[g+'_pct_in']) for g in G))
os.makedirs('stageD',exist_ok=True)
with open('stageD/r5_demod_noise_split.csv','w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
