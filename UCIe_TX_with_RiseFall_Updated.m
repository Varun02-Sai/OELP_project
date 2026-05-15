% =========================================================================
%  UCIe 2.0 TX Behavioral Model  (with rise/fall time)
%  Blocks: PRBS -> NRZ Mapper -> Upsampler -> Rise/Fall Shaping -> TX FFE
%
%  Changes vs. original model:
%   1. Added rise/fall time shaping using a Gaussian transmit filter so
%      transitions are no longer instantaneous (ZOH).
%   2. Reordered processing: FFE is applied at SYMBOL rate (FIR on x[n]),
%      then upsampled (ZOH), then passed through the rise/fall filter.
%      This matches how a real TX driver behaves: the FFE shapes the
%      symbol weights, and the analog driver imposes its bandwidth.
%   3. Added measurement of the achieved 20%-80% rise/fall time so the
%      model can be sanity-checked against UCIe spec targets.
% =========================================================================

clc; clear; close all;

% ---------------- SYSTEM PARAMETERS ----------------
cfg.dataRate     = 32e9;                            % 32 GT/s (UCIe 2.0)
cfg.UI           = 1 / cfg.dataRate;                % 31.25 ps
cfg.samplesPerUI = 16;
cfg.fs           = cfg.dataRate * cfg.samplesPerUI; % 512 GHz waveform rate
cfg.nBits        = 2^15;                            % 32768 bits

% Rise/fall time target (20% - 80%). UCIe 2.0 typical: ~0.2 * UI
cfg.tr_target    = 0.20 * cfg.UI;                   % 6.25 ps (20%-80%)

% Time axis (waveform domain)
cfg.nSamples = cfg.nBits * cfg.samplesPerUI;
cfg.t        = (0 : cfg.nSamples-1) / cfg.fs;

fprintf('=== UCIe 2.0 TX Chain ===\n');
fprintf('Data rate    : %.2f GT/s\n', cfg.dataRate/1e9);
fprintf('UI           : %.3f ps\n',   cfg.UI*1e12);
fprintf('Samples/UI   : %d\n',        cfg.samplesPerUI);
fprintf('Sample rate  : %.2f GHz\n',  cfg.fs/1e9);
fprintf('tr/tf target : %.3f ps (20%%-80%%)\n\n', cfg.tr_target*1e12);


% ---------------- BLOCK 1: PRBS GENERATOR (LFSR) ----------------
% PRBS-15: polynomial x^15 + x^14 + 1
prbs.degree = 15;
prbs.taps   = [1, 2];
prbs.seed   = ones(1, prbs.degree);   % all-ones reset (any non-zero is ok)

reg = prbs.seed;
b   = zeros(1, cfg.nBits);

for i = 1 : cfg.nBits
    b(i) = reg(end);
    fb   = mod(sum(reg(prbs.taps)), 2);
    reg  = [fb, reg(1:end-1)];
end

fprintf('BLOCK 1 - PRBS Generator\n');
fprintf('Ones: %d | Zeros: %d | Total: %d bits\n\n', sum(b), sum(~b), cfg.nBits);


% ---------------- BLOCK 2: NRZ MAPPER ----------------
% Formula: x[n] = 2*b[n] - 1   ->   {-1, +1}
x = 2*b - 1;

fprintf('BLOCK 2 - NRZ Mapper\n');
fprintf('Unique levels : %s\n\n', mat2str(unique(x)));


% ---------------- BLOCK 3: TX FFE (at symbol rate) ----------------
% 2-tap FIR: y[n] = c0*x[n] + c1*x[n-1]
%   c0 = main tap (current symbol)
%   c1 = post-cursor tap (previous symbol -> de-emphasis)
%
% FFE presets (from UCIe 2.0 spec):
%   Preset 0 : [1.00,  0.00]  -> no de-emphasis
%   Preset 1 : [0.90, -0.10]  -> mild de-emphasis
%   Preset 2 : [0.85, -0.15]  -> moderate de-emphasis
%   Preset 3 : [0.75, -0.25]  -> strong de-emphasis
tx.vSwing     = 0.625;                  % peak-to-peak TX swing (V)
tx.ffePresets = [ 1.00,  0.00;
                  0.90, -0.10;
                  0.85, -0.15;
                  0.75, -0.25 ];
tx.presetSel  = 3;                      % 1-indexed row (= Preset 2 in spec)
tx.c0 = tx.ffePresets(tx.presetSel, 1);
tx.c1 = tx.ffePresets(tx.presetSel, 2);

% Apply FFE at symbol rate
ySym = filter([tx.c0, tx.c1], 1, x);

