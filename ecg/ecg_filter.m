function ecgFiltered = ecg_filter(ecgInput, sampleRate, notchHz)
% HP 0.5 Hz -> optional notch (50/60) -> LP 40 Hz. Zero-phase.
if nargin < 3 || isempty(notchHz), notchHz = 60; end
validateattributes(ecgInput,{'numeric'},{'vector','real','finite'}, mfilename,'ecgInput');
validateattributes(sampleRate,{'numeric'},{'scalar','real','finite','>=',100,'<=',2000}, mfilename,'sampleRate');
validateattributes(notchHz,{'numeric'},{'scalar','real','finite'}, mfilename,'notchHz');

[bHP, aHP] = butter(2, 0.5/(sampleRate/2), 'high');
y = filtfilt(bHP, aHP, ecgInput(:));

if notchHz > 0
    wo = notchHz/(sampleRate/2);
    bw = wo/35;
    [bn, an] = iirnotch(wo, bw);
    y = filtfilt(bn, an, y);
end

[bLP, aLP] = butter(3, 40/(sampleRate/2), 'low');
ecgFiltered = filtfilt(bLP, aLP, y);
end
