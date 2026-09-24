    function g = getCurrentGroupVector(N)
        g = [];
        if isfield(app,'state') && isfield(app.state,'data') && isfield(app.state.data,'groupVector')
            g = app.state.data.groupVector;
        elseif isfield(app,'state') && isfield(app.state,'detectedData') && ~isempty(app.state.detectedData) && isfield(app.state.detectedData,'groupVector')
            g = app.state.detectedData.groupVector;
        elseif isfield(app.cfg.cv,'groupVector')
            g = app.cfg.cv.groupVector;
        end
        if isempty(g), return; end
        g = g(:);
        if nargin >= 1 && ~isempty(N) && numel(g) ~= N
            g = [];
        end
    end

    function [gNorm, missingMask] = normalizeGroupVector(gRaw)
        if isnumeric(gRaw) || islogical(gRaw)
            gNorm = string(gRaw(:));
            missingMask = isnan(double(gRaw(:)));
        elseif isstring(gRaw)
            gNorm = gRaw(:);
            missingMask = ismissing(gNorm);
        elseif iscell(gRaw)
            gNorm = strings(numel(gRaw),1);
            missingMask = false(numel(gRaw),1);
            for ii = 1:numel(gRaw)
                val = gRaw{ii};
                try
                    sval = strtrim(char(string(val)));
                catch
                    sval = '';
                end
                if isempty(sval)
                    missingMask(ii) = true;
                else
                    gNorm(ii) = string(sval);
                end
            end
        else
            try
                gNorm = string(gRaw(:));
                missingMask = ismissing(gNorm);
            catch
                gNorm = strings(numel(gRaw),1);
                missingMask = true(numel(gRaw),1);
            end
        end
        if numel(missingMask) ~= numel(gNorm)
            missingMask = false(size(gNorm));
        end
    end

    function info = getSplitValidationInfo()
        info = struct('splitMode',app.cfg.cv.splitMode,'present',false,'validLength',false, ...
            'hasMissing',false,'numGroups',0,'requiredGroups',app.cfg.cv.outerK, ...
            'sufficientForKFold',false,'classWiseMinGroups',0,'classWiseSufficient',false, ...
            'expectedLength',0,'actualLength',0,'groupsUsed',0,'seedBase',app.cfg.cv.seedBase, ...
            'displayStatus','Groups: not checked','message','No group vector loaded.', ...
            'effectiveMode','stratified','fallbackUsed',false,'fallbackReason','', ...
            'numClasses',0,'classNames',{{}},'classGroupCounts',[]);
        y = [];
        expectedN = 0;
        classNames = {};
        if isfield(app,'state') && isfield(app.state,'data') && ~isempty(app.state.data)
            if isfield(app.state.data,'N'), expectedN = app.state.data.N; end
            if isfield(app.state.data,'y_idx'), y = app.state.data.y_idx(:); end
            if isfield(app.state.data,'groupNames'), classNames = app.state.data.groupNames; end
        elseif isfield(app,'state') && isfield(app.state,'detectedData') && ~isempty(app.state.detectedData)
            if isfield(app.state.detectedData,'blocks')
                counts = cellfun(@(b) size(b,2)-1, app.state.detectedData.blocks);
                expectedN = sum(counts);
                for ci = 1:numel(counts)
                    y = [y; ci*ones(counts(ci),1)];
                end
            end
            if isfield(app.state.detectedData,'groupNames'), classNames = app.state.detectedData.groupNames; end
        end
        info.expectedLength = expectedN;
        info.numClasses = numel(unique(y));
        info.classNames = classNames;
        gRaw = getCurrentGroupVector(expectedN);
        if isempty(gRaw)
            if isfield(app.cfg.cv,'groupVector') && ~isempty(app.cfg.cv.groupVector)
                info.actualLength = numel(app.cfg.cv.groupVector);
            end
            info.displayStatus = sprintf('Groups: none | mode=%s', app.cfg.cv.splitMode);
            if strcmpi(app.cfg.cv.splitMode,'grouped')
                info.fallbackUsed = true;
                info.fallbackReason = 'No valid group vector loaded.';
                info.effectiveMode = 'stratified';
                info.message = 'Grouped CV requested but no valid group vector was loaded; fallback to stratified CV.';
            end
            return;
        end
        info.present = true;
        info.actualLength = numel(gRaw);
        info.validLength = numel(gRaw) == expectedN;
        [gNorm, missingMask] = normalizeGroupVector(gRaw);
        info.hasMissing = any(missingMask);
        if ~isempty(gNorm)
            info.numGroups = numel(unique(gNorm(~missingMask),'stable'));
            info.groupsUsed = info.numGroups;
        end
        info.requiredGroups = max(2, app.cfg.cv.outerK);
        info.sufficientForKFold = info.validLength && ~info.hasMissing && info.numGroups >= info.requiredGroups;
        if ~isempty(y) && numel(y) == numel(gNorm) && info.validLength && ~info.hasMissing
            cls = unique(y(:))';
            cgc = zeros(numel(cls),1);
            for ii = 1:numel(cls)
                mask = y == cls(ii);
                cgc(ii) = numel(unique(gNorm(mask),'stable'));
            end
            info.classGroupCounts = cgc;
            info.classWiseMinGroups = min(cgc);
            info.classWiseSufficient = info.classWiseMinGroups >= info.requiredGroups;
        else
            info.classWiseMinGroups = 0;
            info.classWiseSufficient = info.sufficientForKFold;
        end
        if ~info.validLength
            info.message = sprintf('groupVector length mismatch: expected %d, got %d.', info.expectedLength, info.actualLength);
        elseif info.hasMissing
            info.message = 'groupVector contains missing or empty values.';
        elseif ~info.sufficientForKFold
            info.message = sprintf('Only %d unique groups found for K=%d.', info.numGroups, info.requiredGroups);
        elseif ~info.classWiseSufficient
            info.message = sprintf('Some classes span fewer than %d groups.', info.requiredGroups);
        else
            info.message = sprintf('groupVector valid: %d unique groups.', info.numGroups);
        end
        if strcmpi(app.cfg.cv.splitMode,'grouped')
            if info.validLength && ~info.hasMissing && info.sufficientForKFold && info.classWiseSufficient
                info.effectiveMode = 'grouped';
                info.fallbackUsed = false;
                info.fallbackReason = '';
            else
                info.effectiveMode = 'stratified';
                info.fallbackUsed = true;
                info.fallbackReason = info.message;
            end
        else
            info.effectiveMode = 'stratified';
            info.fallbackUsed = false;
            info.fallbackReason = '';
        end
        info.displayStatus = sprintf('Groups: %d | req=%d | mode=%s | effective=%s', info.numGroups, info.requiredGroups, app.cfg.cv.splitMode, info.effectiveMode);
        if info.fallbackUsed && ~isempty(strtrim(info.fallbackReason))
            info.displayStatus = sprintf('%s | fallback', info.displayStatus);
        end
    end

    function splitStruct = buildSplitSummaryStruct()
        info = getSplitValidationInfo();
        splitStruct = struct();
        splitStruct.ModeRequested = app.cfg.cv.splitMode;
        splitStruct.ModeEffective = info.effectiveMode;
        splitStruct.FallbackUsed = info.fallbackUsed;
        splitStruct.FallbackReason = info.fallbackReason;
        splitStruct.GroupVectorPresent = info.present;
        splitStruct.GroupVectorValidLength = info.validLength;
        splitStruct.GroupVectorHasMissing = info.hasMissing;
        splitStruct.GroupsUsed = info.groupsUsed;
        splitStruct.RequiredGroups = info.requiredGroups;
        splitStruct.ClassWiseMinGroups = info.classWiseMinGroups;
        splitStruct.GroupedSufficientForKFold = info.sufficientForKFold;
        splitStruct.ClassWiseGroupedSufficient = info.classWiseSufficient;
        splitStruct.NumClasses = info.numClasses;
        splitStruct.Folds = app.cfg.cv.outerK;
        splitStruct.Repeats = app.cfg.cv.repeats;
        splitStruct.SeedBase = app.cfg.cv.seedBase;
        splitStruct.ValidationMessage = info.message;
    end

    function exportSplitSummary(outDir)
        S = buildSplitSummaryStruct();
        T = struct2table(S,'AsArray',true);
        tryWriteTable(T, fullfile(outDir,'STEP0_PREPROC','SPLIT_SUMMARY.xlsx'),'SplitSummary');
        try
            fid = fopen(fullfile(outDir,'STEP0_PREPROC','SPLIT_SUMMARY.txt'),'w');
            if fid > 0
                fprintf(fid,'RequestedMode: %s\n', S.ModeRequested);
                fprintf(fid,'EffectiveMode: %s\n', S.ModeEffective);
                fprintf(fid,'FallbackUsed: %d\n', S.FallbackUsed);
                fprintf(fid,'FallbackReason: %s\n', S.FallbackReason);
                fprintf(fid,'GroupVectorPresent: %d\n', S.GroupVectorPresent);
                fprintf(fid,'GroupVectorValidLength: %d\n', S.GroupVectorValidLength);
                fprintf(fid,'GroupVectorHasMissing: %d\n', S.GroupVectorHasMissing);
                fprintf(fid,'GroupsUsed: %d\n', S.GroupsUsed);
                fprintf(fid,'RequiredGroups: %d\n', S.RequiredGroups);
                fprintf(fid,'ClassWiseMinGroups: %d\n', S.ClassWiseMinGroups);
                fprintf(fid,'GroupedSufficientForKFold: %d\n', S.GroupedSufficientForKFold);
                fprintf(fid,'ClassWiseGroupedSufficient: %d\n', S.ClassWiseGroupedSufficient);
                fprintf(fid,'NumClasses: %d\n', S.NumClasses);
                fprintf(fid,'Folds: %d\n', S.Folds);
                fprintf(fid,'Repeats: %d\n', S.Repeats);
                fprintf(fid,'SeedBase: %d\n', S.SeedBase);
                fprintf(fid,'ValidationMessage: %s\n', S.ValidationMessage);
                fclose(fid);
            end
        catch
        end
        exportGroupedCVDetails(outDir);
    end

    function exportGroupedCVDetails(outDir)
        try
            [Tclass, Tmanifest] = buildGroupedCVDetailTables();
            if ~isempty(Tclass)
                tryWriteTable(Tclass, fullfile(outDir,'STEP0_PREPROC','GROUP_SUMMARY.xlsx'),'GroupSummary');
            end
            if ~isempty(Tmanifest)
                tryWriteTable(Tmanifest, fullfile(outDir,'STEP0_PREPROC','SPLIT_MANIFEST.xlsx'),'SplitManifest');
            end
            fid = fopen(fullfile(outDir,'STEP0_PREPROC','GROUP_SUMMARY.txt'),'w');
            if fid > 0
                info = getSplitValidationInfo();
                fprintf(fid,'RequestedMode: %s\n', app.cfg.cv.splitMode);
                fprintf(fid,'EffectiveMode: %s\n', info.effectiveMode);
                fprintf(fid,'FallbackUsed: %d\n', info.fallbackUsed);
                fprintf(fid,'FallbackReason: %s\n', info.fallbackReason);
                fprintf(fid,'ValidationMessage: %s\n', info.message);
                if ~isempty(Tclass)
                    fprintf(fid,'\nPer-class group coverage:\n');
                    for ii = 1:height(Tclass)
                        fprintf(fid,'  %s | Samples=%d | UniqueGroups=%d | MeetsRequirement=%d\n', ...
                            char(string(Tclass.ClassName(ii))), Tclass.Samples(ii), Tclass.UniqueGroups(ii), Tclass.MeetsRequirement(ii));
                    end
                end
                fclose(fid);
            end
        catch ME
            logmsg(sprintf('Grouped CV detail export warning: %s', ME.message));
        end
    end

    function [Tclass, Tmanifest] = buildGroupedCVDetailTables()
        Tclass = table();
        Tmanifest = table();
        if ~isfield(app,'state') || ~isfield(app.state,'data') || isempty(app.state.data) || ...
                ~isfield(app.state.data,'y_idx') || isempty(app.state.data.y_idx)
            return;
        end
        y = app.state.data.y_idx(:);
        N = numel(y);
        info = getSplitValidationInfo();
        gRaw = getCurrentGroupVector(N);
        if isempty(gRaw)
            return;
        end
        [gNorm, missingMask] = normalizeGroupVector(gRaw);
        classNames = {};
        if isfield(app.state.data,'groupNames'), classNames = app.state.data.groupNames; end
        cls = unique(y(:))';
        classNameCol = strings(numel(cls),1);
        samplesCol = zeros(numel(cls),1);
        uniqGroupsCol = zeros(numel(cls),1);
        meetsCol = false(numel(cls),1);
        for ii = 1:numel(cls)
            cc = cls(ii);
            mask = y == cc;
            samplesCol(ii) = sum(mask);
            if ~isempty(classNames) && cc <= numel(classNames)
                classNameCol(ii) = string(classNames{cc});
            else
                classNameCol(ii) = "Class_" + string(cc);
            end
            if numel(gNorm) == N
                uniqGroupsCol(ii) = numel(unique(gNorm(mask & ~missingMask),'stable'));
            else
                uniqGroupsCol(ii) = 0;
            end
            meetsCol(ii) = uniqGroupsCol(ii) >= max(2, app.cfg.cv.outerK);
        end
        Tclass = table((1:numel(cls))', classNameCol, samplesCol, uniqGroupsCol, meetsCol, ...
            'VariableNames',{'ClassIndex','ClassName','Samples','UniqueGroups','MeetsRequirement'});

        reps = max(1, app.cfg.cv.repeats);
        K = max(2, app.cfg.cv.outerK);
        effMode = info.effectiveMode;
        foldRep = cell(reps,1);
        sampleIdxRep = cell(reps,1);
        foldRepIdx = cell(reps,1);
        classIdxRep = cell(reps,1);
        classNameRep = cell(reps,1);
        groupIDRep = cell(reps,1);
        for rr = 1:reps
            foldIdx = makeFoldsWithSeed(y, K, gRaw, effMode, app.cfg.cv.seedBase + rr);
            foldRep{rr} = rr*ones(N,1);
            sampleIdxRep{rr} = (1:N)';
            foldRepIdx{rr} = foldIdx(:);
            classIdxRep{rr} = y(:);
            if ~isempty(classNames)
                tmp = strings(N,1);
                for jj = 1:N
                    cc = y(jj);
                    if cc <= numel(classNames), tmp(jj) = string(classNames{cc}); else, tmp(jj) = "Class_" + string(cc); end
                end
                classNameRep{rr} = tmp;
            else
                classNameRep{rr} = "Class_" + string(y(:));
            end
            if numel(gNorm) == N
                groupIDRep{rr} = gNorm(:);
            else
                groupIDRep{rr} = repmat("",N,1);
            end
        end
        Tmanifest = table(vertcat(foldRep{:}), vertcat(sampleIdxRep{:}), vertcat(classIdxRep{:}), vertcat(classNameRep{:}), ...
            vertcat(groupIDRep{:}), vertcat(foldRepIdx{:}), ...
            'VariableNames',{'Repeat','SampleIndex','ClassIndex','ClassName','GroupID','Fold'});
    end

    function foldIdx = makeFoldsWithSeed(y, K, groupIDs, mode, seed)
        st = rng;
        cleanupObj = onCleanup(@() rng(st));
        rng(seed, 'twister');
        foldIdx = makeFolds(y, K, groupIDs, mode);
    end

    function exportDataDisposition(outDir, dataAll, dataUsed, dataFinal)
        try
            rawClasses = numel(dataAll.groupNames);
            rawSpectra = sum(cellfun(@(b) size(b,2)-1, dataAll.blocks));
            selClasses = numel(dataUsed.groupNames);
            selSpectra = sum(cellfun(@(b) size(b,2)-1, dataUsed.blocks));
            T = table(rawClasses, rawSpectra, selClasses, selSpectra, dataFinal.N, dataFinal.D, ...
                'VariableNames',{'RawClasses','RawSpectra','SelectedClasses','SelectedSpectra','FinalSamples','FinalDimension'});
            tryWriteTable(T, fullfile(outDir,'STEP0_PREPROC','DATA_DISPOSITION.xlsx'),'Disposition');
        catch
        end
    end

    function saveRunManifest(outDir)
        manifest = struct();
        manifest.codeVersion = 'RAVEN_V1_01';
        manifest.savedAt = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
        manifest.config = app.cfg;
        manifest.split = buildSplitSummaryStruct();
        if isfield(app.state,'data') && isfield(app.state.data,'adapterMeta'), manifest.step0 = app.state.data.adapterMeta; end
        if isfield(app.state,'results')
            if isfield(app.state.results,'bestStep1'), manifest.bestStep1 = app.state.results.bestStep1; end
            if isfield(app.state.results,'bestStep2'), manifest.bestStep2 = app.state.results.bestStep2; end
            if isfield(app.state.results,'bestStep3'), manifest.bestStep3 = app.state.results.bestStep3; end
            if isfield(app.state.results,'final'), manifest.final = app.state.results.final; end
            if isfield(app.state.results,'finalRole'), manifest.finalRole = app.state.results.finalRole; end
        end
        save(fullfile(outDir,'RUN_MANIFEST.mat'),'manifest','-v7.3');
        updateUnifiedOutputManifest(outDir, 'run', manifest);
        fid = fopen(fullfile(outDir,'RUN_MANIFEST.txt'),'w');
        if fid > 0
            fprintf(fid,'CodeVersion: %s\n', manifest.codeVersion);
            fprintf(fid,'SavedAt: %s\n', manifest.savedAt);
            fprintf(fid,'RequestedMode: %s\n', manifest.split.ModeRequested);
            fprintf(fid,'EffectiveMode: %s\n', manifest.split.ModeEffective);
            fprintf(fid,'FallbackUsed: %d\n', manifest.split.FallbackUsed);
            fprintf(fid,'FallbackReason: %s\n', manifest.split.FallbackReason);
            fprintf(fid,'GroupVectorPresent: %d\n', manifest.split.GroupVectorPresent);
            fprintf(fid,'GroupVectorValidLength: %d\n', manifest.split.GroupVectorValidLength);
            fprintf(fid,'GroupVectorHasMissing: %d\n', manifest.split.GroupVectorHasMissing);
            fprintf(fid,'GroupsUsed: %d\n', manifest.split.GroupsUsed);
            fprintf(fid,'RequiredGroups: %d\n', manifest.split.RequiredGroups);
            fprintf(fid,'ClassWiseMinGroups: %d\n', manifest.split.ClassWiseMinGroups);
            fprintf(fid,'GroupedSufficientForKFold: %d\n', manifest.split.GroupedSufficientForKFold);
            fprintf(fid,'Repeats: %d\n', manifest.split.Repeats);
            fprintf(fid,'SeedBase: %d\n', manifest.split.SeedBase);
            fprintf(fid,'ValidationMessage: %s\n', manifest.split.ValidationMessage);
            if isfield(manifest,'finalRole'), fprintf(fid,'FinalSelectionRole: %s\n', manifest.finalRole); end
            fclose(fid);
        end
    end

    function updateUnifiedOutputManifest(rootOutDir, sectionName, sectionPayload)
        if nargin < 1 || isempty(rootOutDir), return; end
        if ~exist(rootOutDir,'dir'), return; end
        M = buildUnifiedOutputManifestStruct(rootOutDir);
        if nargin >= 2 && ~isempty(sectionName)
            key = matlab.lang.makeValidName(char(string(sectionName)));
            M.sections.(key) = sectionPayload;
        end
        save(fullfile(rootOutDir,'OUTPUT_MANIFEST.mat'),'M','-v7.3');
        writeUnifiedOutputManifestTxt(M, fullfile(rootOutDir,'OUTPUT_MANIFEST.txt'));
        tryWriteTable(buildUnifiedMetadataTable(M), fullfile(rootOutDir,'OUTPUT_METADATA.xlsx'),'Metadata');
        tryWriteTable(buildUnifiedFilesTable(M), fullfile(rootOutDir,'OUTPUT_METADATA.xlsx'),'Files');
    end

    function M = buildUnifiedOutputManifestStruct(rootOutDir)
        M = struct();
        M.codeVersion = 'RAVEN_V1_01';
        M.generatedAt = datestr(now,'yyyy-mm-dd HH:MM:SS');
        M.rootOutputDir = rootOutDir;
        M.config = app.cfg;
        M.split = buildSplitSummaryStruct();
        M.runtime = buildUnifiedRuntimeStruct();
        M.dataset = buildUnifiedDatasetStruct();
        M.results = buildUnifiedResultsStruct();
        M.files = scanOutputFiles(rootOutDir);
        M.sections = struct();
        existingMat = fullfile(rootOutDir,'OUTPUT_MANIFEST.mat');
        if exist(existingMat,'file')
            try
                Sprev = load(existingMat,'M');
                if isfield(Sprev,'M') && isstruct(Sprev.M) && isfield(Sprev.M,'sections')
                    M.sections = Sprev.M.sections;
                end
            catch
            end
        end
    end

    function R = buildUnifiedRuntimeStruct()
        R = struct();
        R.outputDir = ravenGetField(app.state,'outdir','');
        R.stopRequested = getStructScalar(app.state,'stopRequested',0) ~= 0;
        if isfield(app.state,'timing'), R.timing = app.state.timing; end
        if isfield(app.state,'results') && isfield(app.state.results,'step3ModeInfo')
            R.step3ModeInfo = app.state.results.step3ModeInfo;
        end
    end

    function D = buildUnifiedDatasetStruct()
        D = struct();
        if isfield(app.state,'data')
            if isfield(app.state.data,'adapterMeta'), D.adapterMeta = app.state.data.adapterMeta; end
            if isfield(app.state.data,'dataFinal')
                df = app.state.data.dataFinal;
                if isstruct(df)
                    if isfield(df,'N'), D.finalSamples = df.N; end
                    if isfield(df,'D'), D.finalDimension = df.D; end
                end
            end
        end
    end

    function R = buildUnifiedResultsStruct()
        R = struct();
        if isfield(app.state,'results')
            if isfield(app.state.results,'bestStep1'), R.bestStep1 = app.state.results.bestStep1; end
            if isfield(app.state.results,'bestStep2'), R.bestStep2 = app.state.results.bestStep2; end
            if isfield(app.state.results,'bestStep3'), R.bestStep3 = app.state.results.bestStep3; end
            if isfield(app.state.results,'final'), R.final = app.state.results.final; end
            if isfield(app.state.results,'finalRole'), R.finalRole = app.state.results.finalRole; end
            if isfield(app.state.results,'ablationSummaryTable'), R.ablationSummaryTop = headTable(app.state.results.ablationSummaryTable, 10); end
        end
    end

    function T = headTable(Tin, n)
        if nargin < 2, n = 10; end
        T = Tin;
        try
            if istable(Tin) && height(Tin) > n
                T = Tin(1:n,:);
            end
        catch
        end
    end

    function F = scanOutputFiles(rootOutDir)
        dd = dir(fullfile(rootOutDir,'**','*'));
        dd = dd(~[dd.isdir]);
        rel = strings(numel(dd),1);
        bytes = zeros(numel(dd),1);
        dates = strings(numel(dd),1);
        for ii = 1:numel(dd)
            absPath = fullfile(dd(ii).folder, dd(ii).name);
            rel(ii) = string(strrep(absPath, [rootOutDir filesep], ''));
            bytes(ii) = dd(ii).bytes;
            dates(ii) = string(dd(ii).date);
        end
        F = table(rel, bytes, dates, 'VariableNames', {'RelativePath','Bytes','Modified'});
        if ~isempty(F), F = sortrows(F,'RelativePath'); end
    end

    function writeUnifiedOutputManifestTxt(M, txtPath)
        fid = fopen(txtPath,'w');
        if fid <= 0, return; end
        c = onCleanup(@() fclose(fid));
        fprintf(fid,'RAVEN unified output manifest\n');
        fprintf(fid,'Generated: %s\n', M.generatedAt);
        fprintf(fid,'CodeVersion: %s\n', M.codeVersion);
        fprintf(fid,'RootOutputDir: %s\n', M.rootOutputDir);
        fprintf(fid,'RequestedMode: %s\n', ravenGetField(M.split,'ModeRequested','unknown'));
        fprintf(fid,'EffectiveMode: %s\n', ravenGetField(M.split,'ModeEffective','unknown'));
        fprintf(fid,'FallbackUsed: %s\n', localValueToText(ravenGetField(M.split,'FallbackUsed',false)));
        fprintf(fid,'FilesDiscovered: %d\n', height(M.files));
        fprintf(fid,'\nMetadata:\n');
        Tmeta = buildUnifiedMetadataTable(M);
        for ii = 1:height(Tmeta)
            fprintf(fid,'  %s: %s\n', char(Tmeta.Field(ii)), char(Tmeta.Value(ii)));
        end
        fprintf(fid,'\nSections:\n');
        secNames = fieldnames(M.sections);
        if isempty(secNames)
            fprintf(fid,'  (none)\n');
        else
            for ii = 1:numel(secNames)
                fprintf(fid,'  - %s\n', secNames{ii});
            end
        end
        fprintf(fid,'\nFiles:\n');
        topN = min(200, height(M.files));
        for ii = 1:topN
            fprintf(fid,'  %s | %d bytes | %s\n', char(M.files.RelativePath(ii)), M.files.Bytes(ii), char(M.files.Modified(ii)));
        end
    end

    function T = buildUnifiedMetadataTable(M)
        Field = strings(0,1);
        Value = strings(0,1);
        addRow('CodeVersion', M.codeVersion);
        addRow('Generated', M.generatedAt);
        addRow('RootOutputDir', M.rootOutputDir);
        addRow('RequestedMode', ravenGetField(M.split,'ModeRequested','unknown'));
        addRow('EffectiveMode', ravenGetField(M.split,'ModeEffective','unknown'));
        addRow('FallbackUsed', localValueToText(ravenGetField(M.split,'FallbackUsed',false)));
        addRow('FallbackReason', ravenGetField(M.split,'FallbackReason',''));
        addRow('GroupedCVRequested', localValueToText(getNestedLogical(app.cfg, {'cv','useGroups'}, false)));
        addRow('GroupsUsed', localValueToText(ravenGetField(M.split,'GroupsUsed',NaN)));
        addRow('RequiredGroups', localValueToText(ravenGetField(M.split,'RequiredGroups',NaN)));
        addRow('ClassWiseMinGroups', localValueToText(ravenGetField(M.split,'ClassWiseMinGroups',NaN)));
        addRow('FinalSelectionRole', getNestedText(app.state, {'results','finalRole'}, ''));
        addRow('Step3Mode', getNestedText(app.state, {'results','step3ModeInfo','mode'}, ''));
        addRow('FinalSamples', localValueToText(ravenGetField(M.dataset,'finalSamples',NaN)));
        addRow('FinalDimension', localValueToText(ravenGetField(M.dataset,'finalDimension',NaN)));
        addRow('FilesDiscovered', num2str(height(M.files)));
        addRow('SectionsAvailable', strjoin(fieldnames(M.sections), ', '));
        T = table(Field, Value);
        function addRow(f,v)
            Field(end+1,1) = string(f);
            Value(end+1,1) = string(localValueToText(v));
        end
    end

    function T = buildUnifiedFilesTable(M)
        T = M.files;
        if isempty(T)
            T = table(strings(0,1), zeros(0,1), strings(0,1), 'VariableNames', {'RelativePath','Bytes','Modified'});
        end
    end

    function S = buildAblationManifestStruct(Tab, outDir, finalKey)
        S = struct();
        S.kind = 'ablation';
        S.outputDir = outDir;
        S.finalWinner = finalKey;
        S.rows = height(Tab);
        S.files = {'ABLATION_SUMMARY.xlsx','ABLATION_SUMMARY.txt','ABLATION_MANIFEST.txt','ABLATION_EXPORT.mat'};
        if ~isempty(Tab)
            S.topRole = char(Tab.Role(1));
            S.topCandidateID = char(Tab.CandidateID(1));
            S.topAcc = Tab.Acc(1);
            S.topScore = Tab.Score(1);
        end
    end

    function S = buildBenchmarkManifestStruct(Tbench, outDir, kPC, K, Rrepeat, methods)
        S = struct();
        S.kind = 'benchmark';
        S.outputDir = outDir;
        S.kPC = kPC;
        S.outerFolds = K;
        S.repeats = Rrepeat;
        S.methodsRequested = methods;
        S.rows = height(Tbench);
        S.files = {'BENCHMARK_RESULTS.xlsx','BENCHMARK_SUMMARY.txt','BENCHMARK_MANIFEST.txt','BENCHMARK_EXPORT.mat'};
        if ~isempty(Tbench)
            S.topMethod = char(Tbench.Method(1));
            S.topSource = char(Tbench.Source(1));
            S.topAcc = Tbench.Acc(1);
            S.topScore = Tbench.Score(1);
        end
    end

    function exportReportingConsolidation(outDir)
        summaryName = strings(0,1);
        summaryValue = strings(0,1);
        summarySection = strings(0,1);
        try
            step0Dir = fullfile(outDir,'STEP0_PREPROC');
            step1Dir = fullfile(outDir,'STEP1_EMBEDDING');
            step2Dir = fullfile(outDir,'STEP2_LOCALIZATION');
            step3Dir = fullfile(outDir,'STEP3_LOCAL_APPROX');
            step4Dir = fullfile(outDir,'STEP4_FINAL');

            addSummaryRow('Run','CodeVersion','RAVEN_V1_01');
            addSummaryRow('Run','SavedAt',string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
            if isfield(app.state,'outdir'), addSummaryRow('Run','OutputDir',string(app.state.outdir)); end
            if isfield(app.state,'timing')
                fn = fieldnames(app.state.timing);
                totalSec = 0;
                for ii = 1:numel(fn), totalSec = totalSec + app.state.timing.(fn{ii}); end
                addSummaryRow('Run','MeasuredStageWallSec',sprintf('%.6f',totalSec));
            end
            if isfield(app.state,'runTic')
                addSummaryRow('Run','ElapsedWallSec',sprintf('%.6f',toc(app.state.runTic)));
            end

            if isfield(app.state,'data')
                if isfield(app.state.data,'N'), addSummaryRow('Data','Samples',num2str(app.state.data.N)); end
                if isfield(app.state.data,'D'), addSummaryRow('Data','Dimension',num2str(app.state.data.D)); end
                if isfield(app.state.data,'groupNames'), addSummaryRow('Data','NumClasses',num2str(numel(app.state.data.groupNames))); end
                if isfield(app.state.data,'adapterMeta')
                    am = app.state.data.adapterMeta;
                    if isfield(am,'axisMode'), addSummaryRow('Step0','AxisMode',toText(am.axisMode)); end
                    if isfield(am,'targetLength'), addSummaryRow('Step0','TargetLength',num2str(am.targetLength)); end
                    if isfield(am,'segmentationEnable'), addSummaryRow('Step0','SegmentationEnable',num2str(double(am.segmentationEnable))); end
                    if isfield(am,'segmentLength'), addSummaryRow('Step0','SegmentLength',num2str(am.segmentLength)); end
                    if isfield(am,'segmentStride'), addSummaryRow('Step0','SegmentStride',num2str(am.segmentStride)); end
                end
            end

            if isfield(app.state,'results')
                R = app.state.results;
                if isfield(R,'bestStep1')
                    addSummaryRow('Step1','BestKPC',num2str(getNumericScalar(R.bestStep1,'kPC',NaN)));
                    addSummaryRow('Step1','BestAccuracy',sprintf('%.6f',getNumericScalar(R.bestStep1,'acc',NaN)));
                    addSummaryRow('Step1','BestWeightedAcc',sprintf('%.6f',getNumericScalar(R.bestStep1,'WeightedAcc',NaN)));
                    addSummaryRow('Step1','BestMacroF1',sprintf('%.6f',getNumericScalar(R.bestStep1,'macroF1',NaN)));
                    addSummaryRow('Step1','BestWeightedF1',sprintf('%.6f',getNumericScalar(R.bestStep1,'WeightedF1',NaN)));
                end
                if isfield(R,'bestStep2')
                    addSummaryRow('Step2','BestAccuracy',sprintf('%.6f',getNumericScalar(R.bestStep2,'Acc',NaN)));
                    addSummaryRow('Step2','BestWeightedAcc',sprintf('%.6f',getNumericScalar(R.bestStep2,'WeightedAcc',NaN)));
                    addSummaryRow('Step2','BestMacroF1',sprintf('%.6f',getNumericScalar(R.bestStep2,'MacroF1',NaN)));
                    addSummaryRow('Step2','BestWeightedF1',sprintf('%.6f',getNumericScalar(R.bestStep2,'WeightedF1',NaN)));
                    addSummaryRow('Step2','BestScore',sprintf('%.6f',getNumericScalar(R.bestStep2,'Score',NaN)));
                end
                if isfield(R,'bestStep3')
                    addSummaryRow('Step3','CandidateID',getTextScalar(R.bestStep3,'CandidateID',''));
                    addSummaryRow('Step3','BestAccuracy',sprintf('%.6f',getNumericScalar(R.bestStep3,'Acc',NaN)));
                    addSummaryRow('Step3','BestWeightedAcc',sprintf('%.6f',getNumericScalar(R.bestStep3,'WeightedAcc',NaN)));
                    addSummaryRow('Step3','BestMacroF1',sprintf('%.6f',getNumericScalar(R.bestStep3,'MacroF1',NaN)));
                    addSummaryRow('Step3','BestWeightedF1',sprintf('%.6f',getNumericScalar(R.bestStep3,'WeightedF1',NaN)));
                    addSummaryRow('Step3','BestScore',sprintf('%.6f',getNumericScalar(R.bestStep3,'Score',NaN)));
                end
                if isfield(R,'finalWinnerRecord')
                    F = R.finalWinnerRecord;
                    addSummaryRow('Step4','WinnerRole',toText(F.RoleName));
                    addSummaryRow('Step4','WinnerCandidateID',toText(F.CandidateID));
                    addSummaryRow('Step4','WinnerSourceBucket',toText(F.SourceBucket));
                    addSummaryRow('Step4','WinnerRankInBucket',num2str(F.RankInBucket));
                    addSummaryRow('Step4','WinnerAccuracy',sprintf('%.6f',F.Acc));
                    addSummaryRow('Step4','WinnerWeightedAcc',sprintf('%.6f',F.WeightedAcc));
                    addSummaryRow('Step4','WinnerMacroF1',sprintf('%.6f',F.MacroF1));
                    addSummaryRow('Step4','WinnerWeightedF1',sprintf('%.6f',F.WeightedF1));
                    addSummaryRow('Step4','WinnerScore',sprintf('%.6f',F.Score));
                    addSummaryRow('Step4','WinnerTimePerSpec',sprintf('%.6f',F.TimePerSpec));
                    addSummaryRow('Step4','WinnerMemoryPerSpec',sprintf('%.6f',F.MemoryPerSpec));
                elseif isfield(R,'final')
                    addSummaryRow('Step4','FinalAccuracy',sprintf('%.6f',getNumericScalar(R.final,'acc',NaN)));
                    addSummaryRow('Step4','FinalWeightedAcc',sprintf('%.6f',getNumericScalar(R.final,'WeightedAcc',NaN)));
                    addSummaryRow('Step4','FinalMacroF1',sprintf('%.6f',getNumericScalar(R.final,'macroF1',NaN)));
                    addSummaryRow('Step4','FinalWeightedF1',sprintf('%.6f',getNumericScalar(R.final,'WeightedF1',NaN)));
                end
                if isfield(R,'blindPackagePaths') && isstruct(R.blindPackagePaths)
                    bpFields = fieldnames(R.blindPackagePaths);
                    addSummaryRow('Blind','NumBlindPackages',num2str(numel(bpFields)));
                    for ii = 1:numel(bpFields)
                        addSummaryRow('Blind',sprintf('BlindPackage_%s',bpFields{ii}),toText(R.blindPackagePaths.(bpFields{ii})));
                    end
                end
                if isfield(R,'benchmarkTable') && ~isempty(R.benchmarkTable)
                    addSummaryRow('Benchmark','NumMethods',num2str(height(R.benchmarkTable)));
                    if ismember('Method', R.benchmarkTable.Properties.VariableNames)
                        addSummaryRow('Benchmark','Methods', strjoin(cellstr(string(R.benchmarkTable.Method)), ', '));
                    end
                    if ismember('Acc', R.benchmarkTable.Properties.VariableNames)
                        [mx,ix] = max(R.benchmarkTable.Acc);
                        addSummaryRow('Benchmark','BestAccuracy',sprintf('%.6f',mx));
                        if ismember('Method', R.benchmarkTable.Properties.VariableNames)
                            addSummaryRow('Benchmark','BestAccuracyMethod',toText(R.benchmarkTable.Method(ix)));
                        end
                    end
                end
            end

            Tsummary = table(summarySection, summaryName, summaryValue, 'VariableNames',{'Section','Name','Value'});
            tryWriteTable(Tsummary, fullfile(outDir,'MASTER_REPORT.xlsx'),'Summary');

            if isfield(app.state,'results') && isfield(app.state.results,'step1Table') && ~isempty(app.state.results.step1Table)
                tryWriteTable(app.state.results.step1Table, fullfile(outDir,'MASTER_REPORT.xlsx'),'Step1_PCA');
            end
            if isfield(app.state,'results') && isfield(app.state.results,'step2Table') && ~isempty(app.state.results.step2Table)
                tryWriteTable(app.state.results.step2Table, fullfile(outDir,'MASTER_REPORT.xlsx'),'Step2_Teacher');
            end
            if isfield(app.state,'results') && isfield(app.state.results,'step3Table') && ~isempty(app.state.results.step3Table)
                tryWriteTable(app.state.results.step3Table, fullfile(outDir,'MASTER_REPORT.xlsx'),'Step3_Candidates');
            end
            if isfield(app.state,'results') && isfield(app.state.results,'finalSelections') && ~isempty(app.state.results.finalSelections)
                tryWriteTable(app.state.results.finalSelections, fullfile(outDir,'MASTER_REPORT.xlsx'),'Step4_Finalists');
            end
            if isfield(app.state,'timing') && ~isempty(app.state.timing)
                fn = fieldnames(app.state.timing);
                sec = zeros(numel(fn),1);
                for ii = 1:numel(fn), sec(ii) = app.state.timing.(fn{ii}); end
                Ttim = table(string(fn), sec, 'VariableNames',{'Step','WallSec'});
                tryWriteTable(Ttim, fullfile(outDir,'MASTER_REPORT.xlsx'),'Timing');
                tryWriteTable(Ttim, fullfile(outDir,'TIMING_SUMMARY.xlsx'),'Timing');
            end
            if isfield(app.state,'results') && isfield(app.state.results,'benchmarkTable') && ~isempty(app.state.results.benchmarkTable)
                tryWriteTable(app.state.results.benchmarkTable, fullfile(outDir,'MASTER_REPORT.xlsx'),'Benchmark');
            end

            if exist(fullfile(step0Dir,'DATA_DISPOSITION.xlsx'),'file')
                try
                    Tdisp = readtable(fullfile(step0Dir,'DATA_DISPOSITION.xlsx'));
                    tryWriteTable(Tdisp, fullfile(outDir,'MASTER_REPORT.xlsx'),'Data_Disposition');
                catch
                end
            end
            if exist(fullfile(step0Dir,'SPLIT_SUMMARY.xlsx'),'file')
                try
                    Ts = readtable(fullfile(step0Dir,'SPLIT_SUMMARY.xlsx'));
                    tryWriteTable(Ts, fullfile(outDir,'MASTER_REPORT.xlsx'),'Split_Summary');
                catch
                end
            end
            if exist(fullfile(step0Dir,'GROUP_SUMMARY.xlsx'),'file')
                try
                    Tg = readtable(fullfile(step0Dir,'GROUP_SUMMARY.xlsx'));
                    tryWriteTable(Tg, fullfile(outDir,'MASTER_REPORT.xlsx'),'Group_Summary');
                catch
                end
            end

            fid = fopen(fullfile(outDir,'RUN_SUMMARY.txt'),'w');
            if fid > 0
                fprintf(fid,'RAVEN consolidated run summary\n');
                fprintf(fid,'SavedAt: %s\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
                for ii = 1:height(Tsummary)
                    fprintf(fid,'[%s] %s: %s\n', Tsummary.Section{ii}, Tsummary.Name{ii}, Tsummary.Value{ii});
                end
                fclose(fid);
            end

            fid = fopen(fullfile(outDir,'FINAL_SETTINGS.txt'),'w');
            if fid > 0
                fprintf(fid,'RAVEN final settings snapshot\n');
                fprintf(fid,'InputMode: %s\n', toText(app.cfg.io.inputMode));
                fprintf(fid,'DataSource: %s\n', toText(app.cfg.io.dataSource));
                fprintf(fid,'RootName: %s\n', toText(app.cfg.io.rootName));
                fprintf(fid,'SplitMode: %s\n', toText(app.cfg.cv.splitMode));
                fprintf(fid,'OuterK: %d\n', app.cfg.cv.outerK);
                fprintf(fid,'Repeats: %d\n', app.cfg.cv.repeats);
                fprintf(fid,'SeedBase: %d\n', app.cfg.cv.seedBase);
                fprintf(fid,'PreprocSmooth: %d\n', app.cfg.preproc.smoothEnable);
                fprintf(fid,'PreprocBaseline: %d\n', app.cfg.preproc.baseEnable);
                fprintf(fid,'PreprocNormalize: %d\n', app.cfg.preproc.normEnable);
                fprintf(fid,'PreprocDerivativeOrder: %d\n', app.cfg.preproc.derivOrder);
                fprintf(fid,'Step0AxisMode: %s\n', toText(app.cfg.step0.commonAxisMode));
                fprintf(fid,'Step0TargetLength: %d\n', app.cfg.step0.targetLength);
                fprintf(fid,'Step0SegmentationEnable: %d\n', app.cfg.step0.segmentationEnable);
                fprintf(fid,'Step0SegmentLength: %d\n', app.cfg.step0.segmentLength);
                fprintf(fid,'Step0SegmentStride: %d\n', app.cfg.step0.segmentStride);
                fprintf(fid,'Step1Mode: %s\n', toText(app.cfg.step1.pcaMode));
                fprintf(fid,'Step1VarianceTarget: %.6f\n', app.cfg.step1.varianceTarget);
                fprintf(fid,'Step1SingleKPCEnable: %d\n', app.cfg.step1.singleKPCEnable);
                fprintf(fid,'Step1SingleKPC: %d\n', app.cfg.step1.singleKPC);
                fprintf(fid,'Step4WinnerPolicy: %s\n', toText(app.cfg.step4.winnerPolicy));
                fprintf(fid,'Step4TopFinalistsPerBucket: %d\n', app.cfg.step4.topFinalistsPerBucket);
                fclose(fid);
            end

            if exist(fullfile(step0Dir,'DATA_DISPOSITION.xlsx'),'file')
                try
                    copyfile(fullfile(step0Dir,'DATA_DISPOSITION.xlsx'), fullfile(outDir,'DATA_DISPOSITION.xlsx'));
                catch
                end
            end
        catch ME
            logmsg(['Reporting consolidation skipped: ' ME.message]);
        end

        function addSummaryRow(sec,name,val)
            summarySection(end+1,1) = string(sec);
            summaryName(end+1,1) = string(name);
            summaryValue(end+1,1) = string(val);
        end
    end

    function s = toText(v)
        if isstring(v)
            if isempty(v), s = ''; else, s = char(v(1)); end
        elseif ischar(v)
            s = v;
        elseif iscell(v)
            if isempty(v), s = ''; else, s = toText(v{1}); end
        elseif isnumeric(v) || islogical(v)
            if isscalar(v), s = num2str(v); else, s = mat2str(v); end
        else
            try, s = char(string(v)); catch, s = ''; end
        end
    end
