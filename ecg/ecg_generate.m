function [timeSec, ecg, rIndex] = ecg_generate(sampleRate, durationSec, heartRateBpm, injectPVC, useAF_RR)
% ecg_generate — synthetic single-lead ECG via PQRST template stamping.

% Validation
validateattributes(sampleRate, {'numeric'},{'scalar','real','finite','>=',100,'<=',2000}, mfilename,'sampleRate');
validateattributes(durationSec,{'numeric'},{'scalar','real','finite','>=',1,'<=',600}, mfilename,'durationSec');
validateattributes(heartRateBpm,{'numeric'},{'scalar','real','finite','>=',30,'<=',220}, mfilename,'heartRateBpm');
if nargin < 4, injectPVC = false; end
if nargin < 5, useAF_RR  = false; end

timeSec = (0:1/sampleRate:durationSec)';
rrMean  = 60 / heartRateBpm;  % seconds/beat

% RR series
if useAF_RR
    nBeats = max(4, round(durationSec / rrMean));
    rrSec  = max(0.35, rrMean + 0.12*randn(nBeats,1) + 0.05*sin(2*pi*(1/10)*(1:nBeats)'));
else
    nBeats = max(2, round(durationSec / rrMean));
    rrSec  = rrMean * ones(nBeats,1);
end

% Optional PVC
if injectPVC && numel(rrSec) > 5
    k = randi([3, numel(rrSec)-2], 1, 1);
    rrSec(k)   = rrSec(k) * 0.5;
    rrSec(k+1) = rrSec(k+1) * 1.5;
end

% R peak indices
rTimes = cumsum(rrSec);
rTimes = rTimes(rTimes < durationSec);
rIndex = round(rTimes * sampleRate);

% PQRST template
bt = 0:1/sampleRate:0.8;
P =  0.10*exp(-((bt-0.15)/0.040).^2);
Q = -0.15*exp(-((bt-0.25)/0.010).^2);
R =  1.00*exp(-((bt-0.27)/0.012).^2);
S = -0.25*exp(-((bt-0.31)/0.015).^2);
T =  0.30*exp(-((bt-0.55)/0.080).^2);
beatTemplate = P + Q + R + S + T;

% Stamp beats
ecg = zeros(size(timeSec));
offsetR = round(0.27*sampleRate);
for k = 1:numel(rIndex)
    s = rIndex(k) - offsetR;
    e = s + numel(beatTemplate) - 1;
    if s < 1 || e > numel(ecg), continue, end
    ecg(s:e) = ecg(s:e) + beatTemplate(:);
end
end
