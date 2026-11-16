% ece203_hpfb_plot.m -- ece203_hp_fb_tb (extracted 3-pin network) vs ece203_hp_ideal_tb (golden)
% Data: ece203_hpfb_ac.csv here, ece203_hp_ac.csv in _raw/2026-11-15_ece203_hp_ideal_closed_loop/
clear; close all;
here = fileparts(mfilename('fullpath'));
[~, e] = fileparts(here);
out = fullfile(fileparts(fileparts(here)), e);
if ~exist(out, 'dir'), mkdir(out); end
B = readtable(fullfile(here, 'ece203_hpfb_ac.csv'), 'VariableNamingRule', 'preserve');
A = readtable(fullfile(fileparts(here), '2026-11-15_ece203_hp_ideal_closed_loop', 'ece203_hp_ac.csv'), ...
    'VariableNamingRule', 'preserve');
fig = figure('Name', 'hpfb_vs_ideal', 'Position', [100 100 760 640]);
subplot(3,1,1);
semilogx(A.f_Hz, A.H_dB, 'LineWidth', 2.5); hold on; grid on;
semilogx(B.f_Hz, B.H_dB, '--', 'LineWidth', 1.5);
ylabel('|H| (dB)'); legend('ece203\_hp\_ideal\_tb (CC/CF/RP drawn inline)', ...
    'ece203\_hp\_fb\_tb (one ece203\_hp\_fb instance)', 'Location', 'southeast');
title('Before / after extracting the feedback network (A_{OL} = 1e5)');
subplot(3,1,2);
semilogx(A.f_Hz, B.H_dB - A.H_dB, 'LineWidth', 1.5); grid on; ylabel('\Delta|H| (dB)');
subplot(3,1,3);
semilogx(A.f_Hz, B.phase_deg - A.phase_deg, 'LineWidth', 1.5); grid on;
ylabel('\Delta phase (deg)'); xlabel('f (Hz)');
exportgraphics(fig, fullfile(out, 'hpfb_vs_ideal.png'), 'Resolution', 130);
fprintf('max |dH| = %g dB, max |dphase| = %g deg\n', max(abs(B.H_dB - A.H_dB)), max(abs(B.phase_deg - A.phase_deg)));
