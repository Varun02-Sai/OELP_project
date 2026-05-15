function [rxNoisy, plotData] = block_add_noise(rxIn, cfg)
% BLOCK_ADD_NOISE  Add Gaussian voltage noise at receiver.
%
%   [rxNoisy, plotData] = block_add_noise(rxIn, cfg)
%
%   Inputs
%     rxIn           – 1×N clean analog waveform
%     cfg.noiseSigma – noise standard deviation (V)
%
%   Outputs
%     rxNoisy  – 1×N noisy analog waveform
%     plotData – struct for per-block plotting

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
        cfg.ffeC0 = 0.75;
        cfg.ffeC1 = -0.25;
        b = block_prbs(cfg);
        x = block_nrz_mapper(b, cfg);
        ySym = block_tx_ffe(x, cfg);
        txOut = block_tx_driver(ySym, b, cfg);
        chOut = block_channel(txOut, cfg);
        rxIn = block_rx_load(chOut, cfg);
        [rxNoisy, plotData] = block_add_noise(rxIn, cfg);
        plot_block_output(7, plotData);
        return;
    end

    noise = cfg.noiseSigma * randn(size(rxIn));
    rxNoisy = rxIn + noise;

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 7 — Receiver Noise\n');
    fprintf('  σ_V (noise)   : %.3f mV RMS\n\n', cfg.noiseSigma*1e3);

    % ---- plot data -------------------------------------------------------
    plotData.title   = 'Block 7 — Noisy Waveform';
    nShowSmp = min(50 * cfg.samplesPerUI, length(rxIn));
    plotData.t       = (0:nShowSmp-1) / cfg.fs * 1e12; % ps
    plotData.rxIn    = rxIn(1:nShowSmp);
    plotData.rxNoisy = rxNoisy(1:nShowSmp);
end
