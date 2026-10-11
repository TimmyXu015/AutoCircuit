%% capc_plot.m -- plots for the "real" capacitor (C = 0.4 uF, Rs = 0.1 ohm, Ls = 0.1 nH)
% Data comes from ~/AutoCircuit_results on ieng6 (run.sh capc). Copy it next to this
% script first, from PowerShell:
%   scp lix015@ieng6-ece-20.ucsd.edu:~/AutoCircuit_results/capc_*.csv .
%
% Figure 1  Smith chart (Z0 = 50 ohm and Z0 = 1 ohm) -- a sub-ohm part sits on the
%           short-circuit point of a 50 ohm chart, so the 1 ohm chart shows its path
% Figure 2  |X| and Q = |X|/R vs frequency, 1-300 MHz (the homework sweep)
% Figure 3  |Z|, R, |X| and phase, 100 kHz - 3 GHz, with the ideal C and L asymptotes
% No toolboxes needed (the Smith grid is drawn by hand).

clear; close all;
C = 0.4e-6;  Ls = 0.1e-9;  Rs = 0.1;

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
lin  = readtable(fullfile(here, 'capc_lin.csv'));   % homework sweep
wide = readtable(fullfile(here, 'capc_log.csv'));   % 100 kHz .. 3 GHz

Zlin  = lin.R_ohm  + 1j*lin.X_ohm;
Zwide = wide.R_ohm + 1j*wide.X_ohm;

% series resonance read off the data: where X crosses zero (linear interpolation)
k   = find(diff(sign(wide.X_ohm)) ~= 0, 1);
fsr = interp1(wide.X_ohm(k:k+1), wide.f_Hz(k:k+1), 0);

%% Figure 1: Smith charts
figure('Name', 'Smith chart', 'Color', 'w', 'Position', [100 100 1100 520]);
Z0s = [50 1];
for n = 1:2
    subplot(1, 2, n); hold on; axis equal off;
    smithGrid();
    G  = (Zwide - Z0s(n)) ./ (Zwide + Z0s(n));
    Gl = (Zlin  - Z0s(n)) ./ (Zlin  + Z0s(n));
    h1 = plot(real(G), imag(G), 'b-', 'LineWidth', 1.5);
    h2 = plot(real(Gl), imag(Gl), 'r.', 'MarkerSize', 10);
    h3 = plot(real(G(1)), imag(G(1)), 'ko', 'MarkerFaceColor', 'g');      % lowest frequency
    h4 = plot(real(G(end)), imag(G(end)), 'ko', 'MarkerFaceColor', 'm');  % highest frequency
    title(sprintf('Z_{in}, Z_0 = %g \\Omega', Z0s(n)));
    if n == 2
        legend([h1 h2 h3 h4], {'100 kHz - 3 GHz', '1 - 300 MHz (5 MHz steps)', ...
               '100 kHz', '3 GHz'}, 'Location', 'southoutside');
    end
end

%% Figure 2: |X| and Q, homework sweep
fM = lin.f_Hz / 1e6;
figure('Name', '|X| and Q', 'Color', 'w');
yyaxis left
plot(fM, abs(lin.X_ohm), 'o-', 'LineWidth', 1.2, 'MarkerSize', 4);
ylabel('|X| (\Omega)');
yyaxis right
plot(fM, lin.Q, 's-', 'LineWidth', 1.2, 'MarkerSize', 4);
ylabel('Q = |X| / R');
xline(fsr/1e6, 'k--', sprintf('X = 0 at %.1f MHz', fsr/1e6), 'LabelVerticalAlignment', 'middle');
xlabel('f (MHz)'); grid on;
title('Real capacitor, 1 - 300 MHz');

%% Figure 3: wide view with ideal asymptotes
f = wide.f_Hz;  w = 2*pi*f;
figure('Name', 'Wide view', 'Color', 'w', 'Position', [150 150 700 650]);
subplot(2, 1, 1);
loglog(f, abs(Zwide), 'k-', 'LineWidth', 1.8); hold on;
loglog(f, wide.R_ohm, 'g-', 'LineWidth', 1.2);
loglog(f, abs(wide.X_ohm), 'b-', 'LineWidth', 1.2);
loglog(f, 1./(w*C), 'b:', f, w*Ls, 'r:', 'LineWidth', 1.2);
xline(fsr, 'k--');
ylim([min(abs(Zwide))/3, max(abs(Zwide))*3]);
legend({'|Z|', 'R', '|X|', '1/(\omegaC) ideal C', '\omegaL_s ideal L'}, 'Location', 'north');
ylabel('\Omega'); grid on; title('Impedance, 100 kHz - 3 GHz');
subplot(2, 1, 2);
semilogx(f, wide.phase_deg, 'k-', 'LineWidth', 1.5); hold on;
yline(0, 'k:'); xline(fsr, 'k--');
ylim([-95 95]); yticks(-90:45:90);
xlabel('f (Hz)'); ylabel('phase (deg)'); grid on;
title('Capacitive (-90^\circ) below the series resonance, inductive (+90^\circ) above');

%% ---------- Smith chart grid ----------
function smithGrid()
    t = linspace(0, 2*pi, 400);
    plot(cos(t), sin(t), 'k-', 'LineWidth', 1);                    % |Gamma| = 1
    plot([-1 1], [0 0], 'Color', [.6 .6 .6]);                       % real axis
    for r = [0.2 0.5 1 2 5]                                         % constant resistance
        c = r/(1+r);  a = 1/(1+r);
        plot(c + a*cos(t), a*sin(t), 'Color', [.75 .75 .75]);
        text(c - a + 0.01, 0.03, num2str(r), 'FontSize', 7, 'Color', [.4 .4 .4]);
    end
    for x = [0.2 0.5 1 2 5]                                         % constant reactance
        for s = [1 -1]
            cx = 1;  cy = s/x;  a = 1/x;
            px = cx + a*cos(t);  py = cy + a*sin(t);
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
