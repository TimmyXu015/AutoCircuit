"""R8C shared definitions (pre-registered in r8c_plan.md).

fL_flat: plateau P = mean |H| over the grid points with 5 <= f <= 10 Hz (inclusive);
fL = the frequency, scanning downward from 5 Hz, where |H| first falls below P/sqrt(2),
by linear interpolation of log|H| versus log f between the two bracketing points.
Also reported: the same with P = max |H| over 5-10 Hz (sensitivity only).
"""
import csv, math

def read(path):
    with open(path) as fh:
        r = csv.DictReader(fh)
        rows = [{k: float(v) for k, v in row.items() if v not in ('', None)} for row in r]
    return rows

def plateau(f, m, how='mean', lo=5.0, hi=10.0):
    v = [x for fi, x in zip(f, m) if lo - 1e-9 <= fi <= hi + 1e-9]
    if not v:
        raise ValueError('no points in the 5-10 Hz plateau window')
    return (sum(v) / len(v)) if how == 'mean' else max(v)

def fl_flat(f, m, how='mean'):
    """return (fL, plateau). None if no crossing inside the data."""
    P = plateau(f, m, how)
    thr = P / math.sqrt(2)
    pts = sorted(zip(f, m))
    idx = [i for i, (fi, _) in enumerate(pts) if fi <= 5.0 + 1e-9]
    for i in reversed(idx):
        if i == 0:
            break
        f1, m1 = pts[i - 1]; f2, m2 = pts[i]
        if m2 >= thr > m1:
            a = (math.log(thr) - math.log(m1)) / (math.log(m2) - math.log(m1))
            return math.exp(math.log(f1) + a * (math.log(f2) - math.log(f1))), P
    return None, P

def interp(f, y, x, log=True):
    pts = sorted(zip(f, y))
    for (f1, y1), (f2, y2) in zip(pts, pts[1:]):
        if f1 <= x <= f2:
            if log:
                a = (math.log(x) - math.log(f1)) / (math.log(f2) - math.log(f1))
            else:
                a = (x - f1) / (f2 - f1)
            return y1 + a * (y2 - y1)
    return None
