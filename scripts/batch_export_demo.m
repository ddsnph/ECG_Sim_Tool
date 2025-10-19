% scripts/batch_export_demo.m — batch cases with RR & metrics export
addpath('ecg'); rng(0,'twister');

outDir = fullfile(pwd,'exports'); if ~exist(outDir,'dir'), mkdir(outDir); end
cases = [
    struct('fs',360,'dur',20,'hr',70,'pvc',false,'af',false,'noise',struct('baseline',0.1,'emg',0.1,'hum',0.0),'mains',60)
    struct('fs',360,'dur',20,'hr',90,'pvc',true, 'af',false,'noise',struct('baseline',0.2,'emg',0.2,'hum',0.1),'mains',60)
    struct('fs',360,'dur',30,'hr',75,'pvc',false,'af',true, 'noise',struct('baseline',0.2,'emg',0.15,'hum',0.05),'mains',50)
];

for i = 1:numel(cases)
    C = cases(i);
    [t, clean, ~] = ecg_generate(C.fs, C.dur, C.hr, C.pvc, C.af);
    noisy = ecg_add_noise(clean, C.fs, C.noise);
    filt  = ecg_filter(noisy, C.fs, C.mains);
    [rd, ~] = ecg_detect_rpeaks(filt, C.fs, struct('Method','adaptive'));

    T = table(t(:), clean(:), noisy(:), filt(:), 'VariableNames',{'time_s','clean','noisy','filtered'});
    fn = sprintf('case_%02d_fs%d_dur%d_hr%d', i, C.fs, C.dur, C.hr);
    writetable(T, fullfile(outDir, fn + "_signals.csv"));

    rr  = diff(t(rd)); rrt = t(rd(2:end));
    S = table(rrt(:), rr(:), 'VariableNames',{'t_s','rr_s'});
    writetable(S, fullfile(outDir, fn + "_rr.csv"));

    M = table(C.fs, C.dur, C.hr, C.mains, mean(60./rr), std(rr)*1000, sqrt(mean(diff(rr).^2))*1000,...
        'VariableNames', {'fs','dur_s','hr_set','mains_hz','hr_mean','sdnn_ms','rmssd_ms'});
    writetable(M, fullfile(outDir, fn + "_summary.csv"));
end
disp('Batch export complete.');
