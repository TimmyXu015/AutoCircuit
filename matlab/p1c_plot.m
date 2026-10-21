%% p1c_plot.m -- HW1 P1c: NMOS (nfetx 5u/1u, tt) Id vs VGS for VDS = 0.1 .. 1.8 V
% Data: p1c_p1_nmos.csv next to this script (in _raw); the PNG goes to the experiment folder (one DC sweep per VDS, from run.sh p1c).
% Left:  the whole family on a log axis.
% Right: zoom into the clean subthreshold part, where the curves for different VDS
%        are separated by tens of mV -- read the VGS shift at one fixed current here.
clear; close all;
here = fileparts(mfilename('fullpath')); if isempty(here), here = pwd; end
T = readtable(fullfile(here, 'p1c_p1_nmos.csv'), 'VariableNamingRule', 'preserve');
vgs = T{:,1}; I = T{:,2:end};
vds = [0.1 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8];
cols = parula(numel(vds) + 2); cols = cols(1:numel(vds), :);
lg = arrayfun(@(x) sprintf('V_{DS} = %.1f V', x), vds, 'UniformOutput', false);

figure('Name', 'P1c NMOS VDS family', 'Color', 'w', 'Position', [80 80 1150 480]);
tiledlayout(1, 2, 'TileSpacing', 'compact');

nexttile; hold on;
for j = 1:numel(vds), semilogy(vgs, I(:,j), 'Color', cols(j,:), 'LineWidth', 1.4); end
set(gca, 'YScale', 'log'); grid on; box on; xlim([0 1.8]);
xlabel('V_{GS} (V)'); ylabel('I_D (A)');
title('NMOS 5u/1u, tt: I_D vs V_{GS}');
legend(lg, 'Location', 'southeast');

nexttile; hold on;
for j = 1:numel(vds), semilogy(vgs, I(:,j), '.-', 'Color', cols(j,:), 'LineWidth', 1.2); end
set(gca, 'YScale', 'log'); grid on; box on;
xlim([0.05 0.20]); ylim([1e-10 1e-7]);
yline(10^-8.5, 'k--', 'I_D = 10^{-8.5} A', 'LabelHorizontalAlignment', 'left');
xlabel('V_{GS} (V)'); ylabel('I_D (A)');
title('Zoom: clean subthreshold region');
[~, expName] = fileparts(here);
exportgraphics(gcf, fullfile(fileparts(fileparts(here)), expName, 'p1c_nmos_vds_family.png'), 'Resolution', 130);
