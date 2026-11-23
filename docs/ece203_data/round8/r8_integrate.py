#!/usr/bin/env python3
"""R8 integration cross-check: Python trapezoid on the exported output PSD and the exported transfer (r8_spec.load) vs the
OCEAN integ() values in <tag>.csv (out_rms, app_in, deemb_in). Usage: python3 r8_integrate.py TAG_BASE [TAG_BASE ...]"""
import sys, os, csv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r8_spec
for base in sys.argv[1:]:
    kv = {r['key']: r['value'] for r in csv.DictReader(open(base + '.csv'))}
    f, so, H, H100 = r8_spec.load(base)
    out = r8_spec.rms(f, so); dein = r8_spec.rms(f, so / H); app = out / H100
    print('%s: %d points %.4g..%.4g Hz | out rms %.6g V (OCEAN %s, %+.3f %%) | app %.6g V (OCEAN %s, %+.3f %%) | deemb %.6g V (OCEAN %s, %+.3f %%) | H100 %.5g'
          % (os.path.basename(base), len(f), f[0], f[-1], out, kv['out_rms'], 100 * (out / float(kv['out_rms']) - 1), app, kv['app_in'],
             100 * (app / float(kv['app_in']) - 1), dein, kv['deemb_in'], 100 * (dein / float(kv['deemb_in']) - 1), H100))