fprintf('BLOCK 3 - TX FFE (symbol rate)\n');
fprintf('Selected preset : %d\n',      tx.presetSel);
fprintf('Main tap c0     : %.2f\n',    tx.c0);
fprintf('Post tap c1     : %.2f\n',    tx.c1);
fprintf('TX swing (Vpp)  : %.3f V\n\n', tx.vSwing);


% ---------------- BLOCK 4: UPSAMPLE (ZOH to waveform domain) ----------------
% Each FFE-equalized symbol held for samplesPerUI samples.
yUp_symRate = repelem(ySym, cfg.samplesPerUI);

% Scale to TX swing (symbols are nominally +/- 1 -> scaled to +/- vSwing/2)
yIdeal = (tx.vSwing / 2) * yUp_symRate;     % "ideal" square-edge waveform


% ---------------- BLOCK 5: RISE/FALL TIME SHAPING ----------------
% Model the analog driver bandwidth as a Gaussian low-pass filter.
% Relationship: t_2080 (20%-80%) = 0.6796 / (BW_-3dB)  for a Gaussian.
% Equivalently, the Gaussian impulse response h(t) = (1/(sigma*sqrt(2pi))) * exp(-t^2/(2*sigma^2))
% has 20%-80% step rise time tr2080 ~= 1.6832 * sigma.
%
%   sigma = tr2080 / 1.6832
%
% We construct a finite-length truncated Gaussian kernel (+/- 4*sigma) and
% normalize it to unit DC gain so the steady-state level is preserved.

sigma_sec    = cfg.tr_target / 1.6832;            % seconds
sigma_samp   = sigma_sec * cfg.fs;                % samples
halfLen      = ceil(4 * sigma_samp);              % +/- 4*sigma support
nKern        = 2*halfLen + 1;
nKernel      = (-halfLen : halfLen);
gKernel      = exp(-(nKernel.^2) / (2 * sigma_samp^2));
gKernel      = gKernel / sum(gKernel);            % unit DC gain

% Apply zero-phase Gaussian filtering. Use 'same' length conv with
% pre-/post- padding by edge values to avoid startup transients.
padPre  = yIdeal(1)   * ones(1, halfLen);
padPost = yIdeal(end) * ones(1, halfLen);
yPad    = [padPre, yIdeal, padPost];
yConv   = conv(yPad, gKernel, 'same');
yFFE    = yConv(halfLen+1 : halfLen+length(yIdeal));   % trim back to original length

fprintf('BLOCK 5 - Rise/Fall Shaping (Gaussian)\n');
fprintf('sigma           : %.3f ps  (%.2f samples)\n', sigma_sec*1e12, sigma_samp);
fprintf('Kernel length   : %d samples (+/- %.2f ps)\n', nKern, halfLen/cfg.fs*1e12);
fprintf('FFE output range: [%.4f V, %.4f V]\n\n', min(yFFE), max(yFFE));


% ---------------- MEASURE ACHIEVED RISE/FALL TIME ----------------
% Take a clean isolated rising edge from the waveform (a 0->1 transition
% preceded and followed by stable bits) to measure 20%-80% time.
[tr_meas, tf_meas] = measureRiseFall(b, yFFE, cfg);

fprintf('=== Measured Rise/Fall (20%%-80%%) ===\n');
fprintf('Target          : %.3f ps\n', cfg.tr_target*1e12);
fprintf('Measured tr     : %.3f ps\n', tr_meas*1e12);
fprintf('Measured tf     : %.3f ps\n\n', tf_meas*1e12);


% =========================================================================
%                                 PLOTS
% =========================================================================
nShow_UI  = 50;
nShow_smp = nShow_UI * cfg.samplesPerUI;
nShow_bits = 100;

% --- Plot 1: PRBS bits ---
figure('Name','Block 1: PRBS Output','Color','w');
stem(1:nShow_bits, b(1:nShow_bits), 'filled', ...
    'MarkerSize', 3, 'Color', [0.2 0.4 0.8]);
grid on;
xlabel('Bit index n'); ylabel('b[n]');
title('Block 1 - PRBS Output : b[n] (first 100 bits)');
ylim([-0.3, 1.3]);
yticks([0 1]); yticklabels({'0','1'});

% --- Plot 2: NRZ mapped symbols ---
figure('Name','Block 2: NRZ Mapper Output','Color','w');
stem(1:nShow_bits, x(1:nShow_bits), 'filled', ...
    'MarkerSize', 3, 'Color', [0.8 0.2 0.2]);
