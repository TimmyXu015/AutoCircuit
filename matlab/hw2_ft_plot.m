%% hw2_ft_plot.m -- HW2 P1: f_t vs VGS of nfetx 5u/1u and 2u/0.18u (VDS = 1.8 V, tt)
% Data: hw2_ft_p1_ft_5u1u.csv, hw2_ft_p1_ft_2u018.csv next to this script (run.sh hw2ftsweep).
% Reference for checking your own ADE L parametric run. Three f_t versions per device:
%   o markers  cross(db20(h21), 0 dB)      -- empty where |h21| never falls to 0 dB
%   solid      |h21(1 Hz)| x 1 Hz          -- -20 dB/dec line extrapolated to 0 dB
%   dashed     gm / (2 pi Cgg) from the OP -- the hand formula with Spectre's gm, Cgg
clear; close all;
here = fileparts(mfilename('fullpath')); if isempty(here), here = pwd; end
[~, e] = fileparts(here); out = fullfile(fileparts(fileparts(here)), e);
cells = {'p1_ft_5u1u', 'p1_ft_2u018'};
lbl   = {'W/L = 5u/1u', 'W/L = 2u/0.18u'};
col   = {[42 120 214]/255, [235 104 52]/255};
figure('Name', 'HW2 P1 ft vs VGS', 'Color', 'w', 'Position', [80 80 900 560]); hold on;
h = gobjects(0); lg = {};
for k = 1:2
    T = readtable(fullfile(here, ['hw2_ft_' cells{k} '.csv']), 'TreatAsMissing', 'n/a');
    h(end+1) = semilogy(T.vgs_V, T.ft_extrap_Hz, '-', 'Color', col{k}, 'LineWidth', 1.8); %#ok<SAGROW>
    lg{end+1} = [lbl{k} ': |h_{21}(1 Hz)| \times 1 Hz'];                                   %#ok<SAGROW>
    h(end+1) = semilogy(T.vgs_V, T.ft_cross_Hz, 'o', 'Color', col{k}, 'MarkerSize', 5);  %#ok<SAGROW>
    lg{end+1} = [lbl{k} ': 0 dB crossing'];                                               %#ok<SAGROW>
    h(end+1) = semilogy(T.vgs_V, T.gm_over_2piCgg_Hz, '--', 'Color', col{k}, 'LineWidth', 1); %#ok<SAGROW>
    lg{end+1} = [lbl{k} ': g_m / (2\pi C_{gg})'];                                         %#ok<SAGROW>
end
set(gca, 'YScale', 'log'); grid on; box on; xlim([0 1.8]);
xline(0.25, ':', 'V_{GS} = 0.25 V', 'LabelVerticalAlignment', 'bottom');
xlabel('V_{GS} (V)'); ylabel('f_t (Hz)'); title('nfetx f_t vs V_{GS}, V_{DS} = 1.8 V (tt)');
legend(h, lg, 'Location', 'southeast');
exportgraphics(gcf, fullfile(out, 'hw2_ft_vs_vgs.png'), 'Resolution', 130);
