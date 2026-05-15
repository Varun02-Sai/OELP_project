function [b, plotData] = block_prbs(cfg)
% BLOCK_PRBS  Generate a Pseudo-Random Binary Sequence using an LFSR.
%
%   [b, plotData] = block_prbs(cfg)
%
%   The PRBS degree and tap positions are set via cfg.prbsDegree and
%   cfg.prbsTaps.  Default is PRBS-13 (degree=13, taps=[13,4,3,1])
%   matching the architecture diagram.
%
%   Inputs
%     cfg.nBits      – number of output bits
%     cfg.prbsDegree – LFSR register length  (default 13)
%     cfg.prbsTaps   – XOR feedback taps     (default [13 4 3 1])
%     cfg.prbsSeed   – initial register      (default all-ones)
%
%   Outputs
%     b        – 1×nBits binary sequence {0,1}
%     plotData – struct with fields for plotting

    % ---- standalone execution check --------------------------------------
    if nargin == 0
        cfg.nBits        = 10000;
        cfg.prbsDegree   = 13;
        cfg.prbsTaps     = [13 4 3 1];
        cfg.prbsSeed     = ones(1, 13);
        [b, plotData]    = block_prbs(cfg);
        plot_block_output(1, plotData);
        return;
    end

    % ---- defaults --------------------------------------------------------
    if ~isfield(cfg, 'prbsDegree'), cfg.prbsDegree = 13;                  end
    if ~isfield(cfg, 'prbsTaps'),   cfg.prbsTaps   = [13 4 3 1];         end
    if ~isfield(cfg, 'prbsSeed'),   cfg.prbsSeed   = ones(1, cfg.prbsDegree); end

    degree = cfg.prbsDegree;
    taps   = cfg.prbsTaps;
    reg    = cfg.prbsSeed;

    % ---- LFSR generation -------------------------------------------------
    b = zeros(1, cfg.nBits);
    for i = 1:cfg.nBits
        b(i) = reg(end);                       % output = last register bit
        fb   = mod(sum(reg(taps)), 2);          % XOR of tapped positions
        reg  = [fb, reg(1:end-1)];              % shift right
    end

    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 1 — PRBS-%d Generator\n', degree);
    fprintf('  Taps         : %s\n', mat2str(taps));
    fprintf('  Ones / Zeros : %d / %d  (total %d bits)\n\n', ...
            sum(b), sum(~b), cfg.nBits);

    % ---- plot data -------------------------------------------------------
    nShow = min(100, cfg.nBits);
    plotData.title  = sprintf('Block 1 — PRBS-%d Output (first %d bits)', degree, nShow);
    plotData.xLabel = 'Bit index  n';
    plotData.yLabel = 'b[n]';
    plotData.x      = 1:nShow;
    plotData.y      = b(1:nShow);
end
