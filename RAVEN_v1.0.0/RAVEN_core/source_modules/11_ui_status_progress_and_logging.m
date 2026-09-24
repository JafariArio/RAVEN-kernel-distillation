    function tryWriteTable(T, xlsxPath, sheet)
        try
            writetable(T,xlsxPath,'Sheet',sheet);
        catch MEw
            logmsg(['Write warning: ' MEw.message]);
        end
    end

    function saveFig(fig, pathOut)
        if ~app.cfg.runtime.savePNG
            close(fig);
            return;
        end
        try
            exportgraphics(fig,pathOut,'Resolution',250);
        catch
            try
                saveas(fig,pathOut);
            catch MEf
                logmsg(['Figure save warning: ' MEf.message]);
            end
        end
        close(fig);
    end

    function setStep(txt)
        app.state.currentStep = txt;
        set(app.ui.txtStep,'String',['Step: ' txt]);
        setLiveStatus('Current step', txt);
        refreshLiveStatusContext();
        drawnow;
    end

    function setStatus(txt)
        set(app.ui.txtStatus,'String',['Status: ' txt]);
        setLiveStatus('Pipeline status', txt);
        refreshLiveStatusContext();
        drawnow;
    end

    function setError(txt)
        set(app.ui.txtError,'String',['Last error: ' txt]);
        setLiveStatus('Last error', txt);
        drawnow;
    end

    function setProgress(frac)
        frac = max(0,min(1,frac));
        if isfield(app.ui,'progFill') && ishghandle(app.ui.progFill)
            set(app.ui.progFill,'Position',[0 0 frac 1]);
        elseif isfield(app.ui,'progPatch') && ishghandle(app.ui.progPatch)
            set(app.ui.progPatch,'XData',[0 frac frac 0]);
        end
        pctTxt = sprintf('%.1f%%',100*frac);
        set(app.ui.txtProg,'String',pctTxt);
        setLiveStatus('Progress', pctTxt);
        refreshLiveStatusContext();
        drawnow;
    end

    function initActionProgressTracking()
        app.state.actionHistory = {};
        app.state.progressInfo = struct('done',0,'total',max(1,estimateTotalActions()),'currentAction','Idle');
        setLiveStatus('Current action','Idle');
        setLiveStatus('Action progress',sprintf('%d / %d', app.state.progressInfo.done, app.state.progressInfo.total));
        setProgress(0);
    end

    function total = estimateTotalActions()
        total = 6;
        try
            s1 = estimateStep1ActionCount();
            total = total + s1;
        catch
            total = total + max(1, numel(ravenGetField(ravenGetField(app.cfg,'step1',struct()),'kPCList',1)));
        end
        try
            total = total + estimateStep2ActionCount();
        catch
            total = total + 1;
        end
        try
            total = total + estimateStep3ActionCount();
        catch
            total = total + 1;
        end
        try
            total = total + estimateStep4ActionCount();
        catch
            total = total + 4;
        end
        if isfield(app.cfg,'runtime') && isfield(app.cfg.runtime,'runBenchmarks') && app.cfg.runtime.runBenchmarks
            total = total + 1;
        end
        total = max(1, round(total));
    end

    function n = estimateStep1ActionCount()
        X = []; maxRank = inf;
        if isfield(app.state,'data') && isfield(app.state.data,'X_all') && ~isempty(app.state.data.X_all)
            X = app.state.data.X_all;
            maxRank = max(1, min(size(X,1)-1, size(X,2)));
        end
        pcaMode = 'fixedlist';
        if isfield(app.cfg.step1,'singleKPCEnable') && app.cfg.step1.singleKPCEnable
            pcaMode = 'single';
        elseif isfield(app.cfg.step1,'pcaMode') && ~isempty(app.cfg.step1.pcaMode)
            pcaMode = lower(strtrim(app.cfg.step1.pcaMode));
        end
        switch pcaMode
            case 'single'
                n = 1;
            case 'variance'
                n = 5;
            otherwise
                kList = unique(max(1, round(app.cfg.step1.kPCList(:)')));
                if isfinite(maxRank)
                    kList = kList(kList <= maxRank);
                end
                if isempty(kList), kList = 1; end
                if isfield(app.cfg.step1,'coarseToFine') && app.cfg.step1.coarseToFine && numel(kList) >= 5 && ~strcmpi(pcaMode,'fixedlist')
                    stride = max(1, round(numel(kList)/4));
                    kList = unique([kList(1:stride:end) kList(end)]);
                end
                n = numel(kList);
        end
        n = max(1,n);
    end

    function n = estimateStep2ActionCount()
        mList = unique(max(2, round(app.cfg.step2.mLandList(:)')));
        rList = unique(max(1, round(app.cfg.step2.rTeachList(:)')));
        sList = unique(app.cfg.step2.sigmaScaleList(:)'); sList = sList(sList > 0);
        cList = unique(app.cfg.step2.boxCList(:)'); cList = cList(cList > 0);
        if isempty(mList), mList = 160; end
        if isempty(rList), rList = 60; end
        if isempty(sList), sList = 1.7; end
        if isempty(cList), cList = 0.1; end
        n = numel(mList) * numel(rList) * numel(sList) * numel(cList);
        n = max(1,n);
    end

    function n = estimateStep3ActionCount()
        nTeacherUse = max(1, round(app.cfg.step3.teacherShortlistN));
        if isfield(app.state,'results') && isfield(app.state.results,'step2Shortlist') && ~isempty(app.state.results.step2Shortlist)
            nTeacherUse = min(height(app.state.results.step2Shortlist), nTeacherUse);
        end
        pList = unique(max(4, round(app.cfg.step3.pHiddenList(:)')));
        lamList = unique(app.cfg.step3.lamRidgeList(:)'); lamList = lamList(lamList > 0);
        aList = unique(app.cfg.step3.alphaList(:)'); aList = aList(aList >= 0 & aList <= 1);
        tList = unique(app.cfg.step3.tempList(:)'); tList = tList(tList > 0);
        sList = unique(app.cfg.step3.skipScaleList(:)'); sList = sList(sList >= 0);
        eList = unique(max(1, round(app.cfg.step3.ensembleList(:)')));
        if isempty(pList), pList = 64; end
        if isempty(lamList), lamList = 1e-4; end
        if isempty(aList), aList = 0.10; end
        if isempty(tList), tList = 2; end
        if isempty(sList), sList = 0.25; end
        if isempty(eList), eList = 1; end
        mode = normalizeStep3Mode(ravenGetField(app.cfg.step3,'mode','full_search'));
        switch mode
            case 'fast_search'
                nTeacherUse = min(nTeacherUse,2);
                pList = pList(1:min(numel(pList),2));
                lamList = lamList(1:min(numel(lamList),2));
                aList = aList(1:min(numel(aList),1));
                tList = tList(1:min(numel(tList),2));
                sList = sList(1:min(numel(sList),2));
                eList = eList(1:min(numel(eList),1));
            case 'single_teacher_sweep'
                nTeacherUse = min(nTeacherUse,1);
            case 'single_candidate'
                nTeacherUse = min(nTeacherUse,1);
                pList = pList(1); lamList = lamList(1); aList = aList(1); tList = tList(1); sList = sList(1); eList = eList(1);
        end
        n = nTeacherUse * numel(pList) * numel(lamList) * numel(aList) * numel(tList) * numel(sList) * numel(eList);
        n = max(1,n);
    end

    function n = estimateStep4ActionCount()
        if isfield(app.state,'results') && isfield(app.state.results,'step3Table') && ~isempty(app.state.results.step3Table)
            try
                [selRows,~,~,~] = selectStep4RowsFromStep3Table(app.state.results.step3Table);
                n = height(selRows) + 4;
            catch
                n = max(1, min(height(app.state.results.step3Table), max(1, round(app.cfg.step4.topNPerBucket)))) + 4;
            end
        else
            n = max(1, round(app.cfg.step4.topNPerBucket))*4 + 4;
        end
        n = max(1,n);
    end

    function refreshActionProgressPlan()
        if ~isfield(app.state,'progressInfo') || isempty(app.state.progressInfo)
            initActionProgressTracking();
            return;
        end
        app.state.progressInfo.total = max(app.state.progressInfo.done + 1, estimateTotalActions());
        setLiveStatus('Action progress', sprintf('%d / %d', app.state.progressInfo.done, app.state.progressInfo.total));
        setProgress(app.state.progressInfo.done / max(1, app.state.progressInfo.total));
    end

    function noteAction(txt)
        if ~ischar(txt) && ~isstring(txt)
            txt = evalc('disp(txt)');
        end
        txt = char(txt);
        if ~isfield(app.state,'progressInfo') || isempty(app.state.progressInfo)
            initActionProgressTracking();
        end
        app.state.progressInfo.currentAction = txt;
        setLiveStatus('Current action', txt);
        pushActionHistory(txt);
        setStatus(txt);
        setLiveStatus('Action progress', sprintf('%d / %d', app.state.progressInfo.done, app.state.progressInfo.total));
        drawnow limitrate;
    end

    function completeAction(txt)
        if nargin < 1 || isempty(txt)
            txt = ravenGetField(ravenGetField(app.state,'progressInfo',struct()),'currentAction','Completed action');
        end
        if ~isfield(app.state,'progressInfo') || isempty(app.state.progressInfo)
            initActionProgressTracking();
        end
        app.state.progressInfo.done = min(app.state.progressInfo.total, app.state.progressInfo.done + 1);
        app.state.progressInfo.currentAction = char(txt);
        setLiveStatus('Current action', char(txt));
        setLiveStatus('Action progress', sprintf('%d / %d', app.state.progressInfo.done, app.state.progressInfo.total));
        setProgress(app.state.progressInfo.done / max(1, app.state.progressInfo.total));
    end

    function finalizeActionProgress()
        if ~isfield(app.state,'progressInfo') || isempty(app.state.progressInfo)
            initActionProgressTracking();
        end
        app.state.progressInfo.done = app.state.progressInfo.total;
        app.state.progressInfo.currentAction = 'Completed';
        setLiveStatus('Current action','Completed');
        setLiveStatus('Action progress', sprintf('%d / %d', app.state.progressInfo.done, app.state.progressInfo.total));
        setProgress(1);
    end

    function tf = isParallelReady(nTasks)
        tf = false;
        if nargin < 1 || isempty(nTasks), nTasks = 0; end
        if ~isfield(app.cfg,'cv') || ~isfield(app.cfg.cv,'useParallel') || ~app.cfg.cv.useParallel
            return;
        end
        try
            p = gcp('nocreate');
            tf = ~isempty(p) && p.NumWorkers > 1 && nTasks > 1;
        catch
            tf = false;
        end
    end

    function updateStepChoiceAndBest(stepLabel, chosenText, bestText)
        setLiveStatus([stepLabel ' chosen'], chosenText);
        setLiveStatus([stepLabel ' best'], bestText);
    end

    function metricsTxt = formatActionMetrics(accVal, weightedF1Val, macroF1Val, scoreVal)
        if nargin < 4 || isempty(scoreVal), scoreVal = NaN; end
        metricsTxt = sprintf('Acc=%.2f%% | WeightedF1=%.2f%% | MacroF1=%.2f%% | Score=%.4f', ...
            100*double(accVal), 100*double(weightedF1Val), 100*double(macroF1Val), double(scoreVal));
    end

    function pushActionHistory(txt)
        if ~isfield(app.state,'actionHistory') || isempty(app.state.actionHistory)
            app.state.actionHistory = {};
        end
        app.state.actionHistory{end+1,1} = char(txt);
        if numel(app.state.actionHistory) > 40
            app.state.actionHistory = app.state.actionHistory(end-39:end);
        end
        renderLiveStatusPanel();
    end

    function logmsg(txt)
        if ~ischar(txt) && ~isstring(txt)
            txt = evalc('disp(txt)');
        end
        old = get(app.ui.lstLog,'String');
        if ischar(old), old = {old}; end
        stamp = datestr(now,'HH:MM:SS');
        old{end+1} = sprintf('[%s] %s', stamp, char(txt));
        set(app.ui.lstLog,'String',old,'Value',numel(old));
        drawnow limitrate;
        setLiveStatus('Last activity', char(txt));
    end

    function setSummary(item,val)
        if ~isfield(app.state,'summaryPairs') || isempty(app.state.summaryPairs)
            app.state.summaryPairs = cell(0,2);
        end
        D = app.state.summaryPairs;
        idx = find(strcmp(D(:,1),item),1);
        if isempty(idx)
            D(end+1,:) = {item,val};
        else
            D{idx,2} = val;
        end
        app.state.summaryPairs = D;
        renderSummaryPanel();
        if strcmpi(item,'Final')
            setLiveStatus('Best final', val);
        elseif strcmpi(item,'AutoTune')
            setLiveStatus('Autotune', val);
        end
        drawnow;
    end

    function renderSummaryPanel()
        if ~isfield(app.ui,'lstDatasetSummary') || ~ishandle(app.ui.lstDatasetSummary)
            return;
        end
        D = app.state.summaryPairs;
        if isempty(D)
            set(app.ui.lstDatasetSummary,'String',{'Dataset: Not loaded'});
            return;
        end
        order = {'Dataset','Classes','Selected Classes','Spectra','Spectral Variables','Spectral Range', ...
                 'Preprocessing','Workers','Preset','AutoTune','Final','Priority','Pipeline','Logo'};
        shown = {};
        used = false(size(D,1),1);
        for ii = 1:numel(order)
            idx = find(strcmp(D(:,1),order{ii}),1);
            if ~isempty(idx)
                shown{end+1} = sprintf('%-18s : %s', D{idx,1}, D{idx,2});
                used(idx) = true;
            end
        end
        for ii = find(~used)'
            shown{end+1} = sprintf('%-18s : %s', D{ii,1}, D{ii,2});
        end
        set(app.ui.lstDatasetSummary,'String',shown,'Value',1);
    end

    function setLiveStatus(item,val)
        if ~isfield(app.state,'livePairs') || isempty(app.state.livePairs)
            app.state.livePairs = cell(0,2);
        end
        D = app.state.livePairs;
        idx = find(strcmp(D(:,1),item),1);
        if isempty(idx)
            D(end+1,:) = {item,val};
        else
            D{idx,2} = val;
        end
        app.state.livePairs = D;
        renderLiveStatusPanel();
    end

    function renderLiveStatusPanel()
        if ~isfield(app.ui,'lstRunStatus') || ~ishandle(app.ui.lstRunStatus)
            return;
        end
        D = app.state.livePairs;
        if isempty(D)
            set(app.ui.lstRunStatus,'String',{'Current step: Idle'; 'Pipeline status: Ready'});
            return;
        end
        order = {'Current step','Current action','Action progress','Progress','Pipeline status','Dataset mode','Effective CV mode','Step 3 mode','Current dataset','Active teacher','Active student','Step 1 chosen','Step 1 best','Step 2 chosen','Step 2 best','Step 3 chosen','Step 3 best','Step 4 chosen','Step 4 best','Last activity','Last error','Autotune','Best final','Output root'};
        shown = {};
        used = false(size(D,1),1);
        for ii = 1:numel(order)
            idx = find(strcmp(D(:,1),order{ii}),1);
            if ~isempty(idx)
                shown{end+1} = sprintf('%-16s : %s', D{idx,1}, D{idx,2});
                used(idx) = true;
            end
        end
        for ii = find(~used)'
            shown{end+1} = sprintf('%-16s : %s', D{ii,1}, D{ii,2});
        end
        set(app.ui.lstRunStatus,'String',shown,'Value',1);
    end

    function refreshLiveStatusContext()
        try
            inputMode = ravenGetField(ravenGetField(app.cfg,'step0',struct()),'inputMode',ravenGetField(ravenGetField(app.cfg,'io',struct()),'inputMode','spectra_blocks'));
            setLiveStatus('Dataset mode', char(inputMode));
        catch
        end
        try
            splitInfo = getSplitValidationInfo();
            setLiveStatus('Effective CV mode', char(splitInfo.effectiveMode));
        catch
        end
        try
            setLiveStatus('Step 3 mode', char(ravenGetField(ravenGetField(app.cfg,'step3',struct()),'mode','full_search')));
        catch
        end
        try
            if isfield(app.state,'detectedData') && ~isempty(app.state.detectedData) && isfield(app.state.detectedData,'groupNames')
                if isfield(app.state.detectedData,'isFeatureMatrix') && app.state.detectedData.isFeatureMatrix
                    setLiveStatus('Current dataset', sprintf('%d classes | %d samples | %d features', numel(app.state.detectedData.groupNames), size(app.state.detectedData.X_all,1), size(app.state.detectedData.X_all,2)));
                else
                    counts = cellfun(@(b) size(b,2)-1, app.state.detectedData.blocks);
                    setLiveStatus('Current dataset', sprintf('%d classes | %d spectra | ~%d vars', numel(app.state.detectedData.groupNames), sum(counts), size(app.state.detectedData.blocks{1},1)));
                end
            else
                setLiveStatus('Current dataset', 'none');
            end
        catch
        end
        try
            if isfield(app.state,'results') && isfield(app.state.results,'step2best') && isfield(app.state.results.step2best,'Cfg')
                c = app.state.results.step2best.Cfg;
                setLiveStatus('Active teacher', sprintf('kPC=%d | m=%d | r=%d | s=%g | C=%g', c.kPC, c.mLand, c.rTeach, c.sigmaScale, c.boxC));
            else
                setLiveStatus('Active teacher', 'none');
            end
        catch
        end
        try
            if isfield(app.state,'results') && isfield(app.state.results,'finalSelection') && isfield(app.state.results.finalSelection,'StudentCfg')
                s = app.state.results.finalSelection.StudentCfg;
                setLiveStatus('Active student', sprintf('p=%d | lam=%g | a=%g | t=%g | skip=%g | e=%d', s.pHidden, s.lamRidge, s.alpha, s.temp, s.skipScale, s.ensemble));
            elseif isfield(app.state,'results') && isfield(app.state.results,'step3top') && istable(app.state.results.step3top) && height(app.state.results.step3top) >= 1
                row = app.state.results.step3top(1,:);
                setLiveStatus('Active student', sprintf('p=%d | lam=%g | a=%g | t=%g | skip=%g | e=%d', double(row.pHidden), double(row.lamRidge), double(row.alpha), double(row.temp), double(row.skipScale), double(row.ensemble)));
            else
                setLiveStatus('Active student', 'none');
            end
        catch
        end
        try
            setLiveStatus('Output root', char(ravenGetField(ravenGetField(app.cfg,'io',struct()),'rootName','RAVEN_RUN')));
        catch
        end
    end

    function checkPauseStop()
        while app.state.isPaused
            pause(app.cfg.runtime.pausePollSec);
            drawnow;
            if app.state.stopRequested
                error('Stopped by user.');
            end
        end
        drawnow;
        if app.state.stopRequested
            error('Stopped by user.');
        end
    end
