# R6D-R short consistency: setting C (tran cmin 1e-17 F) vs the R6D default-trap runs (setting A) over 0-1 ms.
# Criteria fixed before comparison: outside +-2 us around each TG edge (k*250 us, k = 1..4 incl. the 1 ms end point), max |delta| < 0.1 mV for
# (fp-fn), (fp+fn)/2, (op+on)/2, vg; TG-edge (op+on)/2 spike peak within 10 %.
# Usage: python3 r6dr_consistency.py <old_dir (R6D attempt1 trap)> <new_dir (R6D-R out)>
import csv, gzip, os, sys, bisect, math
O,N=sys.argv[1],sys.argv[2]
def cols(fn):
    if not os.path.exists(fn) and os.path.exists(fn+'.gz'): fn=fn+'.gz'
    r=csv.reader(gzip.open(fn,'rt') if fn.endswith('.gz') else open(fn)); h=next(r); c=list(zip(*[[float(x) for x in row] for row in r])); return {k:c[i] for i,k in enumerate(h)}
def interp(t,y,x):
    i=bisect.bisect_left(t,x); i=min(max(i,1),len(t)-1); a,b=t[i-1],t[i]; u=(x-a)/(b-a) if b>a else 0; return y[i-1]+u*(y[i]-y[i-1])
def sig(d):
    return {'vpre':[a-b for a,b in zip(d['fp_V'],d['fn_V'])],'fpfn_cm':[(a+b)/2 for a,b in zip(d['fp_V'],d['fn_V'])],
            'opon_cm':[(a+b)/2 for a,b in zip(d['op_V'],d['on_V'])],'vg':list(d['vg_V'])}
def edge_peak(t,y,te):
    i0,i1=bisect.bisect_left(t,te-30e-9),bisect.bisect_left(t,te+2e-6); j0,j1=bisect.bisect_left(t,te-5e-6),bisect.bisect_left(t,te-1e-6)
    base=sum(y[j0:j1])/max(1,j1-j0); return max(abs(v-base) for v in y[i0:i1])
rows=[]
for old,new,lab in (('B_ref','S_C_ref','REF'),('B_direct_1p','S_C_direct_1p','DIRECT 1 pF'),('S_C_ref','S_C_buf_1p','BUFFERED 1 pF vs REF (both C)')):
    a=cols((O if old.startswith('B_') else N)+'/%s_tran.csv'%old); b=cols(N+'/%s_tran.csv'%new)
    sa,sb=sig(a),sig(b); ta,tb=a['t_s'],b['t_s']
    grid=[k*0.2e-6 for k in range(int(1e-3/0.2e-6)+1)]
    near=lambda x:any(abs(x-k*250e-6)<2e-6 for k in range(1,5))
    r=dict(compare=lab,old=old,new=new)
    for k in ('vpre','fpfn_cm','opon_cm','vg'):
        d=[abs(interp(ta,sa[k],x)-interp(tb,sb[k],x)) for x in grid if not near(x)]
        r[k+'_maxdiff_mV']='%.4g'%(max(d)*1e3)
    for te in (250e-6,500e-6,750e-6):
        pa,pb=edge_peak(ta,sa['opon_cm'],te),edge_peak(tb,sb['opon_cm'],te)
        r['opon_spike_%dus_old_new_mV'%round(te*1e6)]='%.2f / %.2f'%(pa*1e3,pb*1e3)
    r['vpre_at_1ms_old_new_mV']='%.4f / %.4f'%(interp(ta,sa['vpre'],1e-3)*1e3,interp(tb,sb['vpre'],1e-3)*1e3)
    ok=all(float(r[k+'_maxdiff_mV'])<0.1 for k in ('vpre','fpfn_cm','opon_cm','vg'))
    ok=ok and all(abs(float(r['opon_spike_%dus_old_new_mV'%u].split('/')[0])-float(r['opon_spike_%dus_old_new_mV'%u].split('/')[1]))<=0.1*float(r['opon_spike_%dus_old_new_mV'%u].split('/')[0]) for u in (250,500,750))
    r['consistent']='yes' if ok else 'NO'
    rows.append(r); print(r)
w=csv.DictWriter(open('r6dr_short_consistency.csv','w',newline=''),fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
