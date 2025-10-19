% RR/HR accuracy on clean and noisy signals
addpath('ecg'); rng(0,'twister');

fs=360; dur=20; hr=72;
[t, clean, rTrue] = ecg_generate(fs, dur, hr, false, false);
rrTrue = diff(t(rTrue)); hrTrueMean = 60/mean(rrTrue);

noisy = ecg_add_noise(clean, fs, struct('baseline',0.2,'emg',0.2,'hum',0.05));
filt  = ecg_filter(noisy, fs, 60);
[rd, ~] = ecg_detect_rpeaks(filt, fs, struct('Method','adaptive'));
rrDet = diff(t(rd)); hrDetMean = 60/mean(rrDet);

assert(abs(hrTrueMean - hr) < 1.5, 'True HR deviates >1.5 bpm');
assert(abs(hrDetMean  - hr) < 3.0, 'Detected HR deviates >3 bpm');
fprintf('HR set=%g, true=%.2f, detected=%.2f bpm\n', hr, hrTrueMean, hrDetMean);
