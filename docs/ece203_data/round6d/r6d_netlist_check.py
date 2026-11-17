# Compare the instance statements of two Spectre netlists (ignores comments and analysis/option/save lines).
# Usage: python3 r6d_netlist_check.py a.scs b.scs
import sys,re
def stm(fn):
    out=[];cur=''
    for l in open(fn):
        l=l.rstrip('\n')
        if l.strip().startswith('//') : continue
        if cur and cur.endswith('\\'): cur=cur[:-1]+' '+l.strip(); 
        else:
            if cur: out.append(cur)
            cur=l.strip()
    if cur: out.append(cur)
    keep=[]
    for s in out:
        if not s: continue
        w=s.split()[0]
        if w in ('simulatorOptions','tran','dc','ac','stb','save','saveOptions','modelParameter','element','outputParameter','designParamVals','primitives','subckts','finalTimeOP','include','parameters','simulator','global','ahdl_include'): continue
        if re.match(r'^\w+ \w+ options',s) or ' info what=' in s: continue
        keep.append(re.sub(r'\s+',' ',s))
    return keep
a=set(stm(sys.argv[1])); b=set(stm(sys.argv[2]))
print('only in',sys.argv[1].split('/')[-1],':'); [print('  -',x[:200]) for x in sorted(a-b)]
print('only in',sys.argv[2].split('/')[-1],':'); [print('  +',x[:200]) for x in sorted(b-a)]
