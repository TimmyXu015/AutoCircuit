% ece203_noise_plot.m -- ECE203 Round 2A noise scan plots.
% Put next to the extracted ece203_ns/ folder in _raw/<exp>/; PNGs go to <notebook>/<exp>/.
clear; close all;
here = fileparts(mfilename('fullpath'));
[~, e] = fileparts(here);
out = fullfile(fileparts(fileparts(here)), e);
if ~exist(out, 'dir'), mkdir(out); end
d = fullfile(here, 'ece203_ns');
rd = @(f) readtable(fullfile(d, f), 'VariableNamingRule', 'preserve', 'TextType', 'string');
S = rd('ece203_ns_sweep.csv');
if exist(fullfile(d, 'ece203_ns_rebias.csv'), 'file')
    R = rd('ece203_ns_rebias.csv'); S = [S; R(:, S.Properties.VariableNames)];
end
B = rd('ece203_noise_breakdown.csv');
groups = ["inpair" "mirror" "pcas" "ncas" "tailref" "rp" "other"];
glab = {'input pair M1/M2', 'NMOS mirror M7/M8', 'PMOS cascode M3/M4', 'NMOS cascode M5/M6', ...
        'tail/ref M0/MREF', 'feedback Rp', 'other (PDK parasitic R)'};
ok = S.run_status == "ok";
uV = 1e6;

% ---------- 1. baseline breakdown ----------
fig = figure('Name', 'ns_breakdown', 'Position', [100 100 900 700]);
b = B(B.tag == "w20_l1" & B.kind == "integrated_0.1_250Hz", :);
tot = sum(b.V2_out);
fl = zeros(1, numel(groups)); th = fl;
for k = 1:numel(groups)
    g = b(b.group == groups(k), :);
    fl(k) = sum(g.V2_out(g.param == "fn")); th(k) = sum(g.V2_out(g.param ~= "fn"));
