% ece203_ss_plot.m -- ECE203 Round 3 single-stage BioAmp plots.
% Set raw (folder with ece203_ss/*.csv) and out (figure folder) before running, or use defaults.
if ~exist('raw','var'), raw = 'C:\Users\Timmy\AutoCircuit_Results\_raw\ece203_round3_single_stage\ece203_ss'; end
if ~exist('out','var'), out = 'C:\Users\Timmy\AutoCircuit_Results\ece203_round3_single_stage'; end
if ~exist(out,'dir'), mkdir(out); end
tags = {'A_ideal_S1','B_real_S1','A_ideal_S2','B_real_S2'};
names = {'ideal S1 (10)','5T S1','ideal S2 (100)','5T S2'};
cols = [0.35 0.55 0.85; 0.05 0.25 0.65; 0.95 0.6 0.35; 0.8 0.3 0.05];
sty = {'--','-','--','-'};
rd = @(f) readtable(fullfile(raw,f),'TreatAsMissing','n/a');

% 1) differential gain
f1 = figure('Position',[100 100 900 600]);
subplot(2,1,1); hold on
for k = 1:4
  t = rd([tags{k} '_ac.csv']);
  semilogx(t.f_Hz, 20*log10(t.abs_Hdm), sty{k}, 'Color', cols(k,:), 'LineWidth', 1.5, 'DisplayName', names{k});
  if k == 2 || k == 4
    semilogx(t.f_Hz, 20*log10(t.abs_Hdm_cl5), ':', 'Color', cols(k,:), 'LineWidth', 1.2, 'DisplayName', [names{k} ' CL=5p']);
  end
end
set(gca,'XScale','log'); grid on; xlim([1e-3 1e5]); ylabel('|V_o/V_{id}| (dB)');
xline([0.1 10 60 100 250],':k','HandleVisibility','off');
legend('Location','southwest'); title('Round 3: classroom single-OTA cap-feedback amp, differential gain');
subplot(2,1,2); hold on
for k = 1:4
  t = rd([tags{k} '_ac.csv']);
  semilogx(t.f_Hz, t.ph_Hdm, sty{k}, 'Color', cols(k,:), 'LineWidth', 1.5);
end
set(gca,'XScale','log'); grid on; xlim([1e-3 1e5]); ylabel('phase (deg)'); xlabel('f (Hz)');
exportgraphics(f1, fullfile(out,'ss_ac_gain.png'), 'Resolution', 150);

% 2) loop gain (stb)
f2 = figure('Position',[100 100 900 600]);
subplot(2,1,1); hold on
for k = 1:4
  t = rd([tags{k} '_stb.csv']);
  semilogx(t.f_Hz, 20*log10(t.abs_LG), sty{k}, 'Color', cols(k,:), 'LineWidth', 1.5, 'DisplayName', names{k});
end
set(gca,'XScale','log'); grid on; yline(0,'k','HandleVisibility','off'); ylabel('|loop gain| (dB)');
legend('Location','southwest'); title('stb loop gain at IPRB (OTA output)');
subplot(2,1,2); hold on
for k = 1:4
  t = rd([tags{k} '_stb.csv']);
  semilogx(t.f_Hz, t.ph_LG, sty{k}, 'Color', cols(k,:), 'LineWidth', 1.5);
end
set(gca,'XScale','log'); grid on; ylabel('phase (deg)'); xlabel('f (Hz)');
exportgraphics(f2, fullfile(out,'ss_stb.png'), 'Resolution', 150);

% 3) noise
f3 = figure('Position',[100 100 900 600]);
subplot(2,1,1); hold on
for k = 1:4
  t = rd([tags{k} '_noise.csv']);
  loglog(t.f_Hz, t.out_V_rtHz, sty{k}, 'Color', cols(k,:), 'LineWidth', 1.5, 'DisplayName', names{k});
end
set(gca,'XScale','log','YScale','log'); grid on; xlim([1e-2 1e3]); ylabel('output noise (V/\surdHz)');
xline([0.1 250],':k','HandleVisibility','off'); legend('Location','southwest');
title('noise: output PSD and differential-input-referred PSD (out/|H_{dm}|)');
subplot(2,1,2); hold on
for k = 1:4
  t = rd([tags{k} '_noise.csv']);
  loglog(t.f_Hz, t.out_over_absHdm_V_rtHz, sty{k}, 'Color', cols(k,:), 'LineWidth', 1.5);
end
set(gca,'XScale','log','YScale','log'); grid on; xlim([1e-2 1e3]); xline([0.1 250],':k');
ylabel('diff input-referred (V/\surdHz)'); xlabel('f (Hz)');
exportgraphics(f3, fullfile(out,'ss_noise.png'), 'Resolution', 150);

% 4) transient
f4 = figure('Position',[100 100 900 600]);
for j = 1:2
  subplot(2,1,j); hold on
  for k = 1:4
    t = rd(sprintf('%s_tran%d.csv', tags{k}, j));
    plot(t.t_s, t.o_V, sty{k}, 'Color', cols(k,:), 'LineWidth', 1.2, 'DisplayName', names{k});
  end
  grid on; ylabel('V_o (V)'); xlim([0 0.5]);
  title(sprintf('10 Hz transient, differential %d mV_{pk}', 1 + 4*(j-1)));
  if j == 1, legend('Location','northeast'); end
end
xlabel('t (s)');
exportgraphics(f4, fullfile(out,'ss_tran.png'), 'Resolution', 150);
close all
disp('ss plots done')
