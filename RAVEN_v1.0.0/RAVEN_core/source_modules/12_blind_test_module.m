    function saveBlindReadyModel(bestAccRes, fileName, classifierLabel)
        if nargin < 2 || isempty(fileName), fileName = 'BestAccuracy_BLIND_MODEL.mat'; end
        if nargin < 3 || isempty(classifierLabel), classifierLabel = 'BestAccuracy'; end
        try
            blindPackage = makeBlindPackageStandard(bestAccRes, classifierLabel);
            modelPath = fullfile(app.state.outdir,'STEP4_FINAL',fileName);
            save(modelPath,'blindPackage','-v7.3');
            if ~isfield(app.state,'results') || isempty(app.state.results), app.state.results = struct(); end
            app.state.results.blindModelPath = modelPath;
            if ~isfield(app.state.results,'blindPackagePaths') || ~isstruct(app.state.results.blindPackagePaths)
                app.state.results.blindPackagePaths = struct();
            end
            roleField = matlab.lang.makeValidName(classifierLabel);
            app.state.results.blindPackagePaths.(roleField) = modelPath;
            setSummary('Blind package', modelPath);
            logmsg(['Standard blind package saved: ' modelPath]);
        catch MEb
            logmsg(['Blind-package save warning: ' MEb.message]);
        end
    end

    function blindPackage = makeBlindPackageStandard(bestRes, classifierLabel)
        blindPackage = struct();
        blindPackage.kind = 'RAVEN_BlindPackage_v1';
        blindPackage.formatVersion = 1;
        blindPackage.savedAt = datestr(now,30);
        blindPackage.roleName = classifierLabel;
        blindPackage.packageID = sprintf('%s__%s', classifierLabel, datestr(now,30));
        blindPackage.note = 'Standard blind package for the selected RAVEN finalist. Blind repeats refit on full training data and vote across blind spectra.';
        blindPackage.groupNames = app.state.data.groupNames;
        blindPackage.sampleCounts = app.state.data.sampleCounts;
        blindPackage.preproc = app.cfg.preproc;
        blindPackage.cfgEval = bestRes.cfg;
        blindPackage.trainData = app.state.rawSelectedData;
        blindPackage.croppedAxis = app.state.data.W;
        if ~isempty(app.state.rawSelectedData) && isfield(app.state.rawSelectedData,'blocks') && ~isempty(app.state.rawSelectedData.blocks)
            blindPackage.rawAxis = app.state.rawSelectedData.blocks{1}(:,1);
        else
            blindPackage.rawAxis = app.state.data.W;
        end
        blindPackage.seedBase = app.cfg.cv.seedBase + 70000;
        blindPackage.step0 = app.cfg.step0;
        blindPackage.split = buildSplitSummaryStruct();
        blindPackage.source = app.cfg.io.dataSource;
        blindPackage.rootName = app.cfg.io.rootName;
        blindPackage.trainingSummary = struct('candidateID', getTextScalar(bestRes,'CandidateID',''), ...
            'selectionName', getTextScalar(bestRes,'SelectionName',classifierLabel), ...
            'acc', getNumericScalar(bestRes,'Acc',NaN), ...
            'weightedAcc', getNumericScalar(bestRes,'WeightedAcc',NaN), ...
                'macroF1', getNumericScalar(bestRes,'MacroF1',NaN), ...
                'weightedF1', getNumericScalar(bestRes,'WeightedF1',NaN), ...
            'balAcc', getNumericScalar(bestRes,'BalAcc',NaN), ...
            'teacherAcc', getNumericScalar(bestRes,'AccTeacher',NaN), ...
            'score', getNumericScalar(bestRes,'Score',NaN), ...
            'wallMsPerSpec', getNumericScalar(bestRes,'WallMsPerSpec',NaN), ...
            'memMiBPerSpec', getNumericScalar(bestRes,'MemMiBPerSpec',NaN));
        blindPackage.inference = struct('mode','refit_vote_repeats','predictFunction','predictBlindReadyModel', ...
            'fitFunction','fitBlindReadyModel','preprocessFunction','preprocessBlindBlock');
        blindPackage.compat = struct('legacyBlindModelKind','RAVEN_BlindReadyModel_v2','schemaName','blindPackage');
    end

    function out = getTextScalar(S, fieldName, defaultVal)
        if nargin < 3, defaultVal = ''; end
        out = defaultVal;
        if isstruct(S) && isfield(S,fieldName)
            v = S.(fieldName);
        elseif istable(S) && any(strcmp(S.Properties.VariableNames, fieldName))
            v = S.(fieldName);
        else
            return;
        end
        if isstring(v)
            if ~isempty(v), out = char(v(1)); end
        elseif ischar(v)
            out = v;
        elseif iscell(v)
            if ~isempty(v)
                if ischar(v{1}), out = v{1};
                elseif isstring(v{1}), out = char(v{1});
                else, out = char(string(v{1})); end
            end
        else
            out = char(string(v(1)));
        end
    end

    function out = getNumericScalar(S, fieldName, defaultVal)
        if nargin < 3, defaultVal = NaN; end
        out = defaultVal;
        if isstruct(S) && isfield(S,fieldName)
            v = S.(fieldName);
        elseif istable(S) && any(strcmp(S.Properties.VariableNames, fieldName))
            v = S.(fieldName);
        else
            return;
        end
        if iscell(v)
            if ~isempty(v), v = v{1}; else, return; end
        end
        if isstring(v) || ischar(v)
            vv = str2double(string(v));
            if isfinite(vv), out = vv; end
        elseif isnumeric(v) || islogical(v)
            if ~isempty(v), out = double(v(1)); end
        end
    end

    function onBlindTest(~,~)
        try
            openBlindTestWindow();
        catch MEb
            errordlg(MEb.message,'RAVEN Blind Test');
        end
    end

    function openBlindTestWindow()
        if isfield(app.ui,'blindFig') && ishghandle(app.ui.blindFig)
            figure(app.ui.blindFig);
            return;
        end
        sc = get(0,'ScreenSize');
        fw = min(1200, sc(3)-100);
        fh = min(760, sc(4)-100);
        fx = round((sc(3)-fw)/2);
        fy = round((sc(4)-fh)/2);
        f = figure('Name','RAVEN | Blind Test','NumberTitle','off','MenuBar','none','ToolBar','none', ...
            'Color',[0 0 0],'Position',[fx fy fw fh],'Resize','on');
        app.ui.blindFig = f;

        pnlLeft = uipanel(f,'Units','normalized','Position',[0.02 0.08 0.31 0.88], ...
            'Title','Blind test setup','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        pnlRight = uipanel(f,'Units','normalized','Position',[0.35 0.08 0.63 0.88], ...
            'Title','Blind vote and live report','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');

        uicontrol(pnlLeft,'Style','text','Units','normalized','Position',[0.04 0.90 0.90 0.04], ...
            'String','Saved blind package (.mat)','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
            'HorizontalAlignment','left','FontWeight','bold');
        defaultModel = '';
        if isfield(app.state,'results') && isfield(app.state.results,'blindModelPath') && exist(app.state.results.blindModelPath,'file')
            defaultModel = app.state.results.blindModelPath;
        end
        edModel = uicontrol(pnlLeft,'Style','edit','Units','normalized','Position',[0.04 0.85 0.66 0.05], ...
            'String',defaultModel,'BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
            'HorizontalAlignment','left');
        uicontrol(pnlLeft,'Style','pushbutton','Units','normalized','Position',[0.73 0.85 0.22 0.05], ...
            'String','Browse','Callback',@browseModelCb);

        uicontrol(pnlLeft,'Style','text','Units','normalized','Position',[0.04 0.77 0.90 0.04], ...
            'String','Blind sample file','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
            'HorizontalAlignment','left','FontWeight','bold');
        edBlind = uicontrol(pnlLeft,'Style','edit','Units','normalized','Position',[0.04 0.72 0.66 0.05], ...
            'String','','BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
            'HorizontalAlignment','left');
        uicontrol(pnlLeft,'Style','pushbutton','Units','normalized','Position',[0.73 0.72 0.22 0.05], ...
            'String','Browse','Callback',@browseBlindCb);

        uicontrol(pnlLeft,'Style','text','Units','normalized','Position',[0.04 0.64 0.90 0.04], ...
            'String','Number of repeats','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
            'HorizontalAlignment','left','FontWeight','bold');
        edRep = uicontrol(pnlLeft,'Style','edit','Units','normalized','Position',[0.04 0.59 0.25 0.05], ...
            'String','3','BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
            'HorizontalAlignment','left');

        btnRunBlind = uicontrol(pnlLeft,'Style','pushbutton','Units','normalized','Position',[0.04 0.49 0.91 0.07], ...
            'String','Run Blind Test','FontWeight','bold','FontSize',11,'Callback',@runBlindCb);

        txtMajor = uicontrol(pnlLeft,'Style','text','Units','normalized','Position',[0.04 0.33 0.91 0.12], ...
            'String','Major vote: -','BackgroundColor',[0 0 0],'ForegroundColor',[0.90 0.95 0.85], ...
            'HorizontalAlignment','left','FontWeight','bold','FontSize',11);
        txtInfo = uicontrol(pnlLeft,'Style','text','Units','normalized','Position',[0.04 0.08 0.91 0.22], ...
            'String','Load a saved blind package and a blind sample file.', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.84 0.90 0.92], ...
            'HorizontalAlignment','left');

        axBlind = axes('Parent',pnlRight,'Units','normalized','Position',[0.10 0.42 0.84 0.50], ...
            'Color',[0.02 0.02 0.02],'XColor',[0.92 0.92 0.92],'YColor',[0.92 0.92 0.92], ...
            'GridColor',[0.25 0.25 0.25],'MinorGridColor',[0.18 0.18 0.18]);
        title(axBlind,'Blind vote (%)','Color',[0.92 0.92 0.92]);
        xlabel(axBlind,'Predicted Class','Color',[0.92 0.92 0.92]);
        ylabel(axBlind,'Vote (%)','Color',[0.92 0.92 0.92]);
        grid(axBlind,'on');

        uicontrol(pnlRight,'Style','text','Units','normalized','Position',[0.04 0.25 0.92 0.04], ...
            'String','Live report','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
            'HorizontalAlignment','left','FontWeight','bold');
        lbBlindLog = uicontrol(pnlRight,'Style','listbox','Units','normalized','Position',[0.04 0.05 0.92 0.20], ...
            'String',{'Blind test window ready.'},'BackgroundColor',[0.04 0.04 0.04],'ForegroundColor',[0.92 0.98 0.96], ...
            'FontName','Consolas','FontSize',10,'Max',2,'Min',0);

        function bLog(msg)
            old = get(lbBlindLog,'String');
            if ischar(old), old = cellstr(old); end
            line = ['[' datestr(now,'HH:MM:SS') '] ' msg];
            old{end+1,1} = line;
            set(lbBlindLog,'String',old,'Value',numel(old));
            drawnow;
        end

        function browseModelCb(~,~)
            [fn,fp] = uigetfile({'*.mat','MAT files (*.mat)'},'Select saved blind package');
            if isequal(fn,0), return; end
            set(edModel,'String',fullfile(fp,fn));
            bLog(['Selected model: ' fullfile(fp,fn)]);
        end

        function browseBlindCb(~,~)
            [fn,fp] = uigetfile({'*.mat;*.xlsx;*.xls;*.csv;*.txt','Supported files (*.mat,*.xlsx,*.xls,*.csv,*.txt)'},'Select blind sample file');
            if isequal(fn,0), return; end
            set(edBlind,'String',fullfile(fp,fn));
            bLog(['Selected blind sample: ' fullfile(fp,fn)]);
        end

        function runBlindCb(~,~)
            modelPath = strtrim(get(edModel,'String'));
            blindPath = strtrim(get(edBlind,'String'));
            nRep = round(str2double(get(edRep,'String')));
            if isempty(modelPath) || exist(modelPath,'file')~=2
                errordlg('Select a valid saved blind package MAT file.','RAVEN Blind Test');
                return;
            end
            if isempty(blindPath) || exist(blindPath,'file')~=2
                errordlg('Select a valid blind sample file.','RAVEN Blind Test');
                return;
            end
            if ~isfinite(nRep) || nRep < 1
                errordlg('Repeats must be a positive integer.','RAVEN Blind Test');
                return;
            end
            set(btnRunBlind,'Enable','off');
            bLog('Blind test started.');
            bLog(['Loading model: ' modelPath]);
            drawnow;
            try
                S = load(modelPath);
                bm = resolveBlindPackageStruct(S);
                bLog(sprintf('Loaded package with %d classes.', numel(bm.groupNames)));
                bLog(['Loaded package role: ' getTextScalar(bm,'roleName','UnknownRole')]);
                bLog(['Loading blind sample: ' blindPath]);
                [blindName, blindBlock] = loadBlindSampleFile(blindPath);
                bLog(sprintf('Blind sample "%s" loaded with %d spectra.', blindName, size(blindBlock,2)-1));
                bLog(sprintf('Running %d blind-test repeats...', nRep));
                resBlind = runBlindRepeats(bm, blindBlock, nRep, @bLog);
                cla(axBlind);
                bar(axBlind, 1:numel(bm.groupNames), resBlind.MeanVote, 0.75, 'FaceColor',[0.65 0.78 0.92], 'EdgeColor',[0.20 0.20 0.25]);
                hold(axBlind,'on');
                errorbar(axBlind, 1:numel(bm.groupNames), resBlind.MeanVote, resBlind.StdVote, '.', ...
                    'Color',[0.95 0.95 0.95], 'LineWidth',1.2);
                hold(axBlind,'off');
                set(axBlind,'XTick',1:numel(bm.groupNames),'XTickLabel',bm.groupNames, ...
                    'Color',[0.02 0.02 0.02],'XColor',[0.92 0.92 0.92],'YColor',[0.92 0.92 0.92], ...
                    'GridColor',[0.25 0.25 0.25],'MinorGridColor',[0.18 0.18 0.18]);
                xtickangle(axBlind,45);
                xlabel(axBlind,'Predicted Class','Color',[0.92 0.92 0.92]);
                ylabel(axBlind,'Vote (%)','Color',[0.92 0.92 0.92]);
                title(axBlind,sprintf('Blind vote | %s | Major: %s (%.2f%%)', blindName, resBlind.MajorClass, resBlind.MajorVote), ...
                    'Color',[0.92 0.92 0.92]);
                grid(axBlind,'on');
                set(txtMajor,'String',sprintf('Major vote: %s | %.2f%% | repeats=%d | blind spectra=%d', resBlind.MajorClass, resBlind.MajorVote, nRep, resBlind.NBlind));
                outDir = fullfile(fileparts(modelPath), ['BLIND_TEST_' regexprep(blindName,'[^A-Za-z0-9_\-]','_') '_' datestr(now,'yyyymmdd_HHMMSS')]);
                if ~exist(outDir,'dir'), mkdir(outDir); end
                bLog('Exporting blind-test results...');
                exportBlindResults(resBlind, bm, blindName, blindPath, outDir);
                set(txtInfo,'String',['Saved blind outputs to: ' outDir]);
                bLog(['Saved blind outputs to: ' outDir]);
                bLog(sprintf('Completed. Major vote = %s (%.2f%%).', resBlind.MajorClass, resBlind.MajorVote));
                logmsg(['Blind test completed. Saved to ' outDir]);
            catch MErr
                bLog(['Error: ' MErr.message]);
                errordlg(MErr.message,'RAVEN Blind Test');
            end
            set(btnRunBlind,'Enable','on');
        end
    end

    function bm = resolveBlindPackageStruct(S)
        if isfield(S,'blindPackage')
            bm = S.blindPackage;
        elseif isfield(S,'blindModel')
            bm = S.blindModel;
            if isstruct(bm) && (~isfield(bm,'formatVersion') || ~isfield(bm,'roleName'))
                bm = upgradeLegacyBlindModelToPackage(bm);
            end
        else
            fns = fieldnames(S);
            if numel(fns)==1 && isstruct(S.(fns{1}))
                bm = S.(fns{1});
                if ~isfield(bm,'formatVersion') || ~isfield(bm,'roleName')
                    bm = upgradeLegacyBlindModelToPackage(bm);
                end
            else
                error('The selected MAT file does not contain a blindPackage or compatible blindModel struct.');
            end
        end
    end

    function bm = upgradeLegacyBlindModelToPackage(legacy)
        bm = legacy;
        bm.kind = 'RAVEN_BlindPackage_v1';
        bm.formatVersion = 1;
        if ~isfield(bm,'roleName')
            if isfield(bm,'classifierLabel') && ~isempty(bm.classifierLabel)
                bm.roleName = bm.classifierLabel;
            else
                bm.roleName = 'LegacyBlindModel';
            end
        end
        if ~isfield(bm,'packageID')
            bm.packageID = sprintf('%s__legacy__%s', char(string(bm.roleName)), datestr(now,30));
        end
        if ~isfield(bm,'trainingSummary')
            bm.trainingSummary = struct();
        end
        if ~isfield(bm,'inference')
            bm.inference = struct('mode','refit_vote_repeats','predictFunction','predictBlindReadyModel', ...
                'fitFunction','fitBlindReadyModel','preprocessFunction','preprocessBlindBlock');
        end
        if ~isfield(bm,'compat')
            bm.compat = struct();
        end
        bm.compat.upgradedFromLegacy = true;
        if isfield(legacy,'kind')
            bm.compat.legacyKind = legacy.kind;
        end
    end

    function [blindName, blindBlock] = loadBlindSampleFile(fp)
        [~,nm,ext] = fileparts(fp);
        blindName = matlab.lang.makeValidName(nm);
        switch lower(ext)
            case '.mat'
                S = load(fp);
                [validNames, validBlocks] = pickMatVariablesAsClasses(S);
                if numel(validBlocks) ~= 1
                    error('Blind MAT file must contain exactly one valid dataset variable.');
                end
                blindBlock = validBlocks{1};
                blindName = matlab.lang.makeValidName(validNames{1});
            case {'.xlsx','.xls'}
                [validSheets, validBlocks] = pickExcelSheetsAsClasses(fp);
                if numel(validBlocks) ~= 1
                    error('Blind Excel file must contain exactly one valid sheet.');
                end
                blindBlock = validBlocks{1};
                blindName = matlab.lang.makeValidName(validSheets{1});
            case {'.csv','.txt'}
                [blindBlock, ~] = readSingleTableBasedFile(fp);
            otherwise
                error('Unsupported blind file type: %s', ext);
        end
        if ~isSuitableBlock(blindBlock)
            error('Blind sample file does not contain a valid [nW x (1+Nspec)] block.');
        end
    end

    function resBlind = runBlindRepeats(bm, blindBlock, nRep, progCb)
        if nargin < 4, progCb = []; end
        Cb = numel(bm.groupNames);
        votePct = zeros(nRep,Cb);
        rawAxis = bm.rawAxis;
        croppedAxis = bm.croppedAxis;
        blindX = preprocessBlindBlock(blindBlock, bm.preproc, rawAxis, croppedAxis);
        nBlind = size(blindX,1);
        for rr = 1:nRep
            if isa(progCb,'function_handle')
                progCb(sprintf('Repeat %d/%d: refitting model and predicting blind spectra...', rr, nRep));
            end
            seed = bm.seedBase + rr;
            mdl = fitBlindReadyModel(bm.trainData, bm.preproc, bm.cfgEval, seed);
            [yhat, scores] = predictBlindReadyModel(mdl, blindX);
            for cc = 1:Cb
                votePct(rr,cc) = 100*sum(yhat==cc)/max(1,numel(yhat));
            end
            if rr == 1
                allScores = scores;
                firstPred = yhat;
            end
        end
        if isa(progCb,'function_handle')
            progCb('Aggregating repeat votes...');
        end
        meanVote = mean(votePct,1);
        stdVote = std(votePct,0,1);
        [majorVote, idx] = max(meanVote);
        resBlind = struct();
        resBlind.VotePct = votePct;
        resBlind.MeanVote = meanVote;
        resBlind.StdVote = stdVote;
        resBlind.MajorIndex = idx;
        resBlind.MajorClass = bm.groupNames{idx};
        resBlind.MajorVote = majorVote;
        resBlind.NBlind = nBlind;
        resBlind.FirstPred = firstPred;
        resBlind.FirstScores = allScores;
    end

    function mdl = fitBlindReadyModel(trainData, pre, cfgEval, seed)
        rng(seed,'twister');
        [Wtrain, X_all, y_idx, groupNames, sampleCounts] = preprocessDataset(trainData, pre);
        mu = mean(X_all,1);
        Xc = bsxfun(@minus, X_all, mu);
        kPC = min([size(Xc,1)-1, size(Xc,2), cfgEval.teacher.kPC]);
        if kPC < 1, kPC = 1; end
        [coeff, scoreTr] = pca(Xc,'NumComponents',kPC,'Centered',false);
        Str = scoreTr(:,1:kPC);
        C = numel(groupNames);
        teacherModel = fitRavenTeacher(Str, y_idx, cfgEval.teacher, C);
        scoreT_tr = teacherModel.scoreTr;
        temp2 = max(1e-6, cfgEval.student.temp);
        Z = scoreT_tr / temp2;
        Z = Z - max(Z,[],2);
        Pteach = exp(Z);
        Pteach = Pteach ./ max(1e-12, sum(Pteach,2));
        Yoh = zeros(size(Str,1), C);
        Yoh(sub2ind([size(Str,1) C], (1:size(Str,1))', y_idx)) = 1;
        a2 = max(0,min(1,cfgEval.student.alpha));
        Ttr = a2*Pteach + (1-a2)*Yoh;
        studentModel = fitRavenStudent(Str, Ttr, cfgEval.student, seed + 1000);
        mdl = struct();
        mdl.kind = 'RAVEN_FullModel_v1';
        mdl.W = Wtrain;
        mdl.mu = mu;
        mdl.coeff = coeff;
        mdl.maxpc = kPC;
        mdl.groupNames = groupNames;
        mdl.sampleCounts = sampleCounts;
        mdl.cfgEval = cfgEval;
        mdl.teacherModel = teacherModel;
        mdl.studentModel = studentModel;
    end

    function [Phi_tr, fitObj] = fitRAVENModel(Str, cfgEval)
        ntr = size(Str,1);
        kEff = size(Str,2);
        D0 = min(cfgEval.D0, kEff);
        Ztr = Str(:,1:D0);
        [idxC, centers] = kmeans(Ztr, cfgEval.R, 'Replicates', cfgEval.kmeansReplicates, 'MaxIter', 200, 'Display', 'off');
        d0 = sqrt(sum((Ztr - centers(idxC,:)).^2,2));
        tau = cfgEval.tauScale * median(d0);
        if ~(isfinite(tau) && tau > 0), tau = 1.0; end
        Gtr = softGating(Ztr, centers, tau, cfgEval.topKGate);
        sigmaBase = autoSigma(Str);
        sigmaFold = sigmaBase * cfgEval.sigmaScale;
        if ~(isfinite(sigmaFold) && sigmaFold > 0), sigmaFold = 1.0; end
        gamma = 1/(2*sigmaFold^2);
        Rloc = cfgEval.R;
        Dm_eff = zeros(Rloc,1);
        Lcell = cell(Rloc,1);
        Ucell = cell(Rloc,1);
        lamCell = cell(Rloc,1);
        for mm = 1:Rloc
            w = Gtr(:,mm);
            idxLand = weightedSampleNoReplace(w, min(cfgEval.mLand, ntr));
            if isempty(idxLand)
                idxLand = randi(ntr, min(cfgEval.mLand,ntr), 1);
            end
            idxLand = unique(idxLand(:),'stable');
            L = Str(idxLand,:);
            if size(L,1) == 1
                L = [L; L + 1e-12*randn(size(L))];
            end
            Kll = rbfGram(L,L,gamma);
            Kll = (Kll + Kll')/2;
            Kll = Kll + cfgEval.ridge * mean(diag(Kll)+eps) * eye(size(Kll));
            [V,Dd] = eig(Kll);
            lam = real(diag(Dd));
            [lam,ord] = sort(lam,'descend');
            V = V(:,ord);
            lam = max(lam,0);
            keep = find(lam > 1e-10*max(1,max(lam)));
            if isempty(keep), keep = 1; end
            lam = lam(keep); V = V(:,keep);
            if strcmpi(cfgEval.rankMode,'adaptive')
                cs = cumsum(lam) / max(eps,sum(lam));
                Duse = find(cs >= cfgEval.rho, 1, 'first');
                if isempty(Duse), Duse = numel(lam); end
            else
                Duse = min(cfgEval.Dloc, numel(lam));
            end
            Duse = max(1, min(Duse, numel(lam)));
            lam = lam(1:Duse); V = V(:,1:Duse);
            Dm_eff(mm) = Duse;
            Lcell{mm} = L;
            Ucell{mm} = V;
            lamCell{mm} = lam;
        end
        Dtot = sum(Dm_eff);
        Phi_tr = zeros(size(Str,1), Dtot);
        c0 = 1;
        for mm = 1:Rloc
            Dm = Dm_eff(mm);
            L = Lcell{mm}; U = Ucell{mm}; lam = lamCell{mm}(:)';
            Ktr = rbfGram(Str,L,gamma);
            tmpTr = (Ktr*U) .* (1./sqrt(max(lam,1e-12)));
            tmpTr = tmpTr .* Gtr(:,mm);
            Phi_tr(:,c0:c0+Dm-1) = tmpTr;
            c0 = c0 + Dm;
        end
        fitObj = struct('centers',centers,'tau',tau,'gamma',gamma,'D0',D0,'topKGate',cfgEval.topKGate, ...
            'Dm_eff',Dm_eff,'Lcell',{Lcell},'Ucell',{Ucell},'lamCell',{lamCell});
    end

    function [yhat, scores] = predictBlindReadyModel(mdl, Xblind)
        Xc = bsxfun(@minus, Xblind, mdl.mu);
        Ste = Xc * mdl.coeff;
        Ste = Ste(:,1:mdl.maxpc);
        [yhat, scores] = predictRavenStudent(mdl.studentModel, Ste);
    end

    function Phi_te = applyRAVENModel(Ste, fitObj)
        Zte = Ste(:,1:fitObj.D0);
        Gte = softGating(Zte, fitObj.centers, fitObj.tau, fitObj.topKGate);
        Dtot = sum(fitObj.Dm_eff);
        Phi_te = zeros(size(Ste,1), Dtot);
        c0 = 1;
        for mm = 1:numel(fitObj.Dm_eff)
            Dm = fitObj.Dm_eff(mm);
            L = fitObj.Lcell{mm}; U = fitObj.Ucell{mm}; lam = fitObj.lamCell{mm}(:)';
            Kte = rbfGram(Ste,L,fitObj.gamma);
            tmpTe = (Kte*U) .* (1./sqrt(max(lam,1e-12)));
            tmpTe = tmpTe .* Gte(:,mm);
            Phi_te(:,c0:c0+Dm-1) = tmpTe;
            c0 = c0 + Dm;
        end
    end

    function Xblind = preprocessBlindBlock(M, pre, rawAxisRef, croppedAxisRef)
        if istable(M), M = table2array(M); end
        if ~isnumeric(M) || size(M,2) < 2
            error('Blind dataset is not a numeric [nW x (1+Nspec)] block.');
        end
        wv = double(M(:,1));
        Xblk = double(M(:,2:end));
        if ~axesMatch(wv, rawAxisRef)
            error('Blind sample spectral-variable axis does not match the trained model axis.');
        end
        [wvUse, XblkUse] = cropBlockByXLimits(wv, Xblk, pre);
        if ~axesMatch(wvUse, croppedAxisRef)
            error('Blind sample cropped spectral-variable axis does not match the trained model cropped axis.');
        end
        if mod(pre.sgFrame,2)==0
            pre.sgFrame = pre.sgFrame + 1;
        end
        sgKernel = [];
        if ravenGetField(pre,'smoothEnable',1) || ravenGetField(pre,'derivOrder',0) > 0
            sgKernel = buildSGKernel(pre.sgFrame, pre.sgOrder, ravenGetField(pre,'derivOrder',0), 1);
        end
        nW = numel(wvUse);
        e = ones(nW,1);
        D2 = spdiags([e -2*e e], 0:2, nW-2, nW);
        DtD = D2'*D2;
        Xpp = applyPreprocBlock(XblkUse, pre, DtD, sgKernel);
        Xblind = Xpp.';
    end

    function exportBlindResults(resBlind, bm, blindName, blindPath, outDir)
        roleName = getTextScalar(bm,'roleName','UnknownRole');
        pkgID = getTextScalar(bm,'packageID','UnknownPackage');
        fmtVer = getNumericScalar(bm,'formatVersion',NaN);
        Tsum = table({blindName},{blindPath},resBlind.NBlind,{resBlind.MajorClass},resBlind.MajorVote,{roleName},{pkgID},fmtVer, ...
            'VariableNames',{'BlindName','BlindFile','NumSpectra','MajorClass','MajorVotePct','PackageRole','PackageID','FormatVersion'});
        Tv = array2table(resBlind.VotePct,'VariableNames', matlab.lang.makeValidName(bm.groupNames));
        Tv = addvars(Tv,(1:size(Tv,1))','Before',1,'NewVariableNames','Repeat');
        Tmean = table(bm.groupNames(:), resBlind.MeanVote(:), resBlind.StdVote(:), ...
            'VariableNames',{'Class','MeanVotePct','StdVotePct'});
        predNames = bm.groupNames(resBlind.FirstPred(:));
        if isempty(resBlind.FirstScores)
            Tpred = table((1:resBlind.NBlind)', resBlind.FirstPred(:), predNames(:), ...
                'VariableNames',{'Spectrum','PredictedIndex','PredictedClass'});
        else
            Tscores = array2table(resBlind.FirstScores, 'VariableNames', strcat('Score_', matlab.lang.makeValidName(bm.groupNames)));
            Tpred = table((1:resBlind.NBlind)', resBlind.FirstPred(:), predNames(:), ...
                'VariableNames',{'Spectrum','PredictedIndex','PredictedClass'});
            Tpred = [Tpred Tscores];
        end
        try
            xlsxBlind = fullfile(outDir,'BLIND_TEST_RESULTS.xlsx');
            writetable(Tsum, xlsxBlind, 'Sheet','Summary');
            writetable(Tmean, xlsxBlind, 'Sheet','MeanVotes');
            writetable(Tv, xlsxBlind, 'Sheet','VotesByRepeat');
            writetable(Tpred, xlsxBlind, 'Sheet','FirstRepeatPredictions');
        catch
        end
        fig = figure('Visible','off','Color','w');
        bar(1:numel(bm.groupNames), resBlind.MeanVote, 0.75, 'FaceColor',[0.63 0.76 0.92], 'EdgeColor',[0.2 0.2 0.2]); hold on;
        errorbar(1:numel(bm.groupNames), resBlind.MeanVote, resBlind.StdVote, 'k.', 'LineWidth',1.2); hold off; grid on;
        set(gca,'XTick',1:numel(bm.groupNames),'XTickLabel',bm.groupNames);
        xtickangle(45);
        xlabel('Predicted Class'); ylabel('Vote (%)');
        title(sprintf('Blind vote | %s | %s | Major=%s (%.2f%%)', blindName, roleName, resBlind.MajorClass, resBlind.MajorVote));
        saveFig(fig, fullfile(outDir,'Blind_vote_percentages.png'));
        try
            fid = fopen(fullfile(outDir,'BLIND_EVALUATION_SUMMARY.txt'),'w');
            if fid > 0
                fprintf(fid,'Blind sample evaluation summary\n');
                fprintf(fid,'===============================\n');
                fprintf(fid,'Blind name      : %s\n', blindName);
                fprintf(fid,'Blind file      : %s\n', blindPath);
                fprintf(fid,'Package role    : %s\n', roleName);
                fprintf(fid,'Package ID      : %s\n', pkgID);
                fprintf(fid,'Format version  : %.0f\n', fmtVer);
                fprintf(fid,'Num spectra     : %d\n', resBlind.NBlind);
                fprintf(fid,'Major class     : %s\n', resBlind.MajorClass);
                fprintf(fid,'Major vote (%%)  : %.4f\n\n', resBlind.MajorVote);
                fprintf(fid,'Mean vote by class\n');
                for ii = 1:numel(bm.groupNames)
                    fprintf(fid,'  %s : %.4f +/- %.4f\n', bm.groupNames{ii}, resBlind.MeanVote(ii), resBlind.StdVote(ii));
                end
                fclose(fid);
            end
            fid = fopen(latestPath,'w');
            if fid ~= -1
                fprintf(fid,'RAVEN GUI error log\n');
                fprintf(fid,'Time: %s\n', datestr(now,31));
                fprintf(fid,'Context: %s\n', context);
                fprintf(fid,'Message: %s\n\n', ME.message);
                fprintf(fid,'%s\n', rep);
                fclose(fid);
            end
            logmsg(['Error log saved: ' errPath]);
        catch MEw
            logmsg(['Could not write error txt: ' MEw.message]);
        end
    end
