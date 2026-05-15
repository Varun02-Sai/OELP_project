function [txOut, plotData] = block_tx_driver(ySym, b, cfg)
% BLOCK_TX_DRIVER  TX analog driver: upsample + rise/fall shaping + output RC.
%
%   [txOut, plotData] = block_tx_driver(ySym, b, cfg)
%
%   This block models the complete TX driver stage:
%     1. Zero-Order Hold (ZOH) upsample to waveform domain
%     2. Scale to ±vSwing/2
%     3. Gaussian rise/fall time shaping (20%–80%)
%     4. TX output RC  (R_driver, C_driver)
%
%   Inputs
%     ySym            – 1×N FFE-equalized symbol-rate sequence
%     b               – 1×N original PRBS bits (for rise/fall measurement)
%     cfg.samplesPerUI – oversampling factor
%     cfg.fs           – waveform sample rate  (Hz)
%     cfg.vSwing       – peak-to-peak TX voltage swing (V)
%     cfg.tr_target    – 20%–80% rise-time target (s)
%     cfg.R_driver     – driver output resistance (Ω)   [30]
%     cfg.C_driver     – driver output capacitance (F)  [0.1 pF]
%
%   Outputs
%     txOut    – 1×(N·samplesPerUI) analog TX output waveform
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
        cfg.ffeC0 = 0.75;
        cfg.ffeC1 = -0.25;
        b = block_prbs(cfg);
        x = block_nrz_mapper(b, cfg);
        ySym = block_tx_ffe(x, cfg);
        [txOut, plotData] = block_tx_driver(ySym, b, cfg);
        plot_block_output(4, plotData);
        return;
    end

    N   = cfg.samplesPerUI;
    fs  = cfg.fs;

    % ---- 1. ZOH upsample -------------------------------------------------
    yUp = repelem(ySym, N);

    % ---- 2. Scale to TX swing ---------------------------------------------
    yIdeal = (cfg.vSwing / 2) * yUp;            % ±vSwing/2

    % ---- 3. Gaussian rise/fall shaping ------------------------------------
    %  sigma = tr_2080 / 1.6832   (Gaussian step-response relationship)
    sigma_sec  = cfg.tr_target / 1.6832;
    sigma_samp = sigma_sec * fs;
    halfLen    = ceil(4 * sigma_samp);
    nKernel    = -halfLen : halfLen;
    gKernel    = exp(-(nKernel.^2) / (2 * sigma_samp^2));
    gKernel    = gKernel / sum(gKernel);         % unit DC gain

    % Pad edges to avoid startup transients
    padPre  = yIdeal(1)   * ones(1, halfLen);
    padPost = yIdeal(end) * ones(1, halfLen);
    yPad    = [padPre, yIdeal, padPost];
    yConv   = conv(yPad, gKernel, 'same');
    yShaped = yConv(halfLen+1 : halfLen+length(yIdeal));

    % ---- 4. TX output RC --------------------------------------------------
    tau_tx   = cfg.R_driver * cfg.C_driver;
    alpha_tx = exp(-1 / (fs * tau_tx));
    txOut    = filter(1 - alpha_tx, [1, -alpha_tx], yShaped);

    % ---- measure rise/fall ------------------------------------------------
    [tr_meas, tf_meas] = measure_rise_fall(b, txOut, cfg);

    % ---- console ----------------------------------------------------------
    fprintf('BLOCK 4 — TX Driver\n');
    fprintf('  ZOH factor    : %d samples/UI\n', N);
    fprintf('  V_swing       : %.3f V  (±%.4f V)\n', cfg.vSwing, cfg.vSwing/2);
    fprintf('  Rise/Fall σ   : %.3f ps  (%.2f samples)\n', sigma_sec*1e12, sigma_samp);
    fprintf('  Kernel length : %d samples\n', length(gKernel));
    fprintf('  R_driver      : %.0f Ω\n', cfg.R_driver);
    fprintf('  C_driver      : %.3f pF\n', cfg.C_driver*1e12);
    fprintf('  τ_driver      : %.3f ps\n', tau_tx*1e12);
    fprintf('  Measured tr   : %.3f ps  (target %.3f ps)\n', tr_meas*1e12, cfg.tr_target*1e12);
    fprintf('  Measured tf   : %.3f ps\n\n', tf_meas*1e12);

    % ---- time axis --------------------------------------------------------
    nSamp = length(txOut);
    t     = (0:nSamp-1) / fs;

    % ---- plot data --------------------------------------------------------
    nShowUI  = 50;
    nShowSmp = min(nShowUI * N, nSamp);

    plotData.title     = 'Block 4 — TX Driver Output';
    plotData.t         = t(1:nShowSmp) * 1e12;   % ps
    plotData.yIdeal    = yIdeal(1:nShowSmp);
    plotData.yShaped   = yShaped(1:nShowSmp);
    plotData.yOut      = txOut(1:nShowSmp);
    plotData.vSwing    = cfg.vSwing;
    plotData.tr_target = cfg.tr_target * 1e12;
    plotData.tr_meas   = tr_meas * 1e12;
    plotData.tf_meas   = tf_meas * 1e12;
    plotData.UI_ps     = 1 / cfg.dataRate * 1e12;
    plotData.N         = N;

    % Zoomed edge data
    edgeIdx = find(diff(b(1:min(nShowUI, length(b)))) == 1, 1, 'first');
    if ~isempty(edgeIdx)
        cWin = (edgeIdx-2)*N + 1 : (edgeIdx+3)*N;
        cWin = cWin(cWin >= 1 & cWin <= nSamp);
        plotData.zoomT       = t(cWin) * 1e12;
        plotData.zoomIdeal   = yIdeal(cWin);
        plotData.zoomShaped  = txOut(cWin);
        plotData.hasZoom     = true;
    else
        plotData.hasZoom     = false;
    end

    % All-presets comparison (with full driver chain)
    presets = [1.00,  0.00;
               0.90, -0.10;
               0.85, -0.15;
               0.75, -0.25];
    nShowP = min(30*N, nSamp);
    plotData.presetWaveforms = cell(1, size(presets,1));
    plotData.presets         = presets;
    x_nrz = 2*b - 1;
    for p = 1:size(presets,1)
        yp_sym  = filter([presets(p,1), presets(p,2)], 1, x_nrz);
        yp_up   = (cfg.vSwing/2) * repelem(yp_sym, N);
        padP    = [yp_up(1)*ones(1,halfLen), yp_up, yp_up(end)*ones(1,halfLen)];
        yp_c    = conv(padP, gKernel, 'same');
        yp_sh   = yp_c(halfLen+1 : halfLen+length(yp_up));
        yp_out  = filter(1-alpha_tx, [1 -alpha_tx], yp_sh);
        plotData.presetWaveforms{p} = yp_out(1:nShowP);
    end
    plotData.presetT = t(1:nShowP) * 1e12;
end
