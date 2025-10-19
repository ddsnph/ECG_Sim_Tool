function ecgNoisy = ecg_add_noise(ecgClean, sampleRate, noise)
% Adds baseline wander (~0.33 Hz), EMG-like band (20–100 Hz), and mains hum.

validateattributes(ecgClean, {'numeric'},{'vector','real','finite'}, mfilename,'ecgClean');
validateattributes(sampleRate,{'numeric'},{'scalar','real','finite','>=',100,'<=',2000}, mfilename,'sampleRate');
if nargin < 3 || isempty(noise), noise = struct('baseline',0,'emg',0,'hum',0); end

n  = numel(ecgClean);
t  = (0:n-1)'/sampleRate;
y  = ecgClean(:);

% Baseline
if isfield(noise,'baseline')
    validateattributes(noise.baseline,{'numeric'},{'scalar','real','finite','>=',0,'<=',5},mfilename,'noise.baseline');
    y = y + noise.baseline * sin(2*pi*0.33*t);
end

% EMG-like
if isfield(noise,'emg') && noise.emg > 0
    validateattributes(noise.emg,{'numeric'},{'scalar','real','finite','>=',0,'<=',5},mfilename,'noise.emg');
    white = randn(size(y));
    [b,a]  = butter(2, [20 100]/(sampleRate/2), 'bandpass');
    emg    = filtfilt(b,a,white);
    emg    = noise.emg * emg / max(rms(emg), eps);
    y = y + emg;
end

% Mains hum (amplitude in mV; freq handled in filter)
if isfield(noise,'hum')
    validateattributes(noise.hum,{'numeric'},{'scalar','real','finite','>=',0,'<=',5},mfilename,'noise.hum');
    y = y + noise.hum * sin(2*pi*60*t); % shown pre-notch; notch removes at chosen mainsHz
end

ecgNoisy = y;
end
