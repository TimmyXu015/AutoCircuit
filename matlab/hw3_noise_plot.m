%% hw3_noise_plot.m -- HW3 P2: CS amp (nfetx 50u/5u, RL 50k, CL 500f, Id = 15 uA) noise check
% Data: hw3_noise.csv next to this script (run.sh hw3check, OCEAN, tt).
% Log-log, as the homework hint suggests. Reference for checking your own ADE L plots.
clear; close all;
here = fileparts(mfilename('fullpath')); if isempty(here), here = pwd; end
[~, e] = fileparts(here); out = fullfile(fileparts(fileparts(here)), e);
T = readtable(fullfile(here, 'hw3_noise.csv'));
f = T.f_Hz;
figure('Name', 'HW3 P2 noise', 'Color', 'w', 'Position', [80 80 820 760]);
tl = tiledlayout(3, 1, 'TileSpacing', 'compact');
nexttile; loglog(f, T.gain_mag, 'LineWidth', 1.6, 'Color', [42 120 214]/255); grid on;
ylabel('|v_{out}/v_{in}| (V/V)'); title('AC transfer function');
nexttile; loglog(f, T.out_noise_V_rtHz, 'LineWidth', 1.6, 'Color', [235 104 52]/255); grid on;
ylabel('V/\surdHz'); title('Output-referred noise');
nexttile; loglog(f, T.in_noise_V_rtHz, 'LineWidth', 1.6, 'Color', [60 150 80]/255); grid on;
ylabel('V/\surdHz'); title('Input-referred noise'); xlabel('f (Hz)');
title(tl, 'CS amp, nfetx 50u/5u, R_L = 50 k\Omega, C_L = 500 fF, I_D = 15 \muA (tt)');
exportgraphics(gcf, fullfile(out, 'hw3_noise_check.png'), 'Resolution', 130);
