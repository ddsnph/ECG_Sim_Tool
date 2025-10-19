% ECG_Sim_Tool.m
% ECG simulator with GUI, validation, preferences, RNG control, 50/60 Hz notch,
% adaptive detection, exports, shortcuts, and resizable layout.
% Run: ECG_Sim_Tool

function ECG_Sim_Tool
    % ---- Config / paths ----
    addpath('ecg'); if exist('scripts','dir'), addpath('scripts'); end
    verTag = 'v1.2.0';

    % ---- Load persisted preferences ----
    P = load_prefs();
    sampleRate   = 360;                      % fixed for GUI demo
    durationSec  = P.durationSec;            % seconds
    heartRateBpm = P.heartRateBpm;           % bpm
    noise        = P.noise;                  % struct: baseline/emg/hum (mV)
    useFilters   = P.useFilters;
    injectPVC    = P.injectPVC;
    useAF_RR     = P.useAF_RR;
    mainsHz      = P.mainsHz;                % 50 or 60
    rngLock      = P.rngLock;                % logical
    rngSeed      = P.rngSeed;                % integer

    % ---- Figure and axes ----
    h.fig = figure('Name',sprintf('ECG Simulation Tool %s',verTag),'NumberTitle','off', ...
        'Color','w','Units','normalized','Position',[0.08 0.06 0.82 0.84], ...
        'Resize','on','WindowKeyPressFcn',@keyHandler, 'CloseRequestFcn',@onClose);

    h.axRaw  = subplot(3,1,1,'Parent',h.fig);  title(h.axRaw,'Raw ECG');       ylabel(h.axRaw,'mV'); grid(h.axRaw,'on');
    h.axFilt = subplot(3,1,2,'Parent',h.fig);  title(h.axFilt,'Filtered ECG'); ylabel(h.axFilt,'mV'); grid(h.axFilt,'on');
    h.axRR   = subplot(3,1,3,'Parent',h.fig);  title(h.axRR,'RR / HR');        ylabel(h.axRR,'ms / bpm'); xlabel(h.axRR,'Time (s)'); grid(h.axRR,'on');

    % ---- Control panel ----
    h.panel = uipanel('Parent',h.fig,'Title','Controls','FontWeight','bold', ...
        'Units','normalized','Position',[0.85 0.02 0.14 0.96]);

    % HR
    uicontrol(h.panel,'Style','text','String','Heart Rate (bpm)','Units','normalized','Position',[0.08 0.93 0.84 0.04]);
    h.hrSlider = uicontrol(h.panel,'Style','slider','Min',30,'Max',180,'Value',heartRateBpm, ...
        'Units','normalized','Position',[0.08 0.90 0.84 0.03],'Callback',@(~,~)updatePlots);
    h.hrText = uicontrol(h.panel,'Style','text','Units','normalized','Position',[0.08 0.865 0.84 0.03], ...
        'String',num2str(heartRateBpm));

    % Duration
    uicontrol(h.panel,'Style','text','String','Duration (s)','Units','normalized','Position',[0.08 0.83 0.84 0.03]);
    h.durationEdit = uicontrol(h.panel,'Style','edit','String',num2str(durationSec), ...
        'Units','normalized','Position',[0.08 0.80 0.84 0.035],'Callback',@(~,~)updatePlots);

    % Noise
    uicontrol(h.panel,'Style','text','String','Baseline (mV)','Units','normalized','Position',[0.08 0.76 0.84 0.03]);
    h.baselineSlider = uicontrol(h.panel,'Style','slider','Min',0,'Max',2,'Value',noise.baseline, ...
        'Units','normalized','Position',[0.08 0.735 0.84 0.025],'Callback',@(~,~)updatePlots);

    uicontrol(h.panel,'Style','text','String','EMG (mV rms)','Units','normalized','Position',[0.08 0.70 0.84 0.03]);
    h.emgSlider = uicontrol(h.panel,'Style','slider','Min',0,'Max',2,'Value',noise.emg, ...
        'Units','normalized','Position',[0.08 0.675 0.84 0.025],'Callback',@(~,~)updatePlots);

    uicontrol(h.panel,'Style','text','String','Hum (mV)','Units','normalized','Position',[0.08 0.64 0.84 0.03]);
    h.humSlider = uicontrol(h.panel,'Style','slider','Min',0,'Max',2,'Value',noise.hum, ...
        'Units','normalized','Position',[0.08 0.615 0.84 0.025],'Callback',@(~,~)updatePlots);

    % Toggles
    h.cbFilters = uicontrol(h.panel,'Style','checkbox','String','Apply Filters','Value',useFilters, ...
        'Units','normalized','Position',[0.08 0.585 0.84 0.03],'Callback',@(~,~)updatePlots);
    h.cbPVC = uicontrol(h.panel,'Style','checkbox','String','Inject PVCs','Value',injectPVC, ...
        'Units','normalized','Position',[0.08 0.555 0.84 0.03],'Callback',@(~,~)updatePlots);
    h.cbAF = uicontrol(h.panel,'Style','checkbox','String','AF-like RR','Value',useAF_RR, ...
        'Units','normalized','Position',[0.08 0.525 0.84 0.03],'Callback',@(~,~)updatePlots);

    % Mains notch (50/60/None)
    uicontrol(h.panel,'Style','text','String','Mains (Hz)','Units','normalized','Position',[0.08 0.49 0.84 0.03]);
    h.mainsMenu = uicontrol(h.panel,'Style','popupmenu','String',{'60','50','None'}, ...
        'Value', mains_to_index(mainsHz), 'Units','normalized','Position',[0.08 0.465 0.84 0.035], ...
        'Callback',@(~,~)updatePlots);

    % RNG lock and seed
    h.cbRng = uicontrol(h.panel,'Style','checkbox','String','Lock RNG','Value',rngLock, ...
        'Units','normalized','Position',[0.08 0.43 0.84 0.03],'Callback',@(~,~)updatePlots);
    uicontrol(h.panel,'Style','text','String','Seed','Units','normalized','Position',[0.08 0.405 0.3 0.025]);
    h.seedEdit = uicontrol(h.panel,'Style','edit','String',num2str(rngSeed), ...
        'Units','normalized','Position',[0.4 0.403 0.52 0.03],'Callback',@(~,~)updatePlots);

    % Buttons
    uicontrol(h.panel,'Style','pushbutton','String','Regenerate','Units','normalized','Position',[0.08 0.36 0.84 0.04], ...
        'Callback',@(~,~)updatePlots);
    uicontrol(h.panel,'Style','pushbutton','String','Export CSV (signals)','Units','normalized','Position',[0.08 0.315 0.84 0.04], ...
        'Callback',@(~,~)exportSignals);
    uicontrol(h.panel,'Style','pushbutton','String','Export RR & Metrics','Units','normalized','Position',[0.08 0.27 0.84 0.04], ...
        'Callback',@(~,~)exportRR);
    uicontrol(h.panel,'Style','pushbutton','String','Save Figure','Units','normalized','Position',[0.08 0.225 0.84 0.04], ...
        'Callback',@(~,~)saveFigure);
    uicontrol(h.panel,'Style','pushbutton','String','About','Units','normalized','Position',[0.08 0.18 0.84 0.04], ...
        'Callback',@(~,~)aboutDialog);

    % Status
    h.status = uicontrol(h.panel,'Style','text','String','Ready','ForegroundColor',[0 0.4 0], ...
        'HorizontalAlignment','left','Units','normalized','Position',[0.08 0.02 0.84 0.15]);

    % Initial render
    updatePlots();

    % =================== Callbacks ===================
    function updatePlots
        heartRateBpm = round(get(h.hrSlider,'Value')); set(h.hrText,'String',num2str(heartRateBpm));
        dIn = str2double(get(h.durationEdit,'String'));
        if ~isfinite(dIn) || dIn < 5 || dIn > 600, errordlg('Duration must be 5–600 s.','Invalid'); return; end
        durationSec = dIn;

        noise.baseline = clamp(get(h.baselineSlider,'Value'),0,5);
        noise.emg      = clamp(get(h.emgSlider,'Value'),0,5);
        noise.hum      = clamp(get(h.humSlider,'Value'),0,5);

        useFilters = logical(get(h.cbFilters,'Value'));
        injectPVC  = logical(get(h.cbPVC,'Value'));
        useAF_RR   = logical(get(h.cbAF,'Value'));

        % Map popup index -> mains Hz
        mainsSel = get(h.mainsMenu,'Value');
        mainsHz  = index_to_mains(mainsSel);

        rngLock = logical(get(h.cbRng,'Value'));
        sIn = str2double(get(h.seedEdit,'String')); if ~isfinite(sIn), sIn = 0; end
        rngSeed = round(sIn);
        if rngLock, rng(rngSeed,'twister'); end

        % Generate, noise, filter
        [t, ecgClean, rTruthIdx] = ecg_generate(sampleRate, durationSec, heartRateBpm, injectPVC, useAF_RR);
        ecgNoisy = ecg_add_noise(ecgClean, sampleRate, noise);
        ecgShown = ecgNoisy;
        if useFilters, ecgShown = ecg_filter(ecgNoisy, sampleRate, mainsHz); end

        % Detect
        [rDetIdx, rDetAmp] = ecg_detect_rpeaks(ecgShown, sampleRate, struct('Method','adaptive'));

        % RR/HR
        rrSec  = diff(t(rDetIdx));
        rrTime = t(rDetIdx(2:end));
        hrInst = 60 ./ rrSec;

        % Plots
        axes(h.axRaw); cla(h.axRaw);
        plot(t, ecgNoisy, 'k'); hold on;
        if ~isempty(rTruthIdx), plot(t(rTruthIdx), ecgNoisy(rTruthIdx), 'go'); end
        ylabel('mV'); title('Raw ECG'); grid on;

        axes(h.axFilt); cla(h.axFilt);
        plot(t, ecgShown, 'b'); hold on;
        if ~isempty(rDetIdx), plot(t(rDetIdx), rDetAmp, 'ro'); end
        ylabel('mV'); title('Filtered ECG + R-peaks'); grid on;

        axes(h.axRR); cla(h.axRR);
        yyaxis left;  plot(rrTime, rrSec*1000, '-'); ylabel('RR (ms)');
        yyaxis right; plot(rrTime, hrInst, '-');     ylabel('HR (bpm)');
        xlabel('Time (s)'); title('RR / HR'); grid on;

        % Status
        if ~isempty(rrSec)
            sdnnMs  = std(rrSec) * 1000;
            rmssdMs = sqrt(mean(diff(rrSec).^2)) * 1000;
            meanHr  = mean(hrInst,'omitnan');
            set(h.status,'String',sprintf('HR mean: %.1f bpm\nSDNN: %.1f ms\nRMSSD: %.1f ms\nNotch: %d Hz\nRNG: %s (seed %d)', ...
                 meanHr, sdnnMs, rmssdMs, mainsHz, yesno(rngLock), rngSeed), ...
                 'ForegroundColor',[0 0.4 0]);
        else
            set(h.status,'String','No beats detected. Adjust HR, noise, or filters.', ...
                'ForegroundColor',[0.6 0 0]);
        end
    end

    function exportSignals
        [fn, pn] = uiputfile('ecg_signals.csv','Save CSV'); if isequal(fn,0), return, end
        heartRateBpm = round(get(h.hrSlider,'Value'));
        durationSec  = clamp(str2double(get(h.durationEdit,'String')),5,600);
        noise.baseline = clamp(get(h.baselineSlider,'Value'),0,5);
        noise.emg      = clamp(get(h.emgSlider,'Value'),0,5);
        noise.hum      = clamp(get(h.humSlider,'Value'),0,5);
        useFilters = logical(get(h.cbFilters,'Value'));
        injectPVC  = logical(get(h.cbPVC,'Value'));
        useAF_RR   = logical(get(h.cbAF,'Value'));
        mainsHz    = index_to_mains(get(h.mainsMenu,'Value'));

        if rngLock, rng(rngSeed,'twister'); end
        [t, clean, ~] = ecg_generate(sampleRate, durationSec, heartRateBpm, injectPVC, useAF_RR);
        noisy = ecg_add_noise(clean, sampleRate, noise);
        shown = noisy; if useFilters, shown = ecg_filter(noisy, sampleRate, mainsHz); end

        T = table(t(:), clean(:), noisy(:), shown(:), ...
            'VariableNames', {'time_s','clean','noisy','filtered'});
        writetable(T, fullfile(pn, fn));
    end

    function exportRR
        [fn, pn] = uiputfile('ecg_rr_metrics.csv','Save RR & Metrics'); if isequal(fn,0), return, end
        heartRateBpm = round(get(h.hrSlider,'Value'));
        durationSec  = clamp(str2double(get(h.durationEdit,'String')),5,600);
        noise.baseline = clamp(get(h.baselineSlider,'Value'),0,5);
        noise.emg      = clamp(get(h.emgSlider,'Value'),0,5);
        noise.hum      = clamp(get(h.humSlider,'Value'),0,5);
        useFilters = logical(get(h.cbFilters,'Value'));
        injectPVC  = logical(get(h.cbPVC,'Value'));
        useAF_RR   = logical(get(h.cbAF,'Value'));
        mainsHz    = index_to_mains(get(h.mainsMenu,'Value'));

        if rngLock, rng(rngSeed,'twister'); end
        [t, clean, rTruthIdx] = ecg_generate(sampleRate, durationSec, heartRateBpm, injectPVC, useAF_RR);
        noisy = ecg_add_noise(clean, sampleRate, noise);
        shown = noisy; if useFilters, shown = ecg_filter(noisy, sampleRate, mainsHz); end
        [rDetIdx, ~] = ecg_detect_rpeaks(shown, sampleRate, struct('Method','adaptive'));

        rrDetSec  = diff(t(rDetIdx));
        rrDetTime = t(rDetIdx(2:end));

        metrics = table;
        metrics.param_fs       = sampleRate;
        metrics.param_duration = durationSec;
        metrics.param_hr_set   = heartRateBpm;
        metrics.param_mainsHz  = mainsHz;
        metrics.param_noise_baseline = noise.baseline;
        metrics.param_noise_emg      = noise.emg;
        metrics.param_noise_hum      = noise.hum;

        if ~isempty(rrDetSec)
            metrics.hr_mean  = mean(60 ./ rrDetSec);
            metrics.sdnn_ms  = std(rrDetSec) * 1000;
            metrics.rmssd_ms = sqrt(mean(diff(rrDetSec).^2)) * 1000;
        else
            metrics.hr_mean = NaN; metrics.sdnn_ms = NaN; metrics.rmssd_ms = NaN;
        end

        writetable(table(rrDetTime(:), rrDetSec(:), 'VariableNames', {'t_s','rr_s'}), fullfile(pn, fn));

        [pth, base, ~] = fileparts(fullfile(pn, fn));
        writetable(metrics, fullfile(pth, sprintf('%s_summary.csv', base)));
        idxTab = table(rTruthIdx(:), rDetIdx(:), 'VariableNames', {'r_true_idx','r_detect_idx'});
        writetable(idxTab, fullfile(pth, sprintf('%s_indices.csv', base)));
    end

    function saveFigure
        [fn, pn] = uiputfile('ecg_figure.png','Save Figure'); if isequal(fn,0), return, end
        exportgraphics(h.fig, fullfile(pn, fn), 'Resolution', 200);
    end

    function aboutDialog
        txt = sprintf(['ECG Simulation Tool %s\n',...
                       'Keys: R=Regenerate, E=Export signals, S=Save fig, Q=Quit\n',...
                       'Notch: 50/60 Hz selectable. RNG lock for reproducibility.\n',...
                       'Exports include signals, RR intervals, and summary metrics.\n'], verTag);
        helpdlg(txt,'About');
    end

    function keyHandler(~,evt)
        if ~isfield(evt,'Key'), return, end
        switch lower(evt.Key)
            case 'r', updatePlots();
            case 'e', exportSignals();
            case 's', saveFigure();
            case 'q', onClose();
        end
    end

    function onClose(~,~)
        % Persist preferences
        P.durationSec  = clamp(str2double(get(h.durationEdit,'String')),5,600);
        P.heartRateBpm = round(get(h.hrSlider,'Value'));
        P.noise = struct('baseline',get(h.baselineSlider,'Value'), ...
                         'emg',get(h.emgSlider,'Value'), ...
                         'hum',get(h.humSlider,'Value'));
        P.useFilters = logical(get(h.cbFilters,'Value'));
        P.injectPVC  = logical(get(h.cbPVC,'Value'));
        P.useAF_RR   = logical(get(h.cbAF,'Value'));
        P.mainsHz    = index_to_mains(get(h.mainsMenu,'Value'));
        P.rngLock    = logical(get(h.cbRng,'Value'));
        sIn = str2double(get(h.seedEdit,'String')); if ~isfinite(sIn), sIn = 0; end
        P.rngSeed    = round(sIn);
        save_prefs(P);
        delete(h.fig);
    end
end

% ---- Helpers: prefs, mapping, validation ----
function out = load_prefs()
    f = fullfile(prefdir,'ECG_Sim_Tool_prefs.mat');
    if exist(f,'file')
        S = load(f);
        if isfield(S,'P'), out = S.P; return; end
    end
    out = struct('durationSec',20,'heartRateBpm',70, ...
                 'noise',struct('baseline',0,'emg',0,'hum',0), ...
                 'useFilters',true,'injectPVC',false,'useAF_RR',false, ...
                 'mainsHz',60,'rngLock',false,'rngSeed',0);
end

function save_prefs(P)
    f = fullfile(prefdir,'ECG_Sim_Tool_prefs.mat');
    try, save(f,'P'); catch, end
end

function idx = mains_to_index(mainsHz)
    % Map Hz to popup index
    if mainsHz==60, idx=1; elseif mainsHz==50, idx=2; else, idx=3; end
end

function hz = index_to_mains(idx)
    % Map popup index to Hz
    switch idx
        case 1, hz = 60;
        case 2, hz = 50;
        otherwise, hz = 0;
    end
end

function y = clamp(x,lo,hi)
    if ~isfinite(x), x = lo; end
    y = min(max(x,lo),hi);
end

function s = yesno(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
