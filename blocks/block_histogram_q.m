function [berQ, qFactor, plotData] = block_histogram_q(rxSamples, b, cfg)
% BLOCK_HISTOGRAM_Q  Voltage histogram and Q-based BER estimation.
%
%   [berQ, qFactor, plotData] = block_histogram_q(rxSamples, b, cfg)
%
%   Splits the received samples by the original transmitted bit,
%   computes the mean and standard deviation for '0' and '1',
%   estimates the eye height, Q-factor, and analytical BER.
%
%   Inputs
%     rxSamples – 1×N array of sampled voltages
%     b         – 1×N array of original bits
%     cfg       – configuration struct
%
%   Outputs
%     berQ      – estimated BER from Q-factor
%     qFactor   – computed Q-factor
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
        rxSamples = block_sample_hold(rxNoisy, cfg);
        [berQ, qFactor, plotData] = block_histogram_q(rxSamples, b, cfg);
        plot_block_output(11, plotData);
        return;
    end

    % Split samples by bit value
    samples0 = rxSamples(b == 0);
    samples1 = rxSamples(b == 1);
    
    % Statistics
    mu0  = mean(samples0);
    sig0 = std(samples0);
    
    mu1  = mean(samples1);
    sig1 = std(samples1);
    
    % Metrics
    eyeHeight = mu1 - mu0;
    if (sig1 + sig0) == 0
        qFactor = inf;
        berQ    = 0;
    else
        qFactor = eyeHeight / (sig1 + sig0);
        berQ    = 0.5 * erfc(qFactor / sqrt(2));
    end

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 11 — Histogram & Q-factor\n');
    fprintf('  Bit 0         : μ = %.3f V, σ = %.3f mV\n', mu0, sig0*1e3);
    fprintf('  Bit 1         : μ = %.3f V, σ = %.3f mV\n', mu1, sig1*1e3);
    fprintf('  Eye Height    : %.3f V\n', eyeHeight);
    fprintf('  Q-factor      : %.2f\n', qFactor);
    fprintf('  BER (Q-est)   : %e\n\n', berQ);

    % ---- plot data -------------------------------------------------------
    plotData.title    = 'Block 11 — Voltage Histograms';
    plotData.samples0 = samples0;
    plotData.samples1 = samples1;
    plotData.mu0      = mu0;
    plotData.sig0     = sig0;
    plotData.mu1      = mu1;
    plotData.sig1     = sig1;
    plotData.qFactor  = qFactor;
    plotData.berQ     = berQ;
end
