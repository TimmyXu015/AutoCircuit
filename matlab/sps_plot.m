% sps_plot.m -- subthreshold vs strong-inversion CS amp (HW1 P2 circuit), Id = 10 uA both
% Data from ~/AutoCircuit/run.sh sps (OCEAN, cmrf7sf tt). Run this file to redraw.
clear; close all;
d = fileparts(mfilename('fullpath')); if isempty(d), d = pwd; end   % raw data: _raw\<experiment>
[~, expName] = fileparts(d); out = fullfile(fileparts(fileparts(d)), expName);   % figures: <experiment>
cells = {'cs_strong', 'cs_sub'};
lbl   = {'Strong inversion (W = 0.75 \mum)', 'Subthreshold (W = 400 \mum)'};
col   = {[42 120 214]/255, [235 104 52]/255};    % fixed: strong = blue, sub = orange
lst   = {'-', '--'};
fmark = [100 1e6];                                % the two input frequencies
gray  = [0.45 0.45 0.45];

op = readtable(fullfile(d, 'sps_op.csv'), 'VariableNamingRule', 'preserve');

%% ---------- AC: metrics ----------
S = struct([]);
for k = 1:2
    A  = readmatrix(fullfile(d, ['sps_ac_' cells{k} '.csv']));
    f  = A(:,1);
    vo = A(:,2) + 1i*A(:,3);          % vout for vin = 1 V  -> overall gain
    vg = A(:,4) + 1i*A(:,5);          % vg   for vin = 1 V  -> input-network transfer
    S(k).f = f;  S(k).G = abs(vo);  S(k).Gg = abs(vg);  S(k).Av = abs(vo ./ vg);
    [pk, ip] = max(S(k).G);
    S(k).Gpk = pk;  S(k).fpk = f(ip);
    S(k).fL  = crossAt(f(1:ip),   S(k).G(1:ip),   pk/sqrt(2));
    S(k).fH  = crossAt(f(ip:end), S(k).G(ip:end), pk/sqrt(2));
    S(k).Av0 = S(k).Av(1);
    S(k).fHv = crossAt(f, S(k).Av, S(k).Av0/sqrt(2));
    S(k).Gat = interp1(log10(f), S(k).G,  log10(fmark));
    S(k).Ggat= interp1(log10(f), S(k).Gg, log10(fmark));
    S(k).Avat= interp1(log10(f), S(k).Av, log10(fmark));
end

%% ---------- transient: amplitude ratio over the last 2 periods ----------
tl = {'100Hz', '1MHz'};  tlab = {'100 Hz', '1 MHz'};
T = struct([]);
for k = 1:2
    for j = 1:2
        B = readmatrix(fullfile(d, sprintf('sps_tran_%s_%s.csv', cells{k}, tl{j})));
        t = B(:,1);  P = 1/fmark(j);  m = t >= t(end) - 2*P;
        T(k,j).t = t(m) - t(find(m,1));
        T(k,j).vin  = B(m,2);
        T(k,j).vg   = B(m,3) - mean(B(m,3));
        T(k,j).vout = B(m,4) - mean(B(m,4));
        amp = @(x) (max(x) - min(x)) / 2;
        T(k,j).gain = amp(T(k,j).vout) / amp(T(k,j).vin);
        T(k,j).ggate = amp(T(k,j).vg) / amp(T(k,j).vin);
    end
end

%% ---------- summary table ----------
rowNames = {'W'; 'VBIAS = VGS (V)'; 'Vth (V)'; 'VGS - Vth (V)'; 'region (2 = sat, 3 = subth)'; ...
    'gm (uS)'; 'gm/Id (1/V)'; 'ro (kOhm)'; 'Cgg (fF)'; '|Cgd| (fF)'; '|Cdd| (fF)'; ...
    '|vout/vg| low f (V/V)'; '-3 dB of |vout/vg| (Hz)'; '|vout/vg| x f-3dB (Hz)'; ...
    '|vout/vin| peak (V/V)'; 'f at peak (Hz)'; 'fL of |vout/vin| (Hz)'; 'fH of |vout/vin| (Hz)'; ...
    'AC |vg/vin| @100 Hz'; 'AC |vout/vg| @100 Hz'; 'AC |vout/vin| @100 Hz'; ...
    'AC |vg/vin| @1 MHz';  'AC |vout/vg| @1 MHz';  'AC |vout/vin| @1 MHz'; ...
    'tran |vout|/|vin| @100 Hz'; 'tran |vout|/|vin| @1 MHz'};
