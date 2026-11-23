"""Minimal psfascii readers (no numpy): node voltages of a dc point and per-instance oppoint structs."""
import re

def nodes(path):
    return {k: float(v) for k, v in re.findall(r'^"([^"]+)" "[VI]" ([-0-9.e+]+)$', open(path).read(), re.M)}

def oppoint(path):
    """returns {instance: {field: value}} for every STRUCT-typed instance in a dcop .info file"""
    txt = open(path).read()
    tsec = txt[txt.find('TYPE'):txt.find('VALUE')]
    types = {}
    cur, depth = None, 0
    for line in tsec.splitlines():
        m = re.match(r'^"(\w+)" STRUCT\(', line)
        if m and depth == 0:
            cur, depth = m.group(1), 1
            types[cur] = []
            continue
        if cur is None:
            continue
        if depth == 1:
            f = re.match(r'^"(\w+)" (?:FLOAT|INT|STRING)', line)
            if f:
                types[cur].append(f.group(1))
        depth += line.count('(') - line.count(')')
        if depth <= 0:
            cur, depth = None, 0
    out = {}
    vsec = txt[txt.find('VALUE'):]
    for m in re.finditer(r'^"([^"]+)" "(\w+)" \(\n(.*?)^\)', vsec, re.M | re.S):
        inst, typ, body = m.groups()
        if typ not in types:
            continue
        vals = []
        for tok in body.split():
            try:
                vals.append(float(tok))
            except ValueError:
                vals.append(tok.strip('"'))
        out[inst] = dict(zip(types[typ], vals))
    return out
