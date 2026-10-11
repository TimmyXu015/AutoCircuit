%% gmid_plot.m -- gm/Id of an NMOS (cmrf7sf nfetx, W/L = 5/1 um, VDS = 1.8 V) vs VGS
% Data: gmid.csv next to this script (from run.sh gmid).
%
% Figure 1  gm/Id vs VGS, with the operating regions shaded and two textbook lines:
%           weak inversion  gm/Id = 1/(n*phi_t)   (diffusion current, exponential law)
%           strong inversion gm/Id = 2/(VGS - Vt) (drift current, square law)
%           Top panel: Ids on a log scale, for context.
% Figure 2  gm/Id vs Ids (log axis) -- the usual "gm/Id design chart" view
%
% Region boundaries are approximate and chosen from the data:
%   leakage floor     gm/Id below half of its peak, on the low-VGS side
%   weak inversion    gm/Id within 90 % of its peak
%   strong inversion  VGS > Vt + 0.2 V
%   moderate          in between

clear; close all;
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
T = readtable(fullfile(here, 'gmid.csv'));
vg = T.VGS_V;  id = T.Ids_A;  gmid = T.gm_over_Id_per_V;
phit = 0.02585;                                    % kT/q at 300 K

% peak (plateau) of gm/Id, ignoring the two end points
inner = 2:numel(vg)-1;
[gpk, ip] = max(gmid(inner));  ip = inner(ip);
n = 1 / (gpk * phit);

% Vt from the square law: extrapolate sqrt(Id) at its steepest point to zero
s  = sqrt(id);
ds = gradient(s, vg);
[~, im] = max(ds);
Vt = vg(im) - s(im) / ds(im);

% region boundaries
lo  = find(gmid(1:ip) < 0.5*gpk, 1, 'last');       % end of leakage floor
wiA = find(gmid(1:ip) >= 0.9*gpk, 1, 'first');      % weak inversion start
wiB = ip - 1 + find(gmid(ip:end) < 0.9*gpk, 1, 'first');  % weak inversion end
siA = Vt + 0.2;
vLo = vg(lo);  vWa = vg(wiA);  vWb = vg(wiB);

fprintf('peak gm/Id = %.2f 1/V at VGS = %.3f V  ->  n = %.3f\n', gpk, vg(ip), n);
fprintf('Vt (sqrt(Id) extrapolation) = %.3f V\n', Vt);
fprintf('weak inversion (>= 90%% of peak): VGS %.3f .. %.3f V\n', vWa, vWb);

%% Figure 1
f1 = figure('Name', 'gmId vs VGS', 'Color', 'w', 'Position', [80 60 820 760]);
tl = tiledlayout(3, 1, 'TileSpacing', 'compact');

nexttile;
semilogy(vg, id, 'k-', 'LineWidth', 1.6); hold on;
shadeRegions(vg, vLo, vWa, vWb, siA);
semilogy(vg, id, 'k-', 'LineWidth', 1.6);
xline(Vt, 'k:', sprintf('V_t \\approx %.2f V', Vt), 'LabelVerticalAlignment', 'bottom');
ylabel('I_{DS} (A)'); grid on; xlim([vg(1) vg(end)]);
title(sprintf('cmrf7sf nfetx, W/L = 5/1 \\mum, V_{DS} = 1.8 V'));

nexttile([2 1]);
shadeRegions(vg, vLo, vWa, vWb, siA); hold on;
h1 = plot(vg, gmid, 'b-', 'LineWidth', 2);
h2 = yline(1/(n*phit), 'r--', 'LineWidth', 1.4);
vs = vg(vg > Vt + 0.05);
h3 = plot(vs, 2./(vs - Vt), 'm:', 'LineWidth', 1.8);
plot(vg(ip), gpk, 'ko', 'MarkerFaceColor', 'y');
text(vg(ip) + 0.03, gpk + 2.2, sprintf('peak %.1f V^{-1}  (n = %.2f)', gpk, n));
xline(Vt, 'k:');
ylim([0 1.3*gpk]); xlim([vg(1) vg(end)]); grid on;
xlabel('V_{GS} (V)'); ylabel('g_m / I_D  (V^{-1})');
legend([h1 h2 h3], {'g_m/I_D (simulation)', ...
        sprintf('1/(n\\phi_t) = %.1f V^{-1}  weak inversion limit', 1/(n*phit)), ...
        '2/(V_{GS} - V_t)  square law'}, 'Location', 'east');
text(mean([vg(1) vLo]), 1.2*gpk, {'leakage', 'floor'}, 'HorizontalAlignment', 'center', 'FontSize', 8);
text(mean([vWa vWb]), 1.2*gpk, {'weak inversion', '(diffusion)'}, 'HorizontalAlignment', 'center', 'FontSize', 8);
text(mean([vWb siA]), 1.2*gpk, 'moderate', 'HorizontalAlignment', 'center', 'FontSize', 8);
text(mean([siA vg(end)]), 1.2*gpk, {'strong inversion', '(drift)'}, 'HorizontalAlignment', 'center', 'FontSize', 8);

%% Figure 2: gm/Id vs Ids
f2 = figure('Name', 'gmId vs Id', 'Color', 'w', 'Position', [140 120 760 480]);
k = vg > vLo;                                       % leave out the leakage floor
semilogx(id(k), gmid(k), 'b-', 'LineWidth', 2); hold on;
yline(1/(n*phit), 'r--', 'LineWidth', 1.4);
plot(id(ip), gpk, 'ko', 'MarkerFaceColor', 'y');
grid on; xlabel('I_{DS} (A)'); ylabel('g_m / I_D  (V^{-1})');
title('g_m/I_D vs drain current: flat at low current, falling in strong inversion');
ylim([0 1.25*gpk]);

%% ---------- helpers ----------
function shadeRegions(vg, vLo, vWa, vWb, siA)
    c = struct('leak', [.92 .92 .92], 'weak', [.85 .95 .85], 'mod', [.97 .95 .82], 'strong', [.86 .90 .98]);
    xregion(vg(1), vLo, 'FaceColor', c.leak);
    xregion(vWa, vWb, 'FaceColor', c.weak);
    xregion(vWb, siA, 'FaceColor', c.mod);
    xregion(siA, vg(end), 'FaceColor', c.strong);
end