grid on;
xlabel('Symbol index n'); ylabel('x[n]');
title('Block 2 - NRZ Mapper Output : x[n] (first 100 symbols)');
ylim([-1.5, 1.5]);
yticks([-1 0 1]); yticklabels({'-1','0','+1'});
yline(0, '--k', 'LineWidth', 0.8);

% --- Plot 3: FFE at symbol rate (before vs after) ---
figure('Name','Block 3: TX FFE Symbol Output','Color','w');
nShow_sym = 80;
subplot(2,1,1);
stem(1:nShow_sym, x(1:nShow_sym), 'filled', ...
    'MarkerSize', 3, 'Color', [0.8 0.2 0.2]);
grid on; ylabel('x[n]'); title('Input to FFE - NRZ symbols x[n]');
ylim([-1.5 1.5]); yticks([-1 0 1]);
yline(0,'--k'); yline(1,':r','LineWidth',0.5); yline(-1,':r','LineWidth',0.5);

subplot(2,1,2);
stem(1:nShow_sym, ySym(1:nShow_sym), 'filled', ...
    'MarkerSize', 3, 'Color', [0.6 0.1 0.8]);
grid on; ylabel('y[n]'); xlabel('Symbol index n');
title(sprintf('FFE Output - y[n] = %.2f \\cdot x[n] + (%.2f) \\cdot x[n-1]  (Preset %d)', ...
    tx.c0, tx.c1, tx.presetSel));
ylim([-1.5 1.5]);
yline(0,'--k');
yline( tx.c0,'--','Color',[0.4 0.4 0.4],'Label',sprintf('c0=%.2f',tx.c0));
yline(-tx.c0,'--','Color',[0.4 0.4 0.4]);
sgtitle('Block 3 - TX FFE: Before vs After','FontWeight','bold');

% --- Plot 4: Waveform domain - ideal (square edges) vs shaped ---
figure('Name','Block 5: Rise/Fall Shaped Waveform','Color','w');
subplot(2,1,1);
plot(cfg.t(1:nShow_smp)*1e12, yIdeal(1:nShow_smp), ...
    'Color', [0.7 0.7 0.7], 'LineWidth', 1.2);
hold on;
plot(cfg.t(1:nShow_smp)*1e12, yFFE(1:nShow_smp), ...
    'Color', [0.1 0.5 0.8], 'LineWidth', 1.4);
grid on; ylabel('Voltage (V)');
title(sprintf('Before rise/fall shaping (gray) vs After (blue), tr_{target}=%.2f ps', ...
    cfg.tr_target*1e12));
ylim([-0.4 0.4]);
yline(0,'--k','LineWidth',0.8);
legend({'Ideal (ZOH)','After Gaussian shaping'},'Location','best');

% Overlay UI grid
for k = 0:nShow_UI
    xline(k * cfg.UI * 1e12, ':k', 'Alpha', 0.2);
end

% Plot zoomed isolated edge to make rise time visible
subplot(2,1,2);
% Find first 0->1 transition in shown window
edgeIdx = find(diff(b(1:nShow_UI)) == 1, 1, 'first');
if ~isempty(edgeIdx)
    cWin = (edgeIdx-2)*cfg.samplesPerUI + 1 : (edgeIdx+3)*cfg.samplesPerUI;
    cWin = cWin(cWin >= 1 & cWin <= length(yFFE));
    plot(cfg.t(cWin)*1e12, yIdeal(cWin), 'Color',[0.7 0.7 0.7], 'LineWidth',1.2);
    hold on;
    plot(cfg.t(cWin)*1e12, yFFE(cWin),  'Color',[0.1 0.5 0.8], 'LineWidth',1.6);
    grid on; xlabel('Time (ps)'); ylabel('Voltage (V)');
    title('Zoom: isolated rising edge - shows finite rise time');
    ylim([-0.4 0.4]);
    yline(0,'--k','LineWidth',0.8);
    yline( 0.2*tx.vSwing/2,':','Color',[0.5 0.5 0.5],'Label','20% level');
    yline( 0.8*tx.vSwing/2,':','Color',[0.5 0.5 0.5],'Label','80% level');
end
sgtitle('Block 5 - TX Output Waveform with finite rise/fall','FontWeight','bold');

