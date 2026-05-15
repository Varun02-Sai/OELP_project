function [bHat, plotData] = block_slicer(rxSamples, cfg)
% BLOCK_SLICER  Threshold comparator for NRZ symbols.
%
%   [bHat, plotData] = block_slicer(rxSamples, cfg)
%
%   Inputs
%     rxSamples    – 1×nBits array of sampled voltages
%     cfg.vThresh  – Threshold voltage (default 0 V)
%
%   Outputs
%     bHat         – 1×nBits array of decided bits {0,1}
%     plotData     – struct for per-block plotting

    % ---- standalone execution check --------------------------------------
    if nargin == 0
        cfg.nBits = 10000;
        cfg.dataRate = 32e9;
        cfg.samplesPerUI = 16;
        cfg.fs = cfg.dataRate * cfg.samplesPerUI;
        cfg.vSwing = 0.625;
        cfg.tr_target = 0.20 / cfg.dataRate;
        cfg.R_driver = 30;
        cfg.C_driver = 0.1e-12;
        cfg.R_ch = 30;
        cfg.C_ch = 0.1e-12;
        cfg.R_rx = 50;
        cfg.C_rx = 0.2e-12;
        cfg.noiseSigma = 5e-3;
        cfg.enableJitter = true;
        cfg.rjSigma = 0.25e-12;
        cfg.vThresh = 0;
        cfg.ffeC0 = 0.75;
        cfg.ffeC1 = -0.25;
        b = block_prbs(cfg);
        x = block_nrz_mapper(b, cfg);
        ySym = block_tx_ffe(x, cfg);
        txOut = block_tx_driver(ySym, b, cfg);
        chOut = block_channel(txOut, cfg);
        rxIn = block_rx_load(chOut, cfg);
        rxNoisy = block_add_noise(rxIn, cfg);
        rxSamples = block_sample_hold(rxNoisy, cfg);
        [bHat, plotData] = block_slicer(rxSamples, cfg);
        plot_block_output(9, plotData);
        return;
    end

    if ~isfield(cfg, 'vThresh'), cfg.vThresh = 0; end
    
    vThresh = cfg.vThresh;
    bHat = rxSamples > vThresh;

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 9 — Slicer\n');
    fprintf('  Threshold     : %.3f V\n', vThresh);
    fprintf('  Decided 1s/0s : %d / %d\n\n', sum(bHat), sum(~bHat));

    % ---- plot data -------------------------------------------------------
    plotData.title   = 'Block 9 — Slicer Decisions';
    nShow            = min(100, length(rxSamples));
    plotData.idx     = 1:nShow;
    plotData.y       = rxSamples(1:nShow);
    plotData.bHat    = bHat(1:nShow);
    plotData.vThresh = vThresh;
end
