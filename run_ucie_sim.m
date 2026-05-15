% RUN_UCIE_SIM  Main runner for the modular UCIe 3.0 link simulator.
%
%   Usage:
%     run_ucie_sim()     % Runs all 5 test cases
%     run_ucie_sim(3)    % Runs test case 3 only
%
function run_ucie_sim(testCaseIdx)
    clc; close all;
    
    % Add blocks directory to path
    addpath(fullfile(pwd, 'blocks'));

    % ---- Define Test Cases -----------------------------------------------
    testCases = define_test_cases();

    if nargin < 1
        runs = 1:length(testCases);
    else
        runs = testCaseIdx;
    end

    for tc = runs
        cfg = testCases(tc);
        fprintf('\n=======================================================\n');
        fprintf('  TEST CASE %d: %s\n', tc, cfg.name);
        fprintf('=======================================================\n\n');
        
        run_single_test(cfg);
        
        if tc ~= runs(end)
            input('Press Enter to continue to the next test case...', 's');
            close all;
        end
    end
end

function run_single_test(cfg)
    % --- SECTION 1: TRANSMITTER ---
    [b, p1]         = block_prbs(cfg);
    [x, p2]         = block_nrz_mapper(b, cfg);
    [ySym, p3]      = block_tx_ffe(x, cfg);
    [txOut, p4]     = block_tx_driver(ySym, b, cfg);

    % --- SECTION 2: CHANNEL & RX LOAD ---
    [chOut, p5]     = block_channel(txOut, cfg);
    [rxIn, p6]      = block_rx_load(chOut, cfg);

    % --- SECTION 3: RECEIVER SAMPLER ---
    [rxNoisy, p7]   = block_add_noise(rxIn, cfg);
    [rxSamples, sampleIdx, p8] = block_sample_hold(rxNoisy, cfg);
    [bHat, p9]      = block_slicer(rxSamples, cfg);

    % --- SECTION 4: MEASUREMENT ---
    [ber, p10]             = block_ber_meas(b, bHat, cfg);
    [berQ, qFactor, p11]   = block_histogram_q(rxSamples, b, cfg);
    p12                    = block_eye_diagram(rxNoisy, cfg);

    % --- PLOTTING ---
    plot_block_output(1, p1);
    plot_block_output(2, p2);
    plot_block_output(3, p3);
    plot_block_output(4, p4);
    plot_block_output(5, p5);
    plot_block_output(6, p6);
    plot_block_output(7, p7);
    plot_block_output(8, p8);
    plot_block_output(9, p9);
    plot_block_output(10, p10);
    plot_block_output(11, p11);
    plot_block_output(12, p12);
    
    % --- SUMMARY ---
    fprintf('=======================================================\n');
    fprintf('  SUMMARY for %s\n', cfg.name);
    fprintf('=======================================================\n');
    fprintf('Data Rate     : %.2f GT/s\n', cfg.dataRate / 1e9);
    fprintf('Channel Specs : R = %.0f Ω, C = %.3f pF\n', cfg.R_ch, cfg.C_ch * 1e12);
    fprintf('FFE Preset    : c0=%.2f, c1=%.2f\n', cfg.ffeC0, cfg.ffeC1);
    fprintf('Noise σ       : %.2f mV\n', cfg.noiseSigma * 1e3);
    fprintf('Jitter σ_RJ   : %.2f ps\n', cfg.rjSigma * 1e12);
    fprintf('Measured BER  : %e\n', ber);
    fprintf('Est BER (Q)   : %e\n', berQ);
    fprintf('Q-factor      : %.2f\n', qFactor);
    fprintf('Rise Time     : %.2f ps\n', p4.tr_meas);
    fprintf('Fall Time     : %.2f ps\n', p4.tf_meas);
    fprintf('=======================================================\n');
end

function tc = define_test_cases()
    % Default shared config (define all fields to avoid dissimilar struct errors)
    def.name         = '';
    def.nBits        = 10000;
    def.dataRate     = 32e9;
    def.samplesPerUI = 16;
    def.fs           = 32e9 * 16;
    def.vSwing       = 0.625;
    def.tr_target    = 0.20 / 32e9;
    def.R_driver     = 30;
    def.C_driver     = 0.1e-12;
    def.R_ch         = 30;
    def.C_ch         = 0.1e-12;
    def.R_rx         = 50;
    def.C_rx         = 0.2e-12;
    def.vThresh      = 0;
    def.ffeC0        = 1.0;
    def.ffeC1        = 0.0;
    def.noiseSigma   = 0;
    def.enableJitter = false;
    def.rjSigma      = 0;
    
    % Test 1: Advanced Silicon Interposer (Ultra-Short Reach)
    tc(1) = def;
    tc(1).name = 'Case 1: Advanced Silicon Interposer (Ultra-Short Reach, 32 GT/s)';
    tc(1).R_ch = 15; tc(1).C_ch = 0.05e-12; % Very low loss
    tc(1).ffeC0 = 1.0; tc(1).ffeC1 = 0.0;   % Preset 0 (No eq needed)
    tc(1).noiseSigma = 1e-3;                % Minimal noise
    tc(1).enableJitter = true; tc(1).rjSigma = 0.1e-12; 
    
    % Test 2: Standard Organic Package Interconnect (Medium Reach)
    tc(2) = def;
    tc(2).name = 'Case 2: Standard Organic Package (Medium Reach, 32 GT/s)';
    tc(2).R_ch = 40; tc(2).C_ch = 0.15e-12; % Standard loss
    tc(2).ffeC0 = 0.85; tc(2).ffeC1 = -0.15;% Preset 2 (Moderate eq needed)
    tc(2).noiseSigma = 3e-3;                % Typical noise
    tc(2).enableJitter = true; tc(2).rjSigma = 0.2e-12;
    
    % Test 3: Next-Generation UCIe 3.0 Limits (64 GT/s)
    tc(3) = def;
    tc(3).name = 'Case 3: Next-Generation UCIe 3.0 Limits (64 GT/s)';
    tc(3).dataRate = 64e9;
    tc(3).fs = tc(3).dataRate * tc(3).samplesPerUI;
    tc(3).tr_target = 0.20 / tc(3).dataRate;
    tc(3).R_ch = 25; tc(3).C_ch = 0.1e-12;  % Good channel, but extreme frequency
    tc(3).ffeC0 = 0.75; tc(3).ffeC1 = -0.25;% Preset 3 (Strong eq needed)
    tc(3).noiseSigma = 5e-3;
    tc(3).enableJitter = true; tc(3).rjSigma = 0.25e-12;
    
    % Test 4: Severe Crosstalk & Power Supply Ripple (Vertical Closure)
    tc(4) = def;
    tc(4).name = 'Case 4: Severe Crosstalk & Power Supply Ripple (Stress Test)';
    tc(4).ffeC0 = 0.90; tc(4).ffeC1 = -0.10;% Preset 1
    tc(4).noiseSigma = 20e-3;               % Extreme voltage noise
    tc(4).enableJitter = false;
    
    % Test 5: Clock Recovery / PLL Jitter Failure (Horizontal Closure)
    tc(5) = def;
    tc(5).name = 'Case 5: Clock Recovery / PLL Jitter Failure';
    tc(5).ffeC0 = 0.85; tc(5).ffeC1 = -0.15;% Preset 2
    tc(5).noiseSigma = 3e-3;                % Low voltage noise
    tc(5).enableJitter = true; tc(5).rjSigma = 2.0e-12; % Extreme horizontal jitter
end
