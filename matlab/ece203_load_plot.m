% ece203_load_plot.m -- ECE203 Round 2B loading diagnosis plots.
% Put next to the extracted ece203_load/ folder in _raw/<exp>/; PNGs go to <notebook>/<exp>/.
clear; close all;
here = fileparts(mfilename('fullpath'));
[~, e] = fileparts(here);
out = fullfile(fileparts(fileparts(here)), e);
if ~exist(out, 'dir'), mkdir(out); end
d = fullfile(here, 'ece203_load');
has = @(t) exist(fullfile(d, [t '_ac.csv']), 'file') == 2;
rd = @(f) readtable(fullfile(d, f), 'VariableNamingRule', 'preserve', 'TextType', 'string');
ac = @(t) rd([t '_ac.csv']);
cases = {'C0', 'C1', 'C2'}; clab = {'R1/R2 = 1M/4M', '10M/40M', '100M/400M'};
cc = lines(3);

% ---------- 1. A1 transfer: standalone vs connected ----------
fig = figure('Name', 'load_a1_transfer', 'Position', [100 100 900 560]);
ax = axes; hold(ax, 'on'); grid on;
L = {};
if has('A_a1iso_cl5p'), T = ac('A_a1iso_cl5p'); semilogx(T.f_Hz, T.abs_A1, 'k-', 'LineWidth', 2.2); L{end+1} = 'A1 alone, C_L 5 pF (= hp\_real\_tb)'; end
if has('B1_a1_rld1M'), T = ac('B1_a1_rld1M'); semilogx(T.f_Hz, T.abs_A1, 'k--', 'LineWidth', 1.4); L{end+1} = 'A1 alone + 1 M\Omega to vref (standalone)'; end
if has('B1_a1_rld5M'), T = ac('B1_a1_rld5M'); semilogx(T.f_Hz, T.abs_A1, 'k:', 'LineWidth', 1.6); L{end+1} = 'A1 alone + 5 M\Omega to vref (standalone)'; end
for k = 1:3
    t = ['C_chain_' cases{k}];
    if has(t)
        T = ac(t);
        semilogx(T.f_Hz, T.abs_A1P, '-', 'Color', cc(k,:), 'LineWidth', 1.6); L{end+1} = ['in chain: |o1/v_{inp}| (port A), ' clab{k}];
        semilogx(T.f_Hz, T.abs_A2N, '--', 'Color', cc(k,:), 'LineWidth', 1.6); L{end+1} = ['in chain: |o2/v_{inn}| (port B), ' clab{k}];
    end
end
if has('B1_chain_buf_C0'), T = ac('B1_chain_buf_C0'); semilogx(T.f_Hz, T.abs_A1P, 'm-.', 'LineWidth', 1.6); L{end+1} = 'chain C0 + ideal buffers: |o1/v_{inp}|'; end
set(ax, 'XScale', 'log', 'YScale', 'log'); xlim([1e-2 1e5]); yline(25, ':', 'ideal 25', 'HandleVisibility', 'off');
xlabel('f (Hz)'); ylabel('|first-stage gain| (V/V)'); legend(L, 'Location', 'eastoutside');
title('A1/A2 closed-loop transfer: alone vs. connected to the real A3 network (single-ended excitation)');
exportgraphics(fig, fullfile(out, 'load_a1_transfer.png'), 'Resolution', 130);

% ---------- 2. chain Hdm and per-stage ----------
fig = figure('Name', 'load_chain_hdm', 'Position', [100 100 900 760]);
subplot(2,1,1); hold on; grid on; L = {};
if has('C_ideal_C0'), T = ac('C_ideal_C0'); semilogx(T.f_Hz, 20*log10(T.abs_Hout), 'k-', 'LineWidth', 2.4); L{end+1} = 'all-VCVS golden (same network + RC)'; end
for k = 1:3
    t = ['C_chain_' cases{k}];
    if has(t), T = ac(t); semilogx(T.f_Hz, 20*log10(T.abs_Hout), 'Color', cc(k,:), 'LineWidth', 1.6); L{end+1} = ['real chain, ' clab{k}]; end
