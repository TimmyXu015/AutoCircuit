% ece203_ota_plot.m -- A3 (ece203_a3_*) or A1/A2 (ece203_a12*) OTA characterisation plots.
% Put next to the CSVs in _raw/<exp>/. Detects which OTA from the files present.
clear; close all;
here = fileparts(mfilename('fullpath'));
[~, e] = fileparts(here);
out = fullfile(fileparts(fileparts(here)), e);
if ~exist(out, 'dir'), mkdir(out); end
% noise integral over 0.1-250 Hz on a fine log grid (log-log interpolation of the PSD)
nint = @(f, S) sqrt(trapz(logspace(-1, log10(250), 4000), exp(interp1(log(f), log(S.^2), log(logspace(-1, log10(250), 4000)), 'linear'))));
rd = @(f) readtable(fullfile(here, f), 'VariableNamingRule', 'preserve');
has = @(f) exist(fullfile(here, f), 'file') == 2;
if has('ece203_a3ol_ac.csv'), tag = 'a3'; name = 'A3 (5T OTA)'; else, tag = 'a12'; name = 'A1/A2 (telescopic cascode OTA)'; end

% --- open loop gain + phase ---
A = rd(['ece203_' tag 'ol_ac.csv']);
fig = figure('Name', [tag '_openloop'], 'Position', [100 100 760 600]);
subplot(2,1,1);
semilogx(A.f_Hz, A.A_dB, 'LineWidth', 1.6); hold on; grid on;
if has('ece203_a12olR1M_ac.csv')
    R = rd('ece203_a12olR1M_ac.csv');
    semilogx(R.f_Hz, R.A_dB, '--', 'LineWidth', 1.4);
    legend('C_L only', 'C_L + 1 M\Omega to v_{cm} (A3 input resistor)', 'Location', 'southwest');
end
yline(0, ':'); ylabel('|A_{OL}| (dB)');
title([name ': open loop (DC unity feedback through 1 T\Omega / 1 F)']);
subplot(2,1,2);
semilogx(A.f_Hz, A.phase_deg, 'LineWidth', 1.6); grid on; ylabel('phase (deg)'); xlabel('f (Hz)');
exportgraphics(fig, fullfile(out, [tag '_openloop.png']), 'Resolution', 130);

% --- input-referred noise ---
N = rd(['ece203_' tag 'ol_noise.csv']);
fig = figure('Name', [tag '_noise'], 'Position', [100 100 760 420]);
loglog(N.f_Hz, N.in_V_rtHz, 'LineWidth', 1.6, 'DisplayName', 'open-loop tb'); hold on; grid on;
vr = nint(N.f_Hz, N.in_V_rtHz);
txt = sprintf('open loop: integrated 0.1-250 Hz = %.3g \\muV_{rms}', vr * 1e6);
if has('ece203_a12cl_noise.csv')
    M = rd('ece203_a12cl_noise.csv');
    loglog(M.f_Hz, M.in_V_rtHz, 'LineWidth', 1.6, 'DisplayName', 'closed loop with ece203\_hp\_fb (from VIN)');
    txt = sprintf('%s\nclosed loop: integrated 0.1-250 Hz = %.3g \\muV_{rms}', txt, nint(M.f_Hz, M.in_V_rtHz) * 1e6);
end
xline([0.1 250], ':', 'HandleVisibility', 'off');
xlabel('f (Hz)'); ylabel('input-referred noise (V/\surdHz)'); legend('Location', 'northeast');
title([name ': input-referred noise']);
text(0.02, 0.1, txt, 'Units', 'normalized');
exportgraphics(fig, fullfile(out, [tag '_noise.png']), 'Resolution', 130);

% --- CM range (follower) ---
S = rd(['ece203_' tag 'ol_cmsweep.csv']);
fig = figure('Name', [tag '_cmrange'], 'Position', [100 100 760 420]);
plot(S.vcm_V, S.vout_V, 'LineWidth', 1.6); hold on; grid on;
plot(S.vcm_V, S.vcm_V, ':');
err = abs(S.vout_V - S.vcm_V); ok = err < 10e-3;
if any(ok), r = S.vcm_V(ok); txt = sprintf('|v_{out} - v_{cm}| < 10 mV for v_{cm} = %.2f ... %.2f V', min(r), max(r));
else, txt = 'no point within 10 mV'; end
text(0.05, 0.9, txt, 'Units', 'normalized');
xlabel('v_{cm} = v_{inp} (V)'); ylabel('v_{out} (V)'); title([name ': unity follower DC sweep (input CM range)']);
exportgraphics(fig, fullfile(out, [tag '_cmrange.png']), 'Resolution', 130);

