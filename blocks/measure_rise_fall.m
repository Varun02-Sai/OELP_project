function [tr, tf] = measure_rise_fall(b, yWave, cfg)
% MEASURE_RISE_FALL  Measure 20%-80% rise/fall time on a waveform.
%
%   [tr, tf] = measure_rise_fall(b, yWave, cfg)
%
%   Finds the first clean, isolated 0->1 transition and 1->0 transition
%   and interpolates the 20% to 80% swing time.

    N = cfg.samplesPerUI;
    fs = cfg.fs;
    
    % Find first isolated transitions
    risePos = find(b(1:end-2)==0 & b(2:end-1)==1, 1, 'first');
    fallPos = find(b(1:end-2)==1 & b(2:end-1)==0, 1, 'first');

    % Estimate pk-pk from early samples to define 20% and 80% levels
    lookLen = min(length(yWave), 2000);
    pkpk = max(yWave(1:lookLen)) - min(yWave(1:lookLen));
    lo   = min(yWave(1:lookLen));
    v20  = lo + 0.20 * pkpk;
    v80  = lo + 0.80 * pkpk;

    tr = NaN; 
    tf = NaN;
    
    if ~isempty(risePos)
        idxStart = (risePos-1)*N + 1;
        idxEnd   = min((risePos+1)*N, length(yWave));
        seg  = yWave(idxStart:idxEnd);
        tseg = (0:length(seg)-1) / fs;
        t20  = interp_cross(tseg, seg, v20, +1);
        t80  = interp_cross(tseg, seg, v80, +1);
        if ~isnan(t20) && ~isnan(t80) && t80 > t20
            tr = t80 - t20;
        end
    end
    
    if ~isempty(fallPos)
        idxStart = (fallPos-1)*N + 1;
        idxEnd   = min((fallPos+1)*N, length(yWave));
        seg  = yWave(idxStart:idxEnd);
        tseg = (0:length(seg)-1) / fs;
        t80  = interp_cross(tseg, seg, v80, -1);
        t20  = interp_cross(tseg, seg, v20, -1);
        if ~isnan(t80) && ~isnan(t20) && t20 > t80
            tf = t20 - t80;
        end
    end
end