end
set(gca, 'XScale', 'log'); xlim([1e-2 1e5]); ylim([-10 45]);
yline([38 42], ':', 'HandleVisibility', 'off'); xline([0.1 250], ':', 'HandleVisibility', 'off');
ylabel('|v_{out} / v_{d}| (dB)'); legend(L, 'Location', 'south'); title('Full chain, final output after the RC, 1 V differential stimulus');
subplot(2,1,2); hold on; grid on; L = {};
t = 'C_chain_C0';
if has(t)
    T = ac(t);
    semilogx(T.f_Hz, T.abs_G12, 'LineWidth', 1.6); L{end+1} = '|(o1 - o2)/v_d|  (A1/A2, ideal 25)';
    semilogx(T.f_Hz, T.abs_G3, 'LineWidth', 1.6);  L{end+1} = '|o3/(o2 - o1)|  (A3 before RC, ideal 4)';
    semilogx(T.f_Hz, T.abs_RC, 'LineWidth', 1.6);  L{end+1} = '|out/o3|  (output RC)';
    semilogx(T.f_Hz, T.abs_Hout, 'k', 'LineWidth', 2); L{end+1} = '|out/v_d|  (total)';
end
set(gca, 'XScale', 'log', 'YScale', 'log'); xlim([1e-2 1e5]); xlabel('f (Hz)'); ylabel('|gain| (V/V)');
legend(L, 'Location', 'southwest'); title('Real chain C0 (1M/4M): where the gain goes, same differential run');
exportgraphics(fig, fullfile(out, 'load_chain_hdm.png'), 'Resolution', 130);

% ---------- 3. A3 before/after RC ----------
fig = figure('Name', 'load_a3_rc', 'Position', [100 100 900 520]); hold on; grid on; L = {};
for k = 1:3
    t = ['C_a3iso_' cases{k}];
    if has(t), T = ac(t);
        semilogx(T.f_Hz, T.abs_G3, '-', 'Color', cc(k,:), 'LineWidth', 1.6); L{end+1} = ['A3 alone, at o3 (before RC), ' clab{k}];
        semilogx(T.f_Hz, T.abs_G3rc, '--', 'Color', cc(k,:), 'LineWidth', 1.4); L{end+1} = ['A3 alone, at out (after RC), ' clab{k}];
    end
end
if has('B3_a3iso_noRC_C0'), T = ac('B3_a3iso_noRC_C0'); semilogx(T.f_Hz, T.abs_G3, 'k:', 'LineWidth', 2); L{end+1} = 'A3 alone, C0, RC removed (RLP = 1e15)'; end
set(gca, 'XScale', 'log', 'YScale', 'log'); xlim([1e-2 1e5]); yline(4, ':', 'ideal 4', 'HandleVisibility', 'off');
xlabel('f (Hz)'); ylabel('|v / (v_{o2} - v_{o1})|'); legend(L, 'Location', 'eastoutside');
title('A3 driven by ideal sources: gain before and after the output RC');
exportgraphics(fig, fullfile(out, 'load_a3_rc.png'), 'Resolution', 130);

% ---------- 4. A3 input loading ----------
fig = figure('Name', 'load_zin', 'Position', [100 100 900 560]); hold on; grid on; L = {};
for k = 1:3
    t = ['C_a3iso_' cases{k}];
    if has(t), T = ac(t);
        loglog(T.f_Hz, T.abs_ZinA, '-', 'Color', cc(k,:), 'LineWidth', 1.4); L{end+1} = ['port A (o1 side), one port driven, ' clab{k}];
        loglog(T.f_Hz, T.abs_ZinB, '--', 'Color', cc(k,:), 'LineWidth', 1.4); L{end+1} = ['port B (o2 side), one port driven, ' clab{k}];
    end
    t = ['C_chain_' cases{k}];
    if has(t), T = ac(t);
        loglog(T.f_Hz, T.abs_ZloadA, ':', 'Color', cc(k,:), 'LineWidth', 2); L{end+1} = ['port A seen by real A1 in DM chain, ' clab{k}];
    end
