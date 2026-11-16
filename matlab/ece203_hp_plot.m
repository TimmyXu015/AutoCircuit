% ece203_hp_plot.m -- closed-loop ideal VCVS high-pass (Project/ece203_hp_ideal_tb), job ece203_hp
% Reads ece203_hp_ac.csv / ece203_hp_aol.csv from its own folder (_raw/<exp>/) and writes PNGs
% to the experiment folder <notebook>/<exp>/.
clear; close all;
here = fileparts(mfilename('fullpath'));
[~, e] = fileparts(here);
out = fullfile(fileparts(fileparts(here)), e);
if ~exist(out, 'dir'), mkdir(out); end

T = readtable(fullfile(here, 'ece203_hp_ac.csv'), 'VariableNamingRule', 'preserve');
A = readtable(fullfile(here, 'ece203_hp_aol.csv'), 'VariableNamingRule', 'preserve');
f = T.f_Hz; nom = A(A.aol == 1e5, :);
midDb = 20*log10(nom.absH_mid);

% --- Bode ---
fig = figure('Name', 'hp_bode', 'Position', [100 100 760 600]);
subplot(2,1,1);
semilogx(f, T.H_dB, 'LineWidth', 1.6); hold on; grid on;
yline(midDb - 3, '--', sprintf('midband - 3 dB = %.2f dB', midDb - 3));
xline(nom.fL_Hz, ':', sprintf('f_L = %.4g Hz', nom.fL_Hz), 'LabelVerticalAlignment', 'bottom');
xline([0.09 0.11], '-', 'Color', [0.8 0.3 0.3]);
ylabel('|V_{out}/V_{in}| (dB)');
title(sprintf('ece203\\_hp\\_ideal\\_tb, A_{OL} = 1e5:  |H(100 Hz)| = %.4f (%.3f dB)', nom.absH_mid, midDb));
legend('|H|', 'Location', 'southeast');
subplot(2,1,2);
semilogx(f, T.phase_deg, 'LineWidth', 1.6); grid on;
ylabel('phase (deg)'); xlabel('f (Hz)');
text(0.02, 0.15, 'red lines: 0.1 Hz \pm 10 % spec window', 'Units', 'normalized');
exportgraphics(fig, fullfile(out, 'hp_bode.png'), 'Resolution', 130);

% --- |Zin| ---
fig = figure('Name', 'hp_zin', 'Position', [100 100 760 420]);
loglog(f, T.absZin_ohm, 'LineWidth', 1.6); hold on; grid on;
yline(100e6, '--', '100 M\Omega spec');
xline(10, ':');
plot(10, nom.absZin10_ohm, 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
text(12, nom.absZin10_ohm * 1.6, sprintf('|Z_{in}(10 Hz)| = %.4g M\\Omega', nom.absZin10_ohm / 1e6));
xlabel('f (Hz)'); ylabel('|Z_{in}| = |V_{in} / I_{VIN}| (\Omega)');
title('Input impedance seen by VIN (no electrode model), A_{OL} = 1e5');
exportgraphics(fig, fullfile(out, 'hp_zin.png'), 'Resolution', 130);