% --- closed loop ---
if strcmp(tag, 'a3')
    fig = figure('Name', 'a3_closedloop', 'Position', [100 100 760 760]);
    rs = {'1e+06', '1e+08'}; lab = {'r1 = 1 M\Omega, r2 = 4 M\Omega', 'r1 = 100 M\Omega, r2 = 400 M\Omega'};
    for k = 1:2
        C = rd(['ece203_a3cl_r1_' rs{k} '.csv']);
        subplot(3,1,1); loglog(C.f_Hz, C.absHcl_o, 'LineWidth', 1.6, 'DisplayName', [lab{k} ', at o']); hold on;
        loglog(C.f_Hz, C.absH_lpo, '--', 'LineWidth', 1.2, 'DisplayName', [lab{k} ', after RC (lpo)']);
        subplot(3,1,2); loglog(C.f_Hz, C.absLoopGain, 'LineWidth', 1.6, 'DisplayName', lab{k}); hold on;
        subplot(3,1,3); semilogx(C.f_Hz, C.phaseLoopGain_deg, 'LineWidth', 1.6, 'DisplayName', lab{k}); hold on;
        W = rd(['ece203_a3sw_r1_' rs{k} '.csv']);
        sw{k} = W; %#ok<SAGROW>
    end
    subplot(3,1,1); grid on; yline(4, ':', 'ideal 4', 'HandleVisibility', 'off'); ylabel('|v_o / v_{diff}|');
    legend('Location', 'southwest'); title('A3 as x4 difference amplifier (output RC 3.18 M\Omega / 200 pF as load)');
    subplot(3,1,2); grid on; yline(1, ':', 'HandleVisibility', 'off'); ylabel('|loop gain| (stb)'); legend('Location', 'southwest');
    subplot(3,1,3); grid on; ylabel('loop gain phase (deg)'); xlabel('f (Hz)');
    text(0.02, 0.15, 'Spectre stb: phase starts at 180 deg; PM = phase at |LG| = 1', 'Units', 'normalized');
    exportgraphics(fig, fullfile(out, 'a3_closedloop.png'), 'Resolution', 130);
    fig = figure('Name', 'a3_swing', 'Position', [100 100 760 420]);
    for k = 1:2, plot(sw{k}.vd_V, sw{k}.vo_V, 'LineWidth', 1.6, 'DisplayName', lab{k}); hold on; end
    grid on; xlabel('differential input v_{in2} - v_{in1} (V)'); ylabel('v_o (V)'); legend('Location', 'northwest');
    title('A3 x4 closed loop: DC transfer (output swing)');
    exportgraphics(fig, fullfile(out, 'a3_swing.png'), 'Resolution', 130);
else
    C = rd('ece203_a12cl_ac.csv'); L = rd('ece203_a12cl_stb.csv');
    fig = figure('Name', 'a12_closedloop', 'Position', [100 100 760 760]);
    subplot(3,1,1); semilogx(C.f_Hz, 20*log10(C.absH), 'LineWidth', 1.6); grid on; hold on;
    xline([0.09 0.11], '-', 'Color', [0.8 0.3 0.3]);
    ylabel('|v_o / v_{in}| (dB)'); title('A1/A2 OTA + ece203\_hp\_fb (ece203\_hp\_real\_tb), C_L = 5 pF');
    subplot(3,1,2); loglog(L.f_Hz, L.absLoopGain, 'LineWidth', 1.6); grid on; yline(1, ':'); ylabel('|loop gain| (stb)');
    subplot(3,1,3); semilogx(L.f_Hz, L.phaseLoopGain_deg, 'LineWidth', 1.6); grid on; ylabel('loop gain phase (deg)'); xlabel('f (Hz)');
    text(0.02, 0.15, 'Spectre stb: phase starts at 180 deg; PM = phase at |LG| = 1', 'Units', 'normalized');
    exportgraphics(fig, fullfile(out, 'a12_closedloop.png'), 'Resolution', 130);
end
