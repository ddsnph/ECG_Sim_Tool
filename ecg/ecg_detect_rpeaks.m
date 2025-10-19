function [rIndex, rAmps] = ecg_detect_rpeaks(ecgIn, sampleRate, opts)
% Light Pan-Tompkins style with fixed or adaptive thresholding.
% Fallback to internal peak finder if Signal Toolbox findpeaks is unavailable.

if nargin < 3 || ~isstruct(opts), opts = struct; end
if ~isfield(opts,'Method'), opts.Method = 'adaptive'; end
method = lower(string(opts.Method));

validateattributes(ecgIn,{'numeric'},{'vector','real','finite'}, mfilename,'ecgIn');
validateattributes(sampleRate,{'numeric'},{'scalar','real','finite','>=',100,'<=',2000}, mfilename,'sampleRate');

% QRS band
[bBP, aBP] = butter(2, [5 15]/(sampleRate/2), 'bandpass');
qrs = filtfilt(bBP, aBP, ecgIn(:));

% Energy envelope
win = max(5, round(0.08*sampleRate)); % ~80 ms
env = movmean(qrs.^2, win);
minDist = round(0.25*sampleRate);

% Peak function handle with fallback
haveFindpeaks = exist('findpeaks','file') == 2;
if haveFindpeaks
    peakfun = @(x,varargin) findpeaks(x,varargin{:});
else
    peakfun = @(x,varargin) fallback_findpeaks(x,varargin{:});
end

switch method
    case "fixed"
        thr = 0.35 * max(env);
        [~, rIndex] = peakfun(env, 'MinPeakDistance', minDist, 'MinPeakHeight', thr);

    case "adaptive"
        base = movmedian(env, max(11, round(0.6*sampleRate)));       % baseline
        thrSeries = base + 6*mad(env-base,1);                         % robust threshold
        [pks, locs] = peakfun(env, 'MinPeakDistance', minDist);
        keep = pks > thrSeries(locs);
        rIndex = locs(keep);

    otherwise
        error('ecg_detect_rpeaks:BadMethod','Unknown Method: %s', method);
end

rAmps = ecgIn(rIndex);
end

% --- Simple internal peak finder (distance + height) ---
function [pks, locs] = fallback_findpeaks(x, varargin)
% Supports 'MinPeakDistance' and 'MinPeakHeight'
minDist = 1; minH = -inf;
for k = 1:2:numel(varargin)
    switch lower(varargin{k})
        case 'minpeakdistance', minDist = varargin{k+1};
        case 'minpeakheight',  minH    = varargin{k+1};
    end
end
x = x(:); n = numel(x);
cand = false(n,1);
for i = 2:n-1
    if x(i) >= x(i-1) && x(i) > x(i+1) && x(i) >= minH, cand(i) = true; end
end
idx = find(cand);
% Enforce refractory distance
keep = true(size(idx));
last = -inf;
for i = 1:numel(idx)
    if idx(i) - last < minDist
        if x(idx(i)) <= x(last), keep(i) = false; else, keep(i-1) = false; last = idx(i); end
    else
        last = idx(i);
    end
end
locs = idx(keep);
pks = x(locs);
end
