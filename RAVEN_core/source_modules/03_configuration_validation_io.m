    function syncCfgFromUI()
        app.cfg.io.dataSource = strtrim(get(app.ui.edData,'String'));
        app.cfg.io.saveBaseDir = strtrim(get(app.ui.edSave,'String'));
        app.cfg.io.rootName = strtrim(get(app.ui.edRoot,'String'));
        app.cfg.io.autoDetectGroups = logical(get(app.ui.chkAutoDetect,'Value'));
        app.cfg.cv.useParallel = logical(get(app.ui.chkParallel,'Value'));
        if isfield(app.ui,'popWorkers') && ishandle(app.ui.popWorkers)
            vals = get(app.ui.popWorkers,'String');
            vIdx = get(app.ui.popWorkers,'Value');
            if iscell(vals) && ~isempty(vals) && vIdx >= 1 && vIdx <= numel(vals)
                app.cfg.cv.nWorkers = max(1, round(str2double(vals{vIdx})));
            end
        end
        if isfield(app.cfg,'step0') && isfield(app.cfg.step0,'inputMode') && ~isempty(app.cfg.step0.inputMode)
            app.cfg.io.inputMode = app.cfg.step0.inputMode;
        end
        if ~isfield(app.cfg.preproc,'enabled')
            app.cfg.preproc.enabled = true;
        end
        updateUploadedFilesList();
        refreshLiveStatusContext();
    end

    function setQuickTableFromCfg()

    end

    function selNames = getSelectedNamesForValidation(allNames)
        if nargin < 1 || isempty(allNames)
            allNames = {};
        end
        if isfield(app.cfg,'preproc') && isfield(app.cfg.preproc,'includeNames') && ~isempty(app.cfg.preproc.includeNames)
            selNames = intersect(allNames, app.cfg.preproc.includeNames, 'stable');
        else
            selNames = allNames;
        end
    end

    function updateValidationPanel()
        msgs = {};
        splitInfo = getSplitValidationInfo();
        app.cfg.cv.groupCount = splitInfo.numGroups;
        gv = splitInfo;
        if isfield(gv,'displayStatus')
            gv = rmfield(gv, {'displayStatus'});
        end
        app.cfg.cv.groupValidation = gv;
        if isfield(app.ui,'txtGroupStatus') && ishghandle(app.ui.txtGroupStatus)
            try
                set(app.ui.txtGroupStatus,'String',splitInfo.displayStatus);
            catch
            end
        end
        if isempty(strtrim(app.cfg.io.dataSource))
            msgs{end+1} = '[OK] Waiting for dataset selection.';
        else
            msgs{end+1} = '[OK] Data source selected.';
        end
        msgs{end+1} = sprintf('[OK] Split mode: %s.', app.cfg.cv.splitMode);
        if isempty(strtrim(app.cfg.io.saveBaseDir))
            msgs{end+1} = '[BLOCK] Save folder is empty.';
        elseif exist(app.cfg.io.saveBaseDir,'dir')~=7
            msgs{end+1} = '[WARN] Save folder does not exist yet.';
        else
            msgs{end+1} = '[OK] Save folder is valid.';
        end
        if isempty(app.state.detectedData)
            msgs{end+1} = '[WARN] No dataset has been pre-detected yet.';
        else
            data = app.state.detectedData;
            selNames = getSelectedNamesForValidation(data.groupNames);
            if isfield(data,'isFeatureMatrix') && data.isFeatureMatrix
                counts = accumarray(double(data.y_idx(:)),1,[numel(data.groupNames),1]);
                dCount = size(data.X_all,2);
                if numel(selNames) < 2
                    msgs{end+1} = '[BLOCK] Fewer than 2 classes are selected for the pipeline.';
                else
                    msgs{end+1} = sprintf('[OK] %d class(es) selected for run.', numel(selNames));
                end
                if max(app.cfg.step1.kPCList) >= dCount
                    msgs{end+1} = '[WARN] kPC list reaches or exceeds the feature count.';
                else
                    msgs{end+1} = '[OK] kPC range is within feature-count range.';
                end
                if max(app.cfg.step2.D0List) > max(app.cfg.step1.kPCList)
                    msgs{end+1} = '[WARN] Some D0 values exceed the largest kPC.';
                else
                    msgs{end+1} = '[OK] D0 values are compatible with kPC range.';
                end
                if max(app.cfg.step3.mLandList) >= min(counts)
                    msgs{end+1} = '[WARN] mLand is high relative to the smallest class size.';
                else
                    msgs{end+1} = '[OK] Landmark counts look safe for class sizes.';
                end
                msgs{end+1} = '[OK] Feature-matrix mode active: spectral crop controls are ignored.';
            else
                counts = cellfun(@(b) size(b,2)-1, data.blocks);
                xvec = data.blocks{1}(:,1);
                if numel(selNames) < 2
                    msgs{end+1} = '[BLOCK] Fewer than 2 classes are selected for the pipeline.';
                else
                    msgs{end+1} = sprintf('[OK] %d class(es) selected for run.', numel(selNames));
                end
                if max(app.cfg.step1.kPCList) >= numel(xvec)
                    msgs{end+1} = '[WARN] kPC list reaches or exceeds the number of spectral variables.';
                else
                    msgs{end+1} = '[OK] kPC range is within spectral-variable count.';
                end
                if max(app.cfg.step2.D0List) > max(app.cfg.step1.kPCList)
                    msgs{end+1} = '[WARN] Some D0 values exceed the largest kPC.';
                else
                    msgs{end+1} = '[OK] D0 values are compatible with kPC range.';
                end
                if max(app.cfg.step3.mLandList) >= min(counts)
                    msgs{end+1} = '[WARN] mLand is high relative to the smallest class size.';
                else
                    msgs{end+1} = '[OK] Landmark counts look safe for class sizes.';
                end
                xmin = app.cfg.preproc.xMin; xmax = app.cfg.preproc.xMax;
                if ~isempty(xmin) && ~isempty(xmax)
                    if xmin >= xmax
                        msgs{end+1} = '[BLOCK] Crop range is invalid: Min must be smaller than Max.';
                    elseif xmin < min(xvec) || xmax > max(xvec)
                        msgs{end+1} = '[WARN] Crop range extends beyond the detected spectral axis.';
                    else
                        msgs{end+1} = '[OK] Crop range is inside the detected spectral axis.';
                    end
                else
                    msgs{end+1} = '[OK] Full spectral range will be used.';
                end
            end
        end
        if strcmpi(app.cfg.cv.splitMode,'grouped')
            if ~splitInfo.present
                msgs{end+1} = '[BLOCK] Grouped split selected but no groupVector is loaded.';
            elseif ~splitInfo.validLength
                msgs{end+1} = sprintf('[BLOCK] groupVector length mismatch: expected %d, got %d.', splitInfo.expectedLength, splitInfo.actualLength);
            elseif splitInfo.hasMissing
                msgs{end+1} = '[BLOCK] groupVector contains missing or empty values.';
            elseif ~splitInfo.sufficientForKFold
                msgs{end+1} = sprintf('[BLOCK] Only %d unique groups for K=%d grouped CV.', splitInfo.numGroups, splitInfo.requiredGroups);
            elseif ~splitInfo.classWiseSufficient
                msgs{end+1} = sprintf('[WARN] Some classes span fewer than %d unique groups.', splitInfo.requiredGroups);
            else
                msgs{end+1} = sprintf('[OK] groupVector valid: %d unique groups for grouped CV.', splitInfo.numGroups);
            end
            if splitInfo.fallbackUsed
                msgs{end+1} = sprintf('[WARN] Effective split mode will fall back to %s. Reason: %s', splitInfo.effectiveMode, splitInfo.fallbackReason);
            end
        else
            if splitInfo.present && splitInfo.validLength && ~splitInfo.hasMissing
                msgs{end+1} = sprintf('[OK] groupVector loaded (%d groups); stratified split currently selected.', splitInfo.numGroups);
            else
                msgs{end+1} = '[OK] Ungrouped stratified validation selected.';
            end
        end
        if isempty(msgs)
            msgs = {'[OK] Ready.'};
        end
        if isfield(app.ui,'lstValidation') && ishghandle(app.ui.lstValidation)
            set(app.ui.lstValidation,'String',msgs,'Value',1);
        end
    end

    function x = parseNumList(s)
        s = strrep(s,'[','');
        s = strrep(s,']','');
        s = strrep(s,',',' ');
        x = str2num(s);
        if isempty(x), x = []; end
    end

    function x = ravenGetField(S, fieldName, defaultVal)
        x = defaultVal;
        if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
            x = S.(fieldName);
        end
    end

    function methods = parseMethodList(s)
        methods = {};
        if nargin < 1 || isempty(s), return; end
        if iscell(s)
            methods = s(:)';
        else
            s = char(string(s));
            s = strrep(s, ',', ' ');
            parts = strsplit(strtrim(s));
            methods = parts(~cellfun('isempty', parts));
        end
        valid = {'PCA_LINSVM','PCA_LDA','PCA_RF'};
        keep = false(size(methods));
        for ii = 1:numel(methods)
            methods{ii} = upper(char(string(methods{ii})));
            keep(ii) = any(strcmpi(methods{ii}, valid));
        end
        methods = methods(keep);
        if isempty(methods)
            methods = {'PCA_LINSVM','PCA_LDA','PCA_RF'};
        end
    end

    function nAvail = getAvailableWorkerCount()
        try
            nAvail = feature('numcores');
        catch
            try
                ctmp = parcluster('local');
                nAvail = ctmp.NumWorkers;
            catch
                nAvail = 1;
            end
        end
        if isempty(nAvail) || ~isfinite(nAvail) || nAvail < 1
            nAvail = 1;
        end
        nAvail = max(1, round(nAvail));
    end

    function entries = parseDataSourceEntries(dataSource)
        if isempty(dataSource)
            entries = {};
            return;
        end
        if iscell(dataSource)
            entries = dataSource(:)';
            entries = entries(~cellfun(@isempty,entries));
            return;
        end
        s = char(dataSource);
        s = strrep(s, char(13), char(10));
        parts = regexp(s, '[;\n\r]+', 'split');
        entries = {};
        for ii = 1:numel(parts)
            t = strtrim(parts{ii});
            if ~isempty(t)
                entries{end+1} = t;
            end
        end
        if isempty(entries) && ~isempty(strtrim(s))
            entries = {strtrim(s)};
        end
    end

    function sig = dataSignatureForTune(data)
        try
            if isfield(data,'isFeatureMatrix') && data.isFeatureMatrix
                counts = accumarray(double(data.y_idx(:)),1,[numel(data.groupNames),1]);
                Dsig = size(data.X_all,2);
            else
                counts = cellfun(@(b) size(b,2)-1, data.blocks);
                Dsig = max(cellfun(@(b) size(b,1), data.blocks));
            end
            sig = sprintf('%d|%d|%d|%d', numel(data.groupNames), sum(counts), min(counts), Dsig);
        catch
            sig = sprintf('rand_%d', randi(1e9));
        end
    end

    function applyRecommendedSettingsForData(data)
        if isempty(data)
            return;
        end
        if isfield(data,'isFeatureMatrix') && data.isFeatureMatrix
            counts = accumarray(double(data.y_idx(:)),1,[numel(data.groupNames),1]);
            D = size(data.X_all,2);
        else
            if ~isfield(data,'blocks') || isempty(data.blocks)
                return;
            end
            counts = cellfun(@(b) max(0,size(b,2)-1), data.blocks);
            D = max(cellfun(@(b) size(b,1), data.blocks));
        end
        C = numel(counts);
        N = sum(counts);
        minClass = max(1,min(counts));
        availWorkers = getAvailableWorkerCount();

        if minClass >= 50
            app.cfg.cv.outerK = 5;
        elseif minClass >= 25
            app.cfg.cv.outerK = 4;
        else
            app.cfg.cv.outerK = 3;
        end
        if N >= 4000
            app.cfg.cv.repeats = 1;
        elseif N >= 1200
            app.cfg.cv.repeats = 2;
        else
            app.cfg.cv.repeats = 3;
        end

        if ~app.cfg.cv.useParallel
            suggestedWorkers = app.cfg.cv.nWorkers;
        else
            suggestedWorkers = min(availWorkers, max(1, ceil(N/600)));
        end
        suggestedWorkers = max(1, min(availWorkers, suggestedWorkers));
        app.cfg.cv.nWorkers = suggestedWorkers;
        if isfield(app.ui,'popWorkers') && ishandle(app.ui.popWorkers)
            strs = get(app.ui.popWorkers,'String');
            if iscell(strs) && ~isempty(strs)
                set(app.ui.popWorkers,'Value', min(max(1,suggestedWorkers), numel(strs)));
            end
        end

        kCap = min([60, max(8, D-1), max(8, minClass-2)]);
        if kCap <= 14
            kList = unique(max(4, round(linspace(4, kCap, min(4, max(2,kCap-3))))));
        elseif kCap <= 30
            kList = unique(max(6, round(linspace(10, kCap, 5))));
        else
            base = [20 30 40 50 60];
            kList = unique(base(base <= kCap));
            if isempty(kList)
                kList = unique(round(linspace(max(6,min(10,kCap)), kCap, min(5, max(2, floor(kCap/5))))));
            end
        end
        app.cfg.step1.kPCList = unique(max(2, kList));
        kPCmax = max(app.cfg.step1.kPCList);
        app.cfg.step1.baselineD0 = min(15, max(4, kPCmax));

        rCapByClass = max(4, 2*C);
        rCapByOccup = max(4, floor(minClass/20));
        rMax = min([12, rCapByClass, max(4,rCapByOccup)]);
        app.cfg.step2.RList = unique([4, 6:2:rMax]);
        app.cfg.step2.RList = app.cfg.step2.RList(app.cfg.step2.RList >= 4 & app.cfg.step2.RList <= rMax);
        if isempty(app.cfg.step2.RList), app.cfg.step2.RList = 4; end

        d0Base = [8 12 16 20];
        d0Cap = max(4, min(20, kPCmax));
        d0List = unique(d0Base(d0Base <= d0Cap));
        if isempty(d0List), d0List = max(4, min(kPCmax,8)); end
        app.cfg.step2.D0List = d0List;
        app.cfg.step2.tauScaleList = [0.5 0.75 1.0 1.25 1.5];
        app.cfg.step2.kmeansReplicates = min(10, max(3, round(min(8, C+2))));

        mCap = max(8, floor(minClass/2));
        mBase = [16 24 32 48 64 96 128];
        mList = unique(mBase(mBase <= mCap));
        if isempty(mList)
            mList = max(8, min(16, mCap));
        end
        app.cfg.step3.mLandList = unique(max(8, round(mList)));
        dlocBase = [12 16 20 24 32];
        dlocCap = max(4, min([32, kPCmax, max(app.cfg.step3.mLandList)]));
        dlocList = unique(dlocBase(dlocBase <= dlocCap));
        if isempty(dlocList), dlocList = max(4, min(12,dlocCap)); end
        app.cfg.step3.DlocList = unique(max(4, round(dlocList)));
        app.cfg.step3.rhoList = [0.90 0.95 0.98];
        app.cfg.step3.ridgeList = [1e-8 1e-6 1e-4];
        app.cfg.step3.sigmaScaleList = [0.75 1.0 1.25];
        if N >= 5000
            app.cfg.step3.CList = [0.1 1];
        else
            app.cfg.step3.CList = [0.1 1 10];
        end

        if N >= 4000
            rep4 = 2;
        else
            rep4 = 3;
        end
        app.cfg.step4.repeatsBestAccuracy = rep4;
        app.cfg.step4.repeatsBestScore = rep4;
        app.cfg.step4.repeatsBestMemory = rep4;
        app.cfg.step4.numROC = 200;

        setQuickTableFromCfg();
        setSummary('AutoTune', sprintf('N=%d | C=%d | D=%d | min/class=%d', N, C, D, minClass));
        logmsg(sprintf('Auto-updated search settings for dataset size: C=%d, N=%d, D=%d, min/class=%d.', C, N, D, minClass));
    end

    function applyPreset(mode)
        syncCfgFromUI();
        userKPCList = [];
        userPcaMode = 'fixedlist';
        userSingleKPC = [];
        userSingleFlag = false;
        if isfield(app,'cfg') && isfield(app.cfg,'step1')
            if isfield(app.cfg.step1,'kPCList') && ~isempty(app.cfg.step1.kPCList)
                userKPCList = unique(max(1, round(app.cfg.step1.kPCList(:)')), 'stable');
            end
            if isfield(app.cfg.step1,'pcaMode') && ~isempty(app.cfg.step1.pcaMode)
                userPcaMode = lower(strtrim(app.cfg.step1.pcaMode));
            end
            if isfield(app.cfg.step1,'singleKPC')
                userSingleKPC = app.cfg.step1.singleKPC;
            end
            if isfield(app.cfg.step1,'singleKPCEnable')
                userSingleFlag = logical(app.cfg.step1.singleKPCEnable);
            end
        end
        if nargin < 1 || isempty(mode)
            mode = 'Accurate';
        end
        mode = char(mode);
        data = [];
        if isfield(app.state,'detectedData') && ~isempty(app.state.detectedData)
            data = app.state.detectedData;
        end
        defs = makeDefaultConfig();
        switch lower(mode)
            case 'quick'
                if ~isempty(data)
                    applyRecommendedSettingsForData(data);
                else
                    app.cfg.step1.kPCList = defs.step1.kPCList;
                    app.cfg.step2.RList = defs.step2.RList;
                    app.cfg.step2.D0List = defs.step2.D0List;
                    app.cfg.step3.mLandList = defs.step3.mLandList;
                    app.cfg.step3.DlocList = defs.step3.DlocList;
                end
                app.cfg.cv.outerK = max(3, min(app.cfg.cv.outerK, 4));
                app.cfg.cv.repeats = 1;
                if numel(app.cfg.step2.RList) > 3
                    app.cfg.step2.RList = unique(app.cfg.step2.RList(1:3));
                end
                if numel(app.cfg.step2.D0List) > 2
                    app.cfg.step2.D0List = unique(app.cfg.step2.D0List(1:2));
                end
                app.cfg.step2.tauScaleList = [0.75 1.0 1.25];
                app.cfg.step2.kmeansReplicates = max(2, min(app.cfg.step2.kmeansReplicates, 3));
                if numel(app.cfg.step3.mLandList) > 3
                    app.cfg.step3.mLandList = unique(app.cfg.step3.mLandList(1:3));
                end
                if numel(app.cfg.step3.DlocList) > 2
                    app.cfg.step3.DlocList = unique(app.cfg.step3.DlocList(1:2));
                end
                app.cfg.step3.rhoList = [0.90 0.95];
                app.cfg.step3.CList = [0.1 1];
                app.cfg.step4.repeatsBestAccuracy = 1;
                app.cfg.step4.repeatsBestScore = 1;
                app.cfg.step4.repeatsBestMemory = 1;
                app.cfg.step4.numROC = 100;
            case 'accurate'
                if ~isempty(data)
                    applyRecommendedSettingsForData(data);
                else
                    app.cfg.cv.outerK = defs.cv.outerK;
                    app.cfg.cv.repeats = defs.cv.repeats;
                    app.cfg.step1 = defs.step1;
                    app.cfg.step2 = defs.step2;
                    app.cfg.step3 = defs.step3;
                    app.cfg.step4 = defs.step4;
                end
            case 'publish'
                if ~isempty(data)
                    applyRecommendedSettingsForData(data);
                    counts = cellfun(@(b) max(0,size(b,2)-1), data.blocks);
                    minClass = max(1,min(counts));
                    kPCmax = max(app.cfg.step1.kPCList);
                    app.cfg.cv.outerK = max(5, app.cfg.cv.outerK);
                    app.cfg.cv.repeats = max(3, app.cfg.cv.repeats);
                    app.cfg.step1.kPCList = unique(sort([app.cfg.step1.kPCList, min(kPCmax,20), min(kPCmax,30), min(kPCmax,40), min(kPCmax,50), min(kPCmax,60)]));
                    app.cfg.step2.RList = unique(sort([app.cfg.step2.RList, 4 6 8 10 12]));
                    app.cfg.step2.RList = app.cfg.step2.RList(app.cfg.step2.RList <= max(4,floor(minClass/10)) | app.cfg.step2.RList<=12);
                    app.cfg.step2.D0List = unique(sort([app.cfg.step2.D0List, 8 12 16 20]));
                    app.cfg.step2.D0List = app.cfg.step2.D0List(app.cfg.step2.D0List <= max(app.cfg.step1.kPCList));
                    app.cfg.step2.tauScaleList = [0.5 0.75 1.0 1.25 1.5];
                    mcap = max(8,floor(minClass/2));
                    app.cfg.step3.mLandList = unique(sort([app.cfg.step3.mLandList, [16 24 32 48 64 96 128]]));
                    app.cfg.step3.mLandList = app.cfg.step3.mLandList(app.cfg.step3.mLandList <= mcap);
                    app.cfg.step3.DlocList = unique(sort([app.cfg.step3.DlocList, [12 16 20 24 32]]));
                    app.cfg.step3.DlocList = app.cfg.step3.DlocList(app.cfg.step3.DlocList <= max(app.cfg.step1.kPCList));
                else
                    app.cfg.cv.outerK = max(5, defs.cv.outerK);
                    app.cfg.cv.repeats = 3;
                    app.cfg.step1 = defs.step1;
                    app.cfg.step2 = defs.step2;
                    app.cfg.step3 = defs.step3;
                    app.cfg.step4 = defs.step4;
                end
                app.cfg.step3.rhoList = [0.90 0.95 0.98];
                app.cfg.step3.CList = [0.1 1 10];
                app.cfg.step4.repeatsBestAccuracy = 5;
                app.cfg.step4.repeatsBestScore = 5;
                app.cfg.step4.repeatsBestMemory = 5;
                app.cfg.step4.makeROC = true;
                app.cfg.step4.numROC = 400;
            otherwise
                return;
        end
        if ~isempty(userKPCList)
            app.cfg.step1.kPCList = userKPCList;
            if numel(userKPCList) > 1
                app.cfg.step1.pcaMode = 'fixedlist';
                app.cfg.step1.singleKPCEnable = false;
            else
                app.cfg.step1.pcaMode = 'single';
                app.cfg.step1.singleKPCEnable = true;
                app.cfg.step1.singleKPC = userKPCList(1);
            end
        else
            app.cfg.step1.pcaMode = userPcaMode;
            app.cfg.step1.singleKPCEnable = userSingleFlag;
            if ~isempty(userSingleKPC)
                app.cfg.step1.singleKPC = userSingleKPC;
            end
        end
        app.cfg.step2.D0List = unique(app.cfg.step2.D0List(app.cfg.step2.D0List <= max(app.cfg.step1.kPCList)));
        if isempty(app.cfg.step2.D0List)
            app.cfg.step2.D0List = min(max(app.cfg.step1.kPCList), 8);
        end
        app.cfg.step3.DlocList = unique(app.cfg.step3.DlocList(app.cfg.step3.DlocList <= max(app.cfg.step1.kPCList)));
        if isempty(app.cfg.step3.DlocList)
            app.cfg.step3.DlocList = min(max(app.cfg.step1.kPCList), 12);
        end
        setSummary('Preset', mode);
        setLiveStatus('Preset', mode);
        refreshPlan();
        logmsg(sprintf('Preset applied: %s', mode));
    end

    function onPresetQuick(~,~)
        applyPreset('Quick');
    end

    function onPresetAccurate(~,~)
        applyPreset('Accurate');
    end

    function onPresetPublish(~,~)
        applyPreset('Publish');
    end

    function ok = detectDatasetNow(showPopup)
        if nargin < 1, showPopup = false; end
        ok = false;
        try
            srcNow = strtrim(get(app.ui.edData,'String'));
        catch
            srcNow = app.cfg.io.dataSource;
        end
        if isempty(srcNow)
            app.state.detectedData = [];
            app.state.detectedSource = '';
            updateUploadedFilesList();
            refreshLiveStatusContext();
            return;
        end
        try
            data = loadDynamicDataset(srcNow, true);
            app.state.detectedData = data;
            app.state.detectedSource = srcNow;
            ok = true;
            sigNow = dataSignatureForTune(data);
            if ~strcmp(app.state.lastAutoTuneSignature, sigNow)
                applyRecommendedSettingsForData(data);
                app.state.lastAutoTuneSignature = sigNow;
            end
            logmsg(sprintf('Pre-detected %d class(es) from selected source.', numel(data.groupNames)));
            updateUploadedFilesList();
            refreshLiveStatusContext();
            setSummary('Classes', sprintf('%d detected class(es)', numel(data.groupNames)));
            if isfield(app.ui,'pp') && isfield(app.ui.pp,'lstClasses') && isfield(app.ui,'preprocFig') && ~isempty(app.ui.preprocFig) && isvalid(app.ui.preprocFig)
                tmpLines = cell(numel(data.groupNames),1);
                if isfield(data,'isFeatureMatrix') && data.isFeatureMatrix
                    counts = accumarray(double(data.y_idx(:)),1,[numel(data.groupNames),1]);
                    for kk = 1:numel(data.groupNames)
                        tmpLines{kk} = sprintf('%02d  %s (n=%d, D=%d) [feature-matrix]', kk, data.groupNames{kk}, counts(kk), size(data.X_all,2));
                    end
                else
                    for kk = 1:numel(data.groupNames)
                        tmpLines{kk} = sprintf('%02d  %s (n=%d)', kk, data.groupNames{kk}, size(data.blocks{kk},2)-1);
                    end
                end
                if isempty(tmpLines)
                    tmpLines = {'No classes loaded'};
                end
                try
                    set(app.ui.pp.lstClasses,'String',tmpLines,'Value',1);
                catch
                end
            end
        catch ME
            app.state.detectedData = [];
            app.state.detectedSource = srcNow;
            updateUploadedFilesList();
            refreshLiveStatusContext();
            setSummary('Classes','Detection failed');
            logmsg(sprintf('Dataset detection failed: %s', ME.message));
            if showPopup
                errordlg(sprintf('Could not detect classes from the selected source.\n\n%s', ME.message), 'RAVEN Detection');
            end
        end
    end

    function updateUploadedFilesList()
        if ~isfield(app,'ui') || ~isfield(app.ui,'lstFiles') || ~ishandle(app.ui.lstFiles)
            return;
        end
        srcNow = strtrim(get(app.ui.edData,'String'));
        entries = parseDataSourceEntries(srcNow);
        shown = {};
        if ~isempty(app.state.detectedData) && isfield(app.state.detectedData,'groupNames') && ...
                strcmp(strtrim(app.state.detectedSource), srcNow)
            data = app.state.detectedData;
            shown = cell(numel(data.groupNames),1);
            if isfield(data,'isFeatureMatrix') && data.isFeatureMatrix
                counts = accumarray(double(data.y_idx(:)),1,[numel(data.groupNames),1]);
                for ii = 1:numel(data.groupNames)
                    shown{ii} = sprintf('%02d  %s (n=%d, D=%d) [feature-matrix]', ii, data.groupNames{ii}, counts(ii), size(data.X_all,2));
                end
            else
                for ii = 1:numel(data.groupNames)
                    srcLabel = '';
                    if isfield(data,'sourceLabels') && numel(data.sourceLabels) >= ii && ~isempty(data.sourceLabels{ii})
                        srcLabel = data.sourceLabels{ii};
                    end
                    nsp = size(data.blocks{ii},2)-1;
                    if isempty(srcLabel)
                        shown{ii} = sprintf('%02d  %s (n=%d)', ii, data.groupNames{ii}, nsp);
                    else
                        shown{ii} = sprintf('%02d  %s  <-  %s  (n=%d)', ii, data.groupNames{ii}, srcLabel, nsp);
                    end
                end
            end
            if isempty(shown)
                shown = {'No classes detected'};
            end
            setSummary('Dataset', sprintf('%d detected class(es)', numel(data.groupNames)));
            set(app.ui.lstFiles,'String',shown,'Value',1);
            return;
        end
        if isempty(entries)
            shown = {'No files selected'};
            setSummary('Dataset','Not loaded');
        elseif numel(entries)==1 && exist(entries{1},'dir')==7
            d = dir(entries{1});
            sup = {'.mat','.csv','.txt','.xlsx','.xls'};
            files = {};
            for ii = 1:numel(d)
                if d(ii).isdir, continue; end
                [~,nm,ext] = fileparts(d(ii).name);
                if ismember(lower(ext),sup)
                    files{end+1} = sprintf('%s   ->   %s', d(ii).name, matlab.lang.makeValidName(nm));
                end
            end
            if isempty(files)
                shown = {'Folder selected, but no supported files found'};
                setSummary('Dataset','Folder selected | 0 supported files');
            else
                shown = files;
                setSummary('Dataset',sprintf('Folder | %d supported file(s)', numel(files)));
            end
        else
            shown = cell(1,numel(entries));
            for ii = 1:numel(entries)
                [~,fname,ext] = fileparts(entries{ii});
                if isempty(ext)
                    shown{ii} = entries{ii};
                else
                    shown{ii} = sprintf('%s%s   ->   %s', fname, ext, matlab.lang.makeValidName(fname));
                end
            end
            setSummary('Dataset',sprintf('%d selected file(s)', numel(entries)));
        end
        set(app.ui.lstFiles,'String',shown,'Value',1);
    end

    function onBrowseFolder(~,~)
        p = uigetdir(pwd,'Select dataset folder');
        if isequal(p,0), return; end
        app.state.selectedFiles = {};
        set(app.ui.edData,'String',p);
        detectDatasetNow(false);
        refreshPlan();
    end

    function onBrowseMat(~,~)
        [f,p] = uigetfile({ ...
            '*.mat;*.csv;*.txt;*.xlsx;*.xls','Supported table files (*.mat, *.csv, *.txt, *.xlsx, *.xls)'; ...
            '*.mat','MAT files (*.mat)'; ...
            '*.csv','CSV files (*.csv)'; ...
            '*.txt','Text files (*.txt)'; ...
            '*.xlsx;*.xls','Excel files (*.xlsx, *.xls)'}, ...
            'Select one or more class files','MultiSelect','on');
        if isequal(f,0), return; end
        if iscell(f)
            fulls = cellfun(@(x) fullfile(p,x), f, 'UniformOutput', false);
            app.state.selectedFiles = fulls;
            set(app.ui.edData,'String',strjoin(fulls,'; '));
        else
            app.state.selectedFiles = {fullfile(p,f)};
            set(app.ui.edData,'String',fullfile(p,f));
        end
        detectDatasetNow(false);
        refreshPlan();
    end

    function onBrowseSave(~,~)
        p = uigetdir(pwd,'Select output folder');
        if isequal(p,0), return; end
        set(app.ui.edSave,'String',p);
        refreshPlan();
    end

    function onDataSourceEdited(~,~)
        app.state.selectedFiles = parseDataSourceEntries(get(app.ui.edData,'String'));
        detectDatasetNow(false);
        refreshPlan();
    end

    function onAdvanced(~,~)
        syncCfgFromUI();
        prompt = { ...
            'SG order', 'SG frame', 'AsLS lambda', 'AsLS p', 'AsLS nIter', ...
            sprintf('Parallel workers (1-%d)', getAvailableWorkerCount()), 'Step2 kmeans replicates', 'Step2 topKGate (0=dense)', ...
            'Step3 rankMode (adaptive/fixed)', 'Step3 DlocList', ...
            'Step4 repeats | BestAccuracy', 'Step4 repeats | BestScore', 'Step4 repeats | BestMemory', ...
            'Step4 numROC', 'Run benchmarks (0/1)', 'Benchmark methods (space/comma separated)', 'Benchmark kPC (blank=best Step1)'};
        def = { ...
            num2str(app.cfg.preproc.sgOrder), num2str(app.cfg.preproc.sgFrame), num2str(app.cfg.preproc.aslsLambda), ...
            num2str(app.cfg.preproc.aslsP), num2str(app.cfg.preproc.aslsNIter), ...
            num2str(app.cfg.cv.nWorkers), num2str(app.cfg.step2.kmeansReplicates), num2str(app.cfg.step2.topKGate), ...
            app.cfg.step3.rankMode, num2str(app.cfg.step3.DlocList), ...
            num2str(app.cfg.step4.repeatsBestAccuracy), num2str(app.cfg.step4.repeatsBestScore), ...
            num2str(app.cfg.step4.repeatsBestMemory), num2str(app.cfg.step4.numROC), ...
            num2str(double(app.cfg.benchmark.enabled || app.cfg.runtime.runBenchmarks)), strjoin(app.cfg.benchmark.methods,' '), num2str(app.cfg.benchmark.kPC)};
        answ = inputdlg(prompt,'Advanced settings',1,def);
        if isempty(answ), return; end
        app.cfg.preproc.sgOrder = max(1,round(str2double(answ{1})));
        app.cfg.preproc.sgFrame = max(3,round(str2double(answ{2})));
        app.cfg.preproc.aslsLambda = max(1e-12,str2double(answ{3}));
        app.cfg.preproc.aslsP = max(1e-12,min(0.5,str2double(answ{4})));
        app.cfg.preproc.aslsNIter = max(1,round(str2double(answ{5})));
        app.cfg.cv.nWorkers = min(getAvailableWorkerCount(), max(1,round(str2double(answ{6}))));
        if isfield(app.ui,'popWorkers') && ishandle(app.ui.popWorkers)
            set(app.ui.popWorkers,'Value',min(max(1,app.cfg.cv.nWorkers), numel(get(app.ui.popWorkers,'String'))));
        end
        app.cfg.step2.kmeansReplicates = max(1,round(str2double(answ{7})));
        app.cfg.step2.topKGate = max(0,round(str2double(answ{8})));
        app.cfg.step3.rankMode = lower(strtrim(answ{9}));
        if ~ismember(app.cfg.step3.rankMode,{'adaptive','fixed'})
            app.cfg.step3.rankMode = 'adaptive';
        end
        tmp = parseNumList(answ{10});
        if ~isempty(tmp), app.cfg.step3.DlocList = unique(max(1,round(tmp))); end
        app.cfg.step4.repeatsBestAccuracy = max(1,round(str2double(answ{11})));
        app.cfg.step4.repeatsBestScore    = max(1,round(str2double(answ{12})));
        app.cfg.step4.repeatsBestMemory   = max(1,round(str2double(answ{13})));
        app.cfg.step4.numROC = max(50,round(str2double(answ{14})));
        app.cfg.runtime.runBenchmarks = logical(round(str2double(answ{15})));
        app.cfg.benchmark.enabled = app.cfg.runtime.runBenchmarks;
        bmMethods = parseMethodList(answ{16});
        if ~isempty(bmMethods), app.cfg.benchmark.methods = bmMethods; end
        bmK = str2double(answ{17});
        if isfinite(bmK) && bmK > 0
            app.cfg.benchmark.kPC = round(bmK);
        else
            app.cfg.benchmark.kPC = [];
        end
        refreshPlan();
        logmsg('Advanced settings updated.');
    end
