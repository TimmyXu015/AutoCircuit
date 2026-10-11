%% wsub_plot.m -- gm vs W with Ids locked (cmrf7sf nfetx, L = 1 um, VDS = 1.8 V)
% Data: wsub.csv next to this script (from run.sh wsub).
% Left:  gm vs W for each locked current, with the weak-inversion limit Id/(n*phi_t) dashed
% Right: the same data normalised to that limit -- 1.0 means "fully in weak inversion,
%        gm no longer depends on W"
clear; close all;
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
T = readtable(fullfile(here, 'wsub.csv'));
phit = 0.02585;
nBest = min(T.n_estimate);                  % deepest weak inversion seen -> smallest n
targets = unique(T.Id_target_A);
cols = lines(numel(targets));

figure('Name', 'gm vs W, Ids locked', 'Color', 'w', 'Position', [80 80 1100 470]);
tiledlayout(1, 2, 'TileSpacing', 'compact');

nexttile; hold on;
for i = 1:numel(targets)
    r = T.Id_target_A == targets(i);
    loglog(T.W_um(r), T.gm_S(r), 'o-', 'Color', cols(i,:), 'LineWidth', 1.8, 'MarkerFaceColor', cols(i,:));
    yline(targets(i)/(nBest*phit), '--', 'Color', cols(i,:), 'LineWidth', 1);
end
set(gca, 'XScale', 'log', 'YScale', 'log'); grid on; box on;
xlabel('W (\mum)'); ylabel('g_m (S)');
title('g_m at fixed I_{DS}; dashed = I_{DS}/(n\phi_t)');
lg = arrayfun(@(x) sprintf('I_{DS} = %s', engStr(x)), targets, 'UniformOutput', false);
h = flipud(findobj(gca, 'Type', 'line', 'Marker', 'o'));
legend(h, lg, 'Location', 'northwest');

nexttile; hold on;
for i = 1:numel(targets)
    r = T.Id_target_A == targets(i);
    semilogx(T.W_um(r), T.gm_over_Id_per_V(r) .* T.n_estimate(r) * phit, 'o-', ...
             'Color', cols(i,:), 'LineWidth', 1.8, 'MarkerFaceColor', cols(i,:));
end
set(gca, 'XScale', 'log'); grid on; box on;
yline(1, 'k--', 'weak-inversion limit', 'LabelHorizontalAlignment', 'left');
ylim([0 1.1]);
xlabel('W (\mum)'); ylabel('g_m / (I_{DS}/(n\phi_t))');
title('Normalised: flat near 1 = g_m independent of W');
legend(lg, 'Location', 'southeast');

function s = engStr(x)
    p = floor(log10(x)/3)*3;
    u = containers.Map({-15,-12,-9,-6,-3}, {'fA','pA','nA','\muA','mA'});
    s = sprintf('%g %s', x/10^p, u(p));
end
