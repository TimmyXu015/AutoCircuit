%% indb_plot.m -- plots for the planar inductor model, port 2 grounded
% L = 9 nH, Rs = 1 ohm, Cs = 50 fF, Cp = 0.2 pF, Rp = 5000 ohm
% Data from ~/AutoCircuit_results on ieng6 (run.sh indb). Copy it next to this script,
% from a LOCAL PowerShell window:
%   scp lix015@ieng6-ece-20.ucsd.edu:~/AutoCircuit_results/indb_*.csv $HOME\Downloads\
%
% Figure 1  X = Im{Zin} and Q = |X|/R, 0.5 - 6 GHz, log frequency (the homework plots)
% Figure 2  |Z|, R, X, phase, 10 MHz - 30 GHz, with the ideal-inductor line wL
% Figure 3  Smith chart (Z0 = 50 ohm) of the wide sweep

clear; close all;
L = 9e-9;  Rs = 1;  Cs = 50e-15;  Cp = 0.2e-12;  Rp = 5000;

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
hw   = readtable(fullfile(here, 'indb_hw.csv'));     % 0.5 .. 6 GHz
wide = readtable(fullfile(here, 'indb_wide.csv'));   % 10 MHz .. 30 GHz
fG = hw.f_Hz / 1e9;

% self-resonance read off the data: X crosses zero going from + to -
k   = find(wide.X_ohm(1:end-1) > 0 & wide.X_ohm(2:end) <= 0, 1);
fsr = [];
if ~isempty(k)
    fsr = interp1(wide.X_ohm(k:k+1), wide.f_Hz(k:k+1), 0);
end

%% Figure 1: homework plots
figure('Name', 'X and Q', 'Color', 'w', 'Position', [100 100 760 650]);
subplot(2, 1, 1);
semilogx(fG, hw.X_ohm, 'b-', 'LineWidth', 1.6); hold on;
semilogx(fG, 2*pi*hw.f_Hz*L, 'r:', 'LineWidth', 1.2);
yline(0, 'k:');
if ~isempty(fsr) && fsr <= 6e9, xline(fsr/1e9, 'k--', sprintf('X = 0 at %.2f GHz', fsr/1e9)); end
xlim([0.5 6]); grid on;
ylabel('X = Im\{Z_{in}\} (\Omega)');
legend({'X (model)', '\omegaL (ideal 9 nH)'}, 'Location', 'northwest');
title('Planar inductor, port 2 grounded');
subplot(2, 1, 2);
semilogx(fG, hw.Q, 'm-', 'LineWidth', 1.6); hold on;
[qmax, iq] = max(hw.Q .* (hw.X_ohm > 0));      % peak Q on the inductive side
plot(fG(iq), qmax, 'ko', 'MarkerFaceColor', 'y');
text(fG(iq), qmax, sprintf('  peak Q = %.2f at %.2f GHz', qmax, fG(iq)), 'VerticalAlignment', 'bottom');
if ~isempty(fsr) && fsr <= 6e9, xline(fsr/1e9, 'k--'); end
xlim([0.5 6]); grid on;
xlabel('f (GHz)'); ylabel('Q = |X| / R');

%% Figure 2: wide view
f = wide.f_Hz;  Z = wide.R_ohm + 1j*wide.X_ohm;
figure('Name', 'Wide view', 'Color', 'w', 'Position', [150 150 760 700]);
subplot(3, 1, 1);
loglog(f, abs(Z), 'k-', 'LineWidth', 1.8); hold on;
loglog(f, 2*pi*f*L, 'r:', 'LineWidth', 1.2);
if ~isempty(fsr), xline(fsr, 'k--'); end
grid on; ylabel('|Z| (\Omega)');
legend({'|Z|', '\omegaL ideal'}, 'Location', 'northwest');
title('Planar inductor, 10 MHz - 30 GHz');
subplot(3, 1, 2);
loglog(f, wide.R_ohm, 'g-', 'LineWidth', 1.5); hold on;
if ~isempty(fsr), xline(fsr, 'k--'); end
grid on; ylabel('R = Re\{Z_{in}\} (\Omega)');
subplot(3, 1, 3);
semilogx(f, wide.phase_deg, 'k-', 'LineWidth', 1.5); hold on;
yline(0, 'k:');
if ~isempty(fsr), xline(fsr, 'k--'); end
ylim([-95 95]); yticks(-90:45:90); grid on;
xlabel('f (Hz)'); ylabel('phase (deg)');

%% Figure 3: Smith chart
figure('Name', 'Smith chart', 'Color', 'w');
hold on; axis equal off;
smithGrid();
G = (Z - 50) ./ (Z + 50);
h1 = plot(real(G), imag(G), 'b-', 'LineWidth', 1.5);
Gh = ((hw.R_ohm + 1j*hw.X_ohm) - 50) ./ ((hw.R_ohm + 1j*hw.X_ohm) + 50);
h2 = plot(real(Gh), imag(Gh), 'r.', 'MarkerSize', 8);
h3 = plot(real(G(1)), imag(G(1)), 'ko', 'MarkerFaceColor', 'g');
h4 = plot(real(G(end)), imag(G(end)), 'ko', 'MarkerFaceColor', 'm');
legend([h1 h2 h3 h4], {'10 MHz - 30 GHz', '0.5 - 6 GHz', '10 MHz', '30 GHz'}, ...
       'Location', 'southoutside');
title('Z_{in}, Z_0 = 50 \Omega');

%% ---------- Smith chart grid ----------
function smithGrid()
    t = linspace(0, 2*pi, 400);
    plot(cos(t), sin(t), 'k-', 'LineWidth', 1);
    plot([-1 1], [0 0], 'Color', [.6 .6 .6]);
    for r = [0.2 0.5 1 2 5]
        c = r/(1+r);  a = 1/(1+r);
        plot(c + a*cos(t), a*sin(t), 'Color', [.75 .75 .75]);
        text(c - a + 0.01, 0.03, num2str(r), 'FontSize', 7, 'Color', [.4 .4 .4]);
    end
    for x = [0.2 0.5 1 2 5]
        for s = [1 -1]
            px = 1 + cos(t)/x;  py = s/x + sin(t)/x;
            in = px.^2 + py.^2 <= 1.0001;
            px(~in) = NaN;  py(~in) = NaN;
            plot(px, py, 'Color', [.75 .75 .75]);
        end
    end
    text(-1.12, 0, 'short', 'FontSize', 8, 'HorizontalAlignment', 'right');
    text( 1.04, 0, 'open',  'FontSize', 8);
    text(0, 1.08, '+jX (inductive)', 'FontSize', 8, 'HorizontalAlignment', 'center');
    text(0, -1.08, '-jX (capacitive)', 'FontSize', 8, 'HorizontalAlignment', 'center');
end
