"""Minimal PSF-ASCII reader for the F2 final validation scout (Spectre 15.1 -format psfascii).
read(path) -> dict: 'x' (sweep values or None), 'sig' {name: list of values per point}, 'types' {name: struct field list}.
Values: float, complex, or list (STRUCT, e.g. noise contribution fields; last field = 'total')."""
import re
TOK = re.compile(r'"(?:[^"\\]|\\.)*"|\(|\)|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?|[A-Za-z_]+')

def _types(text):
    """struct type name -> field names (from the TYPE section)."""
    out = {}
    m = re.search(r'^TYPE\n(.*?)^(?:SWEEP|TRACE|VALUE)', text, re.S | re.M)
    if not m: return out
    for sm in re.finditer(r'^"([^"]+)" STRUCT\((.*?)^\) PROP\(', m.group(1), re.S | re.M):
        out[sm.group(1)] = re.findall(r'^"([^"]+)" FLOAT', sm.group(2), re.M)
    return out

def read(path):
    text = open(path).read()
    types = _types(text)
    trace = {}
    m = re.search(r'^TRACE\n(.*?)^VALUE', text, re.S | re.M)
    if m:
        for a, b in re.findall(r'^"([^"]+)" "([^"]+)"', m.group(1), re.M): trace[a] = types.get(b)
    sw = re.search(r'^SWEEP\n"([^"]+)"', text, re.M)
    xname = sw.group(1) if sw else None
    v = text[text.index('\nVALUE\n') + 7:]
    toks = TOK.findall(v)
    sig, x = {}, []
    i, n = 0, len(toks)
    num = lambda t: float(t)
    while i < n:
        t = toks[i]
        if t == 'END': break
        if not t.startswith('"'): i += 1; continue
        name = t[1:-1]; i += 1
        if i >= n: break
        t = toks[i]
        if t == '(':
            vals = []; i += 1
            while toks[i] != ')': vals.append(num(toks[i])); i += 1
            i += 1
            val = complex(vals[0], vals[1]) if (len(vals) == 2 and not trace.get(name)) else vals   # STRUCT only if TRACE type is a struct
        elif t.startswith('"'):                      # "name" "unit" value [PROP(...)]
            i += 1; val = num(toks[i]); i += 1
        else:
            val = num(t); i += 1
        if i < n and toks[i] == 'PROP':
            i += 2
            while toks[i] != ')': i += 1
            i += 1
        if xname is not None and name == xname: x.append(val); continue
        sig.setdefault(name, []).append(val)
    return {'x': x if xname else None, 'xname': xname, 'sig': sig, 'trace': trace}