end
subplot(2,1,1);
bh = bar(categorical(glab, glab), 100 * [fl; th]' / tot, 'stacked'); grid on;
bh(1).DisplayName = 'flicker (fn)'; bh(2).DisplayName = 'thermal (id, rn)';
legend('Location', 'northeast'); ylabel('% of output noise power');
title(sprintf('Baseline W20/L1: integrated 0.1-250 Hz noise by device group (total out %.3g V^2 -> in %.3g \\muV_{rms})', ...
    tot, sqrt(S.sum_inref_V2(S.tag == "w20_l1")) * uV));
subplot(2,1,2);
sp = B(B.tag == "w20_l1" & B.kind == "spot_V2_per_Hz", :);
fs = unique(sp.freq_Hz);
P = zeros(numel(fs), numel(groups));
for i = 1:numel(fs)
    s = sp(sp.freq_Hz == fs(i), :); t = sum(s.V2_out);
    for k = 1:numel(groups), P(i, k) = 100 * sum(s.V2_out(s.group == groups(k))) / t; end
end
bar(categorical(compose('%g Hz', fs), compose('%g Hz', fs)), P, 'stacked'); grid on;
legend(glab, 'Location', 'eastoutside'); ylabel('% of output noise PSD');
title('Baseline: share of each group in the spot noise');
exportgraphics(fig, fullfile(out, 'ns_breakdown.png'), 'Resolution', 130);

% ---------- 2. baseline PSD + slopes ----------
N = rd('w20_l1_noise.csv');
fig = figure('Name', 'ns_baseline_psd', 'Position', [100 100 800 560]);
subplot(2,1,1);
loglog(N.f_Hz, N.in_V_rtHz, 'LineWidth', 1.6); hold on; grid on;
fsp = [0.1 1 10 100 250 1000];
v = interp1(log(N.f_Hz), log(N.in_V_rtHz), log(fsp)); v = exp(v);
plot(fsp, v, 'o');
for i = 1:numel(fsp) - 1
    sl = (log10(v(i+1)) - log10(v(i))) / (log10(fsp(i+1)) - log10(fsp(i)));
    text(sqrt(fsp(i) * fsp(i+1)), sqrt(v(i) * v(i+1)) * 1.6, sprintf('%.2f', sl), 'HorizontalAlignment', 'center');
end
xline([0.1 250], ':');
ylabel('input-referred (V/\surdHz)');
title('Baseline: noise amplitude density; numbers = log-log slope (-0.5 = 1/f power)');
subplot(2,1,2);
loglog(N.f_Hz, N.out_V_rtHz, 'LineWidth', 1.6); grid on; xline([0.1 250], ':');
ylabel('output (V/\surdHz)'); xlabel('f (Hz)');
exportgraphics(fig, fullfile(out, 'ns_baseline_psd.png'), 'Resolution', 130);

% ---------- 3. grid: rms vs W ----------
G = S(S.stage == "S2grid", :);
Ls = unique(G.l_um);
cols = lines(numel(Ls));
fig = figure('Name', 'ns_grid_rms', 'Position', [100 100 800 700]);
subplot(2,1,1); hold on; grid on;
for k = 1:numel(Ls)
    f = G.l_um == Ls(k) & G.bias_mode == "fixed" & G.run_status == "ok";
    plot(G.w_um(f), G.("rms_in_0.1_250_V")(f) * uV, '-o', 'Color', cols(k,:), 'LineWidth', 1.6, ...
        'DisplayName', sprintf('L = %g \\mum, fixed bias', Ls(k)));
    f = G.l_um == Ls(k) & G.bias_mode == "rebiased" & G.run_status == "ok";
    if any(f)
        plot(G.w_um(f), G.("rms_in_0.1_250_V")(f) * uV, 's', 'Color', cols(k,:), 'MarkerSize', 9, 'LineWidth', 1.6, ...
            'DisplayName', sprintf('L = %g \\mum, rebiased', Ls(k)));
    end
end
S3 = S(S.stage ~= "S2grid" & S.run_status == "ok", :);
for i = 1:height(S3)
    plot(S3.w_um(i), S3.("rms_in_0.1_250_V")(i) * uV, 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'y', ...
        'DisplayName', char(S3.tag(i)));
end
yline([1 1.5], ':', {'1 \muV', '1.5 \muV'}, 'HandleVisibility', 'off');
set(gca, 'XScale', 'log'); xticks([20 40 80 160]); xlabel('input pair W (\mum)');
ylabel('\surd\int_{0.1}^{250} v_{n,in}^2 df (\muV_{rms})'); legend('Location', 'eastoutside', 'Interpreter', 'none');
title('Single A1/A2 + feedback: integrated input-referred noise, 0.1-250 Hz');
subplot(2,1,2); hold on; grid on;
for k = 1:numel(Ls)
    f = G.l_um == Ls(k) & G.run_status == "ok";
    plot(G.w_um(f), G.pct_inpair(f), '-o', 'Color', cols(k,:), 'LineWidth', 1.4, 'DisplayName', sprintf('input pair, L=%g', Ls(k)));
    plot(G.w_um(f), G.pct_mirror(f), '--s', 'Color', cols(k,:), 'LineWidth', 1.4, 'DisplayName', sprintf('mirror M7/M8, L=%g', Ls(k)));
end
set(gca, 'XScale', 'log'); xticks([20 40 80 160]); xlabel('input pair W (\mum)'); ylabel('% of noise power (0.1-250 Hz)');
legend('Location', 'eastoutside');
exportgraphics(fig, fullfile(out, 'ns_grid_rms.png'), 'Resolution', 130);

% ---------- 4. tradeoffs ----------
q = {'idd_A', 1e9, 'I(VDD) (nA)'; 'PM_deg', 1, 'PM (deg)'; 'fH_Hz', 1e-3, 'f_H (kHz)';
     'absH_100Hz', 1, '|H(100 Hz)|'; 'absZin_10Hz_ohm', 1e-6, '|Z_{in}(10 Hz)| (M\Omega)';
     'min_margin_V', 1e3, 'min sat. margin (mV)'; 'A0_unloaded', 1, 'A_0 unloaded'; 'gmid_M1', 1, 'g_m/I_D of M1 (1/V)';
     'fL_Hz', 1, 'f_L (Hz)'};
fig = figure('Name', 'ns_tradeoffs', 'Position', [100 100 1100 800]);
for j = 1:size(q, 1)
    subplot(3, 3, j); hold on; grid on;
    for k = 1:numel(Ls)
        f = G.l_um == Ls(k) & G.run_status == "ok";
        y = G.(q{j,1})(f) * q{j,2};
        plot(G.w_um(f), y, '-o', 'Color', cols(k,:), 'LineWidth', 1.3, 'DisplayName', sprintf('L=%g', Ls(k)));
    end
    set(gca, 'XScale', 'log'); xticks([20 40 80 160]); title(q{j,3});
    if j == 1, legend('Location', 'best'); end
    if j >= 7, xlabel('W (\mum)'); end
end
sgtitle('Round 2A grid (valid points; rebiased points included, see CSV bias\_mode)');
exportgraphics(fig, fullfile(out, 'ns_tradeoffs.png'), 'Resolution', 130);

% ---------- 5. PSD overlay ----------
fig = figure('Name', 'ns_psd_overlay', 'Position', [100 100 800 500]);
V = S(ok, :);
for i = 1:height(V)
    T = rd(V.tag(i) + "_noise.csv");
    loglog(T.f_Hz, T.in_V_rtHz, 'LineWidth', 1.2, 'DisplayName', char(V.tag(i))); hold on;
end
grid on; xline([0.1 250], ':', 'HandleVisibility', 'off'); xlim([1e-2 1e4]);
xlabel('f (Hz)'); ylabel('input-referred (V/\surdHz)'); legend('Location', 'eastoutside', 'Interpreter', 'none');
title('Input-referred noise density of every valid point');
exportgraphics(fig, fullfile(out, 'ns_psd_overlay.png'), 'Resolution', 130);

% ---------- 6. noise vs area ----------
fig = figure('Name', 'ns_area', 'Position', [100 100 800 460]); hold on; grid on;
for k = 1:numel(Ls)
    f = G.l_um == Ls(k) & G.run_status == "ok";
    scatter(G.wl_um2(f), G.("rms_in_0.1_250_V")(f) * uV, 60, cols(k,:), 'filled', 'DisplayName', sprintf('grid, L=%g', Ls(k)));
end
for i = 1:height(S3)
    plot(S3.wl_um2(i), S3.("rms_in_0.1_250_V")(i) * uV, 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'y', 'DisplayName', char(S3.tag(i)));
end
set(gca, 'XScale', 'log', 'YScale', 'log'); xlabel('input pair W \times L (\mum^2, per device)');
ylabel('rms 0.1-250 Hz (\muV)'); legend('Location', 'eastoutside', 'Interpreter', 'none');
yline([1 1.5], ':', 'HandleVisibility', 'off');
title('Integrated input noise vs input-pair gate area');
exportgraphics(fig, fullfile(out, 'ns_area.png'), 'Resolution', 130);
