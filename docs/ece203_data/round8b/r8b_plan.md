# R8B pre-run plan (registered before any Spectre run)

Task: docs/ECE203_round8b_pss_fixture_isolation_task.md. Code = this commit: ece203_r8b.il (new cell + wrappers), R8 measurement code
ece203_r8_noise.il unchanged except a backward-compatible watchdog-name variable r8Wd, tools/r8b_watchdog.sh.

**Only topology change:** new cell Project/ece203_r8b_tb_noeoc_chp = r7fSpecs("gain_g0_load10p") with exactly the two instances
EOC (ocx vref ocm vref vcvs gain 1) and CHP (ocx oac capacitor 1M = 1e6 F) filtered out by exact instance name (the build errors
unless exactly these two are removed). Kept: RHP (oac vref 1T), EB2 (gain -kb*wob = 0, input oac tied to vref through RHP), EB1, EG1,
EG2, VUB, VUG, CVG and every other instance. Old cells read-only.
Netlist proof: r8b_netlist_audit.py compares the new netlists with the R8 ones (same analysis statements): instances removed must be
exactly {EOC, CHP}, nothing added or changed, parameters identical, all subckts identical; ocx must have no remaining connection.

Gate A (OFF, chen 0, vd 0, dcc 0, adm 1, same options gmin 1e-18 iabstol 1e-17 reltol 1e-5): C0 = R8 Stage A data (read-only, same
code), C1 = new cell. Equivalence: DC of the main nodes |dV| <= 1 uV; |Hout(100)| within 0.1 %; Sout at 0.1/1/10/100/250 Hz within 1 %;
both input RMS within 1 % (C0 16.32 / 16.87 uV); source-group ranking unchanged. Fail -> STOP.

Gate B (chen 1, vd 0, adm 0, dcc 0, pacd 0): PSS with the R8 a1 settings exactly (fund 2k, harms 40, maxacfreq 200k, errpreset moderate,
tstab 5m, maxperiods 40, cmin 1e-17, itres 1e-4 = Spectre default as in R8 a1). PASS = Spectre's explicit convergence message, closed
500 us period in pss_td, no clipping / odd operating point. If it fails: record whether the largest residual left VREF/EOC and how the
norm changed; ONE registered numerical retry (a2, settings decided from the new log and written here first); second failure -> BLOCKED.

Gate C (only after B): readpss + sideband-0 PAC 0.1-250 Hz (pacd 1, VSN pacphase 180, clocks pacmag 0): |Hon(100)| within +-10 % of
83.25 V/V (R7F chopped 1 mV transient; different definition, differences explained). Fail -> STOP.

Gate D (only after A-C): PNoise (timeaverage, p outp n outn, relative, relharmnum 0, 0.1-250 Hz 20/dec) maxsideband 10, 30, 60, then 90
only if 30 -> 60 is not converged. Converged = last two completed counts within 5 % in app and de-embedded input RMS and within 10 %
in input density at 1 / 10 / 100 Hz. Integrals double-checked (OCEAN vs Python). < 3 uVrms judged only if converged.
Deterministic R7F items stay out of every noise number.