vals = cell(numel(rowNames), 2);
for k = 1:2
    r = op(k,:);
    vals(:,k) = {r.W{1}; r.vbias_V; r.vth; r.vgs - r.vth; r.region; ...
        r.gm*1e6; r.gm_over_Id_per_V; 1/r.gds/1e3; r.cgg*1e15; abs(r.cgd)*1e15; abs(r.cdd)*1e15; ...
        S(k).Av0; S(k).fHv; S(k).Av0*S(k).fHv; ...
        S(k).Gpk; S(k).fpk; S(k).fL; S(k).fH; ...
        S(k).Ggat(1); S(k).Avat(1); S(k).Gat(1); S(k).Ggat(2); S(k).Avat(2); S(k).Gat(2); ...
        T(k,1).gain; T(k,2).gain};
end
fid = fopen(fullfile(d, 'summary.csv'), 'w');
fprintf(fid, 'quantity,cs_strong,cs_sub\n');
fprintf('\n%-30s %14s %14s\n', 'quantity', 'cs_strong', 'cs_sub');
for i = 1:numel(rowNames)
    s = cellfun(@fmt, vals(i,:), 'UniformOutput', false);
    fprintf(fid, '"%s",%s,%s\n', rowNames{i}, s{1}, s{2});
    fprintf('%-30s %14s %14s\n', rowNames{i}, s{1}, s{2});
end
fclose(fid);

%% ---------- figure 1: AC ----------
fig = figure('Color', 'w', 'Position', [80 60 900 980]);
tlo = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ttl = {'Overall gain  |v_{out}/v_{in}|', 'Transistor stage  |v_{out}/v_{g}|', ...
       'Input network (C0, RLARGE, gate cap)  |v_{g}/v_{in}|'};