end
set(gca, 'XScale', 'log', 'YScale', 'log'); xlim([1e-2 1e5]); xline([1 10 60 100 250], ':', 'HandleVisibility', 'off');
xlabel('f (Hz)'); ylabel('|Z_{in}| (\Omega)'); legend(L, 'Location', 'eastoutside');
title('Impedance looking into the A3 resistor-network inputs');
exportgraphics(fig, fullfile(out, 'load_zin.png'), 'Resolution', 130);

% ---------- 5. loop gains ----------
fig = figure('Name', 'load_stb', 'Position', [100 100 900 700]);
for j = 1:3
    subplot(3,1,j); hold on; grid on; L = {};
    for k = 1:3
        f = fullfile(d, ['C_chain_' cases{k} '_stb.csv']);
        if exist(f, 'file'), T = readtable(f, 'VariableNamingRule', 'preserve');
            loglog(T.f_Hz, T.(sprintf('abs_LG%d', j)), 'Color', cc(k,:), 'LineWidth', 1.5); L{end+1} = clab{k}; end
    end
    set(gca, 'XScale', 'log', 'YScale', 'log'); yline(1, ':', 'HandleVisibility', 'off');
    ylabel(sprintf('|LG%d|', j)); legend(L, 'Location', 'southwest');
    nm = {'A1', 'A2', 'A3'};
    title(sprintf('Loop %d (%s) in the full chain, other loops intact', j, nm{j}));
end
xlabel('f (Hz)');
exportgraphics(fig, fullfile(out, 'load_stb.png'), 'Resolution', 130);

% ---------- 6. transient ----------
fig = figure('Name', 'load_tran', 'Position', [100 100 900 600]);
for k = 1:3
    f = fullfile(d, ['C_chain_' cases{k} '_tran1.csv']);
    if exist(f, 'file'), T = readtable(f, 'VariableNamingRule', 'preserve');
        subplot(3,1,k); plot(T.t_s, T.out_V, 'LineWidth', 1.3); hold on; plot(T.t_s, T.o3_V, '--'); grid on;
        ylabel('V'); title(['10 Hz, v_d = 5 mV peak (ideal out \pm0.5 V): ' clab{k}]); legend('out', 'o3', 'Location', 'eastoutside');
    end
end
xlabel('t (s)');
exportgraphics(fig, fullfile(out, 'load_tran.png'), 'Resolution', 130);

% ---------- 7. decomposition summary ----------
S = [];
for f = ["ece203_load_chain.csv" "ece203_load_isolate.csv" "ece203_load_sweep.csv"]
    if exist(fullfile(d, f), 'file'), S = [S; rd(f)]; end %#ok<AGROW>
end
if ~isempty(S)
    rows = ["C_chain_C0" "C_chain_C1" "C_chain_C2" "C_chainN_C0" "C_chainN_C2" "B1_chain_buf_C0" "B2_chain_a3vcvs_C0" "C_ideal_C0"];
    rows = rows(ismember(rows, S.tag));
    M = nan(numel(rows), 4);
    for i = 1:numel(rows)
        r = S(S.tag == rows(i), :);
        tn = @(x) str2double(string(x));
        M(i,:) = [tn(r.A1P_100) tn(r.A2N_100) 25 * tn(r.G3_100) tn(r.Hout_100)];
    end
    fig = figure('Name', 'load_decomp', 'Position', [100 100 1000 480]);
    b = bar(categorical(rows, rows), M); grid on; set(gca, 'TickLabelInterpreter', 'none');
    yline([25 100], ':', {'25', '100'});
    legend('|o1/v_{inp}| (A1 path)', '|o2/v_{inn}| (A2 path)', '25 \times |A3 gain| (o3/(o2-o1))', '|out/v_d| total', 'Location', 'eastoutside');
    ylabel('V/V at 100 Hz'); title('Per-stage gains at 100 Hz (A3 scaled by 25 to share the axis)');
    exportgraphics(fig, fullfile(out, 'load_decomp.png'), 'Resolution', 130);
end
