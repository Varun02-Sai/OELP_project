function [plotData] = block_eye_diagram(rxNoisy, cfg)
% BLOCK_EYE_DIAGRAM  2-UI eye diagram accumulator.
%
%   [plotData] = block_eye_diagram(rxNoisy, cfg)
%
%   Overlays 2 Unit Intervals (UI) of the received analog waveform.
%
%   Inputs
%     rxNoisy – 1×N analog waveform
%     cfg     – configuration struct
%
%   Outputs
%     plotData – struct containing eye diagram matrix for plotting

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
        [plotData] = block_eye_diagram(rxNoisy, cfg);
        plot_block_output(12, plotData);
        return;
    end

    N = cfg.samplesPerUI;
    
    nUI_eye = 2;
    Leye = nUI_eye * N;
    
    nTraces = floor(length(rxNoisy) / N) - 2;
    nTraces = min(nTraces, 1000); % limit memory/plotting time
    
    eyeMat = zeros(nTraces, Leye);
    
    for k = 1:nTraces
        idx0 = (k-1)*N + 1;
        eyeMat(k, :) = rxNoisy(idx0 : idx0 + Leye - 1);
    end

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 12 — Eye Diagram\n');
    fprintf('  Overlaid UIs  : %d\n', nUI_eye);
    fprintf('  Traces drawn  : %d\n\n', nTraces);

    % ---- plot data -------------------------------------------------------
    plotData.title   = 'Block 12 — Eye Diagram (RX Input)';
    plotData.tEye    = (0:Leye-1) / N; % time in UI
    plotData.eyeMat  = eyeMat;
    plotData.nUI     = nUI_eye;
    plotData.samplesPerUI = N;
end
