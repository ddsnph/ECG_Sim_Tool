% Precision/recall under noise
addpath('ecg'); rng(0,'twister');

fs=360; dur=25; hr=80;
[t, clean, rTrue] = ecg_generate(fs,dur,hr,false,false);
noisy = ecg_add_noise(clean, fs, struct('baseline',0.25,'emg',0.25,'hum',0.1));
filt  = ecg_filter(noisy, fs, 60);
[rd, ~] = ecg_detect_rpeaks(filt, fs, struct('Method','adaptive'));

tol = round(0.05*fs);
tp=0; used=false(size(rd));
for k=1:numel(rTrue)
    j = find(~used & abs(rd - rTrue(k)) <= tol, 1, 'first');
    if ~isempty(j), tp=tp+1; used(j)=true; end
end
fp = sum(~used); fn = numel(rTrue)-tp;
prec = tp / max(tp+fp,1); rec = tp / max(tp+fn,1);
f1 = 2*prec*rec / max(prec+rec,eps);
fprintf('TP=%d FP=%d FN=%d | P=%.3f R=%.3f F1=%.3f\n', tp, fp, fn, prec, rec, f1);
assert(prec>=0.85,'Precision < 0.85'); assert(rec>=0.85,'Recall < 0.85'); assert(f1>=0.85,'F1 < 0.85');
