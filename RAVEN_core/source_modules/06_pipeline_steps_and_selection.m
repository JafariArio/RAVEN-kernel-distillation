    function step0_load_preprocess()
        setStep('Step 0 | Load + Preprocess');
        noteAction('Step 0 | loading datasets...');
        logmsg('Loading datasets...');
        data = loadDynamicDataset(app.cfg.io.dataSource, app.cfg.io.autoDetectGroups);
        completeAction('Step 0 | dataset loaded');
        logmsg(sprintf('Detected %d classes in source.', numel(data.groupNames)));
        for i = 1:numel(data.groupNames)
            logmsg(sprintf('  available: %-20s  %4d spectra', data.groupNames{i}, size(data.blocks{i},2)-1));
        end

        noteAction('Step 0 | filtering selected classes...');
        dataUsed = filterDataByPreprocSelection(data, app.cfg.preproc);
        completeAction('Step 0 | class filtering completed');
        app.state.rawSelectedData = dataUsed;
        logmsg(sprintf('Using %d classes after preprocessing selection.', numel(dataUsed.groupNames)));
        for i = 1:numel(dataUsed.groupNames)
            logmsg(sprintf('  selected:  %-20s  %4d spectra', dataUsed.groupNames{i}, size(dataUsed.blocks{i},2)-1));
        end
        noteAction('Step 0 | adapting input representation...');
        [dataUsed, adapterMeta] = applyStep0Adapter(dataUsed, app.cfg.step0);
        completeAction('Step 0 | input adaptation completed');
        app.state.rawSelectedData = dataUsed;
        if isfield(dataUsed,'groupVector')
            app.cfg.cv.groupVector = dataUsed.groupVector;
            app.cfg.cv.groupVectorSource = 'step0-adapter';
        elseif isfield(app.cfg.cv,'groupVector')
            app.cfg.cv.groupVector = [];
        end
        logmsg(sprintf('Step0 adapter | mode=%s | axis=%s | samples %d -> %d | length %d -> %d', ...
            adapterMeta.inputMode, adapterMeta.commonAxisMode, adapterMeta.originalSamples, adapterMeta.finalSamples, ...
            round(adapterMeta.originalLength), round(adapterMeta.finalLength)));
        setLiveStatus('Dataset mode', char(adapterMeta.inputMode));

        preSig = dataSignatureForTune(dataUsed);
        preCfgSig = flattenStruct(app.cfg.preproc);
        preJson = jsonencode(preCfgSig);
        preHash = num2str(sum(double(preJson)));
        preKey = matlab.lang.makeValidName(['pre_' preSig '_' preHash]);
        canReusePre = false;
        if isfield(app.state,'cache') && isfield(app.state.cache,'preprocess') && isfield(app.state.cache.preprocess, preKey)
            pc = app.state.cache.preprocess.(preKey);
            W = pc.W; X_all = pc.X_all; y_idx = pc.y_idx; groupNames = pc.groupNames; sampleCounts = pc.sampleCounts;
            canReusePre = true;
            logmsg('Step0 | reused cached preprocessing result.');
            completeAction('Step 0 | reused cached preprocessing result');
        else
            noteAction('Step 0 | preprocessing dataset...');
            [W, X_all, y_idx, groupNames, sampleCounts] = preprocessDataset(dataUsed, app.cfg.preproc);
            completeAction('Step 0 | preprocessing completed');
            if ~isfield(app.state.cache,'preprocess'), app.state.cache.preprocess = struct(); end
            app.state.cache.preprocess.(preKey) = struct('W',W,'X_all',X_all,'y_idx',y_idx,'groupNames',{groupNames},'sampleCounts',sampleCounts);
        end
        app.state.data = struct();
        app.state.data.W = W;
        app.state.data.X_all = X_all;
        app.state.data.y_idx = y_idx;
        app.state.data.groupNames = groupNames;
        app.state.data.sampleCounts = sampleCounts;
        if isfield(dataUsed,'groupVector'), app.state.data.groupVector = dataUsed.groupVector; end
        app.state.data.adapterMeta = adapterMeta;
        app.state.data.C = numel(groupNames);
        app.state.data.N = size(X_all,1);
        app.state.data.D = size(X_all,2);
        noteAction('Step 0 | saving preprocessed dataset...');
        save(fullfile(app.state.outdir,'STEP0_PREPROC','PREPROCESSED_DATA.mat'),'W','X_all','y_idx','groupNames','sampleCounts','adapterMeta','-v7.3');
        completeAction('Step 0 | preprocessed dataset saved');
        if isfield(app.cfg.runtime,'exportDataDisposition') && app.cfg.runtime.exportDataDisposition
            exportDataDisposition(app.state.outdir, data, dataUsed, app.state.data);
        end
        setSummary('Dataset', sprintf('%d classes | %d spectra | %d wavenumbers', app.state.data.C, app.state.data.N, app.state.data.D));
        logmsg(sprintf('Preprocessed selected data: N=%d | D=%d.', app.state.data.N, app.state.data.D));
        refreshActionProgressPlan();
    end

    function step1_search_embedding()
        setStep('Step 1 | Teacher Baseline PC Search');
        X = app.state.data.X_all;
        y = app.state.data.y_idx;
        C = app.state.data.C;
        maxRank = max(1, min(size(X,1)-1, size(X,2)));
        pcaMode = 'fixedlist';
        if isfield(app.cfg.step1,'singleKPCEnable') && app.cfg.step1.singleKPCEnable
            pcaMode = 'single';
        elseif isfield(app.cfg.step1,'pcaMode') && ~isempty(app.cfg.step1.pcaMode)
            pcaMode = lower(strtrim(app.cfg.step1.pcaMode));
        end
        switch pcaMode
            case 'single'
                kList = max(1, min(maxRank, round(app.cfg.step1.singleKPC)));
            case 'variance'
                XcAll = bsxfun(@minus, X, mean(X,1));
                try
                    [~,~,latent] = pca(XcAll, 'Centered', false);
                catch
                    latent = var(XcAll,0,1)';
                end
                if isempty(latent), latent = ones(maxRank,1); end
                cs = cumsum(latent(:)) / max(eps, sum(latent(:)));
                kVar = find(cs >= max(0.5, min(0.9999, app.cfg.step1.varianceTarget)), 1, 'first');
                if isempty(kVar), kVar = min(40,maxRank); end
                kList = unique(max(1, min(maxRank, [kVar-4 kVar-2 kVar kVar+2 kVar+4])));
            otherwise
                kRaw = max(1, round(app.cfg.step1.kPCList(:)'));
                kRaw = kRaw(kRaw <= maxRank);
                kList = unique(kRaw, 'stable');
                if isempty(kList), kList = min(40,maxRank); end
                if isfield(app.cfg.step1,'coarseToFine') && app.cfg.step1.coarseToFine && numel(kList) >= 5 && ~strcmpi(pcaMode,'fixedlist')
                    stride = max(1, round(numel(kList)/4));
                    kList = unique([kList(1:stride:end) kList(end)]);
                end
        end

        T = cell(0,12);
        best = struct('Acc',-Inf,'MacroF1',-Inf,'WeightedF1',-Inf,'Score',-Inf);
        cfgList = cell(numel(kList),1);
        resList = cell(numel(kList),1);
        for i = 1:numel(kList)
            teacherCfg = struct();
            teacherCfg.kPC = kList(i);
            teacherCfg.mLand = app.cfg.step1.teacherMLand;
            teacherCfg.rTeach = app.cfg.step1.teacherRTeach;
            teacherCfg.sigmaScale = app.cfg.step1.teacherSigmaScale;
            teacherCfg.boxC = app.cfg.step1.teacherBoxC;
            cfgList{i} = teacherCfg;
        end
        groupVecNow = getCurrentGroupVector(numel(y));
        usePar = isParallelReady(numel(kList));
        doneCount = 0;
        if usePar
            ppool = gcp('nocreate');
            futures(1:numel(kList),1) = parallel.FevalFuture;
            logmsg(sprintf('Step1 parallel ACTIVE across %d candidates.', numel(kList)));
            noteAction(sprintf('Step 1 | submitted %d kPC evaluations', numel(kList)));
            for i = 1:numel(kList)
                futures(i) = parfeval(ppool, @raven_eval_teacher_worker, 1, X, y, C, cfgList{i}, app.cfg.cv.outerK, app.cfg.cv.repeats, app.cfg.cv.seedBase + 1000, false, app.cfg.step4.numROC, app.cfg.cv.splitMode, groupVecNow);
            end
            while doneCount < numel(kList)
                drawnow;
                if app.state.stopRequested
                    cancel(futures);
                    error('Stopped by user.');
                end
                [completedIdx, res] = fetchNext(futures, 0.20);
                if isempty(completedIdx)
                    noteAction(sprintf('Step 1 | running %d/%d complete', doneCount, numel(kList)));
                    continue;
                end
                teacherCfg = cfgList{completedIdx};
                resList{completedIdx} = res;
                T(end+1,:) = {teacherCfg.kPC, res.Acc, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, res.MemMiBPerSpec, res.WallSec, res.WallMsPerSpec, res.PredictMsPerSpec, res.FeatDimMed, res.Score};
                doneCount = doneCount + 1;
                completeAction(sprintf('Step 1 | kPC %d done (%d/%d) | %s', teacherCfg.kPC, doneCount, numel(kList), formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)));
                updateStepChoiceAndBest('Step 1', sprintf('kPC=%d | %s', teacherCfg.kPC, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), 'Waiting for best...');
                if (res.Acc > best.Acc) || (abs(res.Acc - best.Acc) < 1e-12 && res.MacroF1 > best.MacroF1) || ...
                   (abs(res.Acc - best.Acc) < 1e-12 && abs(res.MacroF1 - best.MacroF1) < 1e-12 && res.Score > best.Score)
                    best = res;
                    best.cfg = teacherCfg;
                end
                updateStepChoiceAndBest('Step 1', sprintf('kPC=%d | %s', teacherCfg.kPC, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), ...
                    sprintf('kPC=%d | %s', best.cfg.kPC, formatActionMetrics(best.Acc, best.WeightedF1, best.MacroF1, best.Score)));
                logmsg(sprintf('Step1 | kPC=%d | Acc=%.2f%% | WeightedF1=%.2f%% | MacroF1=%.2f%% | Score=%.4f | Mem=%.4g MiB/spec', ...
                    teacherCfg.kPC, 100*res.Acc, 100*res.WeightedF1, 100*res.MacroF1, res.Score, res.MemMiBPerSpec));
            end
        else
            logmsg(sprintf('Step1 parallel INACTIVE | candidates=%d', numel(kList)));
            for i = 1:numel(kList)
                checkPauseStop();
                noteAction(sprintf('Step 1 | kPC %d (%d/%d)', kList(i), i, numel(kList)));
                teacherCfg = cfgList{i};
                res = raven_eval_teacher_worker(X, y, C, teacherCfg, app.cfg.cv.outerK, app.cfg.cv.repeats, app.cfg.cv.seedBase + 1000, false, app.cfg.step4.numROC, app.cfg.cv.splitMode, groupVecNow);
                resList{i} = res;
                T(end+1,:) = {teacherCfg.kPC, res.Acc, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, res.MemMiBPerSpec, res.WallSec, res.WallMsPerSpec, res.PredictMsPerSpec, res.FeatDimMed, res.Score};
                completeAction(sprintf('Step 1 | finished kPC %d (%d/%d) | %s', kList(i), i, numel(kList), formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)));
                updateStepChoiceAndBest('Step 1', sprintf('kPC=%d | %s', teacherCfg.kPC, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), 'Waiting for best...');
                if (res.Acc > best.Acc) || (abs(res.Acc - best.Acc) < 1e-12 && res.MacroF1 > best.MacroF1) || ...
                   (abs(res.Acc - best.Acc) < 1e-12 && abs(res.MacroF1 - best.MacroF1) < 1e-12 && res.Score > best.Score)
                    best = res;
                    best.cfg = teacherCfg;
                end
                updateStepChoiceAndBest('Step 1', sprintf('kPC=%d | %s', teacherCfg.kPC, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), ...
                    sprintf('kPC=%d | %s', best.cfg.kPC, formatActionMetrics(best.Acc, best.WeightedF1, best.MacroF1, best.Score)));
                logmsg(sprintf('Step1 | kPC=%d | Acc=%.2f%% | WeightedF1=%.2f%% | MacroF1=%.2f%% | Score=%.4f | Mem=%.4g MiB/spec', ...
                    teacherCfg.kPC, 100*res.Acc, 100*res.WeightedF1, 100*res.MacroF1, res.Score, res.MemMiBPerSpec));
            end
        end

        app.state.results.step1Table = cell2table(T, 'VariableNames', ...
            {'kPC','Acc','BalAcc','WeightedAcc','MacroF1','WeightedF1','MemMiBPerSpec','WallSec','WallMsPerSpec','PredictMsPerSpec','FeatDimMed','Score'});
        app.state.results.bestStep1 = best;
        bestStep1 = best; Tstep1 = app.state.results.step1Table;
        save(fullfile(app.state.outdir,'STEP1_EMBEDDING','STEP1_RESULTS.mat'),'bestStep1','Tstep1','-v7.3');
        tryWriteTable(app.state.results.step1Table, fullfile(app.state.outdir,'STEP1_EMBEDDING','STEP1_RESULTS.xlsx'),'Step1');
        makeStep1Plot(app.state.results.step1Table);
        setSummary('Best Step1', sprintf('kPC=%d | Teacher Acc=%.2f%% | WeightedF1=%.2f%% | MacroF1=%.2f%%', best.cfg.kPC, 100*best.Acc, 100*best.WeightedF1, 100*best.MacroF1));
    end

    function step2_search_localization()
        setStep('Step 2 | Teacher Search');
        X = app.state.data.X_all;
        y = app.state.data.y_idx;
        C = app.state.data.C;
        kPC = app.state.results.bestStep1.cfg.kPC;

        mList = unique(max(2, round(app.cfg.step2.mLandList(:)')));
        rList = unique(max(1, round(app.cfg.step2.rTeachList(:)')));
        sList = unique(app.cfg.step2.sigmaScaleList(:)'); sList = sList(sList > 0);
        cList = unique(app.cfg.step2.boxCList(:)'); cList = cList(cList > 0);
        if isempty(mList), mList = 160; end
        if isempty(rList), rList = 60; end
        if isempty(sList), sList = 1.7; end
        if isempty(cList), cList = 0.1; end

        total = numel(mList) * numel(rList) * numel(sList) * numel(cList);
        cfgList = repmat(struct('kPC',kPC,'mLand',0,'rTeach',0,'sigmaScale',0,'boxC',0), total, 1);
        idx = 0;
        for im = 1:numel(mList)
            for ir = 1:numel(rList)
                for isg = 1:numel(sList)
                    for ic = 1:numel(cList)
                        idx = idx + 1;
                        cfgList(idx) = struct('kPC',kPC,'mLand',mList(im),'rTeach',rList(ir), ...
                            'sigmaScale',sList(isg),'boxC',cList(ic));
                    end
                end
            end
        end

        T = cell(total,16);
        resList = cell(total,1);
        groupVecNow = getCurrentGroupVector(numel(y));
        usePar = isParallelReady(total);
        best = struct('Acc',-Inf,'MacroF1',-Inf,'WeightedF1',-Inf,'Score',-Inf);
        doneCount = 0;
        if usePar
            ppool = gcp('nocreate');
            futures(1:total,1) = parallel.FevalFuture;
            logmsg(sprintf('Step2 parallel ACTIVE across %d teacher candidates.', total));
            noteAction(sprintf('Step 2 | submitted %d teacher evaluations', total));
            for ii = 1:total
                futures(ii) = parfeval(ppool, @raven_eval_teacher_worker, 1, X, y, C, cfgList(ii), app.cfg.cv.outerK, app.cfg.cv.repeats, app.cfg.cv.seedBase + 2000, false, app.cfg.step4.numROC, app.cfg.cv.splitMode, groupVecNow);
            end
            while doneCount < total
                drawnow limitrate;
                if app.state.stopRequested
                    cancel(futures);
                    error('Stopped by user.');
                end
                [completedIdx, res] = fetchNext(futures, 0.20);
                if isempty(completedIdx)
                    noteAction(sprintf('Step 2 | running %d/%d complete', doneCount, total));
                    continue;
                end
                teacherCfg = cfgList(completedIdx);
                resList{completedIdx} = res;
                T(completedIdx,:) = {teacherCfg.kPC, teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, ...
                    res.Acc, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, res.MemMiBPerSpec, res.WallSec, res.WallMsPerSpec, ...
                    res.PredictMsPerSpec, res.FeatDimMed, res.Score};
                doneCount = doneCount + 1;
                completeAction(sprintf('Step 2 | teacher %d/%d done | %s', doneCount, total, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)));
                updateStepChoiceAndBest('Step 2', sprintf('m=%d | r=%d | s=%.3g | C=%.3g | %s', teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), 'Waiting for best...');
                if (res.Acc > best.Acc) || (abs(res.Acc - best.Acc) < 1e-12 && res.MacroF1 > best.MacroF1) || ...
                   (abs(res.Acc - best.Acc) < 1e-12 && abs(res.MacroF1 - best.MacroF1) < 1e-12 && res.Score > best.Score)
                    best = res;
                    best.cfg = teacherCfg;
                end
                updateStepChoiceAndBest('Step 2', sprintf('m=%d | r=%d | s=%.3g | C=%.3g | %s', teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), ...
                    sprintf('m=%d | r=%d | s=%.3g | C=%.3g | %s', best.cfg.mLand, best.cfg.rTeach, best.cfg.sigmaScale, best.cfg.boxC, formatActionMetrics(best.Acc, best.WeightedF1, best.MacroF1, best.Score)));
                logmsg(sprintf('Step2 | %d/%d | kPC=%d m=%d r=%d sigma=%.3g C=%.3g | Acc=%.2f%% | WeightedF1=%.2f%%', ...
                    doneCount,total,kPC,teacherCfg.mLand,teacherCfg.rTeach,teacherCfg.sigmaScale,teacherCfg.boxC,100*res.Acc,100*res.WeightedF1));
            end
        else
            logmsg(sprintf('Step2 parallel INACTIVE | candidates=%d', total));
            for ii = 1:total
                checkPauseStop();
                teacherCfg = cfgList(ii);
                noteAction(sprintf('Step 2 | teacher candidate %d/%d', ii, total));
                res = raven_eval_teacher_worker(X, y, C, teacherCfg, app.cfg.cv.outerK, app.cfg.cv.repeats, app.cfg.cv.seedBase + 2000, false, app.cfg.step4.numROC, app.cfg.cv.splitMode, groupVecNow);
                resList{ii} = res;
                T(ii,:) = {teacherCfg.kPC, teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, ...
                    res.Acc, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, res.MemMiBPerSpec, res.WallSec, res.WallMsPerSpec, ...
                    res.PredictMsPerSpec, res.FeatDimMed, res.Score};
                completeAction(sprintf('Step 2 | teacher candidate %d/%d done | %s', ii, total, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)));
                updateStepChoiceAndBest('Step 2', sprintf('m=%d | r=%d | s=%.3g | C=%.3g | %s', teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), 'Waiting for best...');
                if (res.Acc > best.Acc) || (abs(res.Acc - best.Acc) < 1e-12 && res.MacroF1 > best.MacroF1) || ...
                   (abs(res.Acc - best.Acc) < 1e-12 && abs(res.MacroF1 - best.MacroF1) < 1e-12 && res.Score > best.Score)
                    best = res;
                    best.cfg = teacherCfg;
                end
                updateStepChoiceAndBest('Step 2', sprintf('m=%d | r=%d | s=%.3g | C=%.3g | %s', teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), ...
                    sprintf('m=%d | r=%d | s=%.3g | C=%.3g | %s', best.cfg.mLand, best.cfg.rTeach, best.cfg.sigmaScale, best.cfg.boxC, formatActionMetrics(best.Acc, best.WeightedF1, best.MacroF1, best.Score)));
                logmsg(sprintf('Step2 | %d/%d | kPC=%d m=%d r=%d sigma=%.3g C=%.3g | Acc=%.2f%% | WeightedF1=%.2f%%', ...
                    ii,total,kPC,teacherCfg.mLand,teacherCfg.rTeach,teacherCfg.sigmaScale,teacherCfg.boxC,100*res.Acc,100*res.WeightedF1));
            end
        end

        T2 = cell2table(T, 'VariableNames', ...
            {'kPC','mLand','rTeach','sigmaScale','BoxC_T','Acc','BalAcc','WeightedAcc','MacroF1','WeightedF1','MemMiBPerSpec','WallSec','WallMsPerSpec','PredictMsPerSpec','FeatDimMed','Score'});
        T2 = sortrows(T2, {'Acc','MacroF1','Score','WallSec'}, {'descend','descend','descend','ascend'});
        app.state.results.step2Table = T2;
        app.state.results.bestStep2 = best;
        nKeep = min(height(T2), max(1, round(app.cfg.step2.shortlistN)));
        app.state.results.step2Shortlist = T2(1:nKeep,:);
        bestStep2 = best; Tstep2 = T2; Tstep2Short = app.state.results.step2Shortlist;
        save(fullfile(app.state.outdir,'STEP2_LOCALIZATION','STEP2_RESULTS.mat'),'bestStep2','Tstep2','Tstep2Short','-v7.3');
        tryWriteTable(T2, fullfile(app.state.outdir,'STEP2_LOCALIZATION','STEP2_RESULTS.xlsx'),'Step2');
        makeStep2Plot(T2);
        setSummary('Best Step2', sprintf('kPC=%d | m=%d | r=%d | sigma=%.3g | C=%.3g | Acc=%.2f%% | WeightedF1=%.2f%%', ...
            best.cfg.kPC, best.cfg.mLand, best.cfg.rTeach, best.cfg.sigmaScale, best.cfg.boxC, 100*best.Acc, 100*best.WeightedF1));
        logmsg(sprintf('Step2 best teacher | kPC=%d m=%d r=%d sigma=%.3g C=%.3g | Acc=%.2f%%', ...
            best.cfg.kPC, best.cfg.mLand, best.cfg.rTeach, best.cfg.sigmaScale, best.cfg.boxC, 100*best.Acc));
    end

    function mode = normalizeStep3Mode(mode)
        mode = lower(strtrim(toText(mode)));
        valid = {'full_search','fast_search','single_teacher_sweep','single_candidate'};
        if ~ismember(mode, valid)
            mode = 'full_search';
        end
    end

    function [teacherShortOut, pListOut, lamListOut, aListOut, tListOut, sListOut, eListOut, modeInfo] = resolveStep3SearchMode(teacherShortIn, pListIn, lamListIn, aListIn, tListIn, sListIn, eListIn)
        mode = normalizeStep3Mode(ravenGetField(app.cfg.step3,'mode','full_search'));
        teacherShortOut = teacherShortIn;
        pListOut = pListIn;
        lamListOut = lamListIn;
        aListOut = aListIn;
        tListOut = tListIn;
        sListOut = sListIn;
        eListOut = eListIn;
        modeInfo = struct('mode',mode,'teacherCount',height(teacherShortIn),'pCount',numel(pListIn),'lamCount',numel(lamListIn), ...
            'alphaCount',numel(aListIn),'tempCount',numel(tListIn),'skipCount',numel(sListIn),'ensembleCount',numel(eListIn), ...
            'description','');
        switch mode
            case 'full_search'
                modeInfo.description = 'Full teacher shortlist and full student grid.';
            case 'fast_search'
                teacherShortOut = teacherShortIn(1:min(height(teacherShortIn),2),:);
                pListOut = pListIn(1:min(numel(pListIn),2));
                lamListOut = lamListIn(1:min(numel(lamListIn),2));
                aListOut = aListIn(1:min(numel(aListIn),1));
                tListOut = tListIn(1:min(numel(tListIn),2));
                sListOut = sListIn(1:min(numel(sListIn),2));
                eListOut = eListIn(1:min(numel(eListIn),1));
                modeInfo.description = 'Fast mode: reduced teacher shortlist and reduced student grid.';
            case 'single_teacher_sweep'
                teacherShortOut = teacherShortIn(1:min(height(teacherShortIn),1),:);
                modeInfo.description = 'Single-teacher sweep: best teacher only, full student grid.';
            case 'single_candidate'
                teacherShortOut = teacherShortIn(1:min(height(teacherShortIn),1),:);
                pListOut = pListIn(1);
                lamListOut = lamListIn(1);
                aListOut = aListIn(1);
                tListOut = tListIn(1);
                sListOut = sListIn(1);
                eListOut = eListIn(1);
                modeInfo.description = 'Single-candidate mode: best teacher and first student setting only.';
        end
        modeInfo.teacherCount = height(teacherShortOut);
        modeInfo.pCount = numel(pListOut);
        modeInfo.lamCount = numel(lamListOut);
        modeInfo.alphaCount = numel(aListOut);
        modeInfo.tempCount = numel(tListOut);
        modeInfo.skipCount = numel(sListOut);
        modeInfo.ensembleCount = numel(eListOut);
    end

    function step3_search_local_approx()
        setStep('Step 3 | Student Search');
        X = app.state.data.X_all;
        y = app.state.data.y_idx;
        C = app.state.data.C;

        if ~isfield(app.state.results,'step2Shortlist') || isempty(app.state.results.step2Shortlist)
            error('No teacher shortlist is available from Step 2.');
        end
        teacherShort = app.state.results.step2Shortlist;
        nTeacherUse = min(height(teacherShort), max(1, round(app.cfg.step3.teacherShortlistN)));
        teacherShort = teacherShort(1:nTeacherUse,:);

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

        [teacherShort, pList, lamList, aList, tList, sList, eList, modeInfo] = resolveStep3SearchMode(teacherShort, pList, lamList, aList, tList, sList, eList);
        nTeacherUse = height(teacherShort);
        if nTeacherUse < 1
            error('Step 3 mode resolution produced an empty teacher shortlist.');
        end

        teacherCatalog = repmat(struct('TeacherID',[],'Cfg',struct(),'Summary',''), nTeacherUse, 1);
        for itc = 1:nTeacherUse
            teacherCatalog(itc) = makeTeacherCandidateFromRow(teacherShort(itc,:), itc);
        end
        app.state.results.step3TeacherCatalog = teacherCatalog;
        app.state.results.step3ModeInfo = modeInfo;

        total = nTeacherUse * numel(pList) * numel(lamList) * numel(aList) * numel(tList) * numel(sList) * numel(eList);
        T = cell(total,28);
        candidateRecords = repmat(makeEmptyStep3CandidateRecord(), total, 1);
        logmsg(sprintf('Step3 | mode=%s | teacher shortlist=%d | grid=%d x %d x %d x %d x %d x %d', modeInfo.mode, nTeacherUse, numel(pList), numel(lamList), numel(aList), numel(tList), numel(sList), numel(eList)));
        logmsg(sprintf('Step3 | mode details: %s', modeInfo.description));

        idxTeacher = zeros(total,1);
        valP = zeros(total,1); valLam = zeros(total,1); valA = zeros(total,1); valT = zeros(total,1); valS = zeros(total,1); valE = zeros(total,1);
        idx = 0;
        for itc = 1:nTeacherUse
            for ip = 1:numel(pList)
                for il = 1:numel(lamList)
                    for ia = 1:numel(aList)
                        for itp = 1:numel(tList)
                            for isk = 1:numel(sList)
                                for ie = 1:numel(eList)
                                    idx = idx + 1;
                                    idxTeacher(idx) = itc;
                                    valP(idx) = pList(ip);
                                    valLam(idx) = lamList(il);
                                    valA(idx) = aList(ia);
                                    valT(idx) = tList(itp);
                                    valS(idx) = sList(isk);
                                    valE(idx) = eList(ie);
                                end
                            end
                        end
                    end
                end
            end
        end

        groupVecNow = getCurrentGroupVector(numel(y));
        usedParallel = isParallelReady(total);
        doneCount = 0;
        bestStep3Local = struct('Acc',-Inf,'MacroF1',-Inf,'WeightedF1',-Inf,'Score',-Inf);
        bestStep3LocalID = 'Waiting for best...';
        if usedParallel
            ppool = gcp('nocreate');
            logmsg(sprintf('Step3 parallel ACTIVE | teacher-cached student search | workers=%d | candidates=%d', ppool.NumWorkers, total));
        else
            logmsg(sprintf('Step3 parallel INACTIVE | teacher-cached student search | candidates=%d', total));
        end

        teacherCandidateRanges = cell(nTeacherUse,1);
        for itc = 1:nTeacherUse
            teacherCandidateRanges{itc} = find(idxTeacher == itc);
        end

        for itc = 1:nTeacherUse
            checkPauseStop();
            teacherCandidate = teacherCatalog(itc);
            teacherCfg = teacherCandidate.Cfg;
            candIdxList = teacherCandidateRanges{itc};
            if isempty(candIdxList), continue; end
            noteAction(sprintf('Step 3 | teacher %d/%d cache build | %s', itc, nTeacherUse, teacherCandidate.Summary));
            teacherCache = raven_build_teacher_cache(X, y, C, teacherCfg, app.cfg.cv.outerK, app.cfg.cv.repeats, app.cfg.cv.seedBase + 5000, app.cfg.cv.splitMode, groupVecNow);
            logmsg(sprintf('Step3 | teacher %02d cache ready | repeats=%d | folds=%d | teacher acc=%.2f%% | predict %.4f ms/spec | mem %.4f MiB/spec', ...
                teacherCandidate.TeacherID, teacherCache.Rrepeat, teacherCache.K, 100*teacherCache.AccTeacher, teacherCache.TeacherPredictMsPerSpec, teacherCache.TeacherMemMiBPerSpec));

            if usedParallel
                teacherCacheConst = parallel.pool.Constant(teacherCache);
                cleanupTeacherCache = onCleanup(@() deleteValidConstants({teacherCacheConst}));
                qCap = max(1, min(numel(candIdxList), max(1, ppool.NumWorkers)));
                futures = parallel.FevalFuture.empty(0,1);
                futureCandIdx = zeros(0,1);
                nextLocal = 1;
                noteAction(sprintf('Step 3 | teacher %d/%d running 0/%d student evaluations', itc, nTeacherUse, numel(candIdxList)));
                while nextLocal <= numel(candIdxList) || ~isempty(futures)
                    while nextLocal <= numel(candIdxList) && numel(futures) < qCap
                        globalIdx = candIdxList(nextLocal);
                        studentCfg = struct('pHidden',valP(globalIdx),'lamRidge',valLam(globalIdx),'alpha',valA(globalIdx), ...
                            'temp',valT(globalIdx),'skipScale',valS(globalIdx),'ensemble',valE(globalIdx));
                        futures(end+1,1) = parfeval(ppool, @raven_eval_student_worker, 1, teacherCacheConst, studentCfg, false, app.cfg.step4.numROC);
                        futureCandIdx(end+1,1) = globalIdx;
                        nextLocal = nextLocal + 1;
                    end
                    drawnow;
                    if app.state.stopRequested
                        if ~isempty(futures), cancel(futures); end
                        error('Stopped by user.');
                    end
                    [completedPos, res] = fetchNext(futures, 0.20);
                    if isempty(completedPos)
                        noteAction(sprintf('Step 3 | teacher %d/%d | complete %d/%d overall | queued %d/%d for current teacher', ...
                            itc, nTeacherUse, doneCount, total, min(nextLocal-1,numel(candIdxList)), numel(candIdxList)));
                        continue;
                    end
                    completedIdx = futureCandIdx(completedPos);
                    futures(completedPos) = [];
                    futureCandIdx(completedPos) = [];
                    studentCfg = struct('pHidden',valP(completedIdx),'lamRidge',valLam(completedIdx),'alpha',valA(completedIdx), ...
                        'temp',valT(completedIdx),'skipScale',valS(completedIdx),'ensemble',valE(completedIdx));
                    studentID = composeStudentConfigID(studentCfg);
                    candidateID = sprintf('T%02d__%s', teacherCandidate.TeacherID, studentID);
                    candidateRecords(completedIdx) = makeStep3CandidateRecord(candidateID, teacherCandidate, studentCfg, res);
                    T(completedIdx,:) = {candidateID, modeInfo.mode, teacherCandidate.TeacherID, teacherCandidate.Summary, ...
                        teacherCfg.kPC, teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, ...
                        studentCfg.pHidden, studentCfg.lamRidge, studentCfg.alpha, studentCfg.temp, studentCfg.skipScale, studentCfg.ensemble, ...
                        res.Acc, res.AccTeacher, res.RatioToTeacher, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, res.MemMiBPerSpec, ...
                        res.WallSec, res.WallMsPerSpec, res.PredictMsPerSpec, res.FeatDimMed, res.Score};
                    doneCount = doneCount + 1;
                    completeAction(sprintf('Step 3 | %s done (%d/%d) | %s', candidateID, doneCount, total, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)));
                    if (res.Score > bestStep3Local.Score) || (abs(res.Score-bestStep3Local.Score)<1e-12 && res.Acc > bestStep3Local.Acc) || ...
                            (abs(res.Score-bestStep3Local.Score)<1e-12 && abs(res.Acc-bestStep3Local.Acc)<1e-12 && res.MacroF1 > bestStep3Local.MacroF1)
                        bestStep3Local = res; bestStep3LocalID = candidateID;
                    end
                    updateStepChoiceAndBest('Step 3', sprintf('%s | %s', candidateID, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), ...
                        sprintf('%s | %s', bestStep3LocalID, formatActionMetrics(bestStep3Local.Acc, bestStep3Local.WeightedF1, bestStep3Local.MacroF1, bestStep3Local.Score)));
                    if mod(doneCount,5) == 1 || total <= 10
                        logmsg(sprintf('Step3 | %d/%d | %s | Acc=%.2f%% | WeightedF1=%.2f%% | Ratio=%.3f', doneCount,total,candidateID,100*res.Acc,100*res.WeightedF1,res.RatioToTeacher));
                    end
                end
                clear cleanupTeacherCache teacherCacheConst futures futureCandIdx;
            else
                for jj = 1:numel(candIdxList)
                    globalIdx = candIdxList(jj);
                    checkPauseStop();
                    noteAction(sprintf('Step 3 | teacher %d/%d | student %d/%d for current teacher', itc, nTeacherUse, jj, numel(candIdxList)));
                    studentCfg = struct('pHidden',valP(globalIdx),'lamRidge',valLam(globalIdx),'alpha',valA(globalIdx), ...
                        'temp',valT(globalIdx),'skipScale',valS(globalIdx),'ensemble',valE(globalIdx));
                    studentID = composeStudentConfigID(studentCfg);
                    candidateID = sprintf('T%02d__%s', teacherCandidate.TeacherID, studentID);
                    res = raven_eval_student_worker(teacherCache, studentCfg, false, app.cfg.step4.numROC);
                    candidateRecords(globalIdx) = makeStep3CandidateRecord(candidateID, teacherCandidate, studentCfg, res);
                    T(globalIdx,:) = {candidateID, modeInfo.mode, teacherCandidate.TeacherID, teacherCandidate.Summary, ...
                        teacherCfg.kPC, teacherCfg.mLand, teacherCfg.rTeach, teacherCfg.sigmaScale, teacherCfg.boxC, ...
                        studentCfg.pHidden, studentCfg.lamRidge, studentCfg.alpha, studentCfg.temp, studentCfg.skipScale, studentCfg.ensemble, ...
                        res.Acc, res.AccTeacher, res.RatioToTeacher, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, res.MemMiBPerSpec, ...
                        res.WallSec, res.WallMsPerSpec, res.PredictMsPerSpec, res.FeatDimMed, res.Score};
                    doneCount = doneCount + 1;
                    completeAction(sprintf('Step 3 | %s done (%d/%d) | %s', candidateID, doneCount, total, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)));
                    if (res.Score > bestStep3Local.Score) || (abs(res.Score-bestStep3Local.Score)<1e-12 && res.Acc > bestStep3Local.Acc) || ...
                            (abs(res.Score-bestStep3Local.Score)<1e-12 && abs(res.Acc-bestStep3Local.Acc)<1e-12 && res.MacroF1 > bestStep3Local.MacroF1)
                        bestStep3Local = res; bestStep3LocalID = candidateID;
                    end
                    updateStepChoiceAndBest('Step 3', sprintf('%s | %s', candidateID, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), ...
                        sprintf('%s | %s', bestStep3LocalID, formatActionMetrics(bestStep3Local.Acc, bestStep3Local.WeightedF1, bestStep3Local.MacroF1, bestStep3Local.Score)));
                    if mod(doneCount,5) == 1 || total <= 10
                        logmsg(sprintf('Step3 | %d/%d | %s | Acc=%.2f%% | WeightedF1=%.2f%% | Ratio=%.3f', doneCount,total,candidateID,100*res.Acc,100*res.WeightedF1,res.RatioToTeacher));
                    end
                end
            end
        end

        T3 = cell2table(T, 'VariableNames', ...
            {'CandidateID','Mode','TeacherID','TeacherSummary','kPC','mLand','rTeach','sigmaScale','BoxC_T','pHidden','lamRidge','alpha','temp','skipScale','ensemble', ...
             'Acc','AccTeacher','RatioToTeacher','BalAcc','WeightedAcc','MacroF1','WeightedF1','MemMiBPerSpec','WallSec','WallMsPerSpec','PredictMsPerSpec','FeatDimMed','Score'});
        T3 = T3(T3.RatioToTeacher >= app.cfg.step3.minAccRatio, :);
        if isempty(T3)
            error('No student configuration reached the minimum accuracy ratio to teacher.');
        end
        T3 = sortrows(T3, {'Score','Acc','MacroF1','WallSec'}, {'descend','descend','descend','ascend'});
        keepIDs = cellstr(string(T3.CandidateID));
        keepMask = ismember({candidateRecords.CandidateID}', keepIDs);
        candidateRecords = candidateRecords(keepMask);
        [~,ord] = ismember(keepIDs, {candidateRecords.CandidateID}');
        ord = ord(ord > 0);
        candidateRecords = candidateRecords(ord);
        app.state.results.step3Table = T3;
        app.state.results.step3Candidates = candidateRecords;
        keepN = min(height(T3), max(1, round(app.cfg.step3.shortlistN)));
        app.state.results.step3Top = T3(1:keepN,:);
        app.state.results.step3Finalists = candidateRecords(1:keepN);
        app.state.results.bestStep3 = app.state.results.step3Top(1,:);
        app.state.results.bestStep3Candidate = app.state.results.step3Finalists(1);
        Tstep3 = T3; Tstep3Top = app.state.results.step3Top; step3Candidates = candidateRecords; step3Finalists = app.state.results.step3Finalists;
        save(fullfile(app.state.outdir,'STEP3_LOCALAPPROX','STEP3_RESULTS.mat'),'Tstep3','Tstep3Top','step3Candidates','step3Finalists','-v7.3');
        tryWriteTable(T3, fullfile(app.state.outdir,'STEP3_LOCALAPPROX','STEP3_RESULTS.xlsx'),'Step3');
        buildStep3BestTeacherComparison(T3, teacherShort);
        makeStep3Plot(T3);
        bestStep3ID = getScalarTextFromTableVar(app.state.results.bestStep3, 'CandidateID');
        bestStep3Acc = getScalarNumericFromTableVar(app.state.results.bestStep3, 'Acc');
        bestStep3MacroF1 = getScalarNumericFromTableVar(app.state.results.bestStep3, 'MacroF1');
        setSummary('Best Step3', sprintf('%s | Mode=%s | Acc=%.2f%% | WeightedF1=%.2f%% | MacroF1=%.2f%%', ...
            bestStep3ID, modeInfo.mode, 100*bestStep3Acc, 100*getScalarNumericFromTableVar(app.state.results.bestStep3, 'WeightedF1'), 100*bestStep3MacroF1));
    end

    function step4_final_confirmation()
        setStep('Step 4 | Final RAVEN Confirmation');
        X = app.state.data.X_all;
        y = app.state.data.y_idx;
        C = app.state.data.C;
        if ~isfield(app.state.results,'step3Table') || isempty(app.state.results.step3Table)
            error('Step 3 results are empty.');
        end
        T3 = app.state.results.step3Table;

        [selRows, roleNames, sourceBuckets, rankInBucket] = selectStep4RowsFromStep3Table(T3);
        finalSelections = struct();
        finalistRecords = repmat(makeEmptyFinalistRecord(), 0, 1);
        summaryRows = cell(0,17);
        nSel = height(selRows);
        groupVecNow = getCurrentGroupVector(numel(y));
        teacherCfgList4 = cell(nSel,1); studentCfgList4 = cell(nSel,1); selNameList4 = cell(nSel,1); nRepList4 = zeros(nSel,1); teacherIDList4 = zeros(nSel,1); teacherSummaryList4 = cell(nSel,1); rowSerialList4 = cell(nSel,1);
        for iPrep = 1:nSel
            rowSerialList4{iPrep} = selRows(iPrep,:);
            teacherIDList4(iPrep) = double(selRows.TeacherID(iPrep));
            teacherCfgList4{iPrep} = struct('kPC',double(selRows.kPC(iPrep)),'mLand',double(selRows.mLand(iPrep)),'rTeach',double(selRows.rTeach(iPrep)),'sigmaScale',double(selRows.sigmaScale(iPrep)),'boxC',double(selRows.BoxC_T(iPrep)));
            teacherSummaryList4{iPrep} = sprintf('T%02d[k=%d,m=%d,r=%d,s=%.3g,C=%.3g]', teacherIDList4(iPrep), teacherCfgList4{iPrep}.kPC, teacherCfgList4{iPrep}.mLand, teacherCfgList4{iPrep}.rTeach, teacherCfgList4{iPrep}.sigmaScale, teacherCfgList4{iPrep}.boxC);
            studentCfgList4{iPrep} = struct('pHidden',double(selRows.pHidden(iPrep)),'lamRidge',double(selRows.lamRidge(iPrep)),'alpha',double(selRows.alpha(iPrep)),'temp',double(selRows.temp(iPrep)),'skipScale',double(selRows.skipScale(iPrep)),'ensemble',double(selRows.ensemble(iPrep)));
            selNameList4{iPrep} = roleNames{iPrep};
            nRepList4(iPrep) = getStep4RepeatCount(selNameList4{iPrep});
        end
        resSel = cell(nSel,1);
        roleOut = cell(nSel,1);
        rowOut = cell(nSel,1);
        teacherOut = cell(nSel,1);
        studentOut = cell(nSel,1);
        nRepOut = zeros(nSel,1);
        outSubList = cell(nSel,1);
        usePar4 = isParallelReady(nSel);
        doneCount = 0;
        if usePar4
            ppool = gcp('nocreate');
            futures(1:nSel,1) = parallel.FevalFuture;
            logmsg(sprintf('Step4 parallel ACTIVE across %d finalists.', nSel));
            noteAction(sprintf('Step 4 | submitted %d finalist evaluations', nSel));
            for i = 1:nSel
                row = rowSerialList4{i};
                teacherCfg = teacherCfgList4{i};
                studentCfg = studentCfgList4{i};
                nRep = nRepList4(i);
                futures(i) = parfeval(ppool, @raven_eval_student_worker, 1, X, y, C, teacherCfg, studentCfg, app.cfg.cv.outerK, nRep, app.cfg.cv.seedBase + 9000, true, app.cfg.step4.numROC, app.cfg.cv.splitMode, groupVecNow);
            end
            while doneCount < nSel
                drawnow limitrate;
                if app.state.stopRequested
                    cancel(futures);
                    error('Stopped by user.');
                end
                [completedIdx, res] = fetchNext(futures, 0.20);
                if isempty(completedIdx)
                    noteAction(sprintf('Step 4 | running %d/%d complete', doneCount, nSel));
                    continue;
                end
                row = rowSerialList4{completedIdx};
                teacherCandidate = struct('TeacherID',teacherIDList4(completedIdx),'Cfg',teacherCfgList4{completedIdx},'Summary',teacherSummaryList4{completedIdx});
                studentCfg = studentCfgList4{completedIdx};
                selName = selNameList4{completedIdx};
                nRep = nRepList4(completedIdx);
                res.SelectionName = selName;
                res.RoleName = selName;
                res.CandidateID = char(string(row.CandidateID));
                res.SourceBucket = sourceBuckets{completedIdx};
                res.RankInBucket = rankInBucket(completedIdx);
                res.cfg = struct('teacher',teacherCandidate.Cfg,'student',studentCfg);
                resSel{completedIdx} = res; roleOut{completedIdx}=selName; rowOut{completedIdx}=row; teacherOut{completedIdx}=teacherCandidate; studentOut{completedIdx}=studentCfg; nRepOut(completedIdx)=nRep;
                doneCount = doneCount + 1;
                completeAction(sprintf('Step 4 | %s done (%d/%d) | %s', selName, doneCount, nSel, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)));
                updateStepChoiceAndBest('Step 4', sprintf('%s | %s', selName, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), 'Waiting for best...');
                logmsg(sprintf('Step4 | %s done | Student Acc=%.2f%% | WeightedF1=%.2f%% | Teacher Acc=%.2f%% | Score=%.4f | Mem=%.4g MiB/spec', ...
                    selName, 100*res.Acc, 100*res.WeightedF1, 100*res.AccTeacher, res.Score, res.MemMiBPerSpec));
            end
        else
            logmsg(sprintf('Step4 parallel INACTIVE | finalists=%d', nSel));
            for i = 1:nSel
                checkPauseStop();
                noteAction(sprintf('Step 4 | finalist %d/%d', i, nSel));
                row = rowSerialList4{i};
                teacherCandidate = struct('TeacherID',teacherIDList4(i),'Cfg',teacherCfgList4{i},'Summary',teacherSummaryList4{i});
                studentCfg = studentCfgList4{i};
                selName = selNameList4{i};
                nRep = nRepList4(i);
                res = raven_eval_student_worker(X, y, C, teacherCandidate.Cfg, studentCfg, app.cfg.cv.outerK, nRep, app.cfg.cv.seedBase + 9000, true, app.cfg.step4.numROC, app.cfg.cv.splitMode, groupVecNow);
                res.SelectionName = selName;
                res.RoleName = selName;
                res.CandidateID = char(string(row.CandidateID));
                res.SourceBucket = sourceBuckets{i};
                res.RankInBucket = rankInBucket(i);
                res.cfg = struct('teacher',teacherCandidate.Cfg,'student',studentCfg);
                resSel{i} = res; roleOut{i}=selName; rowOut{i}=row; teacherOut{i}=teacherCandidate; studentOut{i}=studentCfg; nRepOut(i)=nRep;
                completeAction(sprintf('Step 4 | finalist %d/%d done (%s) | %s', i, nSel, selName, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)));
                updateStepChoiceAndBest('Step 4', sprintf('%s | %s', selName, formatActionMetrics(res.Acc, res.WeightedF1, res.MacroF1, res.Score)), 'Waiting for best...');
                logmsg(sprintf('Step4 | %s done | Student Acc=%.2f%% | WeightedF1=%.2f%% | Teacher Acc=%.2f%% | Score=%.4f | Mem=%.4g MiB/spec', ...
                    selName, 100*res.Acc, 100*res.WeightedF1, 100*res.AccTeacher, res.Score, res.MemMiBPerSpec));
            end
        end
        for i = 1:nSel
            row = rowOut{i}; teacherCandidate = teacherOut{i}; studentCfg = studentOut{i}; selName = roleOut{i}; nRep = nRepOut(i); res = resSel{i};
            outSub = fullfile(app.state.outdir,'STEP4_FINAL',selName);
            if ~exist(outSub,'dir'), mkdir(outSub); end
            makeSelectionPlots(res, outSub);
            exportSelectionTables(res, outSub);
            finalSelections.(selName) = res;
            finalistRecords(end+1,1) = makeFinalistRecord(selName, row, teacherCandidate, studentCfg, res, nRep, sourceBuckets{i}, rankInBucket(i));
            summaryRows(i,:) = {selName, char(string(row.CandidateID)), sourceBuckets{i}, rankInBucket(i), nRep, res.Acc, res.AccTeacher, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, ...
                res.RatioToTeacher, res.Score, res.WallMsPerSpec, res.MemMiBPerSpec, res.FeatDimMed, teacherCandidate.Summary};
        end

        app.state.results.finalSelections = finalSelections;
        app.state.results.finalistRecords = finalistRecords;
        save(fullfile(app.state.outdir,'STEP4_FINAL','ALL_FINAL_SELECTIONS.mat'),'finalSelections','finalistRecords','-v7.3');
        Tsel = cell2table(summaryRows, 'VariableNames', ...
            {'Selection','CandidateID','SourceBucket','RankInBucket','Repeats','StudentAcc','TeacherAcc','BalAcc','WeightedAcc','MacroF1','WeightedF1','RatioToTeacher','Score','WallMsPerSpec','MemMiBPerSpec','FeatDimMed','TeacherSummary'});
        Tsel = sortStep4SummaryTable(Tsel);
        app.state.results.finalSelectionTable = Tsel;
        exportStep4SelectionSummary(Tsel, finalSelections);

        finalKey = chooseStep4WinnerKey(Tsel);
        app.state.results.final = finalSelections.(finalKey);
        app.state.results.finalRole = finalKey;
        idxWinner = find(strcmp({finalistRecords.RoleName}, finalKey), 1, 'first');
        if isempty(idxWinner)
            idxWinner = 1;
        end
        app.state.results.finalWinnerRecord = finalistRecords(idxWinner);
        refreshLiveStatusContext();
        updateStepChoiceAndBest('Step 4', sprintf('%s | %s', finalKey, formatActionMetrics(app.state.results.final.Acc, app.state.results.final.WeightedF1, app.state.results.final.MacroF1, app.state.results.final.Score)), ...
            sprintf('%s | %s', finalKey, formatActionMetrics(app.state.results.final.Acc, app.state.results.final.WeightedF1, app.state.results.final.MacroF1, app.state.results.final.Score)));
        setSummary('Final', sprintf('%s | %s | Acc=%.2f%% | Teacher=%.2f%% | MacroF1=%.2f%% | Score=%.4f | D=%d', ...
            finalKey, app.state.results.final.CandidateID, 100*app.state.results.final.Acc, 100*app.state.results.final.AccTeacher, ...
            100*app.state.results.final.MacroF1, app.state.results.final.Score, round(app.state.results.final.FeatDimMed)));
        noteAction('Step 4 | exporting final plots...');
        makeFinalPlots(app.state.results.final);
        completeAction('Step 4 | final plots exported');
        noteAction('Step 4 | exporting final tables...');
        exportFinalTables(app.state.results.final);
        completeAction('Step 4 | final tables exported');
        noteAction('Step 4 | exporting winner package...');
        exportStep4WinnerText(finalKey, app.state.results.final, app.state.results.finalWinnerRecord, Tsel);
        saveBlindReadyModel(app.state.results.final, 'FINAL_WINNER_BLIND_MODEL.mat', finalKey);
        completeAction('Step 4 | winner package exported');
        if isfield(finalSelections,'BestAccuracy')
            saveBlindReadyModel(finalSelections.BestAccuracy, 'BestAccuracy_BLIND_MODEL.mat', 'BestAccuracy');
        end
        noteAction('Step 4 | exporting ablation suite...');
        exportAblationSuite(Tsel, finalSelections, finalKey);
        completeAction('Step 4 | ablation suite exported');
        logmsg(sprintf('Step4 final selection export completed. Winner=%s | Candidate=%s', finalKey, app.state.results.final.CandidateID));
    end

    function teacherCandidate = makeTeacherCandidateFromRow(row, teacherID)
        teacherCandidate = struct();
        teacherCandidate.TeacherID = double(teacherID);
        teacherCandidate.Cfg = struct('kPC',double(row.kPC),'mLand',double(row.mLand), ...
            'rTeach',double(row.rTeach),'sigmaScale',double(row.sigmaScale),'boxC',double(row.BoxC_T));
        teacherCandidate.Summary = sprintf('T%02d[k=%d,m=%d,r=%d,s=%.3g,C=%.3g]', ...
            teacherCandidate.TeacherID, teacherCandidate.Cfg.kPC, teacherCandidate.Cfg.mLand, ...
            teacherCandidate.Cfg.rTeach, teacherCandidate.Cfg.sigmaScale, teacherCandidate.Cfg.boxC);
    end

    function studentCfg = makeStudentConfigFromRow(row)
        studentCfg = struct('pHidden',double(row.pHidden),'lamRidge',double(row.lamRidge), ...
            'alpha',double(row.alpha),'temp',double(row.temp),'skipScale',double(row.skipScale), ...
            'ensemble',double(row.ensemble));
    end

    function s = composeStudentConfigID(studentCfg)
        s = sprintf('P%d_L%s_A%s_T%s_S%s_E%d', round(studentCfg.pHidden), ...
            strrep(sprintf('%.3g', studentCfg.lamRidge),'.','p'), ...
            strrep(sprintf('%.3g', studentCfg.alpha),'.','p'), ...
            strrep(sprintf('%.3g', studentCfg.temp),'.','p'), ...
            strrep(sprintf('%.3g', studentCfg.skipScale),'.','p'), ...
            round(studentCfg.ensemble));
    end

    function rec = makeEmptyStep3CandidateRecord()
        rec = struct('CandidateID','','TeacherID',nan,'TeacherSummary','', ...
            'TeacherCfg',struct(),'StudentCfg',struct(),'Metrics',struct(),'RankScore',nan);
    end

    function rec = makeStep3CandidateRecord(candidateID, teacherCandidate, studentCfg, res)
        rec = makeEmptyStep3CandidateRecord();
        rec.CandidateID = candidateID;
        rec.TeacherID = teacherCandidate.TeacherID;
        rec.TeacherSummary = teacherCandidate.Summary;
        rec.TeacherCfg = teacherCandidate.Cfg;
        rec.StudentCfg = studentCfg;
        rec.Metrics = res;
        rec.RankScore = res.Score;
    end

    function rec = makeEmptyFinalistRecord()
        rec = struct('RoleName','','CandidateID','','TeacherID',nan,'TeacherSummary','', ...
            'TeacherCfg',struct(),'StudentCfg',struct(),'Metrics',struct(),'Repeats',nan, ...
            'SourceBucket','','RankInBucket',nan);
    end

    function rec = makeFinalistRecord(roleName, row, teacherCandidate, studentCfg, res, nRep, sourceBucket, rankInBucket)
        rec = makeEmptyFinalistRecord();
        rec.RoleName = roleName;
        rec.CandidateID = char(string(row.CandidateID));
        rec.TeacherID = teacherCandidate.TeacherID;
        rec.TeacherSummary = teacherCandidate.Summary;
        rec.TeacherCfg = teacherCandidate.Cfg;
        rec.StudentCfg = studentCfg;
        rec.Metrics = res;
        rec.Repeats = nRep;
        rec.SourceBucket = sourceBucket;
        rec.RankInBucket = rankInBucket;
    end

    function [selRows, roleNames, sourceBuckets, rankInBucket] = selectStep4RowsFromStep3Table(T3)
        if isempty(T3)
            error('Step 4 selection requires a non-empty Step 3 table.');
        end
        topN = 1;
        if isfield(app.cfg.step4,'topFinalistsPerBucket') && ~isempty(app.cfg.step4.topFinalistsPerBucket)
            topN = max(1, round(app.cfg.step4.topFinalistsPerBucket));
        end
        accThr = app.cfg.step4.accThresholdFrac * max(T3.Acc);
        Tthr = T3(T3.Acc >= accThr,:);
        if isempty(Tthr)
            Tthr = T3(1:min(max(topN,5),height(T3)),:);
        end

        bucketDefs = { ...
            'BestAccuracy', sortrows(T3, {'Acc','Score','MacroF1','WallMsPerSpec'}, {'descend','descend','descend','ascend'}); ...
            'BestScore', sortrows(T3, {'Score','Acc','MacroF1','WallMsPerSpec'}, {'descend','descend','descend','ascend'}); ...
            'BestSpeed', sortrows(Tthr, {'WallMsPerSpec','Acc','Score'}, {'ascend','descend','descend'}); ...
            'BestMemory', sortrows(Tthr, {'MemMiBPerSpec','Acc','Score'}, {'ascend','descend','descend'}) ...
            };

        selRows = T3([],:);
        roleNames = {};
        sourceBuckets = {};
        rankInBucket = zeros(0,1);
        seen = containers.Map('KeyType','char','ValueType','logical');
        for b = 1:size(bucketDefs,1)
            bucketName = bucketDefs{b,1};
            Tb = bucketDefs{b,2};
            takeN = min(topN, height(Tb));
            added = 0;
            j = 1;
            while j <= height(Tb) && added < takeN
                row = Tb(j,:);
                cid = char(string(row.CandidateID));
                if ~isKey(seen, cid)
                    seen(cid) = true;
                    added = added + 1;
                    selRows = [selRows; row];
                    roleNames{end+1,1} = sprintf('%s_%02d', bucketName, added);
                    sourceBuckets{end+1,1} = bucketName;
                    rankInBucket(end+1,1) = j;
                end
                j = j + 1;
            end
        end
        if isempty(roleNames)
            selRows = T3(1,:);
            roleNames = {'BestScore_01'};
            sourceBuckets = {'BestScore'};
            rankInBucket = 1;
        end
    end

    function Tsel = sortStep4SummaryTable(Tsel)
        if isempty(Tsel)
            return;
        end
        winnerPolicy = 'bestscore';
        if isfield(app.cfg.step4,'winnerPolicy') && ~isempty(app.cfg.step4.winnerPolicy)
            winnerPolicy = lower(string(app.cfg.step4.winnerPolicy));
        elseif isfield(app.cfg.step4,'finalSelectionPolicy') && ~isempty(app.cfg.step4.finalSelectionPolicy)
            winnerPolicy = lower(string(app.cfg.step4.finalSelectionPolicy));
        end
        if strcmp(winnerPolicy,'bestaccuracy')
            Tsel = sortrows(Tsel, {'StudentAcc','Score','WallMsPerSpec','MemMiBPerSpec'}, {'descend','descend','ascend','ascend'});
        else
            Tsel = sortrows(Tsel, {'Score','StudentAcc','WallMsPerSpec','MemMiBPerSpec'}, {'descend','descend','ascend','ascend'});
        end
    end

    function finalKey = chooseStep4WinnerKey(Tsel)
        Tsel = sortStep4SummaryTable(Tsel);
        if isempty(Tsel)
            error('Step 4 winner selection received an empty finalist table.');
        end
        finalKey = char(string(Tsel.Selection(1)));
    end

    function nRep = getStep4RepeatCount(selName)
        if strcmpi(selName,'BestAccuracy')
            nRep = app.cfg.step4.repeatsBestAccuracy;
        elseif strcmpi(selName,'BestScore')
            nRep = app.cfg.step4.repeatsBestScore;
        elseif strcmpi(selName,'LowestMemoryAboveThreshold')
            nRep = app.cfg.step4.repeatsBestMemory;
        else
            nRep = app.cfg.step4.repeatsFast;
        end
    end
