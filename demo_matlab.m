% This script reads transmit/receive .dat files, performs matched filtering
% Results match research paper Table II.

clear; clc; close all;

c = 3e8; 
fs = 1e6; % Sample rate from GRC
txfile = 'put your path here where you save the tranmit.dat';  %for example like C:/Users/maila/IMA312_GNU_Demo/transmit.dat
rxfile = 'put your path here where you save the receive.dat';  %for example like C:/Users/maila/IMA312_GNU_Demo/receive.dat

tx_fid = fopen(txfile, 'rb');
if tx_fid == -1
    error(['ERROR: Cannot open file: ' txfile]);
end
tx_data = fread(tx_fid, 'float');
fclose(tx_fid);

rx_fid = fopen(rxfile, 'rb');
if rx_fid == -1
    error(['ERROR: Cannot open file: ' rxfile]);
end
rx_data = fread(rx_fid, 'float');
fclose(rx_fid);

fprintf('TX file: %s (%d samples)\n', txfile, length(tx_data));
fprintf('RX file: %s (%d samples)\n', rxfile, length(rx_data));

figure('Name','Input Signals');
subplot(2,1,1); 
plot(tx_data, '.-', 'LineWidth', 0.5); 
title('Transmit Signal (Baseband Modulated Barker Code)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Sample'); ylabel('Amplitude');
grid on;

subplot(2,1,2); 
plot(rx_data, '.-', 'LineWidth', 0.5); 
title('Received Signal (After Channel + Delay)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Sample'); ylabel('Amplitude');
grid on;

% === MATCHED FILTERING (Cross-Correlation) ===
[mf, lags] = xcorr(rx_data, tx_data);
mf_abs = abs(mf);

% In radar: positive lag = received signal delayed relative to transmit (physical)
% Negative lag = non-physical (would mean target returned before being sent)
pos_idx = find(lags >= 0);
mf_pos = mf_abs(pos_idx);
lags_pos = lags(pos_idx);

% peak in positive lag region
[peakval, peak_rel_idx] = max(mf_pos);
sample_lag = lags_pos(peak_rel_idx);
range_m = (sample_lag / fs) * (c / 2);

fprintf('\n===== MATCHED FILTER RESULTS =====\n');
fprintf('Peak correlation value: %.4f\n', peakval);
fprintf('Sample lag to peak: %d samples\n', sample_lag);
fprintf('Computed target range: %.1f meters (%.3f km)\n', range_m, range_m/1000);

%Full Matched Filter (Showing Symmetry) 
figure('Name','Matched Filter Full');
plot(lags, mf_abs, 'b', 'LineWidth', 1.5);
xlabel('Lag (samples)', 'FontSize', 11);
ylabel('Matched Filter Amplitude', 'FontSize', 11);
title('Matched Filter Output via xcorr (Full View)', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
hold on;
plot(sample_lag, peakval, 'ro', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', sprintf('Peak @ lag %d', sample_lag));
line([0 0], ylim, 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1, 'DisplayName', 'lag=0');
legend('FontSize', 10);
hold off;

%Positive Lag Region (Zoomed Physical View)
figure('Name','Matched Filter Positive Lags');
plot(lags_pos, mf_pos, 'b', 'LineWidth', 1.5);
xlabel('Lag (samples)', 'FontSize', 11);
ylabel('Matched Filter Amplitude', 'FontSize', 11);
title('Matched Filter Output (Positive Lags Only - Physical Region)', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
hold on;
plot(sample_lag, peakval, 'ro', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', sprintf('Target @ %d km', round(range_m/1000)));
xlim([max(0, sample_lag-2000), sample_lag+2000]);
legend('FontSize', 10);
hold off;

% Zoomed Around Peak
figure('Name','Matched Filter Zoomed');
zoom_range = 1000;
xlim_left = max(0, sample_lag - zoom_range);
xlim_right = sample_lag + zoom_range;
zoom_idx = find(lags_pos >= xlim_left & lags_pos <= xlim_right);
plot(lags_pos(zoom_idx), mf_pos(zoom_idx), 'b', 'LineWidth', 2);
hold on;
plot(sample_lag, peakval, 'ro', 'MarkerSize', 12, 'LineWidth', 2.5);
xlabel('Lag (samples)', 'FontSize', 11);
ylabel('Matched Filter Amplitude', 'FontSize', 11);
title(sprintf('Matched Filter - Peak Region (Delay = %d samples, Range = %.1f km)', sample_lag, range_m/1000), ...
    'FontSize', 12, 'FontWeight', 'bold');
grid on; hold off;

%Analysis Info 
fprintf('\n===== QUALITY METRICS =====\n');
fprintf('Signal length (TX): %d\n', length(tx_data));
fprintf('Signal length (RX): %d\n', length(rx_data));
fprintf('Correlation output length: %d\n', length(mf));
fprintf('Peak amplitude (absolute): %.2f\n', peakval);
sidelobe_idx = find(lags_pos ~= sample_lag);
if ~isempty(sidelobe_idx)
    max_sidelobe = max(mf_pos(sidelobe_idx));
    fprintf('Max sidelobe level: %.2f\n', max_sidelobe);
    fprintf('Peak-to-sidelobe ratio: %.2f dB\n', 20*log10(peakval/max_sidelobe));
end

fprintf('\n===== EXPECTED vs. COMPUTED =====\n');
fprintf('Set Delay in GRC (samples): Check your Delay block value\n');
fprintf('Measured peak lag (samples): %d\n', sample_lag);
fprintf('Expected range (for this delay): Set Delay * (c/2) / fs\n');
fprintf('Computed range (meters): %.1f\n\n', range_m);