% --- Plot 5: All 4 FFE presets compared (with rise/fall shaping) ---
figure('Name','Block 4c: FFE Presets Comparison','Color','w');
colors = {[0.2 0.7 0.2], [0.2 0.4 0.9], [0.9 0.5 0.1], [0.7 0.1 0.1]};
nShow_smp2 = 30 * cfg.samplesPerUI;
hold on;
for p = 1:4
    c0p = tx.ffePresets(p,1);
    c1p = tx.ffePresets(p,2);
    yp_sym  = filter([c0p, c1p], 1, x);
    yp_up   = (tx.vSwing/2) * repelem(yp_sym, cfg.samplesPerUI);
    % Apply same rise/fall shaping
    padP = [yp_up(1)*ones(1,halfLen), yp_up, yp_up(end)*ones(1,halfLen)];
    yp_c = conv(padP, gKernel, 'same');
    yp   = yp_c(halfLen+1 : halfLen+length(yp_up));
    plot(cfg.t(1:nShow_smp2)*1e12, yp(1:nShow_smp2), ...
        'Color', colors{p}, 'LineWidth', 1.3, ...
        'DisplayName', sprintf('Preset %d: [%.2f, %.2f]', p-1, c0p, c1p));
end
grid on;
xlabel('Time (ps)'); ylabel('Voltage (V)');
title('Block 4 - All FFE Presets Compared (with rise/fall shaping, first 30 UI)');
legend('Location','best');
ylim([-0.4 0.4]);
yline(0,'--k','LineWidth',0.8);


% ---------------- FULL CHAIN SUMMARY ----------------
fprintf('=== Signal at Each Stage (first 8 bits) ===\n');
fprintf('%-12s', 'Bit index');     fprintf('%-8d', 1:8); fprintf('\n');
fprintf('%-12s', 'b[n]');          fprintf('%-8d', b(1:8)); fprintf('\n');
fprintf('%-12s', 'x[n]');          fprintf('%-8d', x(1:8)); fprintf('\n');
fprintf('%-12s', 'y_FFE[n]');      fprintf('%-8.2f', ySym(1:8)); fprintf('\n');
fprintf('(each symbol held for %d samples, scaled to +/-%.4f V, then Gaussian-shaped to tr=%.2f ps)\n', ...
    cfg.samplesPerUI, tx.vSwing/2, cfg.tr_target*1e12);


% =========================================================================
%                          LOCAL FUNCTIONS
% =========================================================================
function [tr, tf] = measureRiseFall(b, yWave, cfg)
% Measure 20%-80% rise time and 80%-20% fall time on the first clean
% isolated 0->1 and 1->0 transition. Uses linear interpolation between
% samples so measurement is not quantized by the waveform grid.
    N = cfg.samplesPerUI;
    risePos = find(b(1:end-2)==0 & b(2:end-1)==1, 1, 'first');
    fallPos = find(b(1:end-2)==1 & b(2:end-1)==0, 1, 'first');

    pkpk = max(yWave(1:min(end,2000))) - min(yWave(1:min(end,2000)));
    lo   = min(yWave(1:min(end,2000)));
    v20  = lo + 0.20 * pkpk;
    v80  = lo + 0.80 * pkpk;

    tr = NaN; tf = NaN;
    if ~isempty(risePos)
        idxStart = (risePos-1)*N + 1;
        idxEnd   = min((risePos+1)*N, length(yWave));
        seg  = yWave(idxStart:idxEnd);
        tseg = (0:length(seg)-1) / cfg.fs;
        t20  = interpCross(tseg, seg, v20, +1);
        t80  = interpCross(tseg, seg, v80, +1);
        if ~isnan(t20) && ~isnan(t80) && t80 > t20
            tr = t80 - t20;
        end
    end
    if ~isempty(fallPos)
        idxStart = (fallPos-1)*N + 1;
        idxEnd   = min((fallPos+1)*N, length(yWave));
        seg  = yWave(idxStart:idxEnd);
        tseg = (0:length(seg)-1) / cfg.fs;
        t80  = interpCross(tseg, seg, v80, -1);
        t20  = interpCross(tseg, seg, v20, -1);
        if ~isnan(t80) && ~isnan(t20) && t20 > t80
            tf = t20 - t80;
        end
    end
end

function tcross = interpCross(t, y, level, dir)
% Linear-interpolated time at which y crosses 'level'.
% dir = +1 (rising) or -1 (falling). Returns NaN if no crossing found.
    tcross = NaN;
    if dir > 0
        idx = find(y(1:end-1) < level & y(2:end) >= level, 1, 'first');
    else
        idx = find(y(1:end-1) > level & y(2:end) <= level, 1, 'first');
    end
    if ~isempty(idx)
        y1 = y(idx); y2 = y(idx+1);
        if y2 == y1
            tcross = t(idx);
        else
            frac = (level - y1) / (y2 - y1);
            tcross = t(idx) + frac * (t(idx+1) - t(idx));
        end
    end
end
