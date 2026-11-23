"""R8E design-capacitance budget from a real netlist (the only budget source). Usage: r8e_budget.py NETLIST [dcc_design=0]
Counted (R7F definition, 439 pF for G0): CCP CCN (cc), CFP CFN (cfb), CLBP CLBN (clb), CLP_P CLP_N, CCMP CCMN (ccm, DRL), CVG (cvg).
Excluded: COUTP/COUTN (10 pF/side stress load), CEP/CEN/CER (electrodes), CBODY (body model), CCX = cc*dcc (mismatch fixture, dcc 0 in design)."""
import re, sys
SI = {'T': 1e12, 'G': 1e9, 'M': 1e6, 'K': 1e3, 'k': 1e3, 'm': 1e-3, 'u': 1e-6, 'n': 1e-9, 'p': 1e-12, 'f': 1e-15, 'a': 1e-18}
def num(v):
    try: return float(v)
    except ValueError: return float(v[:-1]) * SI[v[-1]]
def joined(t):
    out = []; cur = ''
    for l in t.splitlines():
        if l.endswith('\\'): cur += l[:-1] + ' '; continue
        out.append(' '.join((cur + l).split())); cur = ''
    return out
def budget(path):
    L = joined(open(path).read()); par = {}
    for l in L:
        if l.startswith('parameters '):
            for kv in l.split()[1:]:
                k, v = kv.split('=', 1)
                try: par[k] = num(v)
                except Exception: pass
    caps = {}
    for l in L:
        m = re.match(r'^(\w+) \((\S+) (\S+)\) capacitor c=(\S+)', l)
        if m: caps[m.group(1)] = (m.group(2), m.group(3), m.group(4))
    def ev(expr):
        try: return num(expr)
        except Exception: pass
        e = re.sub(r'(?<![\w.])([A-Za-z_]\w*)', lambda q: repr(par[q.group(1)]), expr)
        e = re.sub(r'(\d)([TGMKkmunpfa])(?![\w])', lambda q: q.group(1) + '*%r' % SI[q.group(2)], e)
        return eval(e)
    rows = []; tot = 0.0
    for n in ('CCP', 'CCN', 'CFP', 'CFN', 'CLBP', 'CLBN', 'CLP_P', 'CLP_N', 'CCMP', 'CCMN', 'CVG'):
        v = ev(caps[n][2]); tot += v; rows.append((n, caps[n][2], v, 'counted'))
    for n in sorted(set(caps) - {r[0] for r in rows}):
        rows.append((n, caps[n][2], ev(caps[n][2]), 'excluded'))
    return tot, rows, par
if __name__ == '__main__':
    tot, rows, par = budget(sys.argv[1])
    for r in rows: print('%-6s c=%-10s %10.4g pF  %s' % (r[0], r[1], r[2] * 1e12, r[3]))
    print('TOTAL design capacitance %.4f pF' % (tot * 1e12))
