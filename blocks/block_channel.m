function [chOut, plotData] = block_channel(txOut, cfg)
% BLOCK_CHANNEL  Channel RC low-pass model.
%
%   [chOut, plotData] = block_channel(txOut, cfg)
%
%   Models the channel as a single-pole low-pass filter (RC).
%   The architecture diagram specifies R = 30 Ω, C = 0.1 pF for the channel.
%   This attenuation mimics the interconnect traces.
%
%   Inputs
%     txOut        – 1×N analog waveform from TX driver
%     cfg.R_ch     – channel resistance (Ω)  [30]
%     cfg.C_ch     – channel capacitance (F) [0.1 pF]
%     cfg.fs       – sampling frequency (Hz)
%
%   Outputs
%     chOut    – 1×N analog waveform after channel attenuation
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
        cfg.ffeC0 = 0.75;
        cfg.ffeC1 = -0.25;
        b = block_prbs(cfg);
        x = block_nrz_mapper(b, cfg);
        ySym = block_tx_ffe(x, cfg);
        txOut = block_tx_driver(ySym, b, cfg);
        [chOut, plotData] = block_channel(txOut, cfg);
        plot_block_output(5, plotData);
        return;
    end

    fs = cfg.fs;

    % ---- Channel RC filter -----------------------------------------------
    tau_ch   = cfg.R_ch * cfg.C_ch;
    alpha_ch = exp(-1 / (fs * tau_ch));
    chOut    = filter(1 - alpha_ch, [1, -alpha_ch], txOut);

    % ---- Frequency response (for plotting) -------------------------------
    fp = 1 / (2 * pi * tau_ch);
    w0 = 2 * pi * fp;
    
    % Manual bilinear transform for H(s) = w0 / (s + w0)
    % s = 2*fs * (z-1)/(z+1)
    K = 2 * fs;
    num_ch_z = [w0, w0] / (K + w0);
    den_ch_z = [1, -(K - w0)/(K + w0)];

    Nfft = 4096;
    f = linspace(0, fs/2, Nfft/2+1);
    
    % Manual freqz (evaluate at z = e^(jw))
    w = 2 * pi * f / fs;
    z_inv = exp(-1j * w);
    H_mag_complex = (num_ch_z(1) + num_ch_z(2)*z_inv) ./ (den_ch_z(1) + den_ch_z(2)*z_inv);
    H_mag = 20*log10(abs(H_mag_complex));
    
    % ---- console ---------------------------------------------------------
    fprintf('BLOCK 5 — Channel (RC)\n');
    fprintf('  R_ch          : %.0f Ω\n', cfg.R_ch);
    fprintf('  C_ch          : %.3f pF\n', cfg.C_ch*1e12);
    fprintf('  τ_ch          : %.3f ps\n', tau_ch*1e12);
    fprintf('  f_3dB (pole)  : %.2f GHz\n\n', fp/1e9);

    % ---- plot data -------------------------------------------------------
    plotData.title   = 'Block 5 — Channel RC Output';
    nShowSmp = min(50 * cfg.samplesPerUI, length(txOut));
    plotData.t       = (0:nShowSmp-1) / fs * 1e12; % ps
    plotData.txOut   = txOut(1:nShowSmp);
    plotData.chOut   = chOut(1:nShowSmp);
    plotData.f_GHz   = f / 1e9;
    plotData.H_mag   = H_mag;
    plotData.fp      = fp;
end
