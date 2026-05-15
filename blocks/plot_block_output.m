function plot_block_output(blockNum, plotData)
% PLOT_BLOCK_OUTPUT  Standardized plotting routine for all blocks.

    figure('Name', plotData.title, 'Color', 'w');

    switch blockNum
        case 1  % PRBS
            stem(plotData.x, plotData.y, 'filled', 'MarkerSize', 3, 'Color', [0.2 0.4 0.8]);
            grid on; xlabel(plotData.xLabel); ylabel(plotData.yLabel);
            title(plotData.title); ylim([-0.3, 1.3]);
            yticks([0 1]); yticklabels({'0','1'});

        case 2  % NRZ
            stem(plotData.x, plotData.y, 'filled', 'MarkerSize', 3, 'Color', [0.8 0.2 0.2]);
            grid on; xlabel(plotData.xLabel); ylabel(plotData.yLabel);
            title(plotData.title); ylim([-1.5, 1.5]);
            yticks([-1 0 1]); yticklabels({'-1','0','+1'});
            yline(0, '--k', 'LineWidth', 0.8);

        case 3  % TX FFE
            subplot(2,1,1);
            stem(plotData.xBefore, plotData.yBefore, 'filled', 'MarkerSize', 3, 'Color', [0.8 0.2 0.2]);
            grid on; ylabel('x[n]'); title('Input to FFE - NRZ symbols');
            ylim([-1.5 1.5]); yticks([-1 0 1]); yline(0,'--k');

            subplot(2,1,2);
            stem(plotData.xAfter, plotData.yAfter, 'filled', 'MarkerSize', 3, 'Color', [0.6 0.1 0.8]);
            grid on; ylabel('y[n]'); xlabel(plotData.xLabel);
            title(sprintf('FFE Output - c0=%.2f, c1=%.2f', plotData.c0, plotData.c1));
            ylim([-1.5 1.5]); yline(0,'--k');
            
            figure('Name', 'Block 3b — All FFE Presets Comparison', 'Color', 'w');
            colors = {[0.2 0.7 0.2], [0.2 0.4 0.9], [0.9 0.5 0.1], [0.7 0.1 0.1]};
            hold on;
            for p = 1:size(plotData.presets,1)
                stem(plotData.xAfter, plotData.presetSymbols{p}(1:length(plotData.xAfter)), 'filled', 'MarkerSize', 3, 'Color', colors{p});
            end
            grid on; xlabel(plotData.xLabel); ylabel('y[n]');
            title('All FFE Presets Comparison (Symbol Rate)');
            legend({'Preset 0', 'Preset 1', 'Preset 2', 'Preset 3'});
            ylim([-1.5 1.5]);

        case 4  % TX Driver
            subplot(2,1,1);
            plot(plotData.t, plotData.yIdeal, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2); hold on;
            plot(plotData.t, plotData.yOut, 'Color', [0.1 0.5 0.8], 'LineWidth', 1.4);
            grid on; ylabel('Voltage (V)');
            title(sprintf('Driver Output: Ideal (gray) vs Shaped (blue), tr_{target}=%.2f ps', plotData.tr_target));
            ylim([-0.4 0.4]); yline(0,'--k');

            subplot(2,1,2);
            if plotData.hasZoom
                plot(plotData.zoomT, plotData.zoomIdeal, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2); hold on;
                plot(plotData.zoomT, plotData.zoomShaped, 'Color', [0.1 0.5 0.8], 'LineWidth', 1.6);
                grid on; xlabel('Time (ps)'); ylabel('Voltage (V)');
                title('Zoom: isolated rising edge');
                ylim([-0.4 0.4]); yline(0,'--k');
                yline(0.2*plotData.vSwing/2,':','Color',[0.5 0.5 0.5],'Label','20%');
                yline(0.8*plotData.vSwing/2,':','Color',[0.5 0.5 0.5],'Label','80%');
            else
                title('No isolated transition found in window');
            end

            figure('Name', 'Block 4b — All FFE Presets Waveforms', 'Color', 'w');
            colors = {[0.2 0.7 0.2], [0.2 0.4 0.9], [0.9 0.5 0.1], [0.7 0.1 0.1]};
            hold on;
            for p = 1:size(plotData.presets,1)
                plot(plotData.presetT, plotData.presetWaveforms{p}, 'Color', colors{p}, 'LineWidth', 1.3, ...
                     'DisplayName', sprintf('Preset %d: [%.2f, %.2f]', p-1, plotData.presets(p,1), plotData.presets(p,2)));
            end
            grid on; xlabel('Time (ps)'); ylabel('Voltage (V)');
            title('All FFE Presets Compared (After Driver Shaping)');
            legend('Location', 'best');
            ylim([-0.4 0.4]); yline(0,'--k');

        case 5  % Channel
            subplot(2,1,1);
            plot(plotData.t, plotData.txOut, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2); hold on;
            plot(plotData.t, plotData.chOut, 'Color', [0.8 0.4 0.1], 'LineWidth', 1.4);
            grid on; xlabel('Time (ps)'); ylabel('Voltage (V)');
            title('Channel Input (gray) vs Output (orange)');
            ylim([-0.4 0.4]); yline(0,'--k');

            subplot(2,1,2);
            plot(plotData.f_GHz, plotData.H_mag, 'LineWidth', 1.4, 'Color', [0.8 0.4 0.1]);
            grid on; xlabel('Frequency (GHz)'); ylabel('Magnitude (dB)');
            title(sprintf('Channel Frequency Response (Pole: %.2f GHz)', plotData.fp/1e9));

        case 6  % RX Load
            plot(plotData.t, plotData.rxIn, 'Color', [0.2 0.6 0.4], 'LineWidth', 1.4);
            grid on; xlabel('Time (ps)'); ylabel('Voltage (V)');
            title('Waveform at Receiver Input (RX Pad)');
            ylim([-0.4 0.4]); yline(0,'--k');

        case 7  % Noise
            plot(plotData.t, plotData.rxIn, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2); hold on;
            plot(plotData.t, plotData.rxNoisy, 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
            plot(plotData.t, plotData.rxIn, 'Color', [0.2 0.6 0.4], 'LineWidth', 1.0); % redraw clean on top slightly
            grid on; xlabel('Time (ps)'); ylabel('Voltage (V)');
            title('Noisy Waveform (gray) vs Clean (green)');
            ylim([-0.4 0.4]); yline(0,'--k');

        case 8  % Sample & Hold
            plot(plotData.t, plotData.rxNoisy, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0); hold on;
            stem(plotData.sampT, plotData.sampY, 'filled', 'MarkerSize', 5, 'Color', [0.8 0.1 0.1]);
            grid on; xlabel('Time (ps)'); ylabel('Voltage (V)');
            title('Sampled Points Overlaid on Noisy Waveform');
            ylim([-0.4 0.4]); yline(0,'--k');

        case 9  % Slicer
            scatter(plotData.idx, plotData.y, 20, plotData.bHat, 'filled');
            colormap(gca, [0.8 0.2 0.2; 0.2 0.4 0.8]); % Red for 0, Blue for 1
            grid on; xlabel('Sample Index'); ylabel('Sample Voltage (V)');
            title('Slicer Decisions');
            yline(plotData.vThresh, '--k', 'LineWidth', 1.5, 'Label', 'Threshold');
            ylim([-0.4 0.4]);

        case 10 % BER
            stem(plotData.idx, plotData.b, 'Color', [0.7 0.7 0.7], 'Marker', 'none'); hold on;
            errIdx = plotData.idx(plotData.err == 1);
            if ~isempty(errIdx)
                stem(errIdx, plotData.bHat(errIdx), 'filled', 'MarkerSize', 5, 'Color', 'r');
                title(sprintf('Errors found (Red points). BER: %e', plotData.ber));
            else
                title(sprintf('No errors found. BER: %e', plotData.ber));
            end
            grid on; xlabel('Bit Index'); ylabel('Decided Bit Value');
            yticks([0 1]); ylim([-0.3 1.3]);

        case 11 % Histogram & Q
            histogram(plotData.samples0, 50, 'Normalization', 'pdf', 'FaceColor', [0.8 0.2 0.2], 'FaceAlpha', 0.6); hold on;
            histogram(plotData.samples1, 50, 'Normalization', 'pdf', 'FaceColor', [0.2 0.4 0.8], 'FaceAlpha', 0.6);
            grid on; xlabel('Sample Voltage (V)'); ylabel('PDF');
            title(sprintf('Voltage Distributions (Q: %.2f, BER: %e)', plotData.qFactor, plotData.berQ));
            xline(plotData.mu0, '--r'); xline(plotData.mu1, '--b');
            legend({'Bit 0', 'Bit 1'});

        case 12 % Eye Diagram
            hold on;
            for k = 1:size(plotData.eyeMat, 1)
                plot(plotData.tEye, plotData.eyeMat(k,:), 'b', 'Color', [0 0 1 0.1]);
            end
            grid on; xlabel('Time (UI)'); ylabel('Voltage (V)');
            title(plotData.title);
            xlim([0 plotData.nUI]); ylim([-0.4 0.4]); yline(0,'--k');
    end
end
