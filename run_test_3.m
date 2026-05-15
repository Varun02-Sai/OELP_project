% RUN_TEST_3
% Separately runs Test Case 3 and saves plots to a folder

def.name         = ''; def.nBits        = 10000; def.dataRate     = 32e9; def.samplesPerUI = 16;
def.fs           = 32e9 * 16; def.vSwing       = 0.625; def.tr_target    = 0.20 / 32e9;
def.R_driver     = 30; def.C_driver     = 0.1e-12; def.R_ch         = 30; def.C_ch         = 0.1e-12;
def.R_rx         = 50; def.C_rx         = 0.2e-12; def.vThresh      = 0; def.ffeC0        = 1.0;
def.ffeC1        = 0.0; def.noiseSigma   = 0; def.enableJitter = false; def.rjSigma      = 0;

cfg = def;
cfg.name = 'Case 3: Next-Generation UCIe 3.0 Limits (64 GT/s)';
cfg.dataRate = 64e9;
cfg.fs = cfg.dataRate * cfg.samplesPerUI;
cfg.tr_target = 0.20 / cfg.dataRate;
cfg.R_ch = 25; cfg.C_ch = 0.1e-12;  
cfg.ffeC0 = 0.75; cfg.ffeC1 = -0.25;
cfg.noiseSigma = 5e-3;
cfg.enableJitter = true; cfg.rjSigma = 0.25e-12;

run_and_save_test(cfg, fullfile(pwd, 'Output_TestCase_3'));
