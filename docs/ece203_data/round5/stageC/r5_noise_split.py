# Round 5 stage C: per-source noise de-embedding from 15 log sub-band NoiseSummary files (0.1-250 Hz).
# For each bin k: V2_out(source, bin) / |Hdm_out(f_center)|^2 summed over bins -> input-referred power per source.
# Groups by instance prefix: XA.M1/M2 (OTA1 input NMOS), XA.M3/M4 (OTA1 PMOS mirror), XA.* other, X2.* (OTA2), RF* (Rfb).
# "OTA2 own input-referred (approx)": V2_out(OTA2)/|Hout/Hoa1|^2 using the in-loop DM transfer from OTA1 output to out.
# Run in the folder with <tag>_ns_bNN.txt and <tag>_ac.csv files (the raw data stays in the lab notebook _raw folder).
import csv, math
bins=[0.1,0.168,0.282,0.473,0.794,1.33,2.24,3.76,6.31,10.6,17.8,29.9,50.2,84.3,141.6,250.0]
def grp(dev,par):
    d=dev.replace('/','.').lstrip('.')
    if d.startswith('XA.'):
        n=d.split('.')[1]
        if n in('M1','M2'): return 'OTA1_input_NMOS_'+('fn' if par=='fn' else 'thermal')
        if n in('M3','M4'): return 'OTA1_mirror_PMOS_'+('fn' if par=='fn' else 'thermal')
        return 'OTA1_other'
    if d.startswith('X2.'): return 'OTA2_'+('fn' if par=='fn' else 'thermal')
    if d.startswith('RF'): return 'Rfb'
    return 'other'
def readH(tag):
    return [(float(x['f_Hz']),float(x['abs_Hout']),float(x['abs_Hoa1'])) for x in csv.DictReader(open(tag+'_ac.csv'))]
def interp(H,f,col):
    for i in range(1,len(H)):
        if H[i][0]>=f:
            a,b=H[i-1],H[i]; t=(math.log(f)-math.log(a[0]))/(math.log(b[0])-math.log(a[0]))
            return math.exp(math.log(a[col])+t*(math.log(b[col])-math.log(a[col])))
    return H[-1][col]
def parse(fn):
    rows=[]
    for line in open(fn):
        p=line.split()
        if len(p)>=3:
            try: rows.append((p[0],p[1],float(p[2])))
            except ValueError: pass
    return rows
# (same loop as used to produce r5_noise_stage_contributions.csv; see the Round 5 report)
