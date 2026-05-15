% RUN_TEST_4
% Separately runs Test Case 4 and saves plots to a folder

def.name         = ''; def.nBits        = 10000; def.dataRate     = 32e9; def.samplesPerUI = 16;
def.fs           = 32e9 * 16; def.vSwing       = 0.625; def.tr_target    = 0.20 / 32e9;
def.R_driver     = 30; def.C_driver     = 0.1e-12; def.R_ch         = 30; def.C_ch         = 0.1e-12;
def.R_rx         = 50; def.C_rx         = 0.2e-12; def.vThresh      = 0; def.ffeC0        = 1.0;
def.ffeC1        = 0.0; def.noiseSigma   = 0; def.enableJitter = false; def.rjSigma      = 0;

cfg = def;
cfg.name = 'Case 4: Severe Crosstalk & Power Supply Ripple (Stress Test)';
cfg.ffeC0 = 0.90; cfg.ffeC1 = -0.10;
cfg.noiseSigma = 20e-3;             
cfg.enableJitter = false;

run_and_save_test(cfg, fullfile(pwd, 'Output_TestCase_4'));
