function [rxSamples, sampleIdx, plotData] = block_sample_hold(rxNoisy, cfg)
% BLOCK_SAMPLE_HOLD  Sample & hold receiver with optional jitter.
%
%   [rxSamples, sampleIdx, plotData] = block_sample_hold(rxNoisy, cfg)
%
%   Samples the waveform once per UI. Center of the UI is targeted.
%   If jitter is enabled, a random sampling offset is added.
%
%   Inputs
%     rxNoisy         – 1×N noisy analog waveform
%     cfg.samplesPerUI – samples per bit period
%     cfg.nBits       – number of total bits
%     cfg.fs          – sampling rate
%     cfg.enableJitter – true/false
%     cfg.rjSigma     – RMS random jitter (s)  [0.25 ps]
%
%   Outputs
%     rxSamples – 1×nBits sampled voltage values
%     sampleIdx – 1×nBits actual indices sampled in the waveform
%     plotData  – struct for per-block plotting

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
        cfg.ffeC0 = 0.75;
        cfg.ffeC1 = -0.25;
        b = block_prbs(cfg);
        x = block_nrz_mapper(b, cfg);
        ySym = block_tx_ffe(x, cfg);
        txOut = block_tx_driver(ySym, b, cfg);
        chOut = block_channel(txOut, cfg);
        rxIn = block_rx_load(chOut, cfg);
        rxNoisy = block_add_noise(rxIn, cfg);
        [rxSamples, sampleIdx, plotData] = block_sample_hold(rxNoisy, cfg);
        plot_block_output(8, plotData);
        return;
    end

    N = cfg.samplesPerUI;
    
    % Ideal sampling at the center of the UI
    samplePhase = round(N / 2);
    idealIdx = samplePhase : N : length(rxNoisy);
    idealIdx = idealIdx(1:cfg.nBits);
    
    sampleIdx = idealIdx;
    
    if isfield(cfg, 'enableJitter') && cfg.enableJitter
        jitterSec = cfg.rjSigma * randn(size(idealIdx));
        jitterSmp = round(jitterSec * cfg.fs);
        sampleIdx = sampleIdx + jitterSmp;
        % Boundaries
        sampleIdx(sampleIdx < 1) = 1;
        sampleIdx(sampleIdx > length(rxNoisy)) = length(rxNoisy);
    end

    rxSamples = rxNoisy(sampleIdx);

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 8 — Sample & Hold\n');
    if isfield(cfg, 'enableJitter') && cfg.enableJitter
        fprintf('  Jitter        : Enabled (σ_RJ = %.2f ps)\n\n', cfg.rjSigma*1e12);
    else
        fprintf('  Jitter        : Disabled\n\n');
    end

    % ---- plot data -------------------------------------------------------
    plotData.title     = 'Block 8 — Sample & Hold Points';
    nBitsShow          = min(30, cfg.nBits);
    nShowSmp           = nBitsShow * N;
    
    plotData.t         = (0:nShowSmp-1) / cfg.fs * 1e12;
    plotData.rxNoisy   = rxNoisy(1:nShowSmp);
    plotData.sampT     = (sampleIdx(1:nBitsShow) - 1) / cfg.fs * 1e12;
    plotData.sampY     = rxSamples(1:nBitsShow);
end
