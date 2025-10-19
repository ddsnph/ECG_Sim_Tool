% Edge cases: low/high HR, short/long durations, 50 Hz mains
addpath('ecg'); rng(0,'twister');

% Low HR 30 bpm
[t, x, r] = ecg_generate(360, 20, 30, false, false);
assert(~isempty(r), 'No beats at low HR');

% High HR 180 bpm
[t, x, r] = ecg_generate(360, 10, 180, false, false);
assert(numel(r) > 20, 'Too few beats at high HR');

% Very short duration
[t, x, r] = ecg_generate(360, 5, 70, false, false);
assert(numel(x)==numel(t) && numel(r)>=1, 'Short duration failed');

% Long-ish duration
[t, x, r] = ecg_generate(360, 60, 70, true, true);
assert(numel(x)==numel(t) && ~isempty(r), 'Long duration + arrhythmia failed');

% 50 Hz mains notch
noisy = ecg_add_noise(x, 360, struct('baseline',0.2,'emg',0.2,'hum',0.2));
f50   = ecg_filter(noisy, 360, 50);
[rd, ~] = ecg_detect_rpeaks(f50, 360, struct('Method','adaptive'));
assert(~isempty(rd),'Detection failed with 50 Hz notch');
disp('Edge-case tests passed.');
