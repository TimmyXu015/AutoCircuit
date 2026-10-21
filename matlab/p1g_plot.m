%% p1g_plot.m -- HW1 P1g: PMOS (pfetx 5u/1u, tt) |Id| vs VSG for VSD = 0.1 .. 1.8 V
% Data: p1c_p1_pmos.csv next to this script (in _raw); the PNG goes to the experiment folder (one DC sweep per VSD, from run.sh p1cp).
% Left:  the whole family on a log axis.
% Right: zoom into the clean subthreshold part, where the curves for different VSD
%        are separated only by a few mV -- read the VSG shift at one fixed current here.
clear; close all;
here = fileparts(mfilename('fullpath')); if isempty(here), here = pwd; end
T = readtable(fullfile(here, 'p1c_p1_pmos.csv'), 'VariableNamingRule', 'preserve');
vsg = T{:,1}; I = T{:,2:end};
vsd = [0.1 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8];
cols = parula(numel(vsd) + 2); cols = cols(1:numel(vsd), :);
lg = arrayfun(@(x) sprintf('V_{SD} = %.1f V', x), vsd, 'UniformOutput', false);

figure('Name', 'P1g PMOS VSD family', 'Color', 'w', 'Position', [80 80 1150 480]);
tiledlayout(1, 2, 'TileSpacing', 'compact');

nexttile; hold on;
for j = 1:numel(vsd), semilogy(vsg, I(:,j), 'Color', cols(j,:), 'LineWidth', 1.4); end
set(gca, 'YScale', 'log'); grid on; box on; xlim([0 1.8]);
xlabel('V_{SG} (V)'); ylabel('|I_D| (A)');
title('PMOS 5u/1u, tt: |I_D| vs V_{SG}');
legend(lg, 'Location', 'southeast');

nexttile; hold on;
for j = 1:numel(vsd), semilogy(vsg, I(:,j), '.-', 'Color', cols(j,:), 'LineWidth', 1.2); end
set(gca, 'YScale', 'log'); grid on; box on;
xlim([0.08 0.18]); ylim([1e-10 1e-9]);
yline(10^-9.5, 'k--', '|I_D| = 10^{-9.5} A', 'LabelHorizontalAlignment', 'left');
xlabel('V_{SG} (V)'); ylabel('|I_D| (A)');
title('Zoom: clean subthreshold region');
[~, expName] = fileparts(here);
exportgraphics(gcf, fullfile(fileparts(fileparts(here)), expName, 'p1g_pmos_vsd_family.png'), 'Resolution', 130);