fld = {'G', 'Av', 'Gg'};
for p = 1:3
    ax = nexttile; hold(ax, 'on');
    h = gobjects(1,2);
    for k = 1:2
        y = 20*log10(S(k).(fld{p}));
        h(k) = semilogx(ax, S(k).f, y, lst{k}, 'Color', col{k}, 'LineWidth', 2);
        yy = interp1(log10(S(k).f), y, log10(fmark));
        plot(ax, fmark, yy, 'o', 'MarkerSize', 8, 'MarkerFaceColor', col{k}, 'MarkerEdgeColor', 'w');
        for j = 1:2
            text(ax, fmark(j)*1.35, yy(j), sprintf('%.3g', 10^(yy(j)/20)), 'Color', [0.15 0.15 0.15], ...
                 'FontSize', 9, 'VerticalAlignment', 'middle');
        end
    end
    set(ax, 'XScale', 'log', 'XLim', [1 1e10], 'FontSize', 10, 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
    grid(ax, 'on'); box(ax, 'off');
    xline(ax, 100, ':', '100 Hz', 'Color', gray, 'LabelVerticalAlignment', 'bottom', 'FontSize', 9);
    xline(ax, 1e6, ':', '1 MHz',  'Color', gray, 'LabelVerticalAlignment', 'bottom', 'FontSize', 9);
    ylabel(ax, 'dB');  title(ax, ttl{p}, 'FontWeight', 'normal');
    if p == 1, legend(ax, h, lbl, 'Location', 'southeast', 'Box', 'off'); end
    if p == 3, xlabel(ax, 'Frequency (Hz)'); end
end
title(tlo, 'AC sweep, Id = 10 \muA in both  (numbers = linear gain at 100 Hz and 1 MHz)', 'FontSize', 12);
exportgraphics(fig, fullfile(out, 'ac_compare.png'), 'Resolution', 130);

%% ---------- figure 2: transient ----------
fig = figure('Color', 'w', 'Position', [80 60 1100 720]);
tlo = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
tsc = [1e3 1e6];  tun = {'ms', '\mus'};
for j = 1:2
    for k = 1:2
        ax = nexttile; hold(ax, 'on');
        tt = T(k,j).t * tsc(j);
        h1 = plot(ax, tt, T(k,j).vin*1e3,  '-', 'Color', gray, 'LineWidth', 1.5);
        h2 = plot(ax, tt, T(k,j).vg*1e3,   ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.5);
        h3 = plot(ax, tt, T(k,j).vout*1e3, lst{k}, 'Color', col{k}, 'LineWidth', 2);
        grid(ax, 'on'); box(ax, 'off');
        set(ax, 'FontSize', 10, 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
        xlabel(ax, ['t (' tun{j} ')']);  ylabel(ax, 'mV (ac part)');
        title(ax, sprintf('%s, %s:  |v_{out}|/|v_{in}| = %.3g', lbl{k}, tlab{j}, T(k,j).gain), ...
              'FontWeight', 'normal', 'FontSize', 10);
        legend(ax, [h1 h2 h3], {'v_{in}', 'v_{g}', 'v_{out} - V_{out,dc}'}, 'Location', 'northeast', 'Box', 'off');
    end
end
title(tlo, 'Transient, 1 mV sine input, last 2 periods', 'FontSize', 12);
exportgraphics(fig, fullfile(out, 'tran_compare.png'), 'Resolution', 130);

%% ---------- figure 3: W scan that picked the two circuits ----------
W = readtable(fullfile(d, 'sps_wscan.csv'), 'VariableNamingRule', 'preserve');
wu = str2double(erase(W.W, 'u'));
fig = figure('Color', 'w', 'Position', [80 60 900 640]);
tlo = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
pick = [0.75 400];
ax = nexttile; hold(ax, 'on');
semilogx(ax, wu, W.gm_over_Id_per_V, '-o', 'Color', gray, 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'w');
for k = 1:2
    i = find(abs(wu - pick(k)) < 1e-9);
    plot(ax, wu(i), W.gm_over_Id_per_V(i), 'o', 'MarkerSize', 10, 'MarkerFaceColor', col{k}, 'MarkerEdgeColor', 'w');
    text(ax, wu(i)*1.3, W.gm_over_Id_per_V(i), strrep(cells{k}, '_', '\_'), 'FontSize', 10);
end
set(ax, 'XScale', 'log', 'FontSize', 10); grid(ax, 'on'); box(ax, 'off');
ylabel(ax, 'g_m/I_D (1/V)'); title(ax, 'g_m/I_D vs W at I_D = 10 \muA, L = 1.5 \mum', 'FontWeight', 'normal');
ax = nexttile; hold(ax, 'on');
semilogx(ax, wu, W.vbias_V, '-o', 'Color', gray, 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'w');
yline(ax, mean(op.vth), ':', sprintf('V_{th} \\approx %.2f V', mean(op.vth)), 'Color', gray);
for k = 1:2
    i = find(abs(wu - pick(k)) < 1e-9);
    plot(ax, wu(i), W.vbias_V(i), 'o', 'MarkerSize', 10, 'MarkerFaceColor', col{k}, 'MarkerEdgeColor', 'w');
end
set(ax, 'XScale', 'log', 'FontSize', 10); grid(ax, 'on'); box(ax, 'off');
ylabel(ax, 'V_{BIAS} = V_{GS} (V)'); xlabel(ax, 'W (\mum)');
title(ax, 'V_{GS} needed for 10 \muA', 'FontWeight', 'normal');
exportgraphics(fig, fullfile(out, 'wscan.png'), 'Resolution', 130);
disp('done');

%% ---------- helpers ----------
function fx = crossAt(f, y, th)
    % first frequency where y crosses th (log-f interpolation); NaN if none
    fx = NaN;
    s = sign(y - th);
    i = find(s(1:end-1) ~= s(2:end), 1);
    if isempty(i), return; end
    a = log10(f(i)); b = log10(f(i+1));
    fx = 10^(a + (th - y(i)) * (b - a) / (y(i+1) - y(i)));
end

function s = fmt(x)
    if ischar(x) || isstring(x), s = char(x);
    elseif isnan(x), s = 'n/a';
    else, s = sprintf('%.4g', x); end
end
