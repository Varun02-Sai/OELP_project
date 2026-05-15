function [rxIn, plotData] = block_rx_load(chOut, cfg)
% BLOCK_RX_LOAD  RX termination load model.
%
%   [rxIn, plotData] = block_rx_load(chOut, cfg)
%
%   Models the RX pad load as an RC low-pass filter to ground.
%   The architecture diagram specifies R = 50 Ω, C = 0.2 pF.
%
%   Inputs
%     chOut        – 1×N analog waveform from channel
%     cfg.R_rx     – RX input resistance (Ω)  [50]
%     cfg.C_rx     – RX input capacitance (F) [0.2 pF]
%     cfg.fs       – sampling frequency (Hz)
%
%   Outputs
%     rxIn     – 1×N analog waveform at the receiver input
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
        cfg.ffeC0 = 0.75;
        cfg.ffeC1 = -0.25;
        b = block_prbs(cfg);
        x = block_nrz_mapper(b, cfg);
        ySym = block_tx_ffe(x, cfg);
        txOut = block_tx_driver(ySym, b, cfg);
        chOut = block_channel(txOut, cfg);
        [rxIn, plotData] = block_rx_load(chOut, cfg);
        plot_block_output(6, plotData);
        return;
    end

    fs = cfg.fs;

    % ---- RX Load RC filter -----------------------------------------------
    tau_rx   = cfg.R_rx * cfg.C_rx;
    alpha_rx = exp(-1 / (fs * tau_rx));
    rxIn     = filter(1 - alpha_rx, [1, -alpha_rx], chOut);

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 6 — RX Load\n');
    fprintf('  R_rx          : %.0f Ω\n', cfg.R_rx);
    fprintf('  C_rx          : %.3f pF\n', cfg.C_rx*1e12);
    fprintf('  τ_rx          : %.3f ps\n\n', tau_rx*1e12);

    % ---- plot data -------------------------------------------------------
    plotData.title = 'Block 6 — Waveform at RX Load';
    nShowSmp = min(50 * cfg.samplesPerUI, length(rxIn));
    plotData.t     = (0:nShowSmp-1) / fs * 1e12; % ps
    plotData.rxIn  = rxIn(1:nShowSmp);
end
