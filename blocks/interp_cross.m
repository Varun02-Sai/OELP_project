function tcross = interp_cross(t, y, level, dir)
% INTERP_CROSS  Linear-interpolated time crossing.
%
%   tcross = interp_cross(t, y, level, dir)
%
%   dir = +1 (rising) or -1 (falling). Returns NaN if no crossing found.

    tcross = NaN;
    if dir > 0
        idx = find(y(1:end-1) < level & y(2:end) >= level, 1, 'first');
    else
        idx = find(y(1:end-1) > level & y(2:end) <= level, 1, 'first');
    end
    
    if ~isempty(idx)
        y1 = y(idx); 
        y2 = y(idx+1);
        if y2 == y1
            tcross = t(idx);
        else
            frac = (level - y1) / (y2 - y1);
            tcross = t(idx) + frac * (t(idx+1) - t(idx));
        end
    end
end
