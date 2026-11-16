import csv, math
R='docs/ece203_data/round5/'
k=1.380649e-23; T=300; q=1.602176634e-19; UT=k*T/q
Vni=16.584e-6; It=782.004e-9; BW=249.071-0.0773
NEF=Vni*math.sqrt(2*It/(math.pi*UT*4*k*T*BW))
print('NEF',NEF)
S=[('metric','target','R5 final (R4 real arch + C OTA + CS OTA2, Miller 0.5p)','R4 final (reference)','status','evidence / note'),
('DM gain @100 Hz (out, ref. electrode source)','40 +/- 2 dB','91.91 (39.27 dB); at o (before LP) 98.97','72.2 (37.17 dB)','PASS (sim)','Spectre ac, real bias/DRL/pseudo-R; gain 10 Hz 98.92'),
('fL','0.1 Hz +/- 10%','0.0773 Hz','0.073 Hz','SPEC FAIL','set by pseudo-R (unchanged per task); ideal-Rfb S2 bench gives 0.100 Hz'),
('fH','250 Hz +/- 10%','249.1 Hz','121 Hz','PASS (sim)','LP 31.8M/20p now driven by the low-Zout two-stage loop'),
('input-referred noise 0.1-250 Hz','< 3 uVrms','16.58 uV deemb; 17.15 uV app (out 1.577 mVrms / |H100|)','16.6 / 20.1 uV','SPEC FAIL','~99% OTA1 flicker (M1 29.1, M2 26.1, M4 22.0, M3 21.8 %); OTA2 0.0003 %'),
('input PSD 0.1/1/10/100/250 Hz','report','22.9 / 6.13 / 1.76 / 0.541 / 0.350 uV/rtHz','-','reported','pointwise de-embedded'),
('CMRR @60 Hz, DRL ON, Cc 1% mismatch','> 85 dB','95.42 dB (matched Cc: 93.83 dB)','91.35 / 92.51 dB','PASS (sim)','real DRL OTA + 2x1p ccm'),
('CMRR @60 Hz, DRL OFF','report','64.75 dB','53.9 dB','reported','DRL off: body interference clips (below)'),
('body 0.1 uA@60 Hz interference (separate)','no clipping','DRL ON: |Vbody| 37.4 mV, out 2.10 mV; tran o 0.895-0.900 V','37.4 mV / 2.9 mV','PASS (sim)','DRL OFF: |Vbody| 1.32 V, tran o 1.799-1.800 V (rail) - fails'),
('|Zin(10 Hz)| at amplifier inputs','> 100 MOhm','P 7.06 GOhm, N 0.159 GOhm','7.06 / 0.168 GOhm','PASS (sim)','same port definition as R4'),
('main loop stability (probe after OTA2, before LP)','PM >= 55 deg','UGF 8.68 kHz, PM 87.6 deg, LG(10 Hz) 742, LG(100 Hz) 82.8','R4 single stage loaded by LP','PASS (sim)','Spectre stb /IPRB'),
('DRL loop stability','report','UGF 2.05 kHz, PM 90.1 deg, LG(60 Hz) 34.1','2.05 kHz / 90.1 deg','PASS (sim)','stb probe in series with right-leg electrode'),
('DC / headroom','no device in triode','oa1 1.435 V, oa 0.898 V; OTA1 worst M2 0.094 V; OTA2 MCS/MCL margin 0.80 V; DRL worst 0.293 V','M2 0.090 V','PASS (sim)','VCAS divider 1.10 V'),
('total power @1.8 V','< 4 uW','782.0 nA -> 1.408 uW (R4 724.8 nA + OTA2 57.3 nA)','1.30 uW','PASS (sim)','VDD + one ideal 100 nA ref only'),
('NEF','report','%.1f (Itot 782 nA, BW 249 Hz, Vni 16.58 uV)'%NEF,'49.4','reported','NEF = Vni*sqrt(2 Itot/(pi UT 4kT BW)), T 300 K'),
('designed capacitance','< 1 nF','143.5 pF (R4 143 pF + CM2 0.5 pF)','143 pF','PASS','external electrodes/body excluded'),
('source budget','VDD + one 100 nA ref','met: OTA2 sink mirrored from the existing ib node','met','PASS',''),
('chopper','not in this config','NOT RUN in E (D: ideal-switch placement study only)','-','NOT RUN','task E: no chopper'),
('mismatch MC','-','NOT RUN this round','N=12 (R4)','NOT RUN','')]
csv.writer(open(R+'r5_final_spec_matrix.csv','w',newline='')).writerows(S)
A=[('stage','case','config','evidence','H100 (out)','dB','fL Hz','fH Hz','main UGF / PM','LG10','Zout_cl@100Hz','I_OTA2 nA','noise app / deemb uV','OTA2 fn ref. ECG uV','verdict'),
('A','A_noLP','C OTA, no LP (fb)','Spectre','94.22 (fb)','39.48','0.094','8815 (fb)','8.30 kHz / 93.4','16.2','29.1 MOhm','-','-','-','reference'),
('A','A_LP','C OTA + LP (R4 forward chain)','Spectre','71.75','37.12','0.095','117.3','315 Hz / 142','12.5','29.1 MOhm','-','20.22 / 16.68','-','loading loss (R4 problem)'),
('A','A_LP_idealBUF','C OTA + ideal x1 + LP','Spectre + Ideal-diag','87.49','38.84','0.095','249.8','311 kHz / 89.4','16.2','0.058 Ohm','-','17.11 / 16.68','0 (ideal)','proof: Zout is the cause'),
('B1','B1_CD_LP','C OTA + NMOS CD','Spectre','85.47','38.64','0.093','249.5','181 kHz / 73.4','11.5','47.1 kOhm','53.6','17.13 / 16.69','0.042','candidate (chopper-friendly)'),
('B2','B2_CS_cm0p5_LP','C OTA + PMOS CS, Miller 0.5p','Spectre','92.75','39.35','0.100','249.2','8.08 kHz / 87.4','700.8','77.3 kOhm','53.6','17.07 / 16.69','0.028','candidate (best static)'),
('B3','-','C OTA + CS + CD','-','-','-','-','-','-','-','-','-','-','-','NOT RUN (no trigger)'),
('D','D1 (CD)','demod after OTA1, 4 kHz','Spectre PSS/PNoise + ideal switches','81.29 (PAC)','38.20','-','-','-','-','-','53.3','5.29 / 12.17 (sb30)','1.16','OTA2 pushed to cutoff each half period'),
('D','D2 (CD)','demod after OTA2, 4 kHz','Spectre PSS/PNoise + ideal switches','81.13 (PAC)','38.18','-','-','-','-','-','58.0','5.21 / 11.76 (sb30); 6.19 / 14.25 (sb50)','0.040','preferred position; 33 mV pp ripple'),
('E','E_cs_dm','R4 real architecture + CS OTA2','Spectre (real bias, pseudo-R, real DRL)','91.91','39.27','0.0773','249.1','8.68 kHz / 87.6','742','-','57.3','17.15 / 16.58','~0 (0.0003 %)','gain + fH PASS; fL, noise FAIL')]
csv.writer(open(R+'r5_architecture_matrix.csv','w',newline='')).writerows(A)
