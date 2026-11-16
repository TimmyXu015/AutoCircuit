% ece203_ideal_plot.m -- ideal VCVS whole ECG (Project/ece203_ideal_ecg), job ece203_ideal
clear; close all;
here = fileparts(mfilename('fullpath'));
[~, e] = fileparts(here);
out = fullfile(fileparts(fileparts(here)), e);
if ~exist(out, 'dir'), mkdir(out); end
rd = @(f) readtable(fullfile(here, f), 'VariableNamingRule', 'preserve');
D = rd('ece203_ideal_dm.csv');
f = D.f_Hz;

% --- differential gain ---
fig = figure('Name', 'ideal_dm', 'Position', [100 100 760 640]);
subplot(2,1,1);
semilogx(f, 20*log10(D.absHdm), 'LineWidth', 1.8); hold on; grid on;
semilogx(f, 20*log10(D.absH_o3), '--', 'LineWidth', 1.2);
yline([38 42], ':', {'38 dB', '42 dB'}, 'LabelHorizontalAlignment', 'left');
xline([0.09 0.11 225 275], '-', 'Color', [0.8 0.3 0.3]);
[m, ~] = max(D.absHdm);
yline(20*log10(m) - 3, '--', sprintf('max - 3 dB (max %.3f dB)', 20*log10(m)), 'LabelHorizontalAlignment', 'center', 'LabelVerticalAlignment', 'bottom');
ylim([-10 45]); ylabel('|V_{out} / (V_{inp} - V_{inn})| (dB)');
legend('out (after output RC)', 'o3 (A3 output, before RC)', 'Location', 'south');
title('Ideal ECG, differential gain measured after the electrodes (DRL on, matched)');
subplot(2,1,2);
semilogx(f, D.phaseHdm_deg, 'LineWidth', 1.5); grid on;
ylabel('phase (deg)'); xlabel('f (Hz)');
text(0.02, 0.1, 'red lines: 0.1 Hz and 250 Hz \pm 10 % windows', 'Units', 'normalized');
exportgraphics(fig, fullfile(out, 'ideal_dm.png'), 'Resolution', 130);

% --- input impedance ---
fig = figure('Name', 'ideal_zin', 'Position', [100 100 760 420]);
loglog(f, D.absZinP_ohm, 'LineWidth', 1.6); hold on; grid on;
loglog(f, 1 ./ (2*pi*f*100e-12), ':', 'LineWidth', 1.2);
yline(100e6, '--', '100 M\Omega spec'); xline(10, ':');
z10 = interp1(log10(f), D.absZinP_ohm, 1);
plot(10, z10, 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
text(12, z10*1.8, sprintf('|Z_{in}(10 Hz)| = %.4g M\\Omega', z10/1e6));
legend('|Z_{in}| at inp (Cc path + 10 G\Omega CM sense)', '1/(2\pi f \cdot 100 pF) for reference', ...
    'Location', 'northeast');
xlabel('f (Hz)'); ylabel('|Z_{in}| (\Omega)');
title('Input impedance at the amplifier input (after the electrode), DM excitation');
exportgraphics(fig, fullfile(out, 'ideal_zin.png'), 'Resolution', 130);

% --- common mode ---
% matched case: out is at the numerical floor (DRL on: exactly 0), so it is not plotted
cases = {'dcc1pct', 'delec10pct'};
labels = {'Cc mismatch 1 %', 'electrode Z mismatch 10 %'};
fig = figure('Name', 'ideal_cm', 'Position', [100 100 760 700]);
C = rd('ece203_ideal_cm_dcc1pct.csv');
subplot(2,1,1);
loglog(C.f_Hz, C.abs_vcm_off, 'LineWidth', 1.6); hold on; grid on;
loglog(C.f_Hz, C.abs_vcm_on, 'LineWidth', 1.6);
loglog(C.f_Hz, C.abs_out_off, '--', 'LineWidth', 1.4);
loglog(C.f_Hz, C.abs_out_on, '--', 'LineWidth', 1.4);
xline(60, ':');
legend('|v_{cm}| DRL off', '|v_{cm}| DRL on', '|out| DRL off', '|out| DRL on', 'Location', 'southwest');
ylabel('V (0.1 \muA interferer)'); title('60 Hz interferer, case "Cc mismatch 1 %", A_{DRL} = 100');
subplot(2,1,2);
for k = 1:numel(cases)
    T = rd(['ece203_ideal_cm_' cases{k} '.csv']);
    acmOn = T.abs_out_on ./ T.abs_vcm_off;
    acmOff = T.abs_out_off ./ T.abs_vcm_off;
    cOn = 20*log10(T.absHdm ./ acmOn); cOn(~isfinite(cOn) | cOn > 300) = NaN;
    cOff = 20*log10(T.absHdm ./ acmOff); cOff(~isfinite(cOff) | cOff > 300) = NaN;
    semilogx(T.f_Hz, cOn, '-', 'LineWidth', 1.6, 'DisplayName', [labels{k} ', DRL on']); hold on;
    semilogx(T.f_Hz, cOff, '--', 'LineWidth', 1.2, 'DisplayName', [labels{k} ', DRL off']);
end
grid on; yline(85, ':', '85 dB spec', 'HandleVisibility', 'off'); xline(60, ':', 'HandleVisibility', 'off');
ylabel('CMRR (dB) = |A_{dm}| / (|out| / |v_{cm,DRL off}|)'); xlabel('f (Hz)');
legend('Location', 'southwest'); ylim([0 260]); xlim([1e-3 1e4]);
title('CMRR vs f (matched case omitted: |out| at numerical floor)');
exportgraphics(fig, fullfile(out, 'ideal_cm.png'), 'Resolution', 130);
