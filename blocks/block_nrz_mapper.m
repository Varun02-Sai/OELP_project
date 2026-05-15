function [x, plotData] = block_nrz_mapper(b, cfg)
% BLOCK_NRZ_MAPPER  Map binary {0,1} to NRZ bipolar {-1,+1}.
%
%   [x, plotData] = block_nrz_mapper(b, cfg)
%
%   Formula:  x[n] = 2·b[n] − 1
%     b=0 → x=−1   (logic low)
%     b=1 → x=+1   (logic high)
%
%   Inputs
%     b   – 1×N binary sequence
%     cfg – configuration struct (used only for plot limits)
%
%   Outputs
%     x        – 1×N NRZ symbols ∈ {−1, +1}
%     plotData – struct for per-block plotting

    % ---- standalone execution check --------------------------------------
    if nargin == 0
        cfg.nBits = 10000;
        b = block_prbs(cfg);
        [x, plotData] = block_nrz_mapper(b, cfg);
        plot_block_output(2, plotData);
        return;
    end

    x = 2*b - 1;

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 2 — NRZ Mapper\n');
    fprintf('  Unique levels : %s\n\n', mat2str(unique(x)));

    % ---- plot data -------------------------------------------------------
    nShow = min(100, length(x));
    plotData.title  = sprintf('Block 2 — NRZ Mapper Output (first %d symbols)', nShow);
    plotData.xLabel = 'Symbol index  n';
    plotData.yLabel = 'x[n]';
    plotData.x      = 1:nShow;
    plotData.y      = x(1:nShow);
end
