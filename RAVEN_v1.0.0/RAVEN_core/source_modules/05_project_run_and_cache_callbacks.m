    function onSaveConfig(~,~)
        syncCfgFromUI();
        [f,p] = uiputfile('*.mat','Save config MAT',fullfile(app.cfg.io.saveBaseDir,'RAVEN_config.mat'));
        if isequal(f,0), return; end
        cfg = app.cfg;
        save(fullfile(p,f),'cfg');
        logmsg(['Saved config: ' fullfile(p,f)]);
    end

    function onSaveProject(~,~)
        syncCfgFromUI();
        proj = struct();
        proj.cfg = app.cfg;
        proj.selectedFiles = app.state.selectedFiles;
        proj.detectedSource = app.state.detectedSource;
        proj.savedAt = datestr(now,'yyyy-mm-dd HH:MM:SS');
        proj.version = 'RAVEN_V1_01';
        [f,p] = uiputfile('*.mat','Save RAVEN project',fullfile(app.cfg.io.saveBaseDir,[app.cfg.io.rootName '_PROJECT.mat']));
        if isequal(f,0), return; end
        save(fullfile(p,f),'proj');
        logmsg(['Saved project: ' fullfile(p,f)]);
    end

    function onLoadProject(~,~)
        [f,p] = uigetfile('*.mat','Load RAVEN project',app.cfg.io.saveBaseDir);
        if isequal(f,0), return; end
        S = load(fullfile(p,f));
        if ~isfield(S,'proj') || ~isstruct(S.proj) || ~isfield(S.proj,'cfg')
            errordlg('Selected MAT file is not a valid RAVEN project.','RAVEN');
            return;
        end
        proj = S.proj;
        app.cfg = proj.cfg;
        if isfield(proj,'selectedFiles') && ~isempty(proj.selectedFiles)
            app.state.selectedFiles = proj.selectedFiles;
        else
            app.state.selectedFiles = {};
        end
        if isfield(proj,'detectedSource'), app.state.detectedSource = proj.detectedSource; end
        set(app.ui.edData,'String',app.cfg.io.dataSource);
        set(app.ui.edSave,'String',app.cfg.io.saveBaseDir);
        set(app.ui.edRoot,'String',app.cfg.io.rootName);
        set(app.ui.chkAutoDetect,'Value',double(app.cfg.io.autoDetectGroups));
        set(app.ui.chkParallel,'Value',double(app.cfg.cv.useParallel));
        if isfield(app.ui,'popWorkers') && ishandle(app.ui.popWorkers)
            vals = get(app.ui.popWorkers,'String');
            idx = find(strcmp(vals, num2str(max(1,app.cfg.cv.nWorkers))),1);
            if isempty(idx), idx = 1; end
            set(app.ui.popWorkers,'Value',idx);
        end
        updateUploadedFilesList();
        if ~isempty(strtrim(app.cfg.io.dataSource))
            try
                detectDatasetNow(false);
            catch MEP
                logmsg(['Project loaded; pre-detection warning: ' MEP.message]);
            end
        else
            refreshPlan();
        end
        logmsg(['Loaded project: ' fullfile(p,f)]);
    end

    function onClassManager(~,~)
        if isempty(app.state.detectedData)
            try
                detectDatasetNow(false);
            catch
            end
        end
        if isempty(app.state.detectedData)
            warndlg('Load or detect a dataset first.','RAVEN');
            return;
        end
        data = app.state.detectedData;
        names = data.groupNames(:);
        counts = cellfun(@(b) size(b,2)-1, data.blocks(:));
        curSel = getSelectedNamesForValidation(names');
        if isempty(curSel), curSel = names'; end
        sc = get(0,'ScreenSize');
        fw = min(560, sc(3)-120); fh = min(520, sc(4)-140);
        fx = round((sc(3)-fw)/2); fy = round((sc(4)-fh)/2);
        f = figure('Name','RAVEN | Class Manager','NumberTitle','off','MenuBar','none','ToolBar','none', ...
            'Color',[0 0 0],'Position',[fx fy fw fh],'Resize','off');
        pnl = uipanel(f,'Units','normalized','Position',[0.03 0.12 0.94 0.84], ...
            'Title','Select classes for pipeline','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        n = numel(names);
        listStr = cell(n,1);
        for ii=1:n
            listStr{ii} = sprintf('%02d  %-20s (n=%d)',ii,names{ii},counts(ii));
        end
        selectedIdx = find(ismember(names, curSel));
        if isempty(selectedIdx), selectedIdx = 1:n; end
        lst = uicontrol(pnl,'Style','listbox','Units','normalized','Position',[0.03 0.10 0.94 0.85], ...
            'String',listStr,'Value',selectedIdx,'Min',0,'Max',2, ...
            'BackgroundColor',[0.03 0.03 0.03],'ForegroundColor',[0.95 0.95 0.95], ...
            'FontName','Consolas','FontSize',10);
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.03 0.03 0.20 0.06], ...
            'String','Select All','Callback',@(s,e)set(lst,'Value',1:n));
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.25 0.03 0.20 0.06], ...
            'String','Clear All','Callback',@(s,e)set(lst,'Value',[]));
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.57 0.03 0.18 0.06], ...
            'String','Apply','FontWeight','bold','Callback',@applyClassSel);
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.78 0.03 0.18 0.06], ...
            'String','Close','Callback',@(s,e)close(f));
        function applyClassSel(~,~)
            idx = get(lst,'Value');
            if isempty(idx)
                errordlg('Select at least one class.','RAVEN');
                return;
            end
            app.cfg.preproc.includeNames = names(idx)';
            refreshPlan();
            logmsg(sprintf('Class Manager saved %d selected class(es).', numel(idx)));
            close(f);
        end
    end

    function onResultsNavigator(~,~)
        syncCfgFromUI();
        outdir = fullfile(app.cfg.io.saveBaseDir, app.cfg.io.rootName);
        if ~exist(outdir,'dir')
            warndlg('Output folder does not exist yet.','RAVEN');
            return;
        end
        items = {};
        labels = {};
        cand = {outdir,'Project folder'; ...
            fullfile(outdir,'STEP0_PREPROC'),'Step 0 folder'; ...
            fullfile(outdir,'STEP1_EMBEDDING'),'Step 1 folder'; ...
            fullfile(outdir,'STEP2_LOCALIZATION'),'Step 2 folder'; ...
            fullfile(outdir,'STEP3_LOCALAPPROX'),'Step 3 folder'; ...
            fullfile(outdir,'STEP4_FINAL'),'Step 4 folder'; ...
            fullfile(outdir,'STEP0_PREPROC','PREPROCESSED_DATA.mat'),'Preprocessed data'; ...
            fullfile(outdir,'STEP0_PREPROC','SPLIT_SUMMARY.xlsx'),'Split summary'; ...
            fullfile(outdir,'STEP0_PREPROC','DATA_DISPOSITION.xlsx'),'Data disposition'; ...
            fullfile(outdir,'STEP1_EMBEDDING','STEP1_RESULTS.xlsx'),'Step 1 Excel'; ...
            fullfile(outdir,'STEP2_LOCALIZATION','STEP2_RESULTS.xlsx'),'Step 2 Excel'; ...
            fullfile(outdir,'STEP3_LOCALAPPROX','STEP3_RESULTS.xlsx'),'Step 3 Excel'; ...
            fullfile(outdir,'STEP4_FINAL','STEP4_SELECTION_SUMMARY.xlsx'),'Step 4 Excel'; ...
            fullfile(outdir,'RUN_MANIFEST.txt'),'Run manifest'; ...
            fullfile(outdir,'STEP4_FINAL','FINAL_WINNER_BLIND_MODEL.mat'),'Final blind model'; ...
            fullfile(outdir,'STEP4_FINAL','BestAccuracy_BLIND_MODEL.mat'),'Best-accuracy blind model'};
        for ii=1:size(cand,1)
            if exist(cand{ii,1},'file') || exist(cand{ii,1},'dir')
                items{end+1} = cand{ii,1};
                labels{end+1} = sprintf('%-22s  %s', cand{ii,2}, strrep(cand{ii,1}, outdir, '.'));
            end
        end
        if isempty(items)
            warndlg('No saved result items were found yet.','RAVEN');
            return;
        end
        sc = get(0,'ScreenSize'); fw=min(760,sc(3)-120); fh=min(500,sc(4)-160);
        fx=round((sc(3)-fw)/2); fy=round((sc(4)-fh)/2);
        f = figure('Name','RAVEN | Results Navigator','NumberTitle','off','MenuBar','none','ToolBar','none', ...
            'Color',[0 0 0],'Position',[fx fy fw fh],'Resize','off');
        pnl = uipanel(f,'Units','normalized','Position',[0.03 0.14 0.94 0.83], ...
            'Title','Saved results','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        lst = uicontrol(pnl,'Style','listbox','Units','normalized','Position',[0.02 0.04 0.96 0.93], ...
            'String',labels,'Value',1,'BackgroundColor',[0.03 0.03 0.03], ...
            'ForegroundColor',[0.95 0.95 0.95],'FontName','Consolas','Max',1,'Min',0);
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.12 0.03 0.20 0.07], ...
            'String','Open Selected','FontWeight','bold','Callback',@openSelected);
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.40 0.03 0.20 0.07], ...
            'String','Open Folder','Callback',@(s,e)openPath(outdir));
        uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.68 0.03 0.20 0.07], ...
            'String','Close','Callback',@(s,e)close(f));
        function openSelected(~,~)
            idx = get(lst,'Value');
            if isempty(idx) || idx<1 || idx>numel(items), return; end
            openPath(items{idx});
        end
    end

    function openPath(pth)
        try
            if ispc
                winopen(pth);
            elseif ismac
                system(['open ' char(34) pth char(34)]);
            else
                system(['xdg-open ' char(34) pth char(34) ' &']);
            end
        catch
            logmsg(['Path: ' pth]);
        end
    end

    function onOpenOutput(~,~)
        syncCfgFromUI();
        outdir = fullfile(app.cfg.io.saveBaseDir, app.cfg.io.rootName);
        if ~exist(outdir,'dir')
            warndlg('Output folder does not exist yet.','RAVEN');
            return;
        end
        try
            if ispc
                winopen(outdir);
            elseif ismac
                system(['open ' char(34) outdir char(34)]);
            else
                system(['xdg-open ' char(34) outdir char(34) ' &']);
            end
        catch
            logmsg(['Output folder: ' outdir]);
        end
    end

    function onPause(~,~)
        if ~app.state.isRunning
            return;
        end
        app.state.isPaused = ~app.state.isPaused;
        if app.state.isPaused
            set(app.ui.btnPause,'String','Resume');
            setStatus('Paused');
            logmsg('Paused.');
        else
            set(app.ui.btnPause,'String','Pause');
            setStatus('Running');
            logmsg('Resumed.');
        end
    end

    function onStop(~,~)
        if ~app.state.isRunning
            return;
        end
        app.state.stopRequested = true;
        logmsg('Stop requested. Waiting for safe boundary...');
    end

    function onRun(~,~)
        if app.state.isRunning
            warndlg('Pipeline is already running.','RAVEN');
            return;
        end
        syncCfgFromUI();
        refreshPlan();
        app.state.isRunning = true;
        app.state.isPaused = false;
        app.state.stopRequested = false;
        app.state.runTic = tic;
        app.state.cache = struct('folds',struct(),'pca',struct(),'teacher',struct(),'preprocess',struct());
        app.state.timing = struct();
        set(app.ui.btnPause,'String','Pause');
        setStatus('Running');
        setError('none');
        initActionProgressTracking();
        refreshLiveStatusContext();
        drawnow;

        try
            if app.cfg.cv.useParallel
                try
                    p = gcp('nocreate');
                    if isempty(p) || p.NumWorkers ~= app.cfg.cv.nWorkers
                        if ~isempty(p), delete(p); end
                        parpool(app.cfg.cv.nWorkers);
                    end
                    logmsg(sprintf('Parallel pool ready: %d workers.', app.cfg.cv.nWorkers));
                catch MEp
                    logmsg(['Parallel setup failed. Continuing serially. ' MEp.message]);
                    app.cfg.cv.useParallel = false;
                end
            end

            prepareOutput();
            checkPauseStop();
            runTimedStep('step0_load_preprocess', @step0_load_preprocess);
            if isfield(app.cfg.runtime,'exportSplitSummary') && app.cfg.runtime.exportSplitSummary
                exportSplitSummary(app.state.outdir);
            end
            checkPauseStop();
            runTimedStep('step1_search_embedding', @step1_search_embedding);
            checkPauseStop();
            runTimedStep('step2_search_localization', @step2_search_localization);
            checkPauseStop();
            runTimedStep('step3_search_local_approx', @step3_search_local_approx);
            checkPauseStop();
            runTimedStep('step4_final_confirmation', @step4_final_confirmation);
            if isfield(app.cfg.runtime,'runBenchmarks') && app.cfg.runtime.runBenchmarks
                checkPauseStop();
                runTimedStep('benchmark_integration', @runBenchmarkSuite);
            end
            exportTimingReport();
            if isfield(app.cfg.runtime,'saveRunManifest') && app.cfg.runtime.saveRunManifest
                saveRunManifest(app.state.outdir);
            end
            if isfield(app.cfg.runtime,'exportMasterReport') && app.cfg.runtime.exportMasterReport
                exportReportingConsolidation(app.state.outdir);
            end
            finalizeActionProgress();
            setStep('Completed');
            setStatus(sprintf('Finished in %.2f s', toc(app.state.runTic)));
            logmsg(sprintf('Pipeline finished in %.2f s.', toc(app.state.runTic)));
            refreshLiveStatusContext();
        catch ME
            setError(ME.message);
            setStatus('Stopped with error');
            logmsg(getReport(ME,'extended','hyperlinks','off'));
            writeErrorTxt(ME,'Pipeline');
            refreshLiveStatusContext();
        end

        app.state.isRunning = false;
        app.state.isPaused = false;
        app.state.stopRequested = false;
        set(app.ui.btnPause,'String','Pause');
    end

    function runTimedStep(stepName, funHandle)
        t0 = tic;
        funHandle();
        dt = toc(t0);
        app.state.timing.(matlab.lang.makeValidName(stepName)) = dt;
        if isfield(app.cfg,'runtime') && isfield(app.cfg.runtime,'verboseTiming') && app.cfg.runtime.verboseTiming
            logmsg(sprintf('Timing | %s = %.3f s', stepName, dt));
        end
    end

    function exportTimingReport()
        if ~isfield(app.state,'timing') || isempty(app.state.timing)
            return;
        end
        fn = fieldnames(app.state.timing);
        sec = zeros(numel(fn),1);
        for ii = 1:numel(fn)
            sec(ii) = app.state.timing.(fn{ii});
        end
        Ttime = table(fn, sec, 100*sec/max(eps,sum(sec)), 'VariableNames', {'Step','WallSec','PctTotal'});
        tryWriteTable(Ttime, fullfile(app.state.outdir,'TIMING_REPORT.xlsx'),'Timing');
        try
            fid = fopen(fullfile(app.state.outdir,'TIMING_REPORT.txt'),'w');
            if fid > 0
                fprintf(fid, 'RAVEN timing report\n');
                fprintf(fid, 'Total wall time: %.6f s\n\n', toc(app.state.runTic));
                for ii = 1:height(Ttime)
                    fprintf(fid, '%s : %.6f s (%.2f%%%%)\n', Ttime.Step{ii}, Ttime.WallSec(ii), Ttime.PctTotal(ii));
                end
                fclose(fid);
            end
        catch
        end
    end

    function foldIdx = getCachedFoldIdx(y, K, rr, seedBase, cacheTag)
        if nargin < 5 || isempty(cacheTag)
            cacheTag = 'default';
        end
        key = matlab.lang.makeValidName(sprintf('fold_%s_N%d_K%d_rr%d_seed%d', cacheTag, numel(y), K, rr, seedBase));
        if isfield(app,'state') && isfield(app.state,'cache') && isfield(app.state.cache,'folds') && isfield(app.state.cache.folds,key)
            foldIdx = app.state.cache.folds.(key);
            return;
        end
        rng(seedBase + rr, 'twister');
        groupIDs = getCurrentGroupVector(numel(y));
        foldIdx = makeFolds(y, K, groupIDs, app.cfg.cv.splitMode);
        app.state.cache.folds.(key) = foldIdx;
    end

    function [Str, Ste, ytr, yte, pcaObj] = getCachedFoldPCA(X, y, foldIdx, f, kPC, cacheTag)
        if nargin < 6 || isempty(cacheTag)
            cacheTag = 'default';
        end
        tr = ~ (foldIdx == f);
        te = (foldIdx == f);
        key = matlab.lang.makeValidName(sprintf('pca_%s_N%d_D%d_fold%d_k%d_ntr%d', cacheTag, size(X,1), size(X,2), f, kPC, sum(tr)));
        if isfield(app.state.cache.pca, key)
            obj = app.state.cache.pca.(key);
            Str = obj.Str; Ste = obj.Ste; ytr = y(tr); yte = y(te); pcaObj = obj;
            return;
        end
        Xtr = X(tr,:); Xte = X(te,:); ytr = y(tr); yte = y(te);
        mu = mean(Xtr,1);
        Xtrc = bsxfun(@minus, Xtr, mu);
        Xtec = bsxfun(@minus, Xte, mu);
        kEff = min([kPC, size(Xtrc,1)-1, size(Xtrc,2)]);
        if kEff < 1, kEff = 1; end
        [coeff, scoreTr] = pca(Xtrc, 'NumComponents', kEff, 'Centered', false);
        Str = scoreTr(:,1:kEff);
        Ste = Xtec * coeff(:,1:kEff);
        pcaObj = struct('mu',mu,'coeff',coeff(:,1:kEff),'kEff',kEff,'Str',Str,'Ste',Ste);
        app.state.cache.pca.(key) = pcaObj;
    end

    function art = getCachedTeacherFoldArtifacts(X, y, C, foldIdx, f, teacherCfg, seedBase, rr)
        key = matlab.lang.makeValidName(sprintf('teacher_k%d_m%d_r%d_s%.9g_c%.9g_fold%d_rr%d_seed%d', ...
            teacherCfg.kPC, teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, f, rr, seedBase));
        if isfield(app.state.cache.teacher, key)
            art = app.state.cache.teacher.(key);
            return;
        end
        [Str, Ste, ytr, yte] = getCachedFoldPCA(X, y, foldIdx, f, teacherCfg.kPC, sprintf('teacher_seed%d_rr%d', seedBase, rr));
        mdlT = fitRavenTeacher(Str, ytr, teacherCfg, C);
        [yhatT, scoreTe, predMsT, memT] = predictRavenTeacher(mdlT, Ste);
        temp2 = 1.0;
        art = struct();
        art.Str = Str;
        art.Ste = Ste;
        art.ytr = ytr;
        art.yte = yte;
        art.mdlT = mdlT;
        art.yhatT = yhatT;
        art.scoreTe = scoreTe;
        art.predMsT = predMsT;
        art.memT = memT;
        app.state.cache.teacher.(key) = art;
    end

    function prepareOutput()
        outdir = fullfile(app.cfg.io.saveBaseDir, app.cfg.io.rootName);
        if ~exist(outdir,'dir'), mkdir(outdir); end
        app.state.outdir = outdir;
        steps = {'STEP0_PREPROC','STEP1_EMBEDDING','STEP2_LOCALIZATION','STEP3_LOCALAPPROX','STEP4_FINAL','BENCHMARKS','FIGURES'};
        for i = 1:numel(steps)
            d = fullfile(outdir,steps{i});
            if ~exist(d,'dir'), mkdir(d); end
        end
        logmsg(['Output folder: ' outdir]);
    end
