function [ber, plotData] = block_ber_meas(b, bHat, cfg)
% BLOCK_BER_MEAS  Direct BER measurement.
%
%   [ber, plotData] = block_ber_meas(b, bHat, cfg)
%
%   Computes the Bit Error Rate by directly comparing transmitted
%   bits (b) with decided bits (bHat).
%
%   Inputs
%     b        – 1×N original transmitted bits
%     bHat     – 1×N decided bits from slicer
%     cfg      – configuration (unused here, for consistency)
%
%   Outputs
%     ber      – measured Bit Error Rate
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
        bHat = block_slicer(rxSamples, cfg);
        [ber, plotData] = block_ber_meas(b, bHat, cfg);
        plot_block_output(10, plotData);
        return;
    end

    errVec = (b ~= bHat);
    ber = mean(errVec);
    nErrs = sum(errVec);

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 10 — Direct BER Measurement\n');
    fprintf('  Total errors  : %d\n', nErrs);
    fprintf('  Measured BER  : %e\n\n', ber);

    % ---- plot data -------------------------------------------------------
    plotData.title = 'Block 10 — BER Error Locations';
    nShow = min(200, length(b));
    plotData.idx   = 1:nShow;
    plotData.b     = b(1:nShow);
    plotData.bHat  = bHat(1:nShow);
    plotData.err   = errVec(1:nShow);
    plotData.ber   = ber;
    plotData.nErrs = nErrs;
end
