import csv, math
S='/mnt/user-data/uploads/AutoCircuit_Results/_raw/2026-11-16_ece203_round6a_drl_cmfb/ece203_r6a/'
D='docs/ece203_data/round6a/'
def rows(fn): return list(csv.reader(open(fn)))
# decimated D2 trans
for t in ['D2_vos1m_chen0','D2_vos1m_chen1']:
    r=rows(S+t+'_tran.csv'); out=[r[0]]+[x for i,x in enumerate(r[1:]) if i%6==0 or float(x[0])>18.5e-3]
    csv.writer(open(D+'stageD/'+t+'_tran_dec.csv','w',newline='')).writerows(out); print(t,len(r),len(out))
# cm_step_60hz: B vs C tran on a common grid (0.1 ms)
def wav(fn):
    r=list(csv.DictReader(open(fn))); return [(float(x['t_s']),float(x['e_in_V']),float(x['e_out_V']),float(x['vod_V'])) for x in r]
B=wav(D+'stageB/B1_real_indep_tran.csv'); C=wav(D+'stageC/C1_H2_ff_tran.csv')
def at(w,t):
    lo,hi=0,len(w)-1
    while hi-lo>1:
        m=(lo+hi)//2
        if w[m][0]<=t: lo=m
        else: hi=m
    a,b=w[lo],w[hi]; u=(t-a[0])/(b[0]-a[0]) if b[0]>a[0] else 0
    return [a[k]+u*(b[k]-a[k]) for k in (1,2,3)]
out=[['t_s','B_e_in_V','B_e_out_V','B_vod_V','C_e_in_V','C_e_out_V','C_vod_V']]
t=0.0
while t<=0.12+1e-12:
    out.append(['%.5g'%t]+['%.6g'%x for x in at(B,t)+at(C,t)]); t+=1e-4
csv.writer(open(D+'cm_step_60hz.csv','w',newline='')).writerows(out)
# ideal chop waveforms
r=rows(D+'stageD/D1_fdchop_2k_pss_td.csv'); csv.writer(open(D+'ideal_chop_waveforms.csv','w',newline='')).writerows(r)
# comparison
A={x['tag']:x for x in csv.DictReader(open(D+'stageA/r6a_stageA.csv'))}
Bd={x['tag']:x for x in csv.DictReader(open(D+'stageB/r6a_stageB_dist.csv'))}
Cd={x['tag']:x for x in csv.DictReader(open(D+'stageC/r6a_stageC_dist.csv'))}
Bg=list(csv.DictReader(open(D+'stageB/r6a_stageB.csv')))[0]; Cg=list(csv.DictReader(open(D+'stageC/r6a_stageC.csv')))[0]
def g(d,k): return '%.3g'%float(d[k]) if d.get(k) not in (None,'n/a','') else 'n/a'
cmp=[]
def row(name,ev,db,do,G=None,extra='',verdict=''):
    r=dict(config=name,evidence=ev,dbody_ein60_V=g(db,'ei_m60'),dbody_eout60_V=g(db,'eo_m60'),dbody_ein1_V=g(db,'ei_m1'),dbody_eout1_V=g(db,'eo_m1'),
           dota_ein1_V=g(do,'ei_m1'),dota_eout1_V=g(do,'eo_m1'),dota_ein60_V=g(do,'ei_m60'),dota_eout60_V=g(do,'eo_m60'))
    for k in ['tr_ei_pp','tr_eo_pp60','tr_vod_pp60','tr_eo_step','tr_ei_step','tr_eo_t90','Hdm100','CMRR60_dB','cmfb_ugf','cmfb_pm','drl_ugf','drl_pm','drl_lg60','I_VDD','I_VDDD']:
        r[k]=g(G,k) if G else 'n/a'
    r['extra_parts']=extra; r['verdict']=verdict; cmp.append(r)
row('plant, loops open (ideal actuators)','Spectre AC',A['A1_D_body'],A['A1_D_ota'],None,'-','reference (no control)')
row('ideal independent DRL + CMFB (K=1000 each)','Spectre AC, ideal VCVS controllers',A['A2_indep_dbody'],A['A2_indep_dota'],None,'2 controllers','both errors suppressed ~1000x')
row('ideal H0: one error e_in+e_out drives both actuators (K=1000)','Spectre AC, ideal VCVS controllers (analytic agrees)',A['A3_H0_dbody'],A['A3_H0_dota'],None,'1 controller','H0 BLOCKED: d_body e_in not suppressed; d_ota leaks to body')
row('B real independent: FD OTA + DD-pair CMFB + R4 DRL OTA','Spectre (real MOS; ideal VREF/VCAS/IB/IBD, ideal Rfb)',Bd['B1_real_dbody'],Bd['B1_real_dota'],Bg,'baseline','works (both loops stable, both disturbances held)')
row('C H2: B + CMFB reference fed from the DRL CM-sense node (kff 0.0101)','Spectre (real MOS + 2 passive R)',Cd['C1_H2_dbody'],Cd['C1_H2_dota'],Cg,'R(cm-vrc) 0.98 TOhm + R(vrc-VREF) 10 GOhm; shares the DRL CM sensor','WORKS BUT NO BENEFIT YET')
w=csv.DictWriter(open(D+'comparison.csv','w',newline=''),fieldnames=list(cmp[0].keys())); w.writeheader(); w.writerows(cmp)
for r in cmp: print(r['config'][:40],'|',r['dbody_ein60_V'],r['dbody_eout60_V'],'|',r['dota_ein1_V'],r['dota_eout1_V'],'|',r['tr_eo_pp60'],r['tr_vod_pp60'],r['CMRR60_dB'],r['cmfb_pm'])
