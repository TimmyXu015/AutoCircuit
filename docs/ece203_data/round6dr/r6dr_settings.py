# Extract the actually used numerical settings and the progress of each R6D-R run from the netlists (simulatorOptions, tran
# statement) and spectre.out. Usage: python3 r6dr_settings.py <dir with *_netlist.scs and *_spectre.out.gz> [...] -> r6dr_numerical_settings.csv
import sys, glob, gzip, re, os, csv
rows=[]
for D in sys.argv[1:]:
    for so in sorted(glob.glob(D+'/*_spectre.out.gz')):
        tag=os.path.basename(so).replace('_spectre.out.gz',''); txt=gzip.open(so,'rt').read()
        net=D+'/%s_netlist.scs'%tag; nt=open(net).read() if os.path.exists(net) else ''
        def opt(k):
            m=re.search(r'\b%s=([^\s\\]+)'%k,nt); return m.group(1) if m else ''
        tranl=re.search(r'^tran tran (.*?)(?:write=|$)',nt,re.M)
        times=re.findall(r'tran: time = ([^(]+)\(.*?step = ([^(]+)\(',txt)
        steps=[s.strip() for _,s in times]
        def tos(s):
            v,u=s.split(); return float(v)*{'s':1,'ms':1e-3,'us':1e-6,'ns':1e-9,'ps':1e-12,'fs':1e-15,'as':1e-18}[u]
        acc=re.search(r'Number of accepted tran steps =\s*(\d+)',txt)
        rows.append(dict(run=tag,reltol=opt('reltol'),iabstol=opt('iabstol'),gmin=opt('gmin'),vabstol=opt('vabstol'),
            tran_statement=(tranl.group(1).strip() if tranl else ''),cmin_echo=(re.search(r'cmin = ([^\n]+)',txt).group(1).strip() if 'cmin =' in txt else ''),
            last_reported_time=(times[-1][0].strip() if times else ''),lines_at_250us=sum(1 for t,_ in times if t.strip()=='250 us'),
            min_reported_step_s=('%.3g'%min(tos(s) for s in steps) if steps else ''),accepted_steps=(acc.group(1) if acc else 'n/a (killed)'),
            ringing_notices='; '.join(sorted(set(re.findall(r'Found trapezoidal ringing on node (\S+?)\.?\n',txt)))),
            completed=('KILLED by watchdog (SIGTERM)' if 'SIGTERM' in txt else ('yes' if acc else 'no'))))
w=csv.DictWriter(open('r6dr_numerical_settings.csv','w',newline=''),fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
for r in rows: print(r)
