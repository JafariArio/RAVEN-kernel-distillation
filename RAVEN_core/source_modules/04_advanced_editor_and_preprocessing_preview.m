    function onAdvancedSteps(~,~)
        syncCfgFromUI();

        scr = get(0,'ScreenSize');
        dlgW = max(1100, round(0.90*scr(3)));
        dlgH = max(720,  round(0.90*scr(4)));
        dlgX = scr(1) + round((scr(3)-dlgW)/2);
        dlgY = scr(2) + round((scr(4)-dlgH)/2);
        dlg = figure('Name','RAVEN_V1_01 Advanced Settings', ...
            'NumberTitle','off','MenuBar','none','ToolBar','none', ...
            'Resize','on','WindowStyle','modal','Color',[0 0 0], ...
            'Units','pixels','Position',[dlgX dlgY dlgW dlgH]);

        uicontrol(dlg,'Style','text','Units','normalized', ...
            'Position',[0.02 0.945 0.96 0.035], ...
            'String','Step-paged advanced editor for RAVEN. Settings are grouped by pipeline stage so Step 0/1/2/3/4, runtime/CV, and benchmark controls are separated.', ...
            'HorizontalAlignment','left','BackgroundColor',[0 0 0], ...
            'FontWeight','bold','FontSize',10,'ForegroundColor',[0.92 0.92 0.92]);

        uicontrol(dlg,'Style','text','Units','normalized', ...
            'Position',[0.02 0.895 0.12 0.03], ...
            'String','Settings Page','HorizontalAlignment','left', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
            'FontWeight','bold','FontSize',9.5);

        pageNames = {'Step 0 - Data and Preprocessing','Step 1 - CV PCA and Teacher Baseline', ...
            'Step 2 - Teacher Search','Step 3 - Student Search','Step 4 - Final Selection', ...
            'CV and Runtime','Benchmark'};
        popPage = uicontrol(dlg,'Style','popupmenu','Units','normalized', ...
            'Position',[0.145 0.892 0.34 0.04], ...
            'String',pageNames,'Value',1, ...
            'BackgroundColor',[0.08 0.08 0.08],'ForegroundColor',[0.95 0.95 0.95], ...
            'Callback',@onPageChanged,'FontSize',9.5);

        pagePos = [0.02 0.11 0.96 0.77];
        p0 = uipanel(dlg,'Units','normalized','Position',pagePos, ...
            'Title','Step 0 / Data and Preprocessing','FontWeight','bold', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        p1 = uipanel(dlg,'Units','normalized','Position',pagePos, ...
            'Title','Step 1 / CV PCA and Teacher Baseline','FontWeight','bold', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        p2 = uipanel(dlg,'Units','normalized','Position',pagePos, ...
            'Title','Step 2 / Teacher Search','FontWeight','bold', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        p3 = uipanel(dlg,'Units','normalized','Position',pagePos, ...
            'Title','Step 3 / Student Search','FontWeight','bold', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        p4 = uipanel(dlg,'Units','normalized','Position',pagePos, ...
            'Title','Step 4 / Final Selection','FontWeight','bold', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        pR = uipanel(dlg,'Units','normalized','Position',pagePos, ...
            'Title','CV and Runtime','FontWeight','bold', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        pB = uipanel(dlg,'Units','normalized','Position',pagePos, ...
            'Title','Benchmark','FontWeight','bold', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        pagePanels = {p0,p1,p2,p3,p4,pR,pB};

        labels0 = {'Input mode','Common axis mode','Target length (0 = auto)','Segmentation enable (0/1)', ...
            'Segment length','Segment stride','Preprocessing enable (0/1)','Smooth enable (0/1)','Baseline enable (0/1)', ...
            'Normalize enable (0/1)','SG order','SG frame','Derivative order','AsLS lambda','AsLS p','AsLS nIter', ...
            'Normalization mode','Cosmic denoise (0/1)','xMin crop (blank = none)','xMax crop (blank = none)', ...
            'Range windows [min max; ...]'};
        values0 = {app.cfg.step0.inputMode, app.cfg.step0.commonAxisMode, num2str(zeroIfEmpty(app.cfg.step0.targetLength)), ...
            num2str(double(app.cfg.step0.segmentationEnable)), num2str(zeroIfEmpty(app.cfg.step0.segmentLength)), ...
            num2str(zeroIfEmpty(app.cfg.step0.segmentStride)), num2str(double(app.cfg.preproc.enabled)), ...
            num2str(double(ravenGetField(app.cfg.preproc,'smoothEnable',1))), num2str(double(ravenGetField(app.cfg.preproc,'baseEnable',1))), ...
            num2str(double(ravenGetField(app.cfg.preproc,'normEnable',1))), num2str(app.cfg.preproc.sgOrder), num2str(app.cfg.preproc.sgFrame), ...
            num2str(ravenGetField(app.cfg.preproc,'derivOrder',0)), num2str(app.cfg.preproc.aslsLambda), num2str(app.cfg.preproc.aslsP), ...
            num2str(app.cfg.preproc.aslsNIter), app.cfg.preproc.normMode, num2str(double(app.cfg.preproc.cosmicDenoise)), ...
            numToBlank(app.cfg.preproc.xMin), numToBlank(app.cfg.preproc.xMax), rangeWindowsToText(ravenGetField(app.cfg.preproc,'rangeWindows',[]))};
        kinds0 = {'popup','popup','edit','edit','edit','edit','edit','edit','edit','edit','edit','edit','popup','edit','edit','edit','popup','edit','edit','edit','edit'};
        opts0 = {{'spectra_blocks','feature_matrix'},{'preserve','intersect','resample'},[],[],[],[],[],[],[],[],[],[],{'0','1','2'},[],[],[],{'L2','NONE','MAX','SNV'},[],[],[],[]};

        labels1 = {'Outer CV folds','Outer CV repeats','Split mode','Seed base','kPC list','PCA mode', ...
            'Single kPC','Variance target','Coarse-to-fine (0/1)','Teacher baseline mLand', ...
            'Teacher baseline rTeach','Teacher baseline sigmaScale','Teacher baseline BoxC'};
        values1 = {num2str(app.cfg.cv.outerK), num2str(app.cfg.cv.repeats), app.cfg.cv.splitMode, ...
            num2str(app.cfg.cv.seedBase), num2str(app.cfg.step1.kPCList), app.cfg.step1.pcaMode, ...
            num2str(app.cfg.step1.singleKPC), num2str(app.cfg.step1.varianceTarget), ...
            num2str(double(app.cfg.step1.coarseToFine)), num2str(app.cfg.step1.teacherMLand), ...
            num2str(app.cfg.step1.teacherRTeach), num2str(app.cfg.step1.teacherSigmaScale), ...
            num2str(app.cfg.step1.teacherBoxC)};
        kinds1 = {'edit','edit','popup','edit','edit','popup','edit','edit','edit','edit','edit','edit','edit'};
        opts1 = {[],[],{'stratified','grouped'},[],[],{'fixedlist','single','variance'},[],[],[],[],[],[],[]};

        labels2 = {'Teacher mLand list','Teacher rTeach list','Teacher sigmaScale list','Teacher BoxC list', ...
            'Shortlist N','kmeans replicates','topKGate (0 = dense)'};
        values2 = {num2str(app.cfg.step2.mLandList), num2str(app.cfg.step2.rTeachList), ...
            num2str(app.cfg.step2.sigmaScaleList), num2str(app.cfg.step2.boxCList), ...
            num2str(app.cfg.step2.shortlistN), num2str(app.cfg.step2.kmeansReplicates), ...
            num2str(app.cfg.step2.topKGate)};
        kinds2 = {'edit','edit','edit','edit','edit','edit','edit'};
        opts2 = {[],[],[],[],[],[],[]};

        labels3 = {'Search mode','pHidden list','lamRidge list','alpha list','temp list','skipScale list', ...
            'ensemble list','Teacher shortlist N','Student shortlist N','Minimum accuracy ratio', ...
            'Rank mode','Dloc list'};
        values3 = {ravenGetField(app.cfg.step3,'mode','full_search'), num2str(app.cfg.step3.pHiddenList), num2str(app.cfg.step3.lamRidgeList), ...
            num2str(app.cfg.step3.alphaList), num2str(app.cfg.step3.tempList), ...
            num2str(app.cfg.step3.skipScaleList), num2str(app.cfg.step3.ensembleList), ...
            num2str(app.cfg.step3.teacherShortlistN), num2str(app.cfg.step3.shortlistN), ...
            num2str(app.cfg.step3.minAccRatio), app.cfg.step3.rankMode, num2str(app.cfg.step3.DlocList)};
        kinds3 = {'popup','edit','edit','edit','edit','edit','edit','edit','edit','edit','popup','edit'};
        opts3 = {{'full_search','fast_search','single_teacher_sweep','single_candidate'},[],[],[],[],[],[],[],[],[],{'adaptive','fixed'},[]};

        labels4 = {'Winner policy','Top finalists per bucket','repeatsFast','repeatsBestAccuracy', ...
            'repeatsBestScore','repeatsBestMemory','Accuracy threshold fraction','Number of ROC points'};
        values4 = {char(resolveStep4WinnerPolicy()), num2str(app.cfg.step4.topFinalistsPerBucket), ...
            num2str(app.cfg.step4.repeatsFast), num2str(app.cfg.step4.repeatsBestAccuracy), ...
            num2str(app.cfg.step4.repeatsBestScore), num2str(app.cfg.step4.repeatsBestMemory), ...
            num2str(app.cfg.step4.accThresholdFrac), num2str(app.cfg.step4.numROC)};
        kinds4 = {'popup','edit','edit','edit','edit','edit','edit','edit'};
        opts4 = {{'bestscore','bestaccuracy'},[],[],[],[],[],[],[]};

        labelsR = {'Parallel workers','Pause poll sec','Save intermediate (0/1)','Save PNG (0/1)', ...
            'Save Excel (0/1)','Verbose (0/1)','Verbose timing (0/1)','Save run manifest (0/1)', ...
            'Export split summary (0/1)','Export master report (0/1)','Export data disposition (0/1)'};
        valuesR = {num2str(app.cfg.cv.nWorkers), num2str(app.cfg.runtime.pausePollSec), ...
            num2str(double(app.cfg.runtime.saveIntermediate)), num2str(double(app.cfg.runtime.savePNG)), ...
            num2str(double(app.cfg.runtime.saveExcel)), num2str(double(app.cfg.runtime.verbose)), ...
            num2str(double(app.cfg.runtime.verboseTiming)), num2str(double(app.cfg.runtime.saveRunManifest)), ...
            num2str(double(app.cfg.runtime.exportSplitSummary)), num2str(double(app.cfg.runtime.exportMasterReport)), ...
            num2str(double(app.cfg.runtime.exportDataDisposition))};
        kindsR = {'edit','edit','edit','edit','edit','edit','edit','edit','edit','edit','edit'};
        optsR = {[],[],[],[],[],[],[],[],[],[],[]};

        bmEnabled = double(app.cfg.runtime.runBenchmarks || app.cfg.benchmark.enabled);
        benchmarkChoices = {'PCA_LINSVM','PCA_LDA','PCA_RF'};
        labelsB = {'Run benchmarks (0/1)','Benchmark kPC (blank = auto)', ...
            'Benchmark outer folds (blank = main CV)','Benchmark repeats (blank = main CV)', ...
            'Benchmark BoxC','Benchmark numTrees','Benchmark maxSplits'};
        valuesB = {num2str(bmEnabled), numToBlank(app.cfg.benchmark.kPC), ...
            numToBlank(app.cfg.benchmark.outerK), numToBlank(app.cfg.benchmark.repeats), ...
            num2str(app.cfg.benchmark.boxC), num2str(app.cfg.benchmark.numTrees), ...
            num2str(app.cfg.benchmark.maxSplits)};
        kindsB = {'popup','edit','edit','edit','edit','edit','edit'};
        optsB = {{'0','1'},[],[],[],[],[],[]};

        ed0 = buildSettingsPage(p0, labels0, values0, kinds0, opts0, [0.03 0.05 0.94 0.90]);
        ed1 = buildSettingsPage(p1, labels1, values1, kinds1, opts1, [0.03 0.05 0.94 0.90]);
        ed2 = buildSettingsPage(p2, labels2, values2, kinds2, opts2, [0.03 0.08 0.94 0.86]);
        ed3 = buildSettingsPage(p3, labels3, values3, kinds3, opts3, [0.03 0.06 0.94 0.88]);
        ed4 = buildSettingsPage(p4, labels4, values4, kinds4, opts4, [0.03 0.08 0.94 0.86]);
        edR = buildSettingsPage(pR, labelsR, valuesR, kindsR, optsR, [0.03 0.34 0.46 0.58]);
        edB = buildSettingsPage(pB, labelsB, valuesB, kindsB, optsB, [0.03 0.22 0.46 0.76]);

        gv = app.cfg.cv.groupValidation;
        if isempty(gv) || ~isstruct(gv)
            gv = struct('message','No group vector loaded.','effectiveMode','stratified','numGroups',0,'requiredGroups',app.cfg.cv.outerK, ...
                'classWiseMinGroups',0,'fallbackReason','');
        end
        runtimeInfo = sprintf(['Grouped CV status\n\nRequested mode: %s\nEffective mode: %s\nGroups found: %d\nGroups required: %d\nMin class-wise groups: %d\n\nMessage:\n%s\n\nFallback reason:\n%s'], ...
            app.cfg.cv.splitMode, toText(getFieldOr(gv,'effectiveMode','stratified')), round(getFieldOr(gv,'numGroups',0)), ...
            round(getFieldOr(gv,'requiredGroups',app.cfg.cv.outerK)), round(getFieldOr(gv,'classWiseMinGroups',0)), ...
            toText(getFieldOr(gv,'message','')), toText(getFieldOr(gv,'fallbackReason','')));
        uicontrol(pR,'Style','text','Units','normalized', ...
            'Position',[0.54 0.88 0.40 0.06],'String','Grouped-CV validation snapshot', ...
            'HorizontalAlignment','left','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
            'FontWeight','bold','FontSize',9.5);
        txtRuntimeInfo = uicontrol(pR,'Style','edit','Units','normalized', ...
            'Position',[0.54 0.14 0.42 0.72],'String',runtimeInfo, 'Min',0,'Max',2, ...
            'Enable','inactive','HorizontalAlignment','left', ...
            'BackgroundColor',[0.04 0.04 0.04],'ForegroundColor',[0.92 0.92 0.92], ...
            'FontName','Consolas','FontSize',9.2);

        methodLblY = 0.90;
        uicontrol(pB,'Style','text','Units','normalized', ...
            'Position',[0.54 methodLblY 0.40 0.05], ...
            'String','Benchmark methods (multi-select)','HorizontalAlignment','left', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
            'FontWeight','bold','FontSize',9.3);
        methodVals = find(ismember(benchmarkChoices, app.cfg.benchmark.methods));
        if isempty(methodVals), methodVals = 1:numel(benchmarkChoices); end
        lbBenchmarkMethods = uicontrol(pB,'Style','listbox','Units','normalized', ...
            'Position',[0.54 0.65 0.40 0.24], 'String',benchmarkChoices, ...
            'Min',0,'Max',numel(benchmarkChoices),'Value',methodVals, ...
            'BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
            'FontName','Consolas','FontSize',9.3, ...
            'TooltipString','Choose one or more baseline benchmark methods.');
        uicontrol(pB,'Style','text','Units','normalized', ...
            'Position',[0.54 0.50 0.40 0.10], ...
            'String','Benchmark controls are separated from Step 1-4 so publication baselines can be edited without mixing them into the main RAVEN search pages.', ...
            'HorizontalAlignment','left','BackgroundColor',[0 0 0],'ForegroundColor',[0.78 0.84 0.84], ...
            'FontSize',9.1);

        for kk = 1:numel(pagePanels)
            set(pagePanels{kk},'Visible','off');
        end
        set(pagePanels{1},'Visible','on');

        uicontrol(dlg,'Style','pushbutton','Units','normalized', ...
            'Position',[0.56 0.03 0.14 0.055],'String','Load Defaults', ...
            'FontWeight','bold','BackgroundColor',[0.15 0.15 0.15], ...
            'ForegroundColor',[0.92 0.92 0.92],'Callback',@onLoadDefaults);
        uicontrol(dlg,'Style','pushbutton','Units','normalized', ...
            'Position',[0.72 0.03 0.12 0.055],'String','Apply', ...
            'FontWeight','bold','BackgroundColor',[0.10 0.22 0.18], ...
            'ForegroundColor',[0.92 0.98 0.94],'Callback',@onApplyDialog);
        uicontrol(dlg,'Style','pushbutton','Units','normalized', ...
            'Position',[0.86 0.03 0.12 0.055],'String','Cancel', ...
            'FontWeight','bold','BackgroundColor',[0.22 0.12 0.12], ...
            'ForegroundColor',[0.96 0.90 0.90],'Callback',@(~,~) delete(dlg));

        uiwait(dlg);

        function edits = buildSettingsPage(parent, labels, values, kinds, options, panelPos)
            if nargin < 6 || isempty(panelPos)
                panelPos = [0.03 0.05 0.94 0.90];
            end
            n = numel(labels);
            edits = gobjects(n,1);
            if n <= 8
                nCols = 1;
            elseif n <= 16
                nCols = 2;
            else
                nCols = 3;
            end
            colGap = 0.025;
            rowGap = 0.014;
            rowsPerCol = ceil(n / nCols);
            cellW = (panelPos(3) - colGap*(nCols-1)) / nCols;
            cellH = (panelPos(4) - rowGap*(rowsPerCol-1)) / max(1,rowsPerCol);
            cellH = max(0.095, min(0.155, cellH));
            labelFrac = 0.40;
            editFrac = 0.44;
            for ii = 1:n
                colIdx = ceil(ii / rowsPerCol);
                rowIdx = ii - (colIdx-1)*rowsPerCol;
                x = panelPos(1) + (colIdx-1)*(cellW + colGap);
                yTop = panelPos(2) + panelPos(4) - (rowIdx-1)*(cellH + rowGap);
                y = yTop - cellH;
                labelY = y + cellH*(1-labelFrac);
                editY = y + cellH*0.04;
                labelH = cellH*labelFrac;
                editH = cellH*editFrac;
                uicontrol(parent,'Style','text','Units','normalized', ...
                    'Position',[x labelY cellW labelH], ...
                    'String',labels{ii},'HorizontalAlignment','left', ...
                    'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
                    'FontWeight','bold','FontSize',9.0);
                if strcmpi(kinds{ii},'popup')
                    opts = options{ii};
                    if isempty(opts), opts = {char(values{ii})}; end
                    v0 = matchPopupValue(values{ii}, opts);
                    edits(ii) = uicontrol(parent,'Style','popupmenu','Units','normalized', ...
                        'Position',[x editY cellW editH], 'String',opts, 'Value',v0, ...
                        'BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
                        'FontName','Consolas','FontSize',9.0);
                else
                    edits(ii) = uicontrol(parent,'Style','edit','Units','normalized', ...
                        'Position',[x editY cellW editH], 'String',values{ii}, ...
                        'BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
                        'HorizontalAlignment','left','FontName','Consolas','FontSize',9.0);
                end
            end
        end

        function onPageChanged(src,~)
            idx = get(src,'Value');
            for jj = 1:numel(pagePanels)
                set(pagePanels{jj},'Visible','off');
            end
            set(pagePanels{idx},'Visible','on');
        end

        function v = matchPopupValue(curVal, opts)
            curVal = lower(strtrim(toText(curVal)));
            tmp = lower(cellfun(@strtrim, opts, 'UniformOutput', false));
            v = find(strcmp(curVal, tmp), 1, 'first');
            if isempty(v), v = 1; end
        end

        function out = popupText(h)
            strs = get(h,'String');
            if ischar(strs)
                strs = cellstr(strs);
            end
            idx = get(h,'Value');
            idx = max(1, min(numel(strs), idx));
            out = char(strs{idx});
        end

        function out = numToBlank(v)
            if isempty(v) || (isnumeric(v) && any(isnan(v(:))))
                out = '';
            else
                out = num2str(v);
            end
        end

        function z = zeroIfEmpty(v)
            if isempty(v) || (isnumeric(v) && any(isnan(v(:))))
                z = 0;
            else
                z = v;
            end
        end

        function x = getFieldOr(S, fieldName, defaultVal)
            x = defaultVal;
            if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
                x = S.(fieldName);
            end
        end

        function onLoadDefaults(~,~)
            defs = makeDefaultConfig();
            set(ed0(1),'Value',matchPopupValue(defs.step0.inputMode, opts0{1}));
            set(ed0(2),'Value',matchPopupValue(defs.step0.commonAxisMode, opts0{2}));
            set(ed0(3),'String',num2str(zeroIfEmpty(defs.step0.targetLength)));
            set(ed0(4),'String',num2str(double(defs.step0.segmentationEnable)));
            set(ed0(5),'String',num2str(zeroIfEmpty(defs.step0.segmentLength)));
            set(ed0(6),'String',num2str(zeroIfEmpty(defs.step0.segmentStride)));
            set(ed0(7),'String',num2str(double(defs.preproc.enabled)));
            set(ed0(8),'String',num2str(double(defs.preproc.smoothEnable)));
            set(ed0(9),'String',num2str(double(defs.preproc.baseEnable)));
            set(ed0(10),'String',num2str(double(defs.preproc.normEnable)));
            set(ed0(11),'String',num2str(defs.preproc.sgOrder));
            set(ed0(12),'String',num2str(defs.preproc.sgFrame));
            set(ed0(13),'Value',matchPopupValue(num2str(defs.preproc.derivOrder), opts0{13}));
            set(ed0(14),'String',num2str(defs.preproc.aslsLambda));
            set(ed0(15),'String',num2str(defs.preproc.aslsP));
            set(ed0(16),'String',num2str(defs.preproc.aslsNIter));
            set(ed0(17),'Value',matchPopupValue(defs.preproc.normMode, opts0{17}));
            set(ed0(18),'String',num2str(double(defs.preproc.cosmicDenoise)));
            set(ed0(19),'String',numToBlank(defs.preproc.xMin));
            set(ed0(20),'String',numToBlank(defs.preproc.xMax));
            set(ed0(21),'String',rangeWindowsToText(defs.preproc.rangeWindows));

            set(ed1(1),'String',num2str(defs.cv.outerK));
            set(ed1(2),'String',num2str(defs.cv.repeats));
            set(ed1(3),'Value',matchPopupValue(defs.cv.splitMode, opts1{3}));
            set(ed1(4),'String',num2str(defs.cv.seedBase));
            set(ed1(5),'String',num2str(defs.step1.kPCList));
            set(ed1(6),'Value',matchPopupValue(defs.step1.pcaMode, opts1{6}));
            set(ed1(7),'String',num2str(defs.step1.singleKPC));
            set(ed1(8),'String',num2str(defs.step1.varianceTarget));
            set(ed1(9),'String',num2str(double(defs.step1.coarseToFine)));
            set(ed1(10),'String',num2str(defs.step1.teacherMLand));
            set(ed1(11),'String',num2str(defs.step1.teacherRTeach));
            set(ed1(12),'String',num2str(defs.step1.teacherSigmaScale));
            set(ed1(13),'String',num2str(defs.step1.teacherBoxC));

            set(ed2(1),'String',num2str(defs.step2.mLandList));
            set(ed2(2),'String',num2str(defs.step2.rTeachList));
            set(ed2(3),'String',num2str(defs.step2.sigmaScaleList));
            set(ed2(4),'String',num2str(defs.step2.boxCList));
            set(ed2(5),'String',num2str(defs.step2.shortlistN));
            set(ed2(6),'String',num2str(defs.step2.kmeansReplicates));
            set(ed2(7),'String',num2str(defs.step2.topKGate));

            set(ed3(1),'Value',matchPopupValue(ravenGetField(defs.step3,'mode','full_search'), opts3{1}));
            set(ed3(2),'String',num2str(defs.step3.pHiddenList));
            set(ed3(3),'String',num2str(defs.step3.lamRidgeList));
            set(ed3(4),'String',num2str(defs.step3.alphaList));
            set(ed3(5),'String',num2str(defs.step3.tempList));
            set(ed3(6),'String',num2str(defs.step3.skipScaleList));
            set(ed3(7),'String',num2str(defs.step3.ensembleList));
            set(ed3(8),'String',num2str(defs.step3.teacherShortlistN));
            set(ed3(9),'String',num2str(defs.step3.shortlistN));
            set(ed3(10),'String',num2str(defs.step3.minAccRatio));
            set(ed3(11),'Value',matchPopupValue(defs.step3.rankMode, opts3{11}));
            set(ed3(12),'String',num2str(defs.step3.DlocList));

            set(ed4(1),'Value',matchPopupValue(resolveStep4WinnerPolicy(), opts4{1}));
            set(ed4(2),'String',num2str(defs.step4.topFinalistsPerBucket));
            set(ed4(3),'String',num2str(defs.step4.repeatsFast));
            set(ed4(4),'String',num2str(defs.step4.repeatsBestAccuracy));
            set(ed4(5),'String',num2str(defs.step4.repeatsBestScore));
            set(ed4(6),'String',num2str(defs.step4.repeatsBestMemory));
            set(ed4(7),'String',num2str(defs.step4.accThresholdFrac));
            set(ed4(8),'String',num2str(defs.step4.numROC));

            set(edR(1),'String',num2str(defs.cv.nWorkers));
            set(edR(2),'String',num2str(defs.runtime.pausePollSec));
            set(edR(3),'String',num2str(double(defs.runtime.saveIntermediate)));
            set(edR(4),'String',num2str(double(defs.runtime.savePNG)));
            set(edR(5),'String',num2str(double(defs.runtime.saveExcel)));
            set(edR(6),'String',num2str(double(defs.runtime.verbose)));
            set(edR(7),'String',num2str(double(defs.runtime.verboseTiming)));
            set(edR(8),'String',num2str(double(defs.runtime.saveRunManifest)));
            set(edR(9),'String',num2str(double(defs.runtime.exportSplitSummary)));
            set(edR(10),'String',num2str(double(defs.runtime.exportMasterReport)));
            set(edR(11),'String',num2str(double(defs.runtime.exportDataDisposition)));

            set(edB(1),'Value',2);
            methodVals = find(ismember(benchmarkChoices, defs.benchmark.methods));
            if isempty(methodVals), methodVals = 1:numel(benchmarkChoices); end
            set(lbBenchmarkMethods,'Value',methodVals);
            set(edB(2),'String',numToBlank(defs.benchmark.kPC));
            set(edB(3),'String',numToBlank(defs.benchmark.outerK));
            set(edB(4),'String',numToBlank(defs.benchmark.repeats));
            set(edB(5),'String',num2str(defs.benchmark.boxC));
            set(edB(6),'String',num2str(defs.benchmark.numTrees));
            set(edB(7),'String',num2str(defs.benchmark.maxSplits));
        end

        function onApplyDialog(~,~)
            app.cfg.step0.inputMode = lower(strtrim(popupText(ed0(1))));
            app.cfg.io.inputMode = app.cfg.step0.inputMode;
            app.cfg.step0.commonAxisMode = lower(strtrim(popupText(ed0(2))));
            if ~ismember(app.cfg.step0.commonAxisMode, {'preserve','intersect','resample'})
                app.cfg.step0.commonAxisMode = 'preserve';
            end
            app.cfg.step0.targetLength = parseBlankScalar(get(ed0(3),'String'), false);
            app.cfg.step0.segmentationEnable = logical(round(str2double(get(ed0(4),'String'))));
            app.cfg.step0.segmentLength = parseBlankScalar(get(ed0(5),'String'), false);
            app.cfg.step0.segmentStride = parseBlankScalar(get(ed0(6),'String'), false);
            app.cfg.preproc.enabled = logical(round(str2double(get(ed0(7),'String'))));
            app.cfg.preproc.smoothEnable = logical(round(str2double(get(ed0(8),'String'))));
            app.cfg.preproc.baseEnable = logical(round(str2double(get(ed0(9),'String'))));
            app.cfg.preproc.normEnable = logical(round(str2double(get(ed0(10),'String'))));
            app.cfg.preproc.sgOrder = max(1, round(str2double(get(ed0(11),'String'))));
            app.cfg.preproc.sgFrame = max(3, round(str2double(get(ed0(12),'String'))));
            app.cfg.preproc.derivOrder = max(0, min(2, round(str2double(popupText(ed0(13))))));
            app.cfg.preproc.aslsLambda = max(1e-12, str2double(get(ed0(14),'String')));
            app.cfg.preproc.aslsP = max(1e-12, min(0.5, str2double(get(ed0(15),'String'))));
            app.cfg.preproc.aslsNIter = max(1, round(str2double(get(ed0(16),'String'))));
            app.cfg.preproc.normMode = upper(strtrim(popupText(ed0(17))));
            app.cfg.preproc.l2norm = strcmpi(app.cfg.preproc.normMode,'L2');
            app.cfg.preproc.cosmicDenoise = logical(round(str2double(get(ed0(18),'String'))));
            app.cfg.preproc.xMin = parseBlankScalar(get(ed0(19),'String'), false);
            app.cfg.preproc.xMax = parseBlankScalar(get(ed0(20),'String'), false);
            app.cfg.preproc.rangeWindows = parseRangeWindowsText(get(ed0(21),'String'));

            app.cfg.cv.outerK = max(2, round(str2double(get(ed1(1),'String'))));
            app.cfg.cv.repeats = max(1, round(str2double(get(ed1(2),'String'))));
            app.cfg.cv.splitMode = lower(strtrim(popupText(ed1(3))));
            app.cfg.cv.seedBase = max(1, round(str2double(get(ed1(4),'String'))));
            tmp = parseNumList(get(ed1(5),'String'));
            if ~isempty(tmp), app.cfg.step1.kPCList = unique(max(2, round(tmp))); end
            app.cfg.step1.pcaMode = lower(strtrim(popupText(ed1(6))));
            app.cfg.step1.singleKPC = max(1, round(str2double(get(ed1(7),'String'))));
            app.cfg.step1.varianceTarget = max(0.5, min(0.9999, str2double(get(ed1(8),'String'))));
            app.cfg.step1.coarseToFine = logical(round(str2double(get(ed1(9),'String'))));
            app.cfg.step1.teacherMLand = max(2, round(str2double(get(ed1(10),'String'))));
            app.cfg.step1.teacherRTeach = max(1, round(str2double(get(ed1(11),'String'))));
            app.cfg.step1.teacherSigmaScale = max(1e-6, str2double(get(ed1(12),'String')));
            app.cfg.step1.teacherBoxC = max(1e-8, str2double(get(ed1(13),'String')));

            tmp = parseNumList(get(ed2(1),'String'));
            if ~isempty(tmp), app.cfg.step2.mLandList = unique(max(2, round(tmp))); end
            tmp = parseNumList(get(ed2(2),'String'));
            if ~isempty(tmp), app.cfg.step2.rTeachList = unique(max(1, round(tmp))); end
            tmp = parseNumList(get(ed2(3),'String'));
            if ~isempty(tmp), app.cfg.step2.sigmaScaleList = unique(max(1e-6, tmp)); end
            tmp = parseNumList(get(ed2(4),'String'));
            if ~isempty(tmp), app.cfg.step2.boxCList = unique(max(1e-8, tmp)); end
            app.cfg.step2.shortlistN = max(1, round(str2double(get(ed2(5),'String'))));
            app.cfg.step2.kmeansReplicates = max(1, round(str2double(get(ed2(6),'String'))));
            app.cfg.step2.topKGate = max(0, round(str2double(get(ed2(7),'String'))));

            app.cfg.step3.mode = lower(strtrim(popupText(ed3(1))));
            tmp = parseNumList(get(ed3(2),'String'));
            if ~isempty(tmp), app.cfg.step3.pHiddenList = unique(max(4, round(tmp))); end
            tmp = parseNumList(get(ed3(3),'String'));
            if ~isempty(tmp), app.cfg.step3.lamRidgeList = unique(max(1e-12, tmp)); end
            tmp = parseNumList(get(ed3(4),'String'));
            if ~isempty(tmp), app.cfg.step3.alphaList = unique(max(0, tmp)); end
            tmp = parseNumList(get(ed3(5),'String'));
            if ~isempty(tmp), app.cfg.step3.tempList = unique(max(1e-6, tmp)); end
            tmp = parseNumList(get(ed3(6),'String'));
            if ~isempty(tmp), app.cfg.step3.skipScaleList = unique(max(0, tmp)); end
            tmp = parseNumList(get(ed3(7),'String'));
            if ~isempty(tmp), app.cfg.step3.ensembleList = unique(max(1, round(tmp))); end
            app.cfg.step3.teacherShortlistN = max(1, round(str2double(get(ed3(8),'String'))));
            app.cfg.step3.shortlistN = max(1, round(str2double(get(ed3(9),'String'))));
            app.cfg.step3.minAccRatio = max(0, min(1, str2double(get(ed3(10),'String'))));
            app.cfg.step3.rankMode = lower(strtrim(popupText(ed3(11))));
            tmp = parseNumList(get(ed3(12),'String'));
            if ~isempty(tmp), app.cfg.step3.DlocList = unique(max(1, round(tmp))); end

            app.cfg.step4.winnerPolicy = lower(strtrim(popupText(ed4(1))));
            app.cfg.step4.finalSelectionPolicy = app.cfg.step4.winnerPolicy;
            app.cfg.step4.topFinalistsPerBucket = max(1, round(str2double(get(ed4(2),'String'))));
            app.cfg.step4.repeatsFast = max(1, round(str2double(get(ed4(3),'String'))));
            app.cfg.step4.repeatsBestAccuracy = max(1, round(str2double(get(ed4(4),'String'))));
            app.cfg.step4.repeatsBestScore = max(1, round(str2double(get(ed4(5),'String'))));
            app.cfg.step4.repeatsBestMemory = max(1, round(str2double(get(ed4(6),'String'))));
            app.cfg.step4.accThresholdFrac = max(0, min(1, str2double(get(ed4(7),'String'))));
            app.cfg.step4.numROC = max(50, round(str2double(get(ed4(8),'String'))));

            app.cfg.cv.nWorkers = min(getAvailableWorkerCount(), max(1, round(str2double(get(edR(1),'String')))));
            app.cfg.runtime.pausePollSec = max(0.05, str2double(get(edR(2),'String')));
            app.cfg.runtime.saveIntermediate = logical(round(str2double(get(edR(3),'String'))));
            app.cfg.runtime.savePNG = logical(round(str2double(get(edR(4),'String'))));
            app.cfg.runtime.saveExcel = logical(round(str2double(get(edR(5),'String'))));
            app.cfg.runtime.verbose = logical(round(str2double(get(edR(6),'String'))));
            app.cfg.runtime.verboseTiming = logical(round(str2double(get(edR(7),'String'))));
            app.cfg.runtime.saveRunManifest = logical(round(str2double(get(edR(8),'String'))));
            app.cfg.runtime.exportSplitSummary = logical(round(str2double(get(edR(9),'String'))));
            app.cfg.runtime.exportMasterReport = logical(round(str2double(get(edR(10),'String'))));
            app.cfg.runtime.exportDataDisposition = logical(round(str2double(get(edR(11),'String'))));
            if isfield(app.ui,'popWorkers') && ishandle(app.ui.popWorkers)
                set(app.ui.popWorkers,'Value',min(max(1,app.cfg.cv.nWorkers), numel(get(app.ui.popWorkers,'String'))));
            end

            bmEnabled = strcmp(strtrim(popupText(edB(1))), '1');
            app.cfg.runtime.runBenchmarks = bmEnabled;
            app.cfg.benchmark.enabled = bmEnabled;
            methodVals = get(lbBenchmarkMethods,'Value');
            if isempty(methodVals)
                bmMethods = benchmarkChoices;
            else
                methodVals = methodVals(:)';
                methodVals = methodVals(methodVals >= 1 & methodVals <= numel(benchmarkChoices));
                bmMethods = benchmarkChoices(unique(methodVals,'stable'));
            end
            if ~isempty(bmMethods), app.cfg.benchmark.methods = bmMethods; end
            app.cfg.benchmark.kPC = parseBlankScalar(get(edB(2),'String'), true);
            app.cfg.benchmark.outerK = parseBlankScalar(get(edB(3),'String'), true);
            app.cfg.benchmark.repeats = parseBlankScalar(get(edB(4),'String'), true);
            app.cfg.benchmark.boxC = max(1e-8, str2double(get(edB(5),'String')));
            app.cfg.benchmark.numTrees = max(10, round(str2double(get(edB(6),'String'))));
            app.cfg.benchmark.maxSplits = max(2, round(str2double(get(edB(7),'String'))));

            if ~isempty(app.cfg.step0.targetLength) && app.cfg.step0.targetLength <= 0, app.cfg.step0.targetLength = []; end
            if ~isempty(app.cfg.step0.segmentLength) && app.cfg.step0.segmentLength <= 0, app.cfg.step0.segmentLength = []; end
            if ~isempty(app.cfg.step0.segmentStride) && app.cfg.step0.segmentStride <= 0, app.cfg.step0.segmentStride = []; end
            if ~isempty(app.cfg.preproc.xMin) && ~isempty(app.cfg.preproc.xMax) && app.cfg.preproc.xMax <= app.cfg.preproc.xMin
                tmpVal = app.cfg.preproc.xMin; app.cfg.preproc.xMin = app.cfg.preproc.xMax; app.cfg.preproc.xMax = tmpVal;
            end
            app.cfg.preproc.rangeWindows = normalizeRangeWindows(app.cfg.preproc.rangeWindows);
            if isfield(app.cfg,'cv')
                app.cfg.cv.groupValidation.requiredGroups = app.cfg.cv.outerK;
            end
            refreshPlan();
            logmsg('Advanced settings updated via step pages.');
            if ishghandle(dlg)
                uiresume(dlg);
                delete(dlg);
            end
        end

        function out = parseBlankScalar(txt, roundIt)
            txt = strtrim(txt);
            if isempty(txt)
                out = [];
                return;
            end
            out = str2double(txt);
            if ~isfinite(out)
                out = [];
                return;
            end
            if nargin >= 2 && roundIt
                out = round(out);
            end
        end
    end
    function onShowStepMap(~,~)
        msg = sprintf([ ...
            'RAVEN step map\n\n' ...
            'Step 0: Load data -> SG -> AsLS -> L2\n' ...
            'Step 1: Search kPC with fixed baseline localization\n' ...
            'Step 2: Search R, D0, tauScale using best kPC\n' ...
            'Step 3: Search mLand, rho, ridge, sigmaScale, C\n' ...
            'Step 4: Re-run best config with stronger repeats + export\n\n' ...
            'Selection: Accuracy > Stability > Speed > Simplicity']);
        helpdlg(msg,'RAVEN Step Map');
    end

    function onPreprocPreview(~,~)
        syncCfgFromUI();
        srcNow = strtrim(get(app.ui.edData,'String'));
        try
            if ~isempty(app.state.detectedData) && strcmp(strtrim(app.state.detectedSource), srcNow)
                data = app.state.detectedData;
            else
                data = loadDynamicDataset(srcNow, app.cfg.io.autoDetectGroups);
                app.state.detectedData = data;
                app.state.detectedSource = srcNow;
                updateUploadedFilesList();
            end
        catch ME
            errordlg(sprintf('Could not load dataset for preprocessing preview.\n\n%s', ME.message), 'RAVEN Preprocessing');
            return;
        end

        if isfield(app.ui,'preprocFig') && ~isempty(app.ui.preprocFig) && isvalid(app.ui.preprocFig)
            figure(app.ui.preprocFig);
        else
            createPreprocPreviewUI();
        end

        set(app.ui.pp.edSgOrder,'String',num2str(app.cfg.preproc.sgOrder));
        set(app.ui.pp.edSgFrame,'String',num2str(app.cfg.preproc.sgFrame));
        if isfield(app.ui.pp,'popDeriv') && ishandle(app.ui.pp.popDeriv)
            set(app.ui.pp.popDeriv,'Value',max(1,min(3,ravenGetField(app.cfg.preproc,'derivOrder',0)+1)));
        end
        if isfield(app.ui.pp,'chkSmooth') && ishandle(app.ui.pp.chkSmooth)
            set(app.ui.pp.chkSmooth,'Value',double(ravenGetField(app.cfg.preproc,'smoothEnable',1)));
        end
        if isfield(app.ui.pp,'chkBaseline') && ishandle(app.ui.pp.chkBaseline)
            set(app.ui.pp.chkBaseline,'Value',double(ravenGetField(app.cfg.preproc,'baseEnable',1)));
        end
        if isfield(app.ui.pp,'chkNormEnable') && ishandle(app.ui.pp.chkNormEnable)
            set(app.ui.pp.chkNormEnable,'Value',double(ravenGetField(app.cfg.preproc,'normEnable',1)));
        end
        set(app.ui.pp.edLambda,'String',num2str(app.cfg.preproc.aslsLambda));
        set(app.ui.pp.edP,'String',num2str(app.cfg.preproc.aslsP));
        set(app.ui.pp.edIter,'String',num2str(app.cfg.preproc.aslsNIter));
        set(app.ui.pp.popNorm,'Value',normModeToIndex(app.cfg.preproc.normMode));
        set(app.ui.pp.chkCosmic,'Value',double(app.cfg.preproc.cosmicDenoise));
        if isfield(app.ui.pp,'edRanges') && ishandle(app.ui.pp.edRanges)
            set(app.ui.pp.edRanges,'String',rangeWindowsToText(ravenGetField(app.cfg.preproc,'rangeWindows',[])));
        end
        if isfield(app.ui.pp,'chkBypass') && ishandle(app.ui.pp.chkBypass)
            set(app.ui.pp.chkBypass,'Value',double(~app.cfg.preproc.enabled));
        end
        try
            w0 = [];
            if isfield(data,'blocks') && ~isempty(data.blocks) && isnumeric(data.blocks{1}) && size(data.blocks{1},2) >= 1
                w0 = data.blocks{1}(:,1);
            end
            if isfield(app.cfg.preproc,'xMin') && ~isempty(app.cfg.preproc.xMin)
                set(app.ui.pp.edXMin,'String',num2str(app.cfg.preproc.xMin));
            elseif ~isempty(w0)
                set(app.ui.pp.edXMin,'String',num2str(min(w0)));
            else
                set(app.ui.pp.edXMin,'String','');
            end
            if isfield(app.cfg.preproc,'xMax') && ~isempty(app.cfg.preproc.xMax)
                set(app.ui.pp.edXMax,'String',num2str(app.cfg.preproc.xMax));
            elseif ~isempty(w0)
                set(app.ui.pp.edXMax,'String',num2str(max(w0)));
            else
                set(app.ui.pp.edXMax,'String','');
            end
        catch
            set(app.ui.pp.edXMin,'String','');
            set(app.ui.pp.edXMax,'String','');
        end
        app.state.preprocPreviewData = data;
        if isfield(app.ui,'pp') && isfield(app.ui.pp,'lstClasses') && ishandle(app.ui.pp.lstClasses)
            tmpLines = cell(numel(data.groupNames),1);
            for kk = 1:numel(data.groupNames)
                tmpLines{kk} = sprintf('%02d  %s (n=%d)', kk, data.groupNames{kk}, size(data.blocks{kk},2)-1);
            end
            if isempty(tmpLines)
                tmpLines = {'No classes loaded'};
            end
            set(app.ui.pp.lstClasses,'String',tmpLines,'Value',1);
        end
        updatePreprocPreview(false);
    end

    function createPreprocPreviewUI()
        scr = get(0,'ScreenSize');
        figW = min(1380, max(1160, round(0.84*scr(3))));
        figH = min(860,  max(720,  round(0.84*scr(4))));
        figX = scr(1) + round((scr(3)-figW)/2);
        figY = scr(2) + round((scr(4)-figH)/2);
        app.ui.preprocFig = figure('Name','RAVEN | Preprocessing Preview', ...
            'NumberTitle','off','MenuBar','none','ToolBar','none', ...
            'Color',[0 0 0],'Units','pixels','Position',[figX figY figW figH], ...
            'Resize','on','CloseRequestFcn',@onClosePreprocFig, ...
            'WindowScrollWheelFcn',@onPreprocMouseWheel);

        app.ui.pp = struct();
        app.ui.pp.pnlPlot = uipanel(app.ui.preprocFig,'Units','normalized','Position',[0.02 0.05 0.70 0.92], ...
            'Title','Average spectra with std shadow','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pp.pnlSet = uipanel(app.ui.preprocFig,'Units','normalized','Position',[0.74 0.05 0.24 0.92], ...
            'Title','Preprocessing settings','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');

        app.ui.pp.ax = axes('Parent',app.ui.pp.pnlPlot,'Units','normalized','Position',[0.08 0.12 0.86 0.78], ...
            'Color',[0 0 0],'XColor',[0.92 0.92 0.92],'YColor',[0.92 0.92 0.92], ...
            'GridColor',[0.25 0.25 0.25],'MinorGridColor',[0.18 0.18 0.18]);
        xlabel(app.ui.pp.ax,'Spectral Variable');
        ylabel(app.ui.pp.ax,'Intensity');
        grid(app.ui.pp.ax,'on');
        hold(app.ui.pp.ax,'on');

        app.ui.pp.scrollContentH = 2.35;
        app.ui.pp.pnlSetViewport = uipanel(app.ui.pp.pnlSet,'Units','normalized','Position',[0.04 0.085 0.90 0.875], ...
            'BackgroundColor',[0 0 0],'BorderType','none');
        app.ui.pp.pnlSetContent = uipanel(app.ui.pp.pnlSetViewport,'Units','normalized','Position',[0 -0.70 1.00 app.ui.pp.scrollContentH], ...
            'BackgroundColor',[0 0 0],'BorderType','none');
        app.ui.pp.sldSettings = uicontrol(app.ui.pp.pnlSet,'Style','slider','Units','normalized', ...
            'Position',[0.955 0.085 0.025 0.875],'Min',0,'Max',1,'Value',1, ...
            'SliderStep',[0.04 0.20],'BackgroundColor',[0.12 0.12 0.12], ...
            'Callback',@onPPScroll);

        app.ui.pp.pnlMode = uipanel(app.ui.pp.pnlSetContent,'Units','normalized','Position',[0.05 0.915 0.90 0.070], ...
            'Title','Processing mode','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pp.pnlSmooth = uipanel(app.ui.pp.pnlSetContent,'Units','normalized','Position',[0.05 0.645 0.90 0.235], ...
            'Title','Smoothing and derivative','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pp.pnlBase = uipanel(app.ui.pp.pnlSetContent,'Units','normalized','Position',[0.05 0.390 0.90 0.215], ...
            'Title','Baseline correction','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pp.pnlNorm = uipanel(app.ui.pp.pnlSetContent,'Units','normalized','Position',[0.05 0.225 0.90 0.125], ...
            'Title','Normalization','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pp.pnlArt = uipanel(app.ui.pp.pnlSetContent,'Units','normalized','Position',[0.05 0.155 0.90 0.060], ...
            'Title','Artifact handling','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pp.pnlCrop = uipanel(app.ui.pp.pnlSetContent,'Units','normalized','Position',[0.05 0.010 0.90 0.135], ...
            'Title','X-axis limits and windows','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');

        app.ui.pp.chkBypass = uicontrol(app.ui.pp.pnlMode,'Style','checkbox','Units','normalized', ...
            'Position',[0.06 0.22 0.90 0.45],'String','Skip all preprocessing and use raw cropped spectra', 'Value',0, ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);

        app.ui.pp.chkSmooth = uicontrol(app.ui.pp.pnlSmooth,'Style','checkbox','Units','normalized', ...
            'Position',[0.08 0.84 0.84 0.10],'String','Enable smoothing / derivative', 'Value',1, ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        addPPLabel(app.ui.pp.pnlSmooth,'SG order',[0.08 0.68 0.36 0.09]);
        app.ui.pp.edSgOrder = uicontrol(app.ui.pp.pnlSmooth,'Style','edit','Units','normalized', ...
            'Position',[0.08 0.56 0.36 0.10],'BackgroundColor',[0.05 0.05 0.05], ...
            'ForegroundColor',[0.95 0.95 0.95],'HorizontalAlignment','left');
        addPPLabel(app.ui.pp.pnlSmooth,'SG frame',[0.56 0.68 0.28 0.09]);
        app.ui.pp.edSgFrame = uicontrol(app.ui.pp.pnlSmooth,'Style','edit','Units','normalized', ...
            'Position',[0.56 0.56 0.28 0.10],'BackgroundColor',[0.05 0.05 0.05], ...
            'ForegroundColor',[0.95 0.95 0.95],'HorizontalAlignment','left');
        addPPLabel(app.ui.pp.pnlSmooth,'Derivative order',[0.08 0.37 0.84 0.09]);
        app.ui.pp.popDeriv = uicontrol(app.ui.pp.pnlSmooth,'Style','popupmenu','Units','normalized', ...
            'Position',[0.08 0.20 0.84 0.12],'String',{'0','1','2'}, ...
            'BackgroundColor',[0.07 0.07 0.07],'ForegroundColor',[0.95 0.95 0.95]);

        app.ui.pp.chkBaseline = uicontrol(app.ui.pp.pnlBase,'Style','checkbox','Units','normalized', ...
            'Position',[0.08 0.84 0.84 0.10],'String','Enable baseline correction', 'Value',1, ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        addPPLabel(app.ui.pp.pnlBase,'AsLS lambda',[0.08 0.69 0.84 0.085]);
        app.ui.pp.edLambda = uicontrol(app.ui.pp.pnlBase,'Style','edit','Units','normalized', ...
            'Position',[0.08 0.58 0.84 0.085],'BackgroundColor',[0.05 0.05 0.05], ...
            'ForegroundColor',[0.95 0.95 0.95],'HorizontalAlignment','left');
        addPPLabel(app.ui.pp.pnlBase,'AsLS p',[0.08 0.43 0.84 0.085]);
        app.ui.pp.edP = uicontrol(app.ui.pp.pnlBase,'Style','edit','Units','normalized', ...
            'Position',[0.08 0.32 0.84 0.085],'BackgroundColor',[0.05 0.05 0.05], ...
            'ForegroundColor',[0.95 0.95 0.95],'HorizontalAlignment','left');
        addPPLabel(app.ui.pp.pnlBase,'AsLS iterations',[0.08 0.17 0.84 0.085]);
        app.ui.pp.edIter = uicontrol(app.ui.pp.pnlBase,'Style','edit','Units','normalized', ...
            'Position',[0.08 0.06 0.84 0.085],'BackgroundColor',[0.05 0.05 0.05], ...
            'ForegroundColor',[0.95 0.95 0.95],'HorizontalAlignment','left');

        app.ui.pp.chkNormEnable = uicontrol(app.ui.pp.pnlNorm,'Style','checkbox','Units','normalized', ...
            'Position',[0.08 0.68 0.84 0.16],'String','Enable normalization', 'Value',1, ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        addPPLabel(app.ui.pp.pnlNorm,'Normalization mode',[0.08 0.42 0.84 0.14]);
        app.ui.pp.popNorm = uicontrol(app.ui.pp.pnlNorm,'Style','popupmenu','Units','normalized', ...
            'Position',[0.08 0.12 0.84 0.22],'String',{'L2','NONE','MAX','SNV'}, ...
            'BackgroundColor',[0.07 0.07 0.07],'ForegroundColor',[0.95 0.95 0.95]);

        app.ui.pp.chkCosmic = uicontrol(app.ui.pp.pnlArt,'Style','checkbox','Units','normalized', ...
            'Position',[0.08 0.18 0.84 0.42],'String','Cosmic despiking', 'Value',0, ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);

        addPPLabel(app.ui.pp.pnlCrop,'Min',[0.08 0.78 0.40 0.09]);
        app.ui.pp.edXMin = uicontrol(app.ui.pp.pnlCrop,'Style','edit','Units','normalized', ...
            'Position',[0.08 0.62 0.40 0.12],'BackgroundColor',[0.05 0.05 0.05], ...
            'ForegroundColor',[0.95 0.95 0.95],'HorizontalAlignment','left');
        addPPLabel(app.ui.pp.pnlCrop,'Max',[0.54 0.78 0.38 0.09]);
        app.ui.pp.edXMax = uicontrol(app.ui.pp.pnlCrop,'Style','edit','Units','normalized', ...
            'Position',[0.54 0.62 0.38 0.12],'BackgroundColor',[0.05 0.05 0.05], ...
            'ForegroundColor',[0.95 0.95 0.95],'HorizontalAlignment','left');
        addPPLabel(app.ui.pp.pnlCrop,'Ranges',[0.08 0.40 0.40 0.09]);
        app.ui.pp.edRanges = uicontrol(app.ui.pp.pnlCrop,'Style','edit','Units','normalized', ...
            'Position',[0.08 0.17 0.84 0.13],'BackgroundColor',[0.05 0.05 0.05], ...
            'ForegroundColor',[0.95 0.95 0.95],'HorizontalAlignment','left', ...
            'TooltipString','Example: [600 800; 1000 1200]');

        app.ui.pp.btnUpdate = uicontrol(app.ui.pp.pnlSet,'Style','pushbutton','Units','normalized', ...
            'Position',[0.04 0.012 0.42 0.050],'String','Update Preview', ...
            'FontWeight','bold','BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92], ...
            'Callback',@(src,evt)updatePreprocPreview(false));
        app.ui.pp.btnSave = uicontrol(app.ui.pp.pnlSet,'Style','pushbutton','Units','normalized', ...
            'Position',[0.54 0.012 0.42 0.050],'String','Save Settings', ...
            'FontWeight','bold','BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92], ...
            'Callback',@(src,evt)updatePreprocPreview(true));

        updatePPScroll();

        app.ui.pp.pnlLegend = uipanel(app.ui.pp.pnlPlot,'Units','normalized','Position',[0.10 0.64 0.42 0.30], ...
            'Title','Legend','BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pp.legendContentH = 1.0;
        app.ui.pp.pnlLegendViewport = uipanel(app.ui.pp.pnlLegend,'Units','normalized','Position',[0.035 0.055 0.875 0.865], ...
            'BackgroundColor',[0 0 0],'BorderType','none');
        app.ui.pp.pnlLegendContent = uipanel(app.ui.pp.pnlLegendViewport,'Units','normalized','Position',[0 0 1 1], ...
            'BackgroundColor',[0 0 0],'BorderType','none');
        app.ui.pp.sldLegend = uicontrol(app.ui.pp.pnlLegend,'Style','slider','Units','normalized', ...
            'Position',[0.925 0.055 0.045 0.865],'Min',0,'Max',1,'Value',1, ...
            'SliderStep',[0.06 0.25],'BackgroundColor',[0.12 0.12 0.12], ...
            'Callback',@onPreviewLegendScroll,'Visible','off');

        function addPPLabel(parentObj, txt, pos)
            uicontrol(parentObj,'Style','text','Units','normalized', ...
                'Position',pos,'String',txt, ...
                'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
                'HorizontalAlignment','left','FontWeight','bold');
        end

        function onPPScroll(~,~)
            updatePPScroll();
        end

        function onPreprocMouseWheel(~,evt)
            try
                count = evt.VerticalScrollCount;
            catch
                count = 0;
            end
            if isMouseOverPreviewLegend() && isfield(app.ui.pp,'sldLegend') && ishandle(app.ui.pp.sldLegend) ...
                    && strcmpi(get(app.ui.pp.sldLegend,'Visible'),'on')
                val = get(app.ui.pp.sldLegend,'Value');
                step = 0.080;
                val = max(0,min(1,val - step*count));
                set(app.ui.pp.sldLegend,'Value',val);
                updatePreviewLegendScroll();
                return;
            end
            if isfield(app.ui,'pp') && isfield(app.ui.pp,'sldSettings') && ishandle(app.ui.pp.sldSettings)
                val = get(app.ui.pp.sldSettings,'Value');
                step = 0.055;
                val = max(0,min(1,val - step*count));
                set(app.ui.pp.sldSettings,'Value',val);
                updatePPScroll();
            end
        end

        function tf = isMouseOverPreviewLegend()
            tf = false;
            try
                if ~isfield(app.ui,'preprocFig') || ~ishandle(app.ui.preprocFig) || ...
                        ~isfield(app.ui,'pp') || ~isfield(app.ui.pp,'pnlLegend') || ~ishandle(app.ui.pp.pnlLegend)
                    return;
                end
                cp = get(app.ui.preprocFig,'CurrentPoint');
                lp = getpixelposition(app.ui.pp.pnlLegend,true);
                tf = cp(1) >= lp(1) && cp(1) <= lp(1)+lp(3) && cp(2) >= lp(2) && cp(2) <= lp(2)+lp(4);
            catch
                tf = false;
            end
        end

        function onPreviewLegendScroll(~,~)
            updatePreviewLegendScroll();
        end

        function updatePreviewLegendScroll()
            if ~isfield(app.ui,'pp') || ~isfield(app.ui.pp,'pnlLegendContent') || ~ishandle(app.ui.pp.pnlLegendContent)
                return;
            end
            contentH = 1.0;
            if isfield(app.ui.pp,'legendContentH') && ~isempty(app.ui.pp.legendContentH)
                contentH = max(1.0, app.ui.pp.legendContentH);
            end
            val = 1;
            if isfield(app.ui.pp,'sldLegend') && ishandle(app.ui.pp.sldLegend)
                val = get(app.ui.pp.sldLegend,'Value');
            end
            y = -(contentH - 1.0) * val;
            set(app.ui.pp.pnlLegendContent,'Position',[0 y 1.00 contentH]);
        end

        function updatePPScroll()
            if ~isfield(app.ui,'pp') || ~isfield(app.ui.pp,'pnlSetContent') || ~ishandle(app.ui.pp.pnlSetContent)
                return;
            end
            contentH = app.ui.pp.scrollContentH;
            val = 1;
            if isfield(app.ui.pp,'sldSettings') && ishandle(app.ui.pp.sldSettings)
                val = get(app.ui.pp.sldSettings,'Value');
            end
            y = -(contentH - 1.0) * val;
            set(app.ui.pp.pnlSetContent,'Position',[0 y 1.00 contentH]);
        end
    end

    function onClosePreprocFig(~,~)
        try
            delete(app.ui.preprocFig);
        catch
        end
        if isfield(app.ui,'preprocFig')
            app.ui = rmfield(app.ui, intersect(fieldnames(app.ui), {'preprocFig'}));
        end
        if isfield(app.ui,'pp')
            app.ui = rmfield(app.ui, 'pp');
        end
    end

    function updatePreprocPreview(saveToMain)
        if nargin < 1, saveToMain = false; end
        if ~isfield(app.state,'preprocPreviewData') || isempty(app.state.preprocPreviewData)
            errordlg('No dataset is loaded for preprocessing preview.','RAVEN Preprocessing');
            return;
        end
        try
            selNamesForLegend = {};
            if isfield(app.ui,'pp') && isfield(app.ui.pp,'legendCheck') && isfield(app.ui.pp,'legendNames') && ~isempty(app.ui.pp.legendNames)
                try
                    selNamesForLegend = getCurrentPreviewSelectedNames(app.ui.pp.legendNames);
                catch
                    selNamesForLegend = {};
                end
            elseif isfield(app.cfg,'preproc') && isfield(app.cfg.preproc,'includeNames') && ~isempty(app.cfg.preproc.includeNames)
                selNamesForLegend = app.cfg.preproc.includeNames;
            end
            pre = readPreprocSettingsFromPreview();
            [Wprev, muCell, sdCell, namesCell, nSpec] = preprocessPreviewStats(app.state.preprocPreviewData, pre);
            if isfield(app.ui.pp,'hPreviewPatch')
                try, delete(app.ui.pp.hPreviewPatch(isgraphics(app.ui.pp.hPreviewPatch))); end
            end
            if isfield(app.ui.pp,'hPreviewLine')
                try, delete(app.ui.pp.hPreviewLine(isgraphics(app.ui.pp.hPreviewLine))); end
            end
            cla(app.ui.pp.ax,'reset');
            set(app.ui.pp.ax,'Color',[0 0 0],'XColor',[0.92 0.92 0.92],'YColor',[0.92 0.92 0.92], ...
                'GridColor',[0.25 0.25 0.25],'MinorGridColor',[0.18 0.18 0.18]);
            hold(app.ui.pp.ax,'on');
            cc = lines(max(7,numel(namesCell)));
            hLine = gobjects(numel(namesCell),1);
            hPatch = gobjects(numel(namesCell),1);
            for ii = 1:numel(namesCell)
                mu = muCell{ii};
                sd = sdCell{ii};
                xx = Wprev(:);
                lower = (mu-sd)';
                upper = (mu+sd)';
                hPatch(ii) = patch('Parent',app.ui.pp.ax, 'XData',[xx; flipud(xx)]', 'YData',[lower fliplr(upper)], ...
                    'FaceColor',cc(ii,:), 'FaceAlpha',0.18, 'EdgeColor','none', 'HandleVisibility','off');
                hLine(ii) = plot(app.ui.pp.ax, Wprev, mu, 'LineWidth',1.8, 'Color',cc(ii,:));
            end
            hold(app.ui.pp.ax,'off');
            grid(app.ui.pp.ax,'on');
            xlabel(app.ui.pp.ax,'Spectral Variable');
            if isfield(pre,'enabled') && ~pre.enabled
                ylabel(app.ui.pp.ax,'Raw intensity');
                hPTitle = title(app.ui.pp.ax, sprintf('Average raw spectra of %d classes', numel(namesCell)), 'Color',[0.92 0.92 0.92]);
            else
                ylabel(app.ui.pp.ax,'Preprocessed intensity');
                hPTitle = title(app.ui.pp.ax, sprintf('Average spectra of %d classes', numel(namesCell)), 'Color',[0.92 0.92 0.92]);
            end

            try
                set(hPTitle,'Units','normalized','Position',[0.985 1.015 0], ...
                    'HorizontalAlignment','right','VerticalAlignment','bottom','Clipping','off');
            catch
            end
            set(app.ui.pp.pnlPlot,'Title',sprintf('Average spectra of %d classes', numel(namesCell)));
            if ~isempty(Wprev)
                xlim(app.ui.pp.ax,[min(Wprev) max(Wprev)]);
            end
            rebuildPreviewLegendInline(namesCell, nSpec, cc, hLine, hPatch);
            applySavedPreviewSelection(namesCell, selNamesForLegend);
            if saveToMain
                pre.includeNames = getCurrentPreviewSelectedNames(namesCell);
                app.cfg.preproc = pre;
                refreshPlan();
                xlsxPath = exportPreprocPreviewExcel(Wprev, muCell, sdCell, namesCell, nSpec, pre);
                if ~isempty(xlsxPath)
                    logmsg(['Preprocessing settings saved from preview window. Average spectra workbook: ' xlsxPath]);
                else
                    logmsg('Preprocessing settings saved from preview window.');
                end
                if isfield(app.ui,'preprocFig') && ~isempty(app.ui.preprocFig) && isvalid(app.ui.preprocFig)
                    delete(app.ui.preprocFig);
                end
                app.ui.preprocFig = [];
                if isfield(app.ui,'pp')
                    app.ui = rmfield(app.ui,'pp');
                end
                return;
            end
        catch ME
            errordlg(sprintf('Preview update failed.\n\n%s', ME.message),'RAVEN Preprocessing');
        end
    end

    function rebuildPreviewLegendInline(namesCell, nSpec, cc, hLine, hPatch)
        if isfield(app.ui.pp,'legendItems')
            try
                oldh = app.ui.pp.legendItems(:);
                oldh = oldh(ishandle(oldh));
                delete(oldh);
            catch
            end
        end
        app.ui.pp.legendItems = gobjects(0,1);
        nC = numel(namesCell);
        if nC <= 0, return; end
        if isfield(app.ui.pp,'pnlLegend') && isgraphics(app.ui.pp.pnlLegend)
            maxLbl = max(cellfun(@numel, namesCell));
            hgt = min(0.46, max(0.22, 0.16 + 0.030*min(nC,10)));
            wid = min(0.50, max(0.40, 0.20 + 0.008*maxLbl));
            xpos = 0.10;
            ypos = max(0.48, 0.94 - hgt);
            set(app.ui.pp.pnlLegend,'Position',[xpos ypos wid hgt]);
        end
        if isfield(app.ui.pp,'pnlLegendViewport') && isgraphics(app.ui.pp.pnlLegendViewport)
            set(app.ui.pp.pnlLegendViewport,'Position',[0.035 0.055 0.875 0.865]);
        end
        if isfield(app.ui.pp,'sldLegend') && ishandle(app.ui.pp.sldLegend)
            set(app.ui.pp.sldLegend,'Position',[0.925 0.055 0.045 0.865]);
        end

        app.ui.pp.legendItems = gobjects(3*nC,1);
        app.ui.pp.legendCheck = gobjects(nC,1);
        app.ui.pp.legendNames = namesCell;
        app.ui.pp.hPreviewLine = hLine;
        app.ui.pp.hPreviewPatch = hPatch;

        visibleRows = 10;
        contentH = max(1.0, nC / visibleRows);
        app.ui.pp.legendContentH = contentH;
        if isfield(app.ui.pp,'pnlLegendContent') && isgraphics(app.ui.pp.pnlLegendContent)
            set(app.ui.pp.pnlLegendContent,'Position',[0 -(contentH-1.0) 1.00 contentH]);
        end
        if isfield(app.ui.pp,'sldLegend') && ishandle(app.ui.pp.sldLegend)
            if contentH > 1.0001
                set(app.ui.pp.sldLegend,'Visible','on','Value',1, ...
                    'SliderStep',[min(0.25,1/max(nC-visibleRows,1)) min(0.60,visibleRows/max(nC-visibleRows,1))]);
            else
                set(app.ui.pp.sldLegend,'Visible','off','Value',1);
            end
        end

        parentForItems = app.ui.pp.pnlLegend;
        if isfield(app.ui.pp,'pnlLegendContent') && isgraphics(app.ui.pp.pnlLegendContent)
            parentForItems = app.ui.pp.pnlLegendContent;
        end
        topPad = 0.975;
        botPad = 0.025;
        rowH = (topPad - botPad) / max(nC,1);
        for ii = 1:nC
            rowY = topPad - ii*rowH;
            base = 3*(ii-1);
            app.ui.pp.legendItems(base+1) = uipanel(parentForItems,'Units','normalized', ...
                'Position',[0.035 rowY+0.41*rowH 0.105 0.18*rowH],'BackgroundColor',cc(ii,:), 'BorderType','none');
            app.ui.pp.legendItems(base+2) = uicontrol(parentForItems,'Style','checkbox','Units','normalized', ...
                'Position',[0.160 rowY+0.18*rowH 0.080 0.66*rowH], 'Value',1, 'String','', ...
                'BackgroundColor',[0 0 0], 'ForegroundColor',[0.92 0.92 0.92], ...
                'Callback',@(src,evt)togglePreviewVisibility(ii));
            app.ui.pp.legendCheck(ii) = app.ui.pp.legendItems(base+2);
            app.ui.pp.legendItems(base+3) = uicontrol(parentForItems,'Style','text','Units','normalized', ...
                'Position',[0.245 rowY+0.08*rowH 0.735 0.82*rowH], ...
                'String',sprintf('%s (n=%d)', namesCell{ii}, nSpec(ii)), ...
                'BackgroundColor',[0 0 0], 'ForegroundColor',cc(ii,:), 'HorizontalAlignment','left', ...
                'FontWeight','bold', 'FontSize',10);
        end
    end

    function togglePreviewVisibility(ii)
        if ~isfield(app.ui,'pp') || ~isfield(app.ui.pp,'legendCheck')
            return;
        end
        if ii > numel(app.ui.pp.legendCheck) || ~ishandle(app.ui.pp.legendCheck(ii))
            return;
        end
        isOn = logical(get(app.ui.pp.legendCheck(ii),'Value'));
        if isfield(app.ui.pp,'hPreviewLine') && ii <= numel(app.ui.pp.hPreviewLine) && isgraphics(app.ui.pp.hPreviewLine(ii))
            if isOn, set(app.ui.pp.hPreviewLine(ii),'Visible','on'); else, set(app.ui.pp.hPreviewLine(ii),'Visible','off'); end
        end
        if isfield(app.ui.pp,'hPreviewPatch') && ii <= numel(app.ui.pp.hPreviewPatch) && isgraphics(app.ui.pp.hPreviewPatch(ii))
            if isOn, set(app.ui.pp.hPreviewPatch(ii),'Visible','on'); else, set(app.ui.pp.hPreviewPatch(ii),'Visible','off'); end
        end
    end

    function applySavedPreviewSelection(namesCell, selNames)
        if nargin < 2, selNames = {}; end
        if ~isfield(app.ui,'pp') || ~isfield(app.ui.pp,'legendCheck') || isempty(namesCell)
            return;
        end
        if isempty(selNames) && isfield(app.cfg,'preproc') && isfield(app.cfg.preproc,'includeNames') && ~isempty(app.cfg.preproc.includeNames)
            selNames = app.cfg.preproc.includeNames;
        end
        if isempty(selNames)
            for ii = 1:min(numel(namesCell), numel(app.ui.pp.legendCheck))
                if ishandle(app.ui.pp.legendCheck(ii))
                    set(app.ui.pp.legendCheck(ii),'Value',1);
                    togglePreviewVisibility(ii);
                end
            end
            return;
        end
        selNames = cellfun(@(s) lower(strtrim(char(s))), selNames, 'UniformOutput', false);
        for ii = 1:min(numel(namesCell), numel(app.ui.pp.legendCheck))
            if ishandle(app.ui.pp.legendCheck(ii))
                isOn = any(strcmpi(namesCell{ii}, selNames));
                set(app.ui.pp.legendCheck(ii),'Value',double(isOn));
                togglePreviewVisibility(ii);
            end
        end
    end

    function selNames = getCurrentPreviewSelectedNames(namesCell)
        selNames = {};
        if ~isfield(app.ui,'pp') || ~isfield(app.ui.pp,'legendCheck')
            selNames = namesCell(:)';
            return;
        end
        n = min(numel(namesCell), numel(app.ui.pp.legendCheck));
        for ii = 1:n
            if ishandle(app.ui.pp.legendCheck(ii)) && logical(get(app.ui.pp.legendCheck(ii),'Value'))
                selNames{end+1} = namesCell{ii};
            end
        end
        if isempty(selNames)
            error('At least one class must remain selected in the preprocessing legend.');
        end
    end

    function xlsxPath = exportPreprocPreviewExcel(Wprev, muCell, sdCell, namesCell, nSpec, pre)
        xlsxPath = '';
        try
            if isfield(pre,'includeNames') && ~isempty(pre.includeNames)
                keep = false(1,numel(namesCell));
                for kk = 1:numel(namesCell)
                    keep(kk) = any(strcmpi(namesCell{kk}, pre.includeNames));
                end
                namesCell = namesCell(keep);
                muCell = muCell(keep);
                sdCell = sdCell(keep);
                nSpec = nSpec(keep);
            end
            outdir = fullfile(app.cfg.io.saveBaseDir, app.cfg.io.rootName, 'STEP0_PREPROC');
            if ~exist(outdir,'dir'), mkdir(outdir); end
            xlsxPath = fullfile(outdir,'PREPROCESSING_AVERAGE_SPECTRA.xlsx');
            summaryNames = namesCell(:);
            Tsum = table(summaryNames, nSpec(:), 'VariableNames', {'Class','NSpectra'});
            writetable(Tsum, xlsxPath, 'Sheet', 'Summary', 'WriteMode', 'overwritesheet');
            preFlat = flattenStruct(pre);
            fn = fieldnames(preFlat);
            vals = struct2cell(preFlat);
            Tcfg = table(fn, vals, 'VariableNames', {'Setting','Value'});
            writetable(Tcfg, xlsxPath, 'Sheet', 'Settings', 'WriteMode', 'overwritesheet');
            for ii = 1:numel(namesCell)
                mu = muCell{ii}(:);
                sd = sdCell{ii}(:);
                T = table(Wprev(:), mu, sd, mu-sd, mu+sd, 'VariableNames', ...
                    {'SpectralVariable','Mean','Std','Lower','Upper'});
                sh = matlab.lang.makeValidName(namesCell{ii});
                sh = sh(1:min(31, numel(sh)));
                if isempty(sh), sh = sprintf('Class_%d', ii); end
                writetable(T, xlsxPath, 'Sheet', sh, 'WriteMode', 'overwritesheet');
            end
        catch MEexp
            xlsxPath = '';
            logmsg(['Preprocessing preview Excel export failed: ' MEexp.message]);
        end
    end

    function pre = readPreprocSettingsFromPreview()
        pre = struct();
        pre.sgOrder = max(1, round(str2double(get(app.ui.pp.edSgOrder,'String'))));
        pre.sgFrame = max(3, round(str2double(get(app.ui.pp.edSgFrame,'String'))));
        if mod(pre.sgFrame,2)==0, pre.sgFrame = pre.sgFrame + 1; end
        if isfield(app.ui.pp,'popDeriv') && ishandle(app.ui.pp.popDeriv)
            pre.derivOrder = max(0, min(2, get(app.ui.pp.popDeriv,'Value') - 1));
        else
            pre.derivOrder = ravenGetField(app.cfg.preproc,'derivOrder',0);
        end
        pre.smoothEnable = ~isfield(app.ui.pp,'chkSmooth') || logical(get(app.ui.pp.chkSmooth,'Value'));
        pre.baseEnable = ~isfield(app.ui.pp,'chkBaseline') || logical(get(app.ui.pp.chkBaseline,'Value'));
        pre.normEnable = ~isfield(app.ui.pp,'chkNormEnable') || logical(get(app.ui.pp.chkNormEnable,'Value'));
        pre.aslsLambda = max(1e-12, str2double(get(app.ui.pp.edLambda,'String')));
        pre.aslsP = max(1e-12, min(0.5, str2double(get(app.ui.pp.edP,'String'))));
        pre.aslsNIter = max(1, round(str2double(get(app.ui.pp.edIter,'String'))));
        items = get(app.ui.pp.popNorm,'String');
        idx = max(1,min(numel(items), get(app.ui.pp.popNorm,'Value')));
        item = upper(strtrim(char(items{idx})));
        pre.normMode = item;
        pre.l2norm = strcmpi(pre.normMode,'L2');
        pre.cosmicDenoise = logical(get(app.ui.pp.chkCosmic,'Value'));
        if isfield(app.ui.pp,'chkBypass') && ishandle(app.ui.pp.chkBypass)
            pre.enabled = ~logical(get(app.ui.pp.chkBypass,'Value'));
        else
            pre.enabled = true;
        end
        pre.includeNames = {};
        xMin = str2double(strtrim(get(app.ui.pp.edXMin,'String')));
        xMax = str2double(strtrim(get(app.ui.pp.edXMax,'String')));
        if ~isfinite(xMin), xMin = []; end
        if ~isfinite(xMax), xMax = []; end
        if ~isempty(xMin) && ~isempty(xMax) && xMin > xMax
            tmp = xMin; xMin = xMax; xMax = tmp;
        end
        pre.xMin = xMin;
        pre.xMax = xMax;
        if isfield(app.ui.pp,'edRanges') && ishandle(app.ui.pp.edRanges)
            pre.rangeWindows = parseRangeWindowsText(get(app.ui.pp.edRanges,'String'));
        else
            pre.rangeWindows = [];
        end
        pre.rangeWindows = normalizeRangeWindows(pre.rangeWindows);
    end

    function idx = normModeToIndex(mode)
        mode = upper(strtrim(char(mode)));
        switch mode
            case 'NONE'
                idx = 2;
            case 'MAX'
                idx = 3;
            case 'SNV'
                idx = 4;
            otherwise
                idx = 1;
        end
    end

    function [Wprev, muCell, sdCell, namesCell, nSpec] = preprocessPreviewStats(data, pre)
        namesCell = data.groupNames;
        blocks = data.blocks;
        Wprev = [];
        WrawRef = [];
        muCell = cell(numel(blocks),1);
        sdCell = cell(numel(blocks),1);
        nSpec = zeros(numel(blocks),1);
        if mod(pre.sgFrame,2)==0
            pre.sgFrame = pre.sgFrame + 1;
        end
        sgKernel = [];
        if ravenGetField(pre,'smoothEnable',1) || ravenGetField(pre,'derivOrder',0) > 0
            sgKernel = buildSGKernel(pre.sgFrame, pre.sgOrder, ravenGetField(pre,'derivOrder',0), 1);
        end
        DtD = [];
        for c = 1:numel(blocks)
            M = blocks{c};
            if istable(M), M = table2array(M); end
            if ~isnumeric(M) || size(M,2) < 2
                error('Group %s is not numeric [nW x (1+Nspec)].', namesCell{c});
            end
            wv = M(:,1);
            Xblk = double(M(:,2:end));
            if isempty(WrawRef)
                WrawRef = wv;
            else
                if ~axesMatch(wv, WrawRef)
                    error('Spectral-variable axis mismatch in group %s.', namesCell{c});
                end
            end
            [wvUse, XblkUse] = cropBlockByXLimits(wv, Xblk, pre);
            if isempty(DtD)
                Wprev = wvUse;
                nW = numel(Wprev);
                e = ones(nW,1);
                D2 = spdiags([e -2*e e], 0:2, nW-2, nW);
                DtD = D2'*D2;
            else
                if numel(wvUse) ~= numel(Wprev) || any(abs(wvUse(:)-Wprev(:))>1e-9)
                    error('Cropped spectral-variable axis mismatch in group %s.', namesCell{c});
                end
            end
            [~, nS] = size(XblkUse);
            Xpp = applyPreprocBlock(XblkUse, pre, DtD, sgKernel);
            muCell{c} = mean(Xpp,2);
            sdCell{c} = std(Xpp,0,2);
            nSpec(c) = nS;
        end
    end

    function Xpp = applyPreprocBlock(Xblk, pre, DtD, sgKernel)
        [nW,nSpec] = size(Xblk);
        Xwork = double(Xblk);
        if isfield(pre,'enabled') && ~pre.enabled
            Xpp = Xwork;
            return;
        end
        if isfield(pre,'cosmicDenoise') && pre.cosmicDenoise
            for s = 1:nSpec
                ys = Xwork(:,s);
                med5 = movmedian(ys,5,'Endpoints','shrink');
                resid = ys - med5;
                madv = median(abs(resid - median(resid)));
                if madv <= 0 || ~isfinite(madv)
                    madv = std(resid);
                end
                if madv > 0 && isfinite(madv)
                    spikeMask = abs(resid) > 6*madv;
                    if any(spikeMask)
                        ys(spikeMask) = med5(spikeMask);
                    end
                end
                Xwork(:,s) = ys;
            end
        end

        Xcur = Xwork;
        doSmooth = ravenGetField(pre,'smoothEnable',1);
        derivOrder = ravenGetField(pre,'derivOrder',0);
        if (doSmooth || derivOrder > 0) && ~isempty(sgKernel)
            Xtmp = zeros(nW,nSpec);
            for s = 1:nSpec
                Xtmp(:,s) = conv(Xcur(:,s), sgKernel, 'same');
            end
            Xcur = Xtmp;
        end

        if ravenGetField(pre,'baseEnable',1)
            Xbc = zeros(nW,nSpec);
            for s = 1:nSpec
                y = Xcur(:,s);
                w = ones(nW,1);
                z = zeros(nW,1);
                for it = 1:pre.aslsNIter
                    Ww = spdiags(w,0,nW,nW);
                    z = (Ww + pre.aslsLambda*DtD) \ (w.*y);
                    w = pre.aslsP*(y>z) + (1-pre.aslsP)*(y<=z);
                end
                Xbc(:,s) = y - z;
            end
        else
            Xbc = Xcur;
        end

        if ~ravenGetField(pre,'normEnable',1)
            Xpp = Xbc;
            return;
        end

        mode = upper(strtrim(char(ravenGetField(pre,'normMode','L2'))));
        switch mode
            case 'NONE'
                Xpp = Xbc;
            case 'SNV'
                mu = mean(Xbc,1);
                sd = std(Xbc,0,1);
                sd(sd==0) = 1;
                Xpp = (Xbc - mu) ./ sd;
            case 'MAX'
                mx = max(abs(Xbc),[],1);
                mx(mx==0) = 1;
                Xpp = Xbc ./ mx;
            otherwise
                nrm = sqrt(sum(Xbc.^2,1));
                nrm(nrm==0) = 1;
                Xpp = Xbc ./ nrm;
        end
    end
