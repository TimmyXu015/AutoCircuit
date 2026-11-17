# Round 6A stage A: 2x2 CM plant P(f) and open-loop disturbance responses (Spectre AC, ideal actuators, real MOS FD OTA),
# then closed loop e = (I + P C)^-1 d for: independent diagonal control, H0 single error e = e_in + a*e_out with fixed
# actuator split, for several a. "Analytic from Spectre plant": static gains, stability not evaluated.
import csv, cmath, math, sys
D=sys.argv[1] if len(sys.argv)>1 else 'docs/ece203_data/round6a/stageA/'
def rd(fn):
    out={}
    for x in csv.DictReader(open(D+fn)):
        f=float(x['f_Hz'])
        out[f]=(cmath.rect(float(x['abs_ei']),math.radians(float(x['ph_ei']))),cmath.rect(float(x['abs_eo']),math.radians(float(x['ph_eo']))))
    return out
Pb=rd('A1_P_ubody_ac.csv'); Po=rd('A1_P_uota_ac.csv'); Db=rd('A1_D_body_ac.csv'); Do=rd('A1_D_ota_ac.csv')
sims={k:rd(k+'_ac.csv') for k in ['A2_indep_dbody','A2_indep_dota','A3_H0_dbody','A3_H0_dota']}
def near(d,f): return d[min(d,key=lambda k:abs(math.log(k/f)))]
def solve(P,C,d):
    # M = I + P C ; e = M^-1 d
    a=1+P[0][0]*C[0][0]+P[0][1]*C[1][0]; b=P[0][0]*C[0][1]+P[0][1]*C[1][1]
    c=P[1][0]*C[0][0]+P[1][1]*C[1][0]; dd=1+P[1][0]*C[0][1]+P[1][1]*C[1][1]
    det=a*dd-b*c
    return ((dd*d[0]-b*d[1])/det,(-c*d[0]+a*d[1])/det)
K=1000.0
rows=[]; cm=[]
for f in [0.001,1.0,60.0]:
    pb=near(Pb,f); po=near(Po,f)
    P=[[pb[0],po[0]],[pb[1],po[1]]]
    det=P[0][0]*P[1][1]-P[0][1]*P[1][0]
    sv=[abs(x) for x in (P[0][0],P[0][1],P[1][0],P[1][1])]
    cm.append(dict(f_Hz=f,P11_ubody_to_ein='%.4g<%.1f'%(abs(P[0][0]),math.degrees(cmath.phase(P[0][0]))),
       P12_uota_to_ein='%.4g<%.1f'%(abs(P[0][1]),math.degrees(cmath.phase(P[0][1]))),
       P21_ubody_to_eout='%.4g<%.1f'%(abs(P[1][0]),math.degrees(cmath.phase(P[1][0]))),
       P22_uota_to_eout='%.4g<%.1f'%(abs(P[1][1]),math.degrees(cmath.phase(P[1][1]))),
       det_abs='%.4g'%abs(det),RGA11='%.4g'%abs(P[0][0]*P[1][1]/det),
       Dbody_ein='%.4g'%abs(near(Db,f)[0]),Dbody_eout='%.4g'%abs(near(Db,f)[1]),Dota_ein='%.4g'%abs(near(Do,f)[0]),Dota_eout='%.4g'%abs(near(Do,f)[1]),
       evidence='Spectre AC (real MOS FD OTA + CMFB DC; ideal actuators, loops open at f>=1 mHz)'))
    cfgs=[('independent (diag K=1000)',[[K,0],[0,-K]])]
    for a in [0.01,0.1,1.0,10.0]:
        cfgs.append(('H0 single error e_in+%g*e_out'%a,[[K,K*a],[-K,-K*a]]))
    for name,C in cfgs:
        for dn,dist in [('d_body 0.1 uA',near(Db,f)),('d_ota 1 nA/side',near(Do,f))]:
            e=solve(P,C,dist)
            rows.append(dict(f_Hz=f,controller=name,disturbance=dn,ein_open='%.4g'%abs(dist[0]),eout_open='%.4g'%abs(dist[1]),
                             ein_cl='%.4g'%abs(e[0]),eout_cl='%.4g'%abs(e[1]),evidence='analytic from Spectre plant (static gains)'))
# Spectre check rows
for k,v in sims.items():
    for f in [0.001,1.0,60.0]:
        e=near(v,f)
        rows.append(dict(f_Hz=f,controller=('independent (diag K=1000)' if 'indep' in k else 'H0 single error e_in+1*e_out')+' [Spectre ideal VCVS]',
                         disturbance='d_body 0.1 uA' if 'dbody' in k else 'd_ota 1 nA/side',ein_open='',eout_open='',ein_cl='%.4g'%abs(e[0]),eout_cl='%.4g'%abs(e[1]),evidence='Spectre AC, ideal controllers'))
O=D.rstrip('/').rsplit('/',1)[0]+'/'
for fn,data in [('control_matrix.csv',cm),('r6a_stageA_closedloop.csv',rows)]:
    w=csv.DictWriter(open(O+fn,'w',newline=''),fieldnames=list(data[0].keys())); w.writeheader(); w.writerows(data)
for r in cm: print(r)
for r in rows:
    if r['f_Hz']==60.0: print(r['controller'],'|',r['disturbance'],'| ein',r['ein_cl'],'eout',r['eout_cl'])
