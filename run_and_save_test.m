function run_and_save_test(cfg, outDir)
% RUN_AND_SAVE_TEST Helper to run a test case and save plots
    
    clc; close all;
    
    % Ensure outDir exists
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % Add blocks directory to path
    addpath(fullfile(pwd, 'blocks'));

    fprintf('\n=======================================================\n');
    fprintf('  RUNNING: %s\n', cfg.name);
    fprintf('  Output Dir: %s\n', outDir);
    fprintf('=======================================================\n\n');
        
    % --- SECTION 1: TRANSMITTER ---
    [b, p1]         = block_prbs(cfg);
    [x, p2]         = block_nrz_mapper(b, cfg);
    [ySym, p3]      = block_tx_ffe(x, cfg);
    [txOut, p4]     = block_tx_driver(ySym, b, cfg);

    % --- SECTION 2: CHANNEL & RX LOAD ---
    [chOut, p5]     = block_channel(txOut, cfg);
    [rxIn, p6]      = block_rx_load(chOut, cfg);

    % --- SECTION 3: RECEIVER SAMPLER ---
    [rxNoisy, p7]   = block_add_noise(rxIn, cfg);
    [rxSamples, sampleIdx, p8] = block_sample_hold(rxNoisy, cfg);
    [bHat, p9]      = block_slicer(rxSamples, cfg);

    % --- SECTION 4: MEASUREMENT ---
    [ber, p10]             = block_ber_meas(b, bHat, cfg);
    [berQ, qFactor, p11]   = block_histogram_q(rxSamples, b, cfg);
    p12                    = block_eye_diagram(rxNoisy, cfg);

    % --- PLOTTING ---
    plot_block_output(1, p1);
    plot_block_output(2, p2);
    plot_block_output(3, p3);
    plot_block_output(4, p4);
    plot_block_output(5, p5);
    plot_block_output(6, p6);
    plot_block_output(7, p7);
    plot_block_output(8, p8);
    plot_block_output(9, p9);
    plot_block_output(10, p10);
    plot_block_output(11, p11);
    plot_block_output(12, p12);
    
    % --- SAVING PLOTS ---
    fprintf('\nSaving plots to %s...\n', outDir);
    figList = findobj('Type', 'figure');
    for i = 1:length(figList)
        fig = figList(i);
        figName = get(fig, 'Name');
        % Clean filename to be safe for OS
        safeName = regexprep(figName, '[^a-zA-Z0-9_\-]', '_');
        savePath = fullfile(outDir, sprintf('%02d_%s.png', 13-i, safeName)); % prepend roughly chronological number
        saveas(fig, savePath);
        fprintf('  Saved: %s\n', savePath);
    end
    
    % --- SUMMARY ---
    summaryFile = fullfile(outDir, 'summary.txt');
    fid = fopen(summaryFile, 'w');
    fprintf(fid, '=======================================================\n');
    fprintf(fid, '  SUMMARY for %s\n', cfg.name);
    fprintf(fid, '=======================================================\n');
    fprintf(fid, 'Data Rate     : %.2f GT/s\n', cfg.dataRate / 1e9);
    fprintf(fid, 'Channel Specs : R = %.0f Ω, C = %.3f pF\n', cfg.R_ch, cfg.C_ch * 1e12);
    fprintf(fid, 'FFE Preset    : c0=%.2f, c1=%.2f\n', cfg.ffeC0, cfg.ffeC1);
    fprintf(fid, 'Noise σ       : %.2f mV\n', cfg.noiseSigma * 1e3);
    fprintf(fid, 'Jitter σ_RJ   : %.2f ps\n', cfg.rjSigma * 1e12);
    fprintf(fid, 'Measured BER  : %e\n', ber);
    fprintf(fid, 'Est BER (Q)   : %e\n', berQ);
    fprintf(fid, 'Q-factor      : %.2f\n', qFactor);
    fprintf(fid, 'Rise Time     : %.2f ps\n', p4.tr_meas);
    fprintf(fid, 'Fall Time     : %.2f ps\n', p4.tf_meas);
    fprintf(fid, '=======================================================\n');
    fclose(fid);
    
    % Also print to console
    type(summaryFile);
    fprintf('\nRun Complete. All plots and summary saved in %s\n', outDir);
end
