function [ySym, plotData] = block_tx_ffe(x, cfg)
% BLOCK_TX_FFE  2-tap Feed-Forward Equalizer at symbol rate.
%
%   [ySym, plotData] = block_tx_ffe(x, cfg)
%
%   Implements:  y[n] = c0·x[n] + c1·x[n−1]
%     c0 = main (cursor) tap
%     c1 = post-cursor tap  (negative → de-emphasis)
%
%   UCIe 2.0 presets:
%     Preset 0 : [1.00,  0.00]   no de-emphasis
%     Preset 1 : [0.90, −0.10]   mild
%     Preset 2 : [0.85, −0.15]   moderate
%     Preset 3 : [0.75, −0.25]   strong
%
%   Inputs
%     x          – 1×N NRZ symbols {−1,+1}
%     cfg.ffeC0  – main tap weight
%     cfg.ffeC1  – post-cursor tap weight
%
%   Outputs
%     ySym     – 1×N equalized symbol stream
%     plotData – struct for per-block plotting

    % ---- standalone execution check --------------------------------------
    if nargin == 0
        cfg.nBits = 10000;
        cfg.ffeC0 = 0.75;
        cfg.ffeC1 = -0.25;
        b = block_prbs(cfg);
        x = block_nrz_mapper(b, cfg);
        [ySym, plotData] = block_tx_ffe(x, cfg);
        plot_block_output(3, plotData);
        return;
    end

    c0 = cfg.ffeC0;
    c1 = cfg.ffeC1;

    % ---- 2-tap FIR -------------------------------------------------------
    ySym = filter([c0, c1], 1, x);

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 3 — TX FFE (symbol rate)\n');
    fprintf('  c0 (main)     : %.2f\n', c0);
    fprintf('  c1 (post)     : %.2f\n', c1);
    fprintf('  Sum |c|       : %.2f\n\n', abs(c0)+abs(c1));

    % ---- plot data -------------------------------------------------------
    nShow = min(80, length(x));
    plotData.title     = sprintf('Block 3 — TX FFE  [c0=%.2f, c1=%.2f]', c0, c1);
    plotData.xLabel    = 'Symbol index  n';
    plotData.xBefore   = 1:nShow;
    plotData.yBefore   = x(1:nShow);
    plotData.xAfter    = 1:nShow;
    plotData.yAfter    = ySym(1:nShow);
    plotData.c0        = c0;
    plotData.c1        = c1;

    % ---- all-presets comparison data ------------------------------------
    presets = [1.00,  0.00;
               0.90, -0.10;
               0.85, -0.15;
               0.75, -0.25];
    plotData.presets       = presets;
    plotData.presetSymbols = cell(1, size(presets,1));
    for p = 1:size(presets,1)
        plotData.presetSymbols{p} = filter([presets(p,1), presets(p,2)], 1, x);
    end
end
