% RUN_TEST_1
% Separately runs Test Case 1 and saves plots to a folder

% Def struct initialization
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

% Test 1 config
cfg = def;
cfg.name = 'Case 1: Advanced Silicon Interposer (Ultra-Short Reach, 32 GT/s)';
cfg.R_ch = 15; cfg.C_ch = 0.05e-12; 
cfg.ffeC0 = 1.0; cfg.ffeC1 = 0.0;   
cfg.noiseSigma = 1e-3;              
cfg.enableJitter = true; cfg.rjSigma = 0.1e-12; 

% Run and save
run_and_save_test(cfg, fullfile(pwd, 'Output_TestCase_1'));
