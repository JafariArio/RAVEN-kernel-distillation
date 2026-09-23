function RAVEN_V1_01_core()

clc;
close all force;
rng(2468,'twister');

app = struct();
app.cfg   = makeDefaultConfig();
app.state = struct('isRunning',false,'isPaused',false,'stopRequested',false, ...
                   'currentStep',0,'data',[],'results',struct(),'runTic',[], ...
                   'selectedFiles',{{}},'detectedData',[],'detectedSource','', ...
                   'lastAutoTuneSignature','', ...
                   'summaryPairs',{{}},'livePairs',{{}});

createUI();
setSummary('Preset','Accurate');
setLiveStatus('Preset','Accurate');
refreshPlan();
refreshLiveStatusContext();
logmsg('RAVEN_V1_01 ready.');
showLogo();
updateUploadedFilesList();

    function cfg = makeDefaultConfig()
        cfg = struct();
        cfg.io = struct();
        cfg.io.dataSource = '';
        cfg.io.saveBaseDir = pwd;
        cfg.io.rootName = 'RAVEN_RUN';
        cfg.io.autoDetectGroups = true;
        cfg.io.groupNames = {};
        cfg.io.inputMode = 'spectra_blocks';

        cfg.step0 = struct();
        cfg.step0.inputMode = 'spectra_blocks';
        cfg.step0.commonAxisMode = 'preserve';
        cfg.step0.targetLength = [];
        cfg.step0.segmentationEnable = false;
        cfg.step0.segmentLength = [];
        cfg.step0.segmentStride = [];

        cfg.preproc = struct();
        cfg.preproc.sgOrder = 3;
        cfg.preproc.sgFrame = 13;
        cfg.preproc.derivOrder = 0;
        cfg.preproc.smoothEnable = true;
        cfg.preproc.baseEnable = true;
        cfg.preproc.normEnable = true;
        cfg.preproc.aslsLambda = 1e4;
        cfg.preproc.aslsP = 1e-3;
        cfg.preproc.aslsNIter = 10;
        cfg.preproc.normMode = 'L2';
        cfg.preproc.l2norm = true;
        cfg.preproc.cosmicDenoise = false;
        cfg.preproc.xMin = [];
        cfg.preproc.xMax = [];
        cfg.preproc.rangeWindows = [];
        cfg.preproc.includeNames = {};
        cfg.preproc.enabled = true;

        cfg.cv = struct();
        cfg.cv.outerK = 5;
        cfg.cv.repeats = 2;
        cfg.cv.seedBase = 2468;
        cfg.cv.useParallel = false;
        cfg.cv.splitMode = 'stratified';
        cfg.cv.groupVector = [];
        cfg.cv.groupVectorSource = '';
        cfg.cv.groupCount = 0;
        cfg.cv.groupValidation = struct('present',false,'validLength',false,'hasMissing',false, ...
            'numGroups',0,'requiredGroups',cfg.cv.outerK,'sufficientForKFold',false, ...
            'classWiseMinGroups',0,'classWiseSufficient',false,'expectedLength',0,'actualLength',0, ...
            'groupsUsed',0,'seedBase',cfg.cv.seedBase,'message','No group vector loaded.', ...
            'effectiveMode','stratified','fallbackUsed',false,'fallbackReason','');
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
        cfg.cv.nWorkers = max(1, round(nAvail));

        cfg.step1 = struct();
        cfg.step1.kPCList = [20 30 40 50 60];
        cfg.step1.metric = 'macroF1';
        cfg.step1.pcaMode = 'fixedlist';
        cfg.step1.singleKPCEnable = false;
        cfg.step1.singleKPC = 40;
        cfg.step1.varianceTarget = 0.98;
        cfg.step1.coarseToFine = true;
        cfg.step1.baselineR = 6;
        cfg.step1.baselineD0 = 15;
        cfg.step1.baselineTauScale = 1.0;
        cfg.step1.baselineMLand = 64;
        cfg.step1.baselineRho = 0.95;
        cfg.step1.baselineRidge = 1e-6;
        cfg.step1.baselineSigmaScale = 1.0;
        cfg.step1.baselineC = 1;

        cfg.step2 = struct();
        cfg.step2.RList = [4 6 8 10 12];
        cfg.step2.D0List = [8 12 16 20];
        cfg.step2.tauScaleList = [0.5 0.75 1.0 1.25 1.5];
        cfg.step2.kmeansReplicates = 5;
        cfg.step2.topKGate = 0;

        cfg.step3 = struct();
        cfg.step3.mLandList = [32 48 64 96 128];
        cfg.step3.rankMode = 'adaptive';
        cfg.step3.DlocList = [12 16 20 24 32];
        cfg.step3.rhoList = [0.90 0.95 0.98];
        cfg.step3.ridgeList = [1e-8 1e-6 1e-4];
        cfg.step3.sigmaMode = 'auto';
        cfg.step3.sigmaScaleList = [0.75 1.0 1.25];
        cfg.step3.CList = [0.1 1 10];
        cfg.step3.learner = 'linsvm';
        cfg.step3.mode = 'full_search';

        cfg.step4 = struct();
        cfg.step4.repeatsBestAccuracy = 3;
        cfg.step4.repeatsBestScore = 3;
        cfg.step4.repeatsBestMemory = 3;
        cfg.step4.makeROC = true;
        cfg.step4.numROC = 200;
        cfg.step4.useBestAccuracy = true;
        cfg.step4.useBestScore = true;
        cfg.step4.useBestSpeed = true;
        cfg.step4.useBestMemory = true;
        cfg.step4.topFinalistsPerBucket = 1;
        cfg.step4.finalSelectionPolicy = 'bestscore';

        cfg.step1.teacherMLand = 160;
        cfg.step1.teacherRTeach = 60;
        cfg.step1.teacherSigmaScale = 1.70;
        cfg.step1.teacherBoxC = 0.1;

        cfg.step2.mLandList = [96 128 160];
        cfg.step2.rTeachList = [40 60 80];
        cfg.step2.sigmaScaleList = [1.2 1.5 1.7 2.0];
        cfg.step2.boxCList = [0.05 0.1 0.5 1.0];
        cfg.step2.shortlistN = 5;

        cfg.step3.pHiddenList = [48 64 96 128];
        cfg.step3.lamRidgeList = [1e-6 1e-4 1e-2];
        cfg.step3.alphaList = [0.05 0.10 0.20];
        cfg.step3.tempList = [1 2 5];
        cfg.step3.skipScaleList = [0 0.25 0.50];
        cfg.step3.ensembleList = [1 3];
        cfg.step3.teacherShortlistN = 3;
        cfg.step3.shortlistN = 8;
        cfg.step3.minAccRatio = 0.90;

        cfg.step4.accThresholdFrac = 0.97;
        cfg.step4.repeatsFast = 2;

        cfg.runtime = struct();
        cfg.runtime.pausePollSec = 0.20;
        cfg.runtime.saveIntermediate = true;
        cfg.runtime.savePNG = true;
        cfg.runtime.saveExcel = true;
        cfg.runtime.verbose = true;
        cfg.runtime.verboseTiming = true;
        cfg.runtime.saveRunManifest = true;
        cfg.runtime.exportSplitSummary = true;
        cfg.runtime.exportMasterReport = true;
        cfg.runtime.exportDataDisposition = true;
        cfg.runtime.runBenchmarks = false;

        cfg.benchmark = struct();
        cfg.benchmark.enabled = false;
        cfg.benchmark.methods = {'PCA_LINSVM','PCA_LDA','PCA_RF'};
        cfg.benchmark.kPC = [];
        cfg.benchmark.outerK = [];
        cfg.benchmark.repeats = [];
        cfg.benchmark.boxC = 1;
        cfg.benchmark.numTrees = 100;
        cfg.benchmark.maxSplits = 20;
        cfg.benchmark.exportROC = false;
    end

    function createUI()
        sc = get(0,'ScreenSize');
        fw = min(1500, sc(3)-80);
        fh = min(920,  sc(4)-100);
        fx = round((sc(3)-fw)/2);
        fy = round((sc(4)-fh)/2);

        app.ui.fig = figure('Name','RAVEN_V1_01 | Master Pipeline | Distilled Intelligence', ...
            'NumberTitle','off','MenuBar','none','ToolBar','none', ...
            'Color',[0 0 0],'Position',[fx fy fw fh], ...
            'Resize','on','CloseRequestFcn',@onClose);

        app.ui.pnlTop = uipanel(app.ui.fig,'Units','normalized','Position',[0.01 0.92 0.98 0.07], ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.85 0.95 0.92], ...
            'Title','RAVEN_V1_01 | Master Pipeline | Distilled Intelligence', ...
            'FontWeight','bold');

        app.ui.txtStep = uicontrol(app.ui.pnlTop,'Style','text','Units','normalized', ...
            'Position',[0.01 0.15 0.28 0.70],'String','Step: Idle', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.95 0.95 0.95], ...
            'HorizontalAlignment','left','FontWeight','bold','FontSize',12);
        app.ui.txtStatus = uicontrol(app.ui.pnlTop,'Style','text','Units','normalized', ...
            'Position',[0.30 0.15 0.40 0.70],'String','Status: Ready', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.82 0.95 0.85], ...
            'HorizontalAlignment','left','FontSize',11);
        app.ui.txtError = uicontrol(app.ui.pnlTop,'Style','text','Units','normalized', ...
            'Position',[0.71 0.15 0.28 0.70],'String','Last error: none', ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[1.0 0.75 0.75], ...
            'HorizontalAlignment','left','FontSize',10);

        app.ui.pnlLeft = uipanel(app.ui.fig,'Units','normalized','Position',[0.01 0.08 0.31 0.83], ...
            'Title','Project Setup','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pnlCenter = uipanel(app.ui.fig,'Units','normalized','Position',[0.33 0.08 0.42 0.83], ...
            'Title','Activity / Results','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pnlRight = uipanel(app.ui.fig,'Units','normalized','Position',[0.76 0.08 0.23 0.83], ...
            'Title','','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'BorderType','none');
        app.ui.pnlLogo = uipanel(app.ui.pnlRight,'Units','normalized','Position',[0.00 0.56 1.00 0.44], ...
            'Title','','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'BorderType','none');
        app.ui.pnlControls = uipanel(app.ui.pnlRight,'Units','normalized','Position',[0.00 0.00 1.00 0.56], ...
            'Title','Controls','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.pnlBottom = uipanel(app.ui.fig,'Units','normalized','Position',[0.01 0.01 0.98 0.06], ...
            'BackgroundColor',[0 0 0],'BorderType','line','BorderWidth',1);

        curY = 0.95;
        addLabel('Data source (file(s) or folder)', curY);
        app.ui.edData = uicontrol(app.ui.pnlLeft,'Style','edit','Units','normalized', ...
            'Position',[0.03 curY-0.04 0.64 0.045],'String',app.cfg.io.dataSource, ...
            'BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
            'HorizontalAlignment','left','Callback',@onDataSourceEdited);
        app.ui.btnFolder = uicontrol(app.ui.pnlLeft,'Style','pushbutton','Units','normalized', ...
            'Position',[0.69 curY-0.04 0.13 0.045],'String','Folder','Callback',@onBrowseFolder);
        app.ui.btnMat = uicontrol(app.ui.pnlLeft,'Style','pushbutton','Units','normalized', ...
            'Position',[0.83 curY-0.04 0.13 0.045],'String','File(s)','Callback',@onBrowseMat);
        curY = curY - 0.065;

        addLabel('Uploaded files / classes', curY);
        app.ui.lstFiles = uicontrol(app.ui.pnlLeft,'Style','listbox','Units','normalized', ...
            'Position',[0.03 curY-0.11 0.93 0.095], ...
            'BackgroundColor',[0.03 0.03 0.03],'ForegroundColor',[0.90 0.90 0.90], ...
            'FontName','Consolas','String',{'No files selected'});
        curY = curY - 0.135;

        addLabel('Save folder', curY);
        app.ui.edSave = uicontrol(app.ui.pnlLeft,'Style','edit','Units','normalized', ...
            'Position',[0.03 curY-0.04 0.79 0.045],'String',app.cfg.io.saveBaseDir, ...
            'BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
            'HorizontalAlignment','left');
        app.ui.btnSave = uicontrol(app.ui.pnlLeft,'Style','pushbutton','Units','normalized', ...
            'Position',[0.83 curY-0.04 0.13 0.045],'String','...','Callback',@onBrowseSave);
        curY = curY - 0.075;

        addLabel('Output root name', curY);
        app.ui.edRoot = uicontrol(app.ui.pnlLeft,'Style','edit','Units','normalized', ...
            'Position',[0.03 curY-0.04 0.93 0.045],'String',app.cfg.io.rootName, ...
            'BackgroundColor',[0.05 0.05 0.05],'ForegroundColor',[0.95 0.95 0.95], ...
            'HorizontalAlignment','left');
        curY = curY - 0.075;

        app.ui.chkAutoDetect = uicontrol(app.ui.pnlLeft,'Style','checkbox','Units','normalized', ...
            'Position',[0.03 curY-0.02 0.50 0.04],'String','Auto-detect groups', ...
            'Value',1,'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        app.ui.chkParallel = uicontrol(app.ui.pnlLeft,'Style','checkbox','Units','normalized', ...
            'Position',[0.55 curY-0.02 0.23 0.04],'String','Use parallel', ...
            'Value',0,'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92]);
        nAvailWorkers = getAvailableWorkerCount();
        app.ui.popWorkers = uicontrol(app.ui.pnlLeft,'Style','popupmenu','Units','normalized', ...
            'Position',[0.79 curY-0.022 0.17 0.045], ...
            'String',arrayfun(@num2str,1:nAvailWorkers,'UniformOutput',false), ...
            'Value',min(max(1,app.cfg.cv.nWorkers),nAvailWorkers), ...
            'BackgroundColor',[0.07 0.07 0.07],'ForegroundColor',[0.95 0.95 0.95], ...
            'TooltipString',sprintf('Available local workers: %d',nAvailWorkers));

        app.ui.pnlDataSummary = uipanel(app.ui.pnlLeft,'Units','normalized','Position',[0.03 0.29 0.93 0.24], ...
            'Title','Dataset Summary','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.lstDatasetSummary = uicontrol(app.ui.pnlDataSummary,'Style','listbox','Units','normalized', ...
            'Position',[0.02 0.03 0.96 0.94], 'BackgroundColor',[0.03 0.03 0.03], ...
            'ForegroundColor',[0.90 0.90 0.90], 'FontName','Consolas', 'Max',2,'Min',0, ...
            'String',{'Dataset: Not loaded'; 'Status: Ready'});

        app.ui.pnlValidation = uipanel(app.ui.pnlLeft,'Units','normalized','Position',[0.03 0.03 0.93 0.23], ...
            'Title','Validation / Readiness','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.lstValidation = uicontrol(app.ui.pnlValidation,'Style','listbox','Units','normalized', ...
            'Position',[0.02 0.03 0.96 0.94], 'BackgroundColor',[0.03 0.03 0.03], ...
            'ForegroundColor',[0.95 0.93 0.78], 'FontName','Consolas', 'Max',2,'Min',0, ...
            'String',{'[OK] Waiting for dataset selection.'});

        app.ui.lstLog = uicontrol(app.ui.pnlCenter,'Style','listbox','Units','normalized', ...
            'Position',[0.03 0.41 0.94 0.56],'BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.82 0.95 0.85],'FontName','Consolas','FontSize',10, ...
            'Max',2,'Min',0,'String',{'RAVEN GUI initialized.'});

        app.ui.pnlRunStatus = uipanel(app.ui.pnlCenter,'Units','normalized','Position',[0.03 0.03 0.94 0.33], ...
            'Title','Live Run Status / Best So Far','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.92 0.92 0.92],'FontWeight','bold');
        app.ui.lstRunStatus = uicontrol(app.ui.pnlRunStatus,'Style','listbox','Units','normalized', ...
            'Position',[0.02 0.03 0.96 0.94], 'BackgroundColor',[0.03 0.03 0.03], ...
            'ForegroundColor',[0.88 0.95 0.98], 'FontName','Consolas', 'Max',2,'Min',0, ...
            'String',{'Current step: Idle'; 'Pipeline status: Ready'; 'Progress: 0.0%'; 'Dataset mode: spectra_blocks'; 'Effective CV mode: stratified'; 'Step 3 mode: full_search'; 'Current dataset: none'; 'Active teacher: none'; 'Active student: none'; 'Last activity: GUI initialized'; 'Last error: none'; 'Best final: pending'; 'Output root: RAVEN_RUN'});

        nCtrlRows = 13;
        btnX = 0.09; btnW = 0.82; btnFS = 10.0;
        btnTop = 0.975; btnBottom = 0.040; btnGap = 0.010;
        btnH = (btnTop - btnBottom - (nCtrlRows-1)*btnGap) / nCtrlRows;
        btnY0 = btnTop - btnH;
        app.ui.btnPreproc = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0 btnW btnH],'String','Preprocessing', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onPreprocPreview);
        app.ui.btnAdvCtrl = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-(btnH+btnGap) btnW btnH],'String','Advanced Settings', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onAdvancedSteps);
        presetY = btnY0-2*(btnH+btnGap);
        pw = 0.255; pg = 0.027; px = 0.09;
        app.ui.btnPresetQuick = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[px presetY pw btnH],'String','Quick', ...
            'FontWeight','bold','FontSize',9.7,'BackgroundColor',[0.18 0.18 0.18],'ForegroundColor',[0.95 0.95 0.95],'Callback',@onPresetQuick);
        app.ui.btnPresetAcc = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[px+pw+pg presetY pw btnH],'String','Accurate', ...
            'FontWeight','bold','FontSize',9.7,'BackgroundColor',[0.10 0.22 0.18],'ForegroundColor',[0.92 0.98 0.94],'Callback',@onPresetAccurate);
        app.ui.btnPresetPublish = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[px+2*(pw+pg) presetY pw btnH],'String','Publish', ...
            'FontWeight','bold','FontSize',9.7,'BackgroundColor',[0.22 0.18 0.10],'ForegroundColor',[0.98 0.96 0.90],'Callback',@onPresetPublish);
        app.ui.btnRun = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-3*(btnH+btnGap) btnW btnH],'String','Run Pipeline', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.95 0.95 0.95],'Callback',@onRun);
        app.ui.btnPause = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-4*(btnH+btnGap) btnW btnH],'String','Pause', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onPause);
        app.ui.btnStop = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-5*(btnH+btnGap) btnW btnH],'String','Stop', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.95 0.35 0.35],'Callback',@onStop);
        app.ui.btnBlind = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-6*(btnH+btnGap) btnW btnH],'String','Blind Test', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onBlindTest);
        app.ui.btnOpenOut = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-7*(btnH+btnGap) btnW btnH],'String','Open Output Folder', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onOpenOutput);
        app.ui.btnSaveCfg = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-8*(btnH+btnGap) btnW btnH],'String','Save Config MAT', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onSaveConfig);
        app.ui.btnSaveProj = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-9*(btnH+btnGap) btnW btnH],'String','Save Project', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onSaveProject);
        app.ui.btnLoadProj = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-10*(btnH+btnGap) btnW btnH],'String','Load Project', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onLoadProject);
        app.ui.btnClassMgr = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-11*(btnH+btnGap) btnW btnH],'String','Class Manager', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onClassManager);
        app.ui.btnResultsNav = uicontrol(app.ui.pnlControls,'Style','pushbutton','Units','normalized', ...
            'Position',[btnX btnY0-12*(btnH+btnGap) btnW btnH],'String','Results Navigator', ...
            'FontWeight','bold','FontSize',btnFS,'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.92 0.92 0.92],'Callback',@onResultsNavigator);

        app.ui.axLogo = axes('Parent',app.ui.pnlLogo,'Units','normalized','Position',[0.04 0.218 0.92 0.782], ...
            'Color',[0 0 0],'XColor',[0 0 0],'YColor',[0 0 0]);
        axis(app.ui.axLogo,'off');

        app.ui.axLicense = axes('Parent',app.ui.pnlLogo,'Units','normalized','Position',[0.02 0.014 0.96 0.188], ...
            'Color',[0 0 0],'XColor',[0 0 0],'YColor',[0 0 0], ...
            'ButtonDownFcn',@onLicenseEmail);
        axis(app.ui.axLicense,'off');
        xlim(app.ui.axLicense,[0 1]); ylim(app.ui.axLicense,[0 1]);
        app.ui.txtLicenseTitle = text(app.ui.axLicense,0.5,0.78,'RAVEN Software License', ...
            'Color',[0.86 0.86 0.86],'FontSize',9.2,'HorizontalAlignment','center', ...
            'FontWeight','bold','HitTest','on','ButtonDownFcn',@onLicenseEmail);
        app.ui.txtLicenseOwner = text(app.ui.axLicense,0.5,0.47,'Registered licensee: Ario Jafari', ...
            'Color',[0.78 0.78 0.78],'FontSize',8.8,'HorizontalAlignment','center', ...
            'FontWeight','bold','HitTest','on','ButtonDownFcn',@onLicenseEmail);
        app.ui.txtLicenseEmail = text(app.ui.axLicense,0.5,0.18,'ario.jafari@liu.se', ...
            'Color',[0.45 0.70 1.00],'FontSize',8.8,'HorizontalAlignment','center', ...
            'HitTest','on','ButtonDownFcn',@onLicenseEmail);

        app.ui.txtProg = uicontrol(app.ui.pnlBottom,'Style','text','Units','normalized', ...
            'Position',[0.01 0.18 0.12 0.64],'String','0.0%','BackgroundColor',[0 0 0], ...
            'ForegroundColor',[0.90 0.90 0.92],'HorizontalAlignment','left','FontWeight','bold','FontSize',12);
        app.ui.progBox = uipanel(app.ui.pnlBottom,'Units','normalized', ...
            'Position',[0.14 0.24 0.83 0.52], 'BackgroundColor',[0.07 0.07 0.07], ...
            'HighlightColor',[0.28 0.28 0.28], 'BorderColor',[0.28 0.28 0.28], ...
            'BorderType','line','BorderWidth',1);
        app.ui.progFill = uipanel(app.ui.progBox,'Units','normalized', ...
            'Position',[0 0 0 1], 'BackgroundColor',[0.12 0.78 0.72], ...
            'BorderType','none');
    end

    function addLabel(txt, y)

        uicontrol(app.ui.pnlLeft,'Style','text','Units','normalized', ...
            'Position',[0.03 min(0.975, y+0.008) 0.93 0.022],'String',txt, ...
            'BackgroundColor',[0 0 0],'ForegroundColor',[0.92 0.92 0.92], ...
            'HorizontalAlignment','left','FontWeight','bold');
    end

    function showLogo()
        cla(app.ui.axLogo);
        axis(app.ui.axLogo,'off');
        logoCoreDir = fileparts(mfilename('fullpath'));
        logoRootDir = fileparts(logoCoreDir);
        candidates = {fullfile(logoCoreDir,'IMG_3820.png'), ...
                      fullfile(logoCoreDir,'IMG_3820.PNG'), ...
                      fullfile(logoRootDir,'IMG_3820.png'), ...
                      fullfile(logoRootDir,'IMG_3820.PNG'), ...
                      fullfile(pwd,'IMG_3820.png'), ...
                      fullfile(pwd,'IMG_3820.PNG'), ...
                      '/mnt/data/inspect_raven/IMG_3820.png', ...
                      '/mnt/data/IMG_3820.png', ...
                      '/mnt/data/IMG_3820.PNG'};
        found = '';
        for i = 1:numel(candidates)
            if exist(candidates{i},'file')
                found = candidates{i};
                break;
            end
        end
        if ~isempty(found)
            I = imread(found);
            image(app.ui.axLogo,I);
            axis(app.ui.axLogo,'image');
            axis(app.ui.axLogo,'off');
            setSummary('Logo', found);
        else
            text(app.ui.axLogo,0.5,0.5,'RAVEN','Color',[0.8 0.95 0.9], ...
                'FontSize',28,'FontWeight','bold','HorizontalAlignment','center');
            text(app.ui.axLogo,0.5,0.40,'Distilled Intelligence','Color',[0.85 0.85 0.6], ...
                'FontSize',12,'HorizontalAlignment','center');
            xlim(app.ui.axLogo,[0 1]); ylim(app.ui.axLogo,[0 1]);
        end
    end

    function onLicenseEmail(~,~)
        emailAddr = 'ario.jafari@liu.se';
        try
            web(['mailto:' emailAddr],'-browser');
        catch
            try
                clipboard('copy',emailAddr);
                msgbox(sprintf('Could not open the default mail client.\nEmail copied to clipboard:\n%s', emailAddr), ...
                    'RAVEN license','help');
            catch
                try
                    logmsg(sprintf('RAVEN license email: %s', emailAddr));
                catch
                    disp(['RAVEN license email: ' emailAddr]);
                end
            end
        end
    end

    function refreshPlan()
        syncCfgFromUI();
        setSummary('Priority','Accuracy -> Stability -> Speed -> Simplicity');
        setSummary('Pipeline','0 Load | 1 kPC/Teacher Baseline | 2 Teacher Search | 3 Student Search | 4 Final + Blind');
        if isfield(app.cfg.preproc,'enabled') && ~app.cfg.preproc.enabled
            setSummary('Preprocessing','RAW only (no SG, no baseline, no normalization; crop still applied)');
        else
            setSummary('Preprocessing',sprintf('SG(%d,%d), AsLS(%.1e, %.1e, %d), Norm=%s, Cosmic=%d', ...
                app.cfg.preproc.sgOrder, app.cfg.preproc.sgFrame, app.cfg.preproc.aslsLambda, ...
                app.cfg.preproc.aslsP, app.cfg.preproc.aslsNIter, app.cfg.preproc.normMode, app.cfg.preproc.cosmicDenoise));
        end
        setSummary('Workers',sprintf('Parallel=%d | Workers=%d', app.cfg.cv.useParallel, app.cfg.cv.nWorkers));
        setSummary('Benchmark', sprintf('Enabled=%d | Methods=%s', double(app.cfg.runtime.runBenchmarks || app.cfg.benchmark.enabled), strjoin(app.cfg.benchmark.methods, ', ')));
        if isfield(app.state,'detectedData') && ~isempty(app.state.detectedData)
            data = app.state.detectedData;
            counts = cellfun(@(b) size(b,2)-1, data.blocks);
            setSummary('Classes',sprintf('%d available', numel(data.groupNames)));
            selNames = getSelectedNamesForValidation(data.groupNames);
            setSummary('Selected Classes',sprintf('%d selected', numel(selNames)));
            setSummary('Spectra',sprintf('Total=%d | Range/class=%d-%d', sum(counts), min(counts), max(counts)));
            xvec = data.blocks{1}(:,1);
            setSummary('Spectral Variables',sprintf('D=%d', numel(xvec)));
            setSummary('Spectral Range',sprintf('%.4g to %.4g', min(xvec), max(xvec)));
        else
            setSummary('Dataset','Not loaded');
        end
        updateValidationPanel();
    end

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

    function data = loadDynamicDataset(dataSource, autoDetect)
        if isfield(app.cfg,'io') && isfield(app.cfg.io,'inputMode') && strcmpi(app.cfg.io.inputMode,'feature_matrix')
            data = loadFeatureMatrixDataset(dataSource);
            return;
        end
        data = struct();
        data.groupNames = {};
        data.blocks = {};
        data.sourceLabels = {};
        if nargin < 2, autoDetect = true; end

        entries = parseDataSourceEntries(dataSource);
        if isempty(entries)
            logmsg('No data source path given. Trying base workspace.');
            vars = evalin('base','whos');
            for i = 1:numel(vars)
                if ismember(vars(i).class, {'double','single','table'})
                    V = evalin('base',vars(i).name);
                    Mcand = [];
                    if istable(V)
                        Mcand = convertTableLikeToNumericMatrix(V);
                    elseif isnumeric(V) && ismatrix(V)
                        Mcand = sanitizeDataMatrix(double(V));
                    end
                    if isSuitableBlock(Mcand)
                        data.groupNames{end+1} = matlab.lang.makeValidName(vars(i).name);
                        data.blocks{end+1} = Mcand;
                        data.sourceLabels{end+1} = sprintf('base:%s', vars(i).name);
                    end
                end
            end
            if isempty(data.groupNames)
                error('No suitable numeric/table class matrices found in base workspace. Expected first column = spectral variable, remaining columns = intensities.');
            end
            return;
        end

        supported = {'.mat','.csv','.txt','.xlsx','.xls'};
        if numel(entries) > 1
            for i = 1:numel(entries)
                if exist(entries{i},'file') ~= 2
                    error('Selected path is not a valid file: %s', entries{i});
                end
                [~,~,ext] = fileparts(entries{i});
                if ~ismember(lower(ext), supported)
                    error('Unsupported file type: %s', entries{i});
                end
                [gNames, Ms, srcLabels] = expandFileToClasses(entries{i});
                data.groupNames = [data.groupNames, gNames];
                data.blocks = [data.blocks, Ms];
                data.sourceLabels = [data.sourceLabels, srcLabels];
            end
        elseif exist(entries{1},'file') == 2
            [gNames, Ms, srcLabels] = expandFileToClasses(entries{1});
            data.groupNames = gNames;
            data.blocks = Ms;
            data.sourceLabels = srcLabels;
        elseif exist(entries{1},'dir') == 7
            listing = dir(entries{1});
            for i = 1:numel(listing)
                if listing(i).isdir, continue; end
                fp = fullfile(entries{1}, listing(i).name);
                [~,~,ext] = fileparts(fp);
                if ~ismember(lower(ext), supported)
                    continue;
                end
                [gNames, Ms, srcLabels] = expandFileToClasses(fp);
                data.groupNames = [data.groupNames, gNames];
                data.blocks = [data.blocks, Ms];
                data.sourceLabels = [data.sourceLabels, srcLabels];
            end
        else
            error('Data source not found: %s', dataSource);
        end

        if isempty(data.groupNames)
            error('No suitable datasets were found in the selected source. Each file or sheet/variable must contain a numeric table/matrix with first column = spectral variable and remaining columns = intensities.');
        end

        keep = true(1,numel(data.groupNames));
        for i = 1:numel(data.groupNames)
            nm = lower(data.groupNames{i});
            if contains(nm,'blind')
                keep(i) = false;
            end
        end
        data.groupNames = data.groupNames(keep);
        data.blocks = data.blocks(keep);
        if isfield(data,'sourceLabels') && numel(data.sourceLabels)==numel(keep)
            data.sourceLabels = data.sourceLabels(keep);
        end
        if isempty(data.groupNames)
            error('Only blind-like datasets were detected.');
        end

        [~, ia] = unique(lower(data.groupNames), 'stable');
        if numel(ia) < numel(data.groupNames)
            counts = containers.Map('KeyType','char','ValueType','double');
            for i = 1:numel(data.groupNames)
                key = lower(data.groupNames{i});
                if ~isKey(counts,key)
                    counts(key) = 1;
                else
                    counts(key) = counts(key) + 1;
                    data.groupNames{i} = sprintf('%s_%d', data.groupNames{i}, counts(key));
                end
            end
        end
    end

    function data = loadFeatureMatrixDataset(dataSource)
        data = struct();
        data.groupNames = {};
        data.blocks = {};
        data.sourceLabels = {};
        data.isFeatureMatrix = true;
        if isempty(strtrim(dataSource))
            X = evalin('base','X');
            y = evalin('base','y');
            if evalin('base','exist(''groupVector'',''var'')'), groupVector = evalin('base','groupVector'); else, groupVector = []; end
            if evalin('base','exist(''groupNames'',''var'')'), groupNames = evalin('base','groupNames'); else, groupNames = {}; end
        else
            [~,~,ext] = fileparts(dataSource);
            if ~strcmpi(ext,'.mat')
                error('Feature-matrix mode currently expects a MAT file with variables X [N x D] and y [N x 1].');
            end
            S = load(dataSource);
            if ~isfield(S,'X') || ~isfield(S,'y')
                error('Feature-matrix mode expects MAT file variables X [N x D] and y [N x 1].');
            end
            X = S.X; y = S.y;
            if isfield(S,'groupVector'), groupVector = S.groupVector; else, groupVector = []; end
            if isfield(S,'groupNames'), groupNames = S.groupNames; else, groupNames = {}; end
        end
        X = double(X); y = y(:);
        if size(X,1) ~= numel(y)
            error('X and y size mismatch in feature-matrix mode.');
        end
        classes = unique(y(:)','stable');
        if isempty(groupNames) || numel(groupNames) ~= numel(classes)
            groupNames = arrayfun(@(c)sprintf('Class_%s',char(string(c))), classes, 'UniformOutput', false);
        end
        data.X_all = X;
        [~,yidx] = ismember(y, classes);
        data.y_idx = yidx(:);
        data.groupNames = groupNames(:)';
        counts = zeros(numel(classes),1);
        for ii=1:numel(classes)
            counts(ii) = sum(yidx==ii);
        end
        data.sampleCounts = counts;
        data.groupVector = groupVector;
        data.W = (1:size(X,2))';
    end

    function [groupNames, blocks, sourceLabels] = expandFileToClasses(fp)
        [~,nm,ext] = fileparts(fp);
        groupNames = {};
        blocks = {};
        sourceLabels = {};
        switch lower(ext)
            case '.mat'
                S = load(fp);
                [validNames, validBlocks] = pickMatVariablesAsClasses(S);
                if isempty(validNames)
                    error('No suitable numeric/table variable found in MAT file %s.', [nm ext]);
                end
                for ii = 1:numel(validNames)
                    groupNames{end+1} = matlab.lang.makeValidName(validNames{ii});
                    blocks{end+1} = validBlocks{ii};
                    sourceLabels{end+1} = sprintf('%s%s:%s', nm, ext, validNames{ii});
                    logmsg(sprintf('Loaded class %s from MAT file %s using variable %s.', groupNames{end}, [nm ext], validNames{ii}));
                end
            case {'.xlsx','.xls'}
                [sheetNames, validBlocks] = pickExcelSheetsAsClasses(fp);
                if isempty(sheetNames)
                    error('No suitable dataset sheet found in Excel file %s.', [nm ext]);
                end
                if numel(sheetNames) > 1
                    classNames = cellfun(@(s) matlab.lang.makeValidName(s), sheetNames, 'UniformOutput', false);
                else
                    classNames = {matlab.lang.makeValidName(nm)};
                end
                for ii = 1:numel(validBlocks)
                    groupNames{end+1} = classNames{ii};
                    blocks{end+1} = validBlocks{ii};
                    sourceLabels{end+1} = sprintf('%s%s:%s', nm, ext, sheetNames{ii});
                    logmsg(sprintf('Loaded class %s from Excel file %s using sheet %s.', groupNames{end}, [nm ext], sheetNames{ii}));
                end
            case {'.csv','.txt'}
                [M, srcDesc] = readSingleTableBasedFile(fp);
                if ~isSuitableBlock(M)
                    error('File %s does not contain a valid class block. Expected first column = spectral variable and remaining columns = intensity columns.', [nm ext]);
                end
                groupNames = {matlab.lang.makeValidName(nm)};
                blocks = {M};
                sourceLabels = {sprintf('%s%s', nm, ext)};
                logmsg(sprintf('Loaded class %s from %s (%s).', groupNames{1}, [nm ext], srcDesc));
            otherwise
                error('Unsupported file type: %s', ext);
        end
    end

    function [validNames, validBlocks] = pickMatVariablesAsClasses(S)
        validNames = {};
        validBlocks = {};
        fns = fieldnames(S);
        for i = 1:numel(fns)
            V = S.(fns{i});
            Mcand = [];
            if istable(V)
                Mcand = convertTableLikeToNumericMatrix(V);
            elseif isnumeric(V) && ismatrix(V)
                Mcand = sanitizeDataMatrix(double(V));
            end
            if isSuitableBlock(Mcand)
                validNames{end+1} = fns{i};
                validBlocks{end+1} = Mcand;
            end
        end
    end

    function [validSheets, validBlocks] = pickExcelSheetsAsClasses(fp)
        validSheets = {};
        validBlocks = {};
        sh = sheetnames(fp);
        for i = 1:numel(sh)
            Mcand = [];
            try
                opts = detectImportOptions(fp,'Sheet',sh{i});
                T = readtable(fp, opts);
                Mcand = convertTableLikeToNumericMatrix(T);
            catch
                Mcand = [];
            end
            if ~isSuitableBlock(Mcand)
                try
                    Mcand = sanitizeDataMatrix(double(readmatrix(fp,'Sheet',sh{i})));
                catch
                    Mcand = [];
                end
            end
            if isSuitableBlock(Mcand)
                validSheets{end+1} = sh{i};
                validBlocks{end+1} = Mcand;
            end
        end
    end

    function [M, srcDesc] = readSingleTableBasedFile(fp)
        [~,~,ext] = fileparts(fp);
        M = [];
        srcDesc = '';
        switch lower(ext)
            case {'.csv','.txt'}
                Mcandidates = {};
                descs = {};
                try
                    opts = detectImportOptions(fp);
                    T = readtable(fp, opts);
                    Mcand = convertTableLikeToNumericMatrix(T);
                    if isSuitableBlock(Mcand)
                        Mcandidates{end+1} = Mcand;
                        descs{end+1} = 'table import';
                    end
                catch
                end
                try
                    Mcand = sanitizeDataMatrix(double(readmatrix(fp)));
                    if isSuitableBlock(Mcand)
                        isDup = false;
                        for k = 1:numel(Mcandidates)
                            if isequal(size(Mcandidates{k}), size(Mcand)) && max(abs(Mcandidates{k}(:)-Mcand(:))) < 1e-12
                                isDup = true; break;
                            end
                        end
                        if ~isDup
                            Mcandidates{end+1} = Mcand;
                            descs{end+1} = 'matrix import';
                        end
                    end
                catch
                end
                if isempty(Mcandidates)
                    error('Could not read a valid numeric table from %s.', fp);
                end
                if numel(Mcandidates) > 1
                    error('File %s has multiple different valid interpretations (%s). Keep exactly one valid table layout per file.', fp, strjoin(descs, ', '));
                end
                M = Mcandidates{1};
                srcDesc = descs{1};
            case {'.xlsx','.xls'}
                [validSheets, validBlocks] = pickExcelSheetsAsClasses(fp);
                if isempty(validSheets)
                    error('Could not read a valid numeric table from %s.', fp);
                end
                if numel(validSheets) > 1
                    error('Excel file %s contains multiple valid sheets (%s). In the pipeline, each valid sheet is treated as one class. Use the main loader instead of single-table parsing.', fp, strjoin(validSheets, ', '));
                end
                M = validBlocks{1};
                srcDesc = sprintf('sheet %s', validSheets{1});
            otherwise
                error('Unsupported table-based file type: %s', ext);
        end
        if ~isSuitableBlock(M)
            error('Could not read a valid numeric table from %s.', fp);
        end
    end

    function M = convertTableLikeToNumericMatrix(T)
        M = [];
        if isempty(T) || ~istable(T)
            return;
        end
        nR = height(T);
        nC = width(T);
        if nR < 1 || nC < 2
            return;
        end
        cols = nan(nR, nC);
        keep = false(1,nC);
        for c = 1:nC
            v = T{:,c};
            numv = nan(nR,1);
            if isnumeric(v) || islogical(v)
                numv = double(v(:));
            elseif iscell(v) || isstring(v) || ischar(v) || iscategorical(v)
                try
                    numv = str2double(string(v(:)));
                catch
                    numv = nan(nR,1);
                end
            else
                try
                    numv = str2double(string(v(:)));
                catch
                    numv = nan(nR,1);
                end
            end
            cols(:,c) = numv;
            finiteCount = sum(isfinite(numv));
            if finiteCount >= max(3, ceil(0.6*nR)) || (c == 1 && finiteCount >= max(3, ceil(0.6*nR)))
                keep(c) = true;
            end
        end
        cols = cols(:,keep);
        M = sanitizeDataMatrix(cols);
    end

    function M = sanitizeDataMatrix(M)
        if isempty(M)
            M = [];
            return;
        end
        if ~isnumeric(M) || ~ismatrix(M)
            M = [];
            return;
        end
        M = double(M);
        if size(M,2) < 2
            M = [];
            return;
        end

        rowKeep = any(isfinite(M),2);
        colKeep = any(isfinite(M),1);
        M = M(rowKeep, colKeep);
        if isempty(M) || size(M,2) < 2
            M = [];
            return;
        end

        rowKeep = isfinite(M(:,1)) & any(isfinite(M(:,2:end)),2);
        M = M(rowKeep,:);
        if isempty(M) || size(M,2) < 2
            M = [];
            return;
        end

        colKeep = [true, any(isfinite(M(:,2:end)),1)];
        M = M(:,colKeep);
        if size(M,2) < 2
            M = [];
            return;
        end

        rowKeep = all(isfinite(M),2);
        M = M(rowKeep,:);
        if isempty(M) || size(M,1) < 10 || size(M,2) < 2
            M = [];
            return;
        end

        [~,ord] = sort(M(:,1), 'ascend');
        M = M(ord,:);
    end

    function tf = isSuitableBlock(M)
        tf = isnumeric(M) && ismatrix(M) && size(M,1) >= 10 && size(M,2) >= 2 && all(isfinite(M(:)));
    end

    function tf = axesMatch(a,b)
        tf = false;
        if numel(a) ~= numel(b)
            return;
        end
        a = double(a(:)); b = double(b(:));
        scl = max(1, max(abs([a; b])));
        tf = all(abs(a-b) <= 1e-6*scl);
    end

    function dataOut = filterDataByPreprocSelection(dataIn, pre)
        dataOut = dataIn;
        if ~isfield(pre,'includeNames') || isempty(pre.includeNames)
            return;
        end
        keep = false(1, numel(dataIn.groupNames));
        for ii = 1:numel(dataIn.groupNames)
            keep(ii) = any(strcmpi(dataIn.groupNames{ii}, pre.includeNames));
        end
        if ~any(keep)
            error('No classes remain after applying preprocessing legend selection.');
        end
        dataOut.groupNames = dataIn.groupNames(keep);
        dataOut.blocks = dataIn.blocks(keep);
        if isfield(dataIn,'sourceLabels') && numel(dataIn.sourceLabels) == numel(dataIn.groupNames)
            dataOut.sourceLabels = dataIn.sourceLabels(keep);
        end
    end

    function [W, X_all, y_idx, groupNames, sampleCounts] = preprocessDataset(data, pre)
        if isfield(data,'isFeatureMatrix') && data.isFeatureMatrix
            W = data.W; X_all = data.X_all; y_idx = data.y_idx; groupNames = data.groupNames; sampleCounts = data.sampleCounts; return;
        end
        data = filterDataByPreprocSelection(data, pre);
        groupNames = data.groupNames;
        blocks = data.blocks;
        C = numel(groupNames);
        X_all = [];
        y_idx = [];
        sampleCounts = zeros(C,1);
        W = [];
        WrawRef = [];
        if mod(pre.sgFrame,2)==0
            pre.sgFrame = pre.sgFrame + 1;
        end
        DtD = [];
        sgKernel = [];
        if ravenGetField(pre,'smoothEnable',1) || ravenGetField(pre,'derivOrder',0) > 0
            sgKernel = buildSGKernel(pre.sgFrame, pre.sgOrder, ravenGetField(pre,'derivOrder',0), 1);
        end
        for c = 1:C
            M = blocks{c};
            if istable(M), M = table2array(M); end
            if ~isnumeric(M) || size(M,2)<2
                error('Group %s is not numeric [nW x (1+Nspec)].', groupNames{c});
            end
            wv = M(:,1);
            Xblk = double(M(:,2:end));
            if isempty(WrawRef)
                WrawRef = wv;
            else
                if ~axesMatch(wv, WrawRef)
                    error('Spectral-variable axis mismatch in group %s.', groupNames{c});
                end
            end
            [wvUse, XblkUse] = cropBlockByXLimits(wv, Xblk, pre);
            if isempty(DtD)
                W = wvUse;
                nW0 = numel(W);
                e = ones(nW0,1);
                D2 = spdiags([e -2*e e], 0:2, nW0-2, nW0);
                DtD = D2'*D2;
            else
                if ~axesMatch(wvUse, W)
                    error('Cropped spectral-variable axis mismatch in group %s.', groupNames{c});
                end
            end
            [~,nSpec] = size(XblkUse);
            Xpp = applyPreprocBlock(XblkUse, pre, DtD, sgKernel);
            X_all = [X_all; Xpp.']; %#ok<AGROW>
            y_idx = [y_idx; c*ones(nSpec,1)];
            sampleCounts(c) = nSpec;
        end
    end

    function sgKernel = buildSGKernel(frameLen, sgOrder, derivOrder, delta)
        if nargin < 3 || isempty(derivOrder), derivOrder = 0; end
        if nargin < 4 || isempty(delta) || ~isfinite(delta) || delta == 0, delta = 1; end
        derivOrder = max(0, round(double(derivOrder)));
        sgOrder = max(derivOrder, round(double(sgOrder)));
        if mod(frameLen,2)==0
            frameLen = frameLen + 1;
        end
        m = (frameLen-1)/2;
        t = (-m:m)';
        A = zeros(frameLen, sgOrder+1);
        for j = 0:sgOrder
            A(:,j+1) = t.^j;
        end
        H = ((A.'*A)\A.').';
        sgKernel = factorial(derivOrder) / (delta^max(1,derivOrder)) * H(:,derivOrder+1).';
        if derivOrder == 0
            sgKernel = H(:,1).';
        end
    end

    function wins = normalizeRangeWindows(wins)
        if isempty(wins)
            wins = [];
            return;
        end
        wins = double(wins);
        if isvector(wins) && numel(wins) == 2
            wins = reshape(wins,1,2);
        end
        if size(wins,2) ~= 2
            wins = [];
            return;
        end
        wins = wins(all(isfinite(wins),2),:);
        if isempty(wins), return; end
        for ii = 1:size(wins,1)
            if wins(ii,2) < wins(ii,1)
                wins(ii,:) = wins(ii,[2 1]);
            end
        end
        wins = sortrows(wins,1);
    end

    function txt = rangeWindowsToText(wins)
        wins = normalizeRangeWindows(wins);
        if isempty(wins)
            txt = '';
            return;
        end
        parts = cell(size(wins,1),1);
        for ii = 1:size(wins,1)
            parts{ii} = sprintf('[%g %g]', wins(ii,1), wins(ii,2));
        end
        txt = strjoin(parts, '; ');
    end

    function wins = parseRangeWindowsText(txt)
        if nargin < 1 || isempty(txt)
            wins = [];
            return;
        end
        s = char(string(txt));
        s = strrep(s,'[','');
        s = strrep(s,']','');
        s = strrep(s,',',' ');
        s = strrep(s,';','; ');
        vals = sscanf(s,'%f');
        if isempty(vals) || mod(numel(vals),2) ~= 0
            wins = [];
            return;
        end
        wins = reshape(vals,2,[]).';
        wins = normalizeRangeWindows(wins);
    end

    function [wvUse, XblkUse] = cropBlockByXLimits(wv, Xblk, pre)
        mask = true(size(wv));
        if isfield(pre,'xMin') && ~isempty(pre.xMin) && isfinite(pre.xMin)
            mask = mask & (wv >= pre.xMin);
        end
        if isfield(pre,'xMax') && ~isempty(pre.xMax) && isfinite(pre.xMax)
            mask = mask & (wv <= pre.xMax);
        end
        useWins = [];
        if isfield(pre,'rangeWindows') && ~isempty(pre.rangeWindows)
            useWins = normalizeRangeWindows(pre.rangeWindows);
        end
        if ~isempty(useWins)
            winMask = false(size(wv));
            for ii = 1:size(useWins,1)
                winMask = winMask | (wv >= useWins(ii,1) & wv <= useWins(ii,2));
            end
            mask = mask & winMask;
        end
        if ~any(mask)
            error('Chosen x-axis limits removed all wavenumbers.');
        end
        wvUse = wv(mask);
        XblkUse = Xblk(mask,:);
    end

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

    function foldIdx = makeFolds(y, K, groupIDs, mode)
        if nargin < 4 || isempty(mode), mode = 'stratified'; end
        if strcmpi(mode,'grouped')
            info = getSplitValidationInfo();
            if info.present && info.validLength && ~info.hasMissing && info.sufficientForKFold && info.classWiseSufficient && ...
                    ~isempty(groupIDs) && numel(groupIDs) == numel(y)
                foldIdx = makeGroupedStratifiedFolds(y, groupIDs, K);
            else
                if isfield(app,'state') && isfield(app.state,'runtimeFlags')
                    if ~isfield(app.state.runtimeFlags,'groupedFallbackWarned') || ~app.state.runtimeFlags.groupedFallbackWarned
                        logmsg(sprintf('Grouped CV requested but fallback to stratified CV was used. Reason: %s', info.message));
                        app.state.runtimeFlags.groupedFallbackWarned = true;
                    end
                end
                foldIdx = makeStratifiedFolds(y, K);
            end
        else
            foldIdx = makeStratifiedFolds(y, K);
        end
    end

    function foldIdx = makeGroupedStratifiedFolds(y, groupIDs, K)
        y = y(:);
        groupIDs = groupIDs(:);
        if numel(groupIDs) ~= numel(y)
            foldIdx = makeStratifiedFolds(y,K);
            return;
        end
        [G,~,gix] = unique(groupIDs,'stable');
        groupClass = zeros(numel(G),1);
        for gi = 1:numel(G)
            yy = y(gix==gi);
            if isempty(yy)
                groupClass(gi) = 1;
            else
                ux = unique(yy(:)');
                n = zeros(size(ux));
                for ii = 1:numel(ux), n(ii) = sum(yy==ux(ii)); end
                [~,ix] = max(n);
                groupClass(gi) = ux(ix);
            end
        end
        foldByGroup = zeros(numel(G),1);
        cls = unique(groupClass)';
        for cc = cls
            giList = find(groupClass==cc);
            giList = giList(randperm(numel(giList)));
            for ii = 1:numel(giList)
                foldByGroup(giList(ii)) = mod(ii-1,K)+1;
            end
        end
        foldIdx = foldByGroup(gix);
    end

    function [dataOut, meta] = applyStep0Adapter(dataIn, step0Cfg)
        if nargin < 2 || isempty(step0Cfg), step0Cfg = struct(); end
        dataOut = dataIn;
        meta = struct('inputMode',app.cfg.io.inputMode, 'commonAxisMode','preserve', 'targetLength',0, ...
            'segmentationEnable',false,'segmentLength',0,'segmentStride',0,'originalLength',NaN,'finalLength',NaN, ...
            'originalSamples',NaN,'finalSamples',NaN,'nSegmentsPerSample',1,'notes','');
        if isfield(step0Cfg,'inputMode') && ~isempty(step0Cfg.inputMode), meta.inputMode = step0Cfg.inputMode; end
        if isfield(step0Cfg,'commonAxisMode') && ~isempty(step0Cfg.commonAxisMode), meta.commonAxisMode = step0Cfg.commonAxisMode; end
        if isfield(step0Cfg,'targetLength') && ~isempty(step0Cfg.targetLength), meta.targetLength = step0Cfg.targetLength; end
        if isfield(step0Cfg,'segmentationEnable'), meta.segmentationEnable = logical(step0Cfg.segmentationEnable); end
        if isfield(step0Cfg,'segmentLength') && ~isempty(step0Cfg.segmentLength), meta.segmentLength = step0Cfg.segmentLength; end
        if isfield(step0Cfg,'segmentStride') && ~isempty(step0Cfg.segmentStride), meta.segmentStride = step0Cfg.segmentStride; end
        if isfield(dataIn,'isFeatureMatrix') && dataIn.isFeatureMatrix
            [dataOut, meta] = step0AdaptFeatureMatrix(dataIn, step0Cfg, meta);
        else
            [dataOut, meta] = step0AdaptSpectralBlocks(dataIn, step0Cfg, meta);
        end
    end

    function [dataOut, meta] = step0AdaptFeatureMatrix(dataIn, step0Cfg, meta)
        dataOut = dataIn;
        X = double(dataIn.X_all);
        meta.originalSamples = size(X,1);
        meta.originalLength = size(X,2);
        targetLen = max(0, round(ravenGetField(step0Cfg,'targetLength',0)));
        if targetLen > 0 && size(X,2) ~= targetLen
            X2 = zeros(size(X,1), targetLen);
            keepLen = min(size(X,2), targetLen);
            X2(:,1:keepLen) = X(:,1:keepLen);
            X = X2;
            dataOut.W = (1:targetLen)';
        else
            dataOut.W = (1:size(X,2))';
        end
        segEnable = logical(ravenGetField(step0Cfg,'segmentationEnable',false));
        segLen = max(0, round(ravenGetField(step0Cfg,'segmentLength',0)));
        segStride = max(0, round(ravenGetField(step0Cfg,'segmentStride',0)));
        if segEnable && segLen > 0 && size(X,2) > segLen
            if segStride <= 0, segStride = segLen; end
            starts = 1:segStride:(size(X,2)-segLen+1);
            Xseg = zeros(size(X,1)*numel(starts), segLen);
            yseg = zeros(size(X,1)*numel(starts),1);
            gseg = [];
            if isfield(dataIn,'groupVector') && ~isempty(dataIn.groupVector), gseg = zeros(size(X,1)*numel(starts),1); end
            row = 0;
            for s = starts
                rows = row + (1:size(X,1));
                Xseg(rows,:) = X(:, s:(s+segLen-1));
                yseg(rows) = dataIn.y_idx(:);
                if ~isempty(gseg), gseg(rows) = dataIn.groupVector(:); end
                row = row + size(X,1);
            end
            X = Xseg;
            dataOut.y_idx = yseg;
            if ~isempty(gseg), dataOut.groupVector = gseg; end
            dataOut.W = (1:segLen)';
            counts = accumarray(yseg,1,[numel(dataIn.groupNames),1]);
            dataOut.sampleCounts = counts;
            meta.nSegmentsPerSample = numel(starts);
        end
        dataOut.X_all = X;
        meta.finalLength = size(X,2);
        meta.finalSamples = size(X,1);
        meta.notes = 'Feature-matrix adapter uses target-length truncation/padding and optional feature-window segmentation.';
    end

    function [dataOut, meta] = step0AdaptSpectralBlocks(dataIn, step0Cfg, meta)
        dataOut = dataIn;
        blocks = dataIn.blocks;
        nB = numel(blocks);
        lens = zeros(nB,1); mins = zeros(nB,1); maxs = zeros(nB,1); nSamp = zeros(nB,1);
        for ii = 1:nB
            M = double(blocks{ii});
            lens(ii) = size(M,1); mins(ii) = min(M(:,1)); maxs(ii) = max(M(:,1)); nSamp(ii) = size(M,2)-1;
        end
        meta.originalLength = median(lens);
        meta.originalSamples = sum(nSamp);
        modeStr = lower(strtrim(char(meta.commonAxisMode)));
        targetLen = max(0, round(meta.targetLength));
        useCommon = ~strcmpi(modeStr,'preserve') || targetLen > 0;
        commonW = [];
        if useCommon
            x0 = max(mins); x1 = min(maxs);
            if ~(isfinite(x0) && isfinite(x1) && x1 > x0)
                useCommon = false; modeStr = 'preserve';
            else
                if targetLen <= 1, targetLen = max(16, round(median(lens))); end
                commonW = linspace(x0, x1, targetLen)';
            end
        end
        segEnable = meta.segmentationEnable;
        segLen = max(0, round(meta.segmentLength));
        segStride = max(0, round(meta.segmentStride));
        groupVecNew = [];
        blockStart = 1;
        for ii = 1:nB
            M = double(blocks{ii});
            wv = M(:,1); Xblk = M(:,2:end);
            if useCommon
                Xnew = zeros(numel(commonW), size(Xblk,2));
                for jj = 1:size(Xblk,2)
                    Xnew(:,jj) = interp1(wv, Xblk(:,jj), commonW, 'linear', 'extrap');
                end
                wv = commonW; Xblk = Xnew;
            end
            if segEnable && segLen > 0 && size(Xblk,1) > segLen
                if segStride <= 0, segStride = segLen; end
                starts = 1:segStride:(size(Xblk,1)-segLen+1);
                Xseg = zeros(segLen, size(Xblk,2)*numel(starts));
                col = 0;
                for s = starts
                    cols = col + (1:size(Xblk,2));
                    Xseg(:,cols) = Xblk(s:(s+segLen-1),:);
                    col = col + size(Xblk,2);
                end
                Xblk = Xseg; wv = (1:segLen)'; meta.nSegmentsPerSample = numel(starts);
                if isfield(dataIn,'groupVector') && ~isempty(dataIn.groupVector)
                    blockGV = dataIn.groupVector(blockStart:(blockStart+nSamp(ii)-1));
                    groupVecNew = [groupVecNew; repmat(blockGV(:), numel(starts), 1)];
                end
            elseif isfield(dataIn,'groupVector') && ~isempty(dataIn.groupVector)
                blockGV = dataIn.groupVector(blockStart:(blockStart+nSamp(ii)-1));
                groupVecNew = [groupVecNew; blockGV(:)];
            end
            blocks{ii} = [wv Xblk];
            nSamp(ii) = size(Xblk,2);
            blockStart = blockStart + size(M,2)-1;
        end
        dataOut.blocks = blocks;
        dataOut.sampleCounts = nSamp(:);
        if ~isempty(groupVecNew), dataOut.groupVector = groupVecNew; end
        meta.commonAxisMode = modeStr;
        meta.finalLength = size(blocks{1},1);
        meta.finalSamples = sum(nSamp);
        meta.notes = 'Step0 adapter optionally resamples to a common axis and segments each spectrum.';
    end

    function res = evaluateConfig(X, y, C, cfgEval, K, Rrepeat, seedBase, doFull)
        if nargin < 8, doFull = false; end
        N = size(X,1);
        allTrue = [];
        allPred = [];
        allScores = [];
        CMsum = zeros(C,C);

        accVec = zeros(Rrepeat,1);
        balVec = zeros(Rrepeat,1);
        wtAccVec = zeros(Rrepeat,1);
        f1Vec = zeros(Rrepeat,1);
        wtF1Vec = zeros(Rrepeat,1);
        s2Vec = zeros(Rrepeat,1);
        lowOccVec = zeros(Rrepeat,1);
        condVec = zeros(Rrepeat,1);
        dimVec = zeros(Rrepeat,1);
        memVec = zeros(Rrepeat,1);
        wallVec = zeros(Rrepeat,1);
        wallMsVec = zeros(Rrepeat,1);
        rankMeanVec = zeros(Rrepeat,1);
        predMsVec = nan(Rrepeat,1);
        recallMat = zeros(C,Rrepeat);

        repeatCM = zeros(C,C,Rrepeat);
        repeatTrue = cell(Rrepeat,1);
        repeatPred = cell(Rrepeat,1);
        repeatScores = cell(Rrepeat,1);

        for rr = 1:Rrepeat
            checkPauseStop();
            rng(seedBase+rr,'twister');
            tRep = tic;
            foldIdx = getCachedFoldIdx(y, K, rr, seedBase, 'generic_eval');
            CMrep = zeros(C,C);
            foldS2 = zeros(K,1);
            foldLowOcc = zeros(K,1);
            foldCond = zeros(K,1);
            foldDim = zeros(K,1);
            foldMem = zeros(K,1);
            foldRankMean = zeros(K,1);
            foldPredMs = nan(K,1);

            trueRep = [];
            predRep = [];
            scoreRep = [];

            for f = 1:K
                checkPauseStop();
                teMask = (foldIdx==f);
                trMask = ~teMask;
                Xtr = X(trMask,:); ytr = y(trMask);
                Xte = X(teMask,:); yte = y(teMask);

                mu = mean(Xtr,1);
                Xtrc = bsxfun(@minus,Xtr,mu);
                Xtec = bsxfun(@minus,Xte,mu);

                maxpc = min([size(Xtrc,1)-1, size(Xtrc,2), cfgEval.kPC]);
                if maxpc < 1, maxpc = 1; end
                [coeff, scoreTr] = pca(Xtrc,'NumComponents',maxpc,'Centered',false);
                scoreTe = Xtec*coeff;

                Str = scoreTr(:,1:maxpc);
                Ste = scoreTe(:,1:maxpc);

                [Phi_tr, Phi_te, diagFold, aux] = buildRAVEN(Str, Ste, cfgEval);
                foldS2(f) = diagFold.S2;
                foldLowOcc(f) = diagFold.LowOccFrac;
                foldCond(f) = diagFold.CondMedian;
                foldDim(f) = size(Phi_tr,2);
                foldMem(f) = (size(Phi_tr,2)*8)/(1024^2);
                foldRankMean(f) = diagFold.RankMean;

                tSVM = templateSVM('KernelFunction','linear','Standardize',true,'BoxConstraint',cfgEval.C);
                Mdl = fitcecoc(Phi_tr, ytr, 'Learners', tSVM, 'ClassNames', 1:C, 'Coding','onevsall');

                yhat = [];
                scores = [];
                mdlPred = Mdl;
                try
                    MdlCal = fitPosterior(Mdl, Phi_tr, ytr);
                    mdlPred = MdlCal;
                    [yhat, scores] = predict(MdlCal, Phi_te);
                catch
                    [yhat, scores] = predict(Mdl, Phi_te);
                    if size(scores,2) ~= C
                        scores = zeros(numel(yhat),C);
                    end
                end

                if doFull
                    tPred = tic;
                    try
                        predict(mdlPred, Phi_te);
                    catch
                        predict(Mdl, Phi_te);
                    end
                    foldPredMs(f) = 1000*toc(tPred)/max(1,numel(yte));
                end

                for ii = 1:numel(yte)
                    CMrep(yte(ii),yhat(ii)) = CMrep(yte(ii),yhat(ii)) + 1;
                end
                if doFull
                    trueRep = [trueRep; yte];
                    predRep = [predRep; yhat];
                    scoreRep = [scoreRep; scores];
                    allTrue = [allTrue; yte];
                    allPred = [allPred; yhat];
                    allScores = [allScores; scores];
                end
            end

            accVec(rr) = sum(diag(CMrep))/max(1,sum(CMrep(:)));
            recall = diag(CMrep) ./ max(1,sum(CMrep,2));
            prec = diag(CMrep) ./ max(1,sum(CMrep,1)');
            f1 = 2*(prec.*recall) ./ max(1e-12,prec+recall);
            support = sum(CMrep,2);
            wClass = support ./ max(1,sum(support));
            balVec(rr) = mean(recall,'omitnan');
            wtAccVec(rr) = sum(wClass .* recall,'omitnan');
            f1Vec(rr) = mean(f1,'omitnan');
            wtF1Vec(rr) = sum(wClass .* f1,'omitnan');
            recallMat(:,rr) = recall;
            CMsum = CMsum + CMrep;
            s2Vec(rr) = mean(foldS2);
            lowOccVec(rr) = mean(foldLowOcc);
            condVec(rr) = median(foldCond);
            dimVec(rr) = median(foldDim);
            memVec(rr) = median(foldMem);
            rankMeanVec(rr) = mean(foldRankMean);
            wallVec(rr) = toc(tRep);
            wallMsVec(rr) = 1000*wallVec(rr)/max(1,N);
            predMsVec(rr) = mean(foldPredMs,'omitnan');

            repeatCM(:,:,rr) = CMrep;
            if doFull
                repeatTrue{rr} = trueRep;
                repeatPred{rr} = predRep;
                repeatScores{rr} = scoreRep;
            end
        end

        CMmean = CMsum / Rrepeat;
        recallMean = mean(recallMat,2,'omitnan');
        precMean = diag(CMmean) ./ max(1,sum(CMmean,1)');
        F1class = 2*(precMean.*recallMean) ./ max(1e-12,precMean+recallMean);

        res = struct();
        res.Acc = mean(accVec);
        res.BalAcc = mean(balVec);
        res.WeightedAcc = mean(wtAccVec);
        res.MacroF1 = mean(f1Vec);
        res.WeightedF1 = mean(wtF1Vec);
        res.S2 = mean(s2Vec);
        res.LowOccFrac = mean(lowOccVec);
        res.CondMed = median(condVec);
        res.FeatDimMed = median(dimVec);
        res.MemMiBPerSpec = median(memVec);
        res.RankMean = mean(rankMeanVec);
        res.WallSec = mean(wallVec);
        res.WallMsPerSpec = mean(wallMsVec);
        res.PredictMsPerSpec = mean(predMsVec,'omitnan');
        res.CMmean = CMmean;
        res.RecallPerClass = recallMean;
        res.PrecisionPerClass = precMean;
        res.F1PerClass = F1class;
        res.cfg = cfgEval;
        res.Score = compositeScore(res);

        repeatScoreVec = zeros(Rrepeat,1);
        for rr = 1:Rrepeat
            repeatScoreVec(rr) = compositeScoreFields(accVec(rr), balVec(rr), f1Vec(rr), s2Vec(rr), lowOccVec(rr), ...
                condVec(rr), dimVec(rr), memVec(rr), wallVec(rr), cfgEval.R);
        end

        res.RepeatMetrics = table((1:Rrepeat)', accVec, balVec, wtAccVec, f1Vec, wtF1Vec, s2Vec, lowOccVec, condVec, ...
            dimVec, memVec, wallVec, wallMsVec, predMsVec, rankMeanVec, repeatScoreVec, ...
            'VariableNames', {'Repeat','Acc','BalAcc','WeightedAcc','MacroF1','WeightedF1','S2','LowOccFrac','CondMed', ...
            'FeatDimMed','MemMiBPerSpec','WallSec','WallMsPerSpec','PredictMsPerSpec','RankMean','Score'});
        res.RepeatCM = repeatCM;

        [~,ordBest] = sortrows([-accVec, -f1Vec, -balVec, memVec, wallVec]);
        bestRep = ordBest(1);
        res.BestRepeatIndex = bestRep;
        res.CMBest = repeatCM(:,:,bestRep);

        if doFull
            res.AllTrue = allTrue;
            res.AllPred = allPred;
            res.AllScores = allScores;
            res.RepeatTrue = repeatTrue;
            res.RepeatPred = repeatPred;
            res.RepeatScores = repeatScores;

            [fprGrid, tprGrid, aucPerClass, microAUC, macroAUC, microTPR, macroTPR] = makeROC(allTrue, allScores, C, app.cfg.step4.numROC);
            res.ROC_FPR = fprGrid;
            res.ROC_TPR = tprGrid;
            res.AUCPerClass = aucPerClass;
            res.MicroAUC = microAUC;
            res.MacroAUC = macroAUC;
            res.ROC_MicroTPR = microTPR;
            res.ROC_MacroTPR = macroTPR;

            [bfpr, btpr, bauc, bmicro, bmacro, bmicroTPR, bmacroTPR] = makeROC(repeatTrue{bestRep}, repeatScores{bestRep}, C, app.cfg.step4.numROC);
            res.ROCbest_FPR = bfpr;
            res.ROCbest_TPR = btpr;
            res.AUCbest_PerClass = bauc;
            res.MicroAUC_Best = bmicro;
            res.MacroAUC_Best = bmacro;
            res.ROCbest_MicroTPR = bmicroTPR;
            res.ROCbest_MacroTPR = bmacroTPR;
        end
    end

    function score = compositeScore(res)
        accTerm = 100*res.MacroF1 + 20*res.BalAcc + 5*res.Acc;
        stabilityPenalty = 20*res.LowOccFrac + 2*max(0,log10(max(1,res.CondMed))) + 5*uniformPenalty(res.S2, res.cfg.R);
        speedPenalty = 0.03*res.WallSec + 0.005*res.FeatDimMed + 0.3*res.MemMiBPerSpec;
        score = accTerm - stabilityPenalty - speedPenalty;
    end

    function score = compositeScoreFields(Acc, BalAcc, MacroF1, S2, LowOccFrac, CondMed, FeatDimMed, MemMiBPerSpec, WallSec, R)
        accTerm = 100*MacroF1 + 20*BalAcc + 5*Acc;
        stabilityPenalty = 20*LowOccFrac + 2*max(0,log10(max(1,CondMed))) + 5*uniformPenalty(S2, R);
        speedPenalty = 0.03*WallSec + 0.005*FeatDimMed + 0.3*MemMiBPerSpec;
        score = accTerm - stabilityPenalty - speedPenalty;
    end

    function [selNames, selRows, selRepeats] = selectStep4Candidates(T3)
        if isempty(T3)
            error('Step 3 results table is empty.');
        end
        Macc = [-T3.Acc, -T3.MacroF1, -T3.Score, T3.MemMiBPerSpec, T3.WallSec];
        [~,ordA] = sortrows(Macc);
        Mscore = [-T3.Score, -T3.Acc, -T3.MacroF1, T3.MemMiBPerSpec, T3.WallSec];
        [~,ordS] = sortrows(Mscore);
        Mmem = [T3.MemMiBPerSpec, -T3.Score, -T3.Acc, -T3.MacroF1, T3.WallSec];
        [~,ordM] = sortrows(Mmem);

        selNames = {'BestAccuracy','BestScore','BestMemory'};
        selRows = [ordA(1), ordS(1), ordM(1)];
        selRepeats = [app.cfg.step4.repeatsBestAccuracy, app.cfg.step4.repeatsBestScore, app.cfg.step4.repeatsBestMemory];
    end

    function cfgEval = cfgFromStep3Row(baseCfg, row)
        cfgEval = baseCfg;
        cfgEval.mLand = row.mLand(1);
        cfgEval.rankMode = app.cfg.step3.rankMode;
        cfgEval.Dloc = max(1, min(max(app.cfg.step3.DlocList), cfgEval.mLand));
        cfgEval.rho = row.rho(1);
        cfgEval.ridge = row.ridge(1);
        cfgEval.sigmaMode = app.cfg.step3.sigmaMode;
        cfgEval.sigmaScale = row.sigmaScale(1);
        cfgEval.C = row.C(1);
        cfgEval.kmeansReplicates = app.cfg.step2.kmeansReplicates;
        cfgEval.topKGate = app.cfg.step2.topKGate;
    end

    function p = uniformPenalty(S2, R)
        p = max(0, (1.15*(1/R) - S2));
    end

    function tf = isBetter(a,b)
        if ~isfield(b,'Score') || isempty(b.Score) || ~isfinite(b.Score)
            tf = true;
            return;
        end
        va = [a.MacroF1, a.BalAcc, -a.LowOccFrac, -log10(max(1,a.CondMed)), -a.WallSec, -a.FeatDimMed];
        vb = [b.MacroF1, b.BalAcc, -b.LowOccFrac, -log10(max(1,b.CondMed)), -b.WallSec, -b.FeatDimMed];
        if a.MacroF1 > b.MacroF1 + 1e-10
            tf = true; return;
        elseif b.MacroF1 > a.MacroF1 + 1e-10
            tf = false; return;
        end
        if a.BalAcc > b.BalAcc + 1e-10
            tf = true; return;
        elseif b.BalAcc > a.BalAcc + 1e-10
            tf = false; return;
        end
        if a.LowOccFrac < b.LowOccFrac - 1e-10
            tf = true; return;
        elseif b.LowOccFrac < a.LowOccFrac - 1e-10
            tf = false; return;
        end
        if a.CondMed < b.CondMed - 1e-10
            tf = true; return;
        elseif b.CondMed < a.CondMed - 1e-10
            tf = false; return;
        end
        if a.WallSec < b.WallSec - 1e-10
            tf = true; return;
        elseif b.WallSec < a.WallSec - 1e-10
            tf = false; return;
        end
        tf = a.Score > b.Score;
    end

    function [Phi_tr, Phi_te, diagFold, aux] = buildRAVEN(Str, Ste, cfgEval)
        ntr = size(Str,1);
        kEff = size(Str,2);
        D0 = min(cfgEval.D0, kEff);
        Ztr = Str(:,1:D0);
        Zte = Ste(:,1:D0);

        [idxC, centers] = kmeans(Ztr, cfgEval.R, 'Replicates', cfgEval.kmeansReplicates, 'MaxIter', 200, 'Display', 'off');
        d0 = sqrt(sum((Ztr - centers(idxC,:)).^2,2));
        tau = cfgEval.tauScale * median(d0);
        if ~(isfinite(tau) && tau > 0), tau = 1.0; end

        Gtr = softGating(Ztr, centers, tau, cfgEval.topKGate);
        Gte = softGating(Zte, centers, tau, cfgEval.topKGate);
        S2 = mean(sum(Gtr.^2,2));
        occ = sum(Gtr,1);
        lowOccFrac = mean(occ < 5*cfgEval.mLand);

        sigmaBase = autoSigma(Str);
        sigmaFold = sigmaBase * cfgEval.sigmaScale;
        if ~(isfinite(sigmaFold) && sigmaFold > 0), sigmaFold = 1.0; end
        gamma = 1/(2*sigmaFold^2);

        Rloc = cfgEval.R;
        Dm_eff = zeros(Rloc,1);
        Lcell = cell(Rloc,1);
        Ucell = cell(Rloc,1);
        lamCell = cell(Rloc,1);
        condList = nan(Rloc,1);
        rankList = nan(Rloc,1);

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
            Lcell{mm} = L;
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
            lam = lam(keep);
            V = V(:,keep);
            if strcmpi(cfgEval.rankMode,'adaptive')
                cs = cumsum(lam) / max(eps,sum(lam));
                Duse = find(cs >= cfgEval.rho, 1, 'first');
                if isempty(Duse), Duse = numel(lam); end
            else
                Duse = min(cfgEval.Dloc, numel(lam));
            end
            Duse = max(1, min(Duse, numel(lam)));
            lam = lam(1:Duse);
            V = V(:,1:Duse);
            Dm_eff(mm) = Duse;
            Ucell{mm} = V;
            lamCell{mm} = lam;
            condList(mm) = max(lam)/max(min(lam),1e-12);
            rankList(mm) = Duse;
        end

        Dtot = sum(Dm_eff);
        Phi_tr = zeros(size(Str,1), Dtot);
        Phi_te = zeros(size(Ste,1), Dtot);
        c0 = 1;
        for mm = 1:Rloc
            Dm = Dm_eff(mm);
            L = Lcell{mm};
            U = Ucell{mm};
            lam = lamCell{mm}(:)';
            Ktr = rbfGram(Str,L,gamma);
            Kte = rbfGram(Ste,L,gamma);
            tmpTr = (Ktr*U) .* (1./sqrt(max(lam,1e-12)));
            tmpTe = (Kte*U) .* (1./sqrt(max(lam,1e-12)));
            tmpTr = tmpTr .* Gtr(:,mm);
            tmpTe = tmpTe .* Gte(:,mm);
            Phi_tr(:,c0:c0+Dm-1) = tmpTr;
            Phi_te(:,c0:c0+Dm-1) = tmpTe;
            c0 = c0 + Dm;
        end

        diagFold = struct();
        diagFold.S2 = S2;
        diagFold.LowOccFrac = lowOccFrac;
        diagFold.CondMedian = median(condList,'omitnan');
        diagFold.RankMean = mean(rankList,'omitnan');
        diagFold.Occ = occ;
        aux = struct('tau',tau,'sigma',sigmaFold,'occ',occ,'condList',condList,'rankList',rankList);
    end

    function G = softGating(Z, centers, tau, topK)
        A2 = sum(Z.^2,2);
        B2 = sum(centers.^2,2)';
        D2 = bsxfun(@plus, A2, B2) - 2*(Z*centers');
        D2 = max(D2,0);
        logits = -D2/(2*tau^2);
        logits = logits - max(logits,[],2);
        G = exp(logits);
        G = G ./ max(1e-12,sum(G,2));
        if topK > 0 && topK < size(G,2)
            [~,ord] = sort(G,2,'descend');
            mask = false(size(G));
            for i = 1:size(G,1)
                mask(i,ord(i,1:topK)) = true;
            end
            G(~mask) = 0;
            G = G ./ max(1e-12,sum(G,2));
        end
    end

    function sigma = autoSigma(Str)
        n = size(Str,1);
        nsub = min(600,n);
        idx = randperm(n,nsub);
        S = Str(idx,:);
        npairs = min(3000, nsub*(nsub-1)/2);
        ii = randi(nsub,npairs,1);
        jj = randi(nsub,npairs,1);
        jj(jj==ii) = mod(jj(jj==ii), nsub)+1;
        d = sqrt(sum((S(ii,:)-S(jj,:)).^2,2));
        sigma = median(d) / sqrt(2);
        if ~(isfinite(sigma) && sigma > 0), sigma = 1.0; end
    end

    function idx = weightedSampleNoReplace(w, m)
        w = w(:);
        w(~isfinite(w) | w<0) = 0;
        if sum(w) <= 0
            if numel(w) == 0
                idx = [];
            else
                idx = randperm(numel(w), min(m,numel(w)))';
            end
            return;
        end
        m = min(m, numel(w));
        ww = w / max(sum(w),eps);
        keys = rand(numel(ww),1) .^ (1./max(ww,eps));
        [~,ord] = sort(keys,'descend');
        idx = ord(1:m);
    end

    function K = rbfGram(A,B,gamma)
        A2 = sum(A.^2,2);
        B2 = sum(B.^2,2)';
        D2 = bsxfun(@plus,A2,B2) - 2*(A*B');
        D2 = max(D2,0);
        K = exp(-gamma*D2);
    end

    function foldIdx = makeStratifiedFolds(y,K)
        foldIdx = zeros(numel(y),1);
        classes = unique(y(:))';
        for c = classes
            idx = find(y==c);
            idx = idx(randperm(numel(idx)));
            edges = round(linspace(0,numel(idx),K+1));
            for f = 1:K
                if edges(f) < edges(f+1)
                    foldIdx(idx(edges(f)+1:edges(f+1))) = f;
                end
            end
        end
    end

    function [fprGrid, tprGrid, aucPerClass, microAUC, macroAUC, microTPR, macroTPR] = makeROC(Y, Scores, C, numROC)
        if isempty(Scores) || size(Scores,2) ~= C
            fprGrid = linspace(0,1,numROC)';
            tprGrid = zeros(numROC,C);
            aucPerClass = 0.5*ones(C,1);
            microAUC = 0.5;
            macroAUC = 0.5;
            microTPR = fprGrid;
            macroTPR = fprGrid;
            return;
        end
        fprGrid = linspace(0,1,numROC)';
        tprGrid = zeros(numROC,C);
        aucPerClass = zeros(C,1);
        for c = 1:C
            ybin = (Y==c);
            sc = Scores(:,c);
            [scs, idx] = sort(sc,'descend');
            y = ybin(idx);
            P = sum(y); Nn = numel(y)-P;
            if P==0 || Nn==0
                fpr = [0;1]; tpr = [0;1]; auc = 0.5;
            else
                tp = cumsum(y); fp = cumsum(~y);
                tpr = [0; tp./P; 1];
                fpr = [0; fp./Nn; 1];
                [fpr, iu, ic] = unique(fpr,'stable'); tpr = accumarray(ic, tpr, [], @max); tpr = cummax(tpr);
                auc = trapz(fpr,tpr);
            end
            tprGrid(:,c) = interp1(fpr,tpr,fprGrid,'linear','extrap');
            tprGrid(:,c) = min(max(tprGrid(:,c),0),1);
            aucPerClass(c) = auc;
        end
        macroAUC = mean(aucPerClass);
        Ymicro = false(numel(Y)*C,1);
        Smicro = zeros(numel(Y)*C,1);
        ptr = 1;
        for c = 1:C
            ybin = (Y==c);
            m = numel(ybin);
            Ymicro(ptr:ptr+m-1) = ybin;
            Smicro(ptr:ptr+m-1) = Scores(:,c);
            ptr = ptr + m;
        end
        [~, idx] = sort(Smicro,'descend');
        y = Ymicro(idx);
        P = sum(y); Nn = numel(y)-P;
        if P==0 || Nn==0
            microAUC = 0.5;
            microTPR = fprGrid;
        else
            tp = cumsum(y); fp = cumsum(~y);
            tpr = [0; tp./P; 1];
            fpr = [0; fp./Nn; 1];
            [fpr, iu, ic] = unique(fpr,'stable'); tpr = accumarray(ic, tpr, [], @max); tpr = cummax(tpr);
            microAUC = trapz(fpr,tpr);
            microTPR = interp1(fpr,tpr,fprGrid,'linear','extrap');
            microTPR = min(max(microTPR,0),1);
        end
        macroTPR = mean(tprGrid,2);
        macroTPR = min(max(macroTPR,0),1);
    end

    function makeStep1Plot(T)
        fig = figure('Visible','off','Color','w','Name','Step1');
        yyaxis left; plot(T.kPC,100*T.MacroF1,'-o','LineWidth',1.5); ylabel('MacroF1 (%)');
        yyaxis right; plot(T.kPC,T.WallSec,'-s','LineWidth',1.5); ylabel('Wall time (s)');
        xlabel('kPC'); grid on; title('Step 1 | Embedding search');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP1_kPC.png'));
    end

    function makeStep2Plot(T)
        fig = figure('Visible','off','Color','w','Name','Step2');
        scatter(T.mLand, 100*T.Acc, 90, T.rTeach, 'filled'); colorbar; grid on;
        xlabel('mLand'); ylabel('Teacher accuracy (%)');
        title('Step 2 | Teacher search');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP2_teacher_search.png'));
    end

    function makeStep3Plot(T)
        fig = figure('Visible','off','Color','w','Name','Step3');
        scatter(T.FeatDimMed,100*T.MacroF1,80,T.WallSec,'filled'); colorbar; grid on;
        xlabel('Median feature dimension'); ylabel('MacroF1 (%)'); title('Step 3 | Accuracy vs feature dimension');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP3_dim_vs_F1.png'));
    end

    function buildStep3BestTeacherComparison(T3, teacherShort)
        if isempty(T3) || isempty(teacherShort)
            return;
        end
        bestTeacherID = 1;
        bestTeacherMask = (T3.TeacherID == bestTeacherID);
        if ~any(bestTeacherMask)
            return;
        end
        trow = teacherShort(1,:);
        teacherAcc = getScalarNumericFromTableVar(trow, 'Acc');
        teacherWall = getScalarNumericFromTableVar(trow, 'WallMsPerSpec');
        teacherMem = getScalarNumericFromTableVar(trow, 'MemMiBPerSpec');
        teacherPredict = getScalarNumericFromTableVar(trow, 'PredictMsPerSpec');
        teacherScore = getScalarNumericFromTableVar(trow, 'Score');
        teacherMacroF1 = getScalarNumericFromTableVar(trow, 'MacroF1');
        teacherWeightedF1 = getScalarNumericFromTableVar(trow, 'WeightedF1');
        teacherSummary = sprintf('T%02d[k=%d,m=%d,r=%d,s=%.3g,C=%.3g]', bestTeacherID, double(trow.kPC), double(trow.mLand), double(trow.rTeach), double(trow.sigmaScale), double(trow.BoxC_T));

        Tbest = T3(bestTeacherMask,:);
        nBest = height(Tbest);
        TeacherSummary = repmat(string(teacherSummary), nBest, 1);
        TeacherAcc = repmat(teacherAcc, nBest, 1);
        TeacherMacroF1 = repmat(teacherMacroF1, nBest, 1);
        TeacherWeightedF1 = repmat(teacherWeightedF1, nBest, 1);
        TeacherWallMsPerSpec = repmat(teacherWall, nBest, 1);
        TeacherMemMiBPerSpec = repmat(teacherMem, nBest, 1);
        TeacherPredictMsPerSpec = repmat(teacherPredict, nBest, 1);
        TeacherScore = repmat(teacherScore, nBest, 1);
        StudentPredictMsPerSpec = Tbest.PredictMsPerSpec;
        StudentMemMiBPerSpec = Tbest.MemMiBPerSpec;
        StudentVsTeacherAccRatio = safeDivideVector(Tbest.Acc, teacherAcc);
        StudentVsTeacherTimeRatio = safeDivideVector(StudentPredictMsPerSpec, teacherPredict);
        StudentVsTeacherMemoryRatio = safeDivideVector(StudentMemMiBPerSpec, teacherMem);
        AccuracyDeltaPctPts = 100*(Tbest.Acc - teacherAcc);
        TimeReductionPct = 100*(1 - StudentVsTeacherTimeRatio);
        MemoryReductionPct = 100*(1 - StudentVsTeacherMemoryRatio);
        FasterThanTeacher = StudentVsTeacherTimeRatio < 1;
        LowerMemoryThanTeacher = StudentVsTeacherMemoryRatio < 1;
        Tcompare = table(Tbest.CandidateID, TeacherSummary, TeacherAcc, Tbest.Acc, StudentVsTeacherAccRatio, AccuracyDeltaPctPts, ...
            TeacherMacroF1, Tbest.MacroF1, TeacherWeightedF1, Tbest.WeightedF1, TeacherWallMsPerSpec, Tbest.WallMsPerSpec, ...
            TeacherPredictMsPerSpec, StudentPredictMsPerSpec, StudentVsTeacherTimeRatio, TimeReductionPct, ...
            TeacherMemMiBPerSpec, StudentMemMiBPerSpec, StudentVsTeacherMemoryRatio, MemoryReductionPct, ...
            TeacherScore, Tbest.Score, Tbest.pHidden, Tbest.lamRidge, Tbest.alpha, Tbest.temp, Tbest.skipScale, Tbest.ensemble, FasterThanTeacher, LowerMemoryThanTeacher, ...
            'VariableNames', {'CandidateID','TeacherSummary','TeacherAcc','StudentAcc','StudentPerTeacherAccRatio','AccuracyDeltaPctPts', ...
            'TeacherMacroF1','StudentMacroF1','TeacherWeightedF1','StudentWeightedF1','TeacherWallMsPerSpec_Search','StudentWallMsPerSpec_Search', ...
            'TeacherPredictMsPerSpec','StudentPredictMsPerSpec','StudentPerTeacherTimeRatio','TimeReductionPct', ...
            'TeacherMemMiBPerSpec','StudentMemMiBPerSpec','StudentPerTeacherMemoryRatio','MemoryReductionPct', ...
            'TeacherScore','StudentScore','pHidden','lamRidge','alpha','temp','skipScale','ensemble','FasterThanTeacher','LowerMemoryThanTeacher'});
        Tcompare = sortrows(Tcompare, {'StudentPerTeacherAccRatio','StudentPerTeacherTimeRatio','StudentPerTeacherMemoryRatio','StudentScore'}, {'descend','ascend','ascend','descend'});
        app.state.results.step3BestTeacherComparison = Tcompare;
        save(fullfile(app.state.outdir,'STEP3_LOCALAPPROX','STEP3_BEST_TEACHER_COMPARISON.mat'),'Tcompare','-v7.3');
        compareXlsx = fullfile(app.state.outdir,'STEP3_LOCALAPPROX','STEP3_BEST_TEACHER_COMPARISON.xlsx');
        tryWriteTable(Tcompare, compareXlsx, 'BestTeacherCompare');
        try
            writetable(table(string(teacherSummary), teacherAcc, teacherMacroF1, teacherWeightedF1, teacherWall, teacherMem, teacherPredict, teacherScore, ...
                'VariableNames', {'TeacherSummary','TeacherAcc','TeacherMacroF1','TeacherWeightedF1','TeacherWallMsPerSpec','TeacherMemMiBPerSpec','TeacherPredictMsPerSpec','TeacherScore'}), compareXlsx, 'Sheet', 'TeacherBaseline');
            writetable(Tcompare, fullfile(app.state.outdir,'STEP3_LOCALAPPROX','STEP3_RESULTS.xlsx'), 'Sheet', 'BestTeacherCompare');
        catch
        end

        fig = figure('Visible','off','Color','w','Name','Step3BestTeacher_AccVsTime');
        scatter(Tcompare.StudentPerTeacherAccRatio, Tcompare.StudentPerTeacherTimeRatio, 80, Tcompare.StudentPerTeacherMemoryRatio, 'filled');
        grid on; colorbar;
        hold on; yline(1,'--');
        xlabel('Student accuracy / teacher accuracy'); ylabel('Student predict time / teacher predict time');
        xline(1,'--');
        title('Step 3 | Best teacher | Accuracy ratio vs time ratio');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP3_bestTeacher_accuracy_vs_time.png'));

        fig = figure('Visible','off','Color','w','Name','Step3BestTeacher_AccVsMemory');
        scatter(Tcompare.StudentPerTeacherAccRatio, Tcompare.StudentPerTeacherMemoryRatio, 80, Tcompare.StudentPerTeacherTimeRatio, 'filled');
        grid on; colorbar;
        hold on; yline(1,'--');
        xlabel('Student accuracy / teacher accuracy'); ylabel('Student memory / teacher memory');
        xline(1,'--');
        title('Step 3 | Best teacher | Accuracy ratio vs memory ratio');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP3_bestTeacher_accuracy_vs_memory.png'));
    end

    function out = safeDivideVector(num, den)
        out = num ./ max(1e-12, den);
        out(~isfinite(out)) = NaN;
    end

    function makeSelectionPlots(res, outSub)
        groups = app.state.data.groupNames(:);
        C = numel(groups);

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_AccuracyOverRepeats']);
        plot(res.RepeatMetrics.Repeat, 100*res.RepeatMetrics.Acc, '-o','LineWidth',1.5); grid on;
        xlabel('Repeat'); ylabel('Accuracy (%)');
        title(sprintf('%s | Accuracy over repeats', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Accuracy_over_repeats.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_TimePerSpec']);
        plot(res.RepeatMetrics.Repeat, res.RepeatMetrics.WallMsPerSpec, '-o','LineWidth',1.5); grid on;
        xlabel('Repeat'); ylabel('Wall ms / spectrum');
        title(sprintf('%s | Wall time per spectrum', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Time_msPerSpec.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_MemoryPerSpec']);
        plot(res.RepeatMetrics.Repeat, res.RepeatMetrics.MemMiBPerSpec, '-o','LineWidth',1.5); grid on;
        xlabel('Repeat'); ylabel('MiB / spectrum');
        title(sprintf('%s | Memory per spectrum', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Memory_MiBPerSpec.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_CM_BEST_counts']);
        imagesc(res.CMBest); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True');
        title(sprintf('%s | Confusion BEST run (counts)', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Confusion_BEST_counts.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_CM_BEST_rowpct']);
        rowpctBest = 100*(res.CMBest ./ max(1,sum(res.CMBest,2)));
        imagesc(rowpctBest,[0 100]); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True');
        title(sprintf('%s | Confusion BEST run (row %%)', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Confusion_BEST_rowpct.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_CM_AVG_counts']);
        imagesc(res.CMmean); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True');
        title(sprintf('%s | Confusion AVG (counts)', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Confusion_AVG_counts.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_CM_AVG_rowpct']);
        rowpctAvg = 100*(res.CMmean ./ max(1,sum(res.CMmean,2)));
        imagesc(rowpctAvg,[0 100]); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True');
        title(sprintf('%s | Confusion AVG (row %%)', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Confusion_AVG_rowpct.png'));

        if app.cfg.step4.makeROC && isfield(res,'ROC_TPR')
            fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_ROC_AVG']);
            hold on; grid on; axis([0 1 0 1]);
            for c = 1:C
                plot(res.ROC_FPR,res.ROC_TPR(:,c),'LineWidth',1.2);
            end
            plot([0 1],[0 1],'k:');
            xlabel('FPR'); ylabel('TPR');
            title(sprintf('%s | ROC AVG | MacroAUC=%.3f | MicroAUC=%.3f', res.SelectionName, res.MacroAUC, res.MicroAUC));
            legend(groups,'Location','SouthEast');
            saveFig(fig, fullfile(outSub,'ROC_AVG.png'));

            fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_ROC_BEST']);
            hold on; grid on; axis([0 1 0 1]);
            for c = 1:C
                plot(res.ROCbest_FPR,res.ROCbest_TPR(:,c),'LineWidth',1.2);
            end
            plot([0 1],[0 1],'k:');
            xlabel('FPR'); ylabel('TPR');
            title(sprintf('%s | ROC BEST run | MacroAUC=%.3f | MicroAUC=%.3f', res.SelectionName, res.MacroAUC_Best, res.MicroAUC_Best));
            legend(groups,'Location','SouthEast');
            saveFig(fig, fullfile(outSub,'ROC_BEST.png'));
        end
    end

    function exportSelectionTables(res, outSub)
        groups = app.state.data.groupNames(:);
        outxlsx = fullfile(outSub, [res.SelectionName '_Report.xlsx']);

        Tsetting = struct2table(flattenStruct(res.cfg));
        Tsetting.Selection = {res.SelectionName};
        Tsetting.TotalWallSec = res.WallSec;

        Tmacro = table(res.Acc, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, res.Score, res.S2, res.LowOccFrac, res.CondMed, ...
            res.FeatDimMed, res.MemMiBPerSpec, res.WallSec, res.WallMsPerSpec, res.PredictMsPerSpec, ...
            'VariableNames', {'MeanAcc','MeanBalAcc','MeanWeightedAcc','MeanMacroF1','MeanWeightedF1','MeanScore','MeanS2','MeanLowOccFrac', ...
            'MeanCondMed','MeanFeatDimMed','MeanMemMiBPerSpec','MeanWallSec','MeanWallMsPerSpec','MeanPredictMsPerSpec'});

        AUC = nan(numel(groups),1);
        if isfield(res,'AUCPerClass'), AUC = res.AUCPerClass; end
        Tper = table(groups, res.RecallPerClass, res.PrecisionPerClass, res.F1PerClass, AUC, ...
            'VariableNames', {'Class','Recall','Precision','F1','AUC'});

        try
            writetable(res.RepeatMetrics, outxlsx, 'Sheet','Runs');
            writetable(Tsetting, outxlsx, 'Sheet','Setting');
            writetable(Tmacro, outxlsx, 'Sheet','Macro');
            writetable(Tper, outxlsx, 'Sheet','PerClass');

            rowpctBest = 100*(res.CMBest ./ max(1,sum(res.CMBest,2)));
            rowpctAvg = 100*(res.CMmean ./ max(1,sum(res.CMmean,2)));
            writecell([{'True_Pred'}, groups'; groups, num2cell(res.CMBest)], outxlsx, 'Sheet','CM_Counts_BEST');
            writecell([{'True_Pred'}, groups'; groups, num2cell(rowpctBest)], outxlsx, 'Sheet','CM_RowPct_BEST');
            writecell([{'True_Pred'}, groups'; groups, num2cell(res.CMmean)], outxlsx, 'Sheet','CM_Counts_AVG');
            writecell([{'True_Pred'}, groups'; groups, num2cell(rowpctAvg)], outxlsx, 'Sheet','CM_RowPct_AVG');

            if isfield(res,'AUCPerClass')
                Tauc = table(groups, res.AUCPerClass, res.AUCbest_PerClass, 'VariableNames', {'Class','AUC_AVG','AUC_BEST'});
                Tauc2 = table("MacroAUC", res.MacroAUC, res.MacroAUC_Best, 'VariableNames', {'Class','AUC_AVG','AUC_BEST'});
                Tauc3 = table("MicroAUC", res.MicroAUC, res.MicroAUC_Best, 'VariableNames', {'Class','AUC_AVG','AUC_BEST'});
                writetable([Tauc; Tauc2; Tauc3], outxlsx, 'Sheet','ROC_AUC');

                TrocAvg = array2table([res.ROC_FPR, res.ROC_TPR], 'VariableNames', [{'FPR'}, strcat('TPR_',matlab.lang.makeValidName(groups'))]);
                writetable(TrocAvg, outxlsx, 'Sheet','ROC_Grid_AVG');

                TrocBest = array2table([res.ROCbest_FPR, res.ROCbest_TPR], 'VariableNames', [{'FPR'}, strcat('TPR_',matlab.lang.makeValidName(groups'))]);
                writetable(TrocBest, outxlsx, 'Sheet','ROC_Grid_BEST');
            end
        catch MEw
            logmsg(['Excel export warning: ' MEw.message]);
        end

        save(fullfile(outSub,'FINAL_RESULTS_SUMMARY.mat'),'res','-v7.3');
    end

    function exportStep4SelectionSummary(Tsel, finalSelections)
        outxlsx = fullfile(app.state.outdir,'STEP4_FINAL','STEP4_SELECTION_SUMMARY.xlsx');
        outtxt = fullfile(app.state.outdir,'STEP4_FINAL','STEP4_FINALISTS.txt');
        try
            writetable(Tsel, outxlsx, 'Sheet','SelectionSummary');
            fn = fieldnames(finalSelections);
            for i = 1:numel(fn)
                res = finalSelections.(fn{i});
                Tcfg = struct2table(flattenStruct(res.cfg));
                writetable(Tcfg, outxlsx, 'Sheet', ['Config_' fn{i}]);
            end
        catch MEw
            logmsg(['Step4 summary export warning: ' MEw.message]);
        end
        fid = fopen(outtxt,'w');
        if fid > 0
            fprintf(fid, 'Step 4 finalists\n');
            fprintf(fid, 'Winner policy: %s\n', char(resolveStep4WinnerPolicy()));
            fprintf(fid, 'Top finalists per bucket: %d\n\n', max(1, round(app.cfg.step4.topFinalistsPerBucket)));
            for i = 1:height(Tsel)
                fprintf(fid, '%02d. %s | %s | Candidate=%s | Acc=%.2f%% | WeightedAcc=%.2f%% | MacroF1=%.2f%% | WeightedF1=%.2f%% | Score=%.4f | Time=%.4f ms/spec | Mem=%.4g MiB/spec\n', ...
                    i, char(string(Tsel.Selection(i))), char(string(Tsel.SourceBucket(i))), char(string(Tsel.CandidateID(i))), ...
                    100*Tsel.StudentAcc(i), 100*Tsel.WeightedAcc(i), 100*Tsel.MacroF1(i), 100*Tsel.WeightedF1(i), Tsel.Score(i), Tsel.WallMsPerSpec(i), Tsel.MemMiBPerSpec(i));
            end
            fclose(fid);
        end
    end

    function winnerPolicy = resolveStep4WinnerPolicy()
        winnerPolicy = "bestscore";
        if isfield(app.cfg.step4,'winnerPolicy') && ~isempty(app.cfg.step4.winnerPolicy)
            winnerPolicy = string(app.cfg.step4.winnerPolicy);
        elseif isfield(app.cfg.step4,'finalSelectionPolicy') && ~isempty(app.cfg.step4.finalSelectionPolicy)
            winnerPolicy = string(app.cfg.step4.finalSelectionPolicy);
        end
        winnerPolicy = lower(winnerPolicy);
    end

    function exportStep4WinnerText(finalKey, res, finalWinnerRecord, Tsel)
        outtxt = fullfile(app.state.outdir,'STEP4_FINAL','STEP4_WINNER.txt');
        fid = fopen(outtxt,'w');
        if fid <= 0
            return;
        end
        fprintf(fid, 'Step 4 winner\n');
        fprintf(fid, 'Selection: %s\n', finalKey);
        fprintf(fid, 'Winner policy: %s\n', char(resolveStep4WinnerPolicy()));
        fprintf(fid, 'CandidateID: %s\n', res.CandidateID);
        fprintf(fid, 'SourceBucket: %s\n', finalWinnerRecord.SourceBucket);
        fprintf(fid, 'RankInBucket: %d\n', finalWinnerRecord.RankInBucket);
        fprintf(fid, 'StudentAcc: %.2f%%\n', 100*res.Acc);
        fprintf(fid, 'TeacherAcc: %.2f%%\n', 100*res.AccTeacher);
        fprintf(fid, 'WeightedAcc: %.2f%%\n', 100*res.WeightedAcc);
        fprintf(fid, 'MacroF1: %.2f%%\n', 100*res.MacroF1);
        fprintf(fid, 'WeightedF1: %.2f%%\n', 100*res.WeightedF1);
        fprintf(fid, 'Score: %.4f\n', res.Score);
        fprintf(fid, 'WallMsPerSpec: %.4f\n', res.WallMsPerSpec);
        fprintf(fid, 'MemMiBPerSpec: %.4g\n', res.MemMiBPerSpec);
        fprintf(fid, 'FeatDimMed: %d\n', round(res.FeatDimMed));
        fprintf(fid, '\nFinalist order after winner sort:\n');
        for i = 1:height(Tsel)
            fprintf(fid, '%02d. %s | Candidate=%s | Score=%.4f | Acc=%.2f%% | WeightedAcc=%.2f%% | WeightedF1=%.2f%%\n', i, char(string(Tsel.Selection(i))), char(string(Tsel.CandidateID(i))), Tsel.Score(i), 100*Tsel.StudentAcc(i), 100*Tsel.WeightedAcc(i), 100*Tsel.WeightedF1(i));
        end
        fclose(fid);
    end

    function makeFinalPlots(res)
        groups = app.state.data.groupNames(:);
        C = numel(groups);
        fig1 = figure('Visible','off','Color','w','Name','Final_CM_counts');
        imagesc(res.CMmean); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True'); title('Average confusion matrix');
        saveFig(fig1, fullfile(app.state.outdir,'FIGURES','FINAL_CM_counts.png'));

        fig2 = figure('Visible','off','Color','w','Name','Final_CM_rowpct');
        rowpct = 100*(res.CMmean ./ max(1,sum(res.CMmean,2)));
        imagesc(rowpct,[0 100]); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True'); title('Average confusion matrix (row %)');
        saveFig(fig2, fullfile(app.state.outdir,'FIGURES','FINAL_CM_rowpct.png'));

        if app.cfg.step4.makeROC && isfield(res,'ROC_TPR')
            fig3 = figure('Visible','off','Color','w','Name','Final_ROC');
            hold on; grid on; axis([0 1 0 1]);
            for c = 1:C
                plot(res.ROC_FPR,res.ROC_TPR(:,c),'LineWidth',1.2);
            end
            if isfield(res,'ROC_MacroTPR')
                plot(res.ROC_FPR,res.ROC_MacroTPR,'k-','LineWidth',2.0);
            end
            if isfield(res,'ROC_MicroTPR')
                plot(res.ROC_FPR,res.ROC_MicroTPR,'k--','LineWidth',2.0);
            end
            plot([0 1],[0 1],'k:');
            xlabel('FPR'); ylabel('TPR');
            title(sprintf('ROC | MacroAUC=%.3f | MicroAUC=%.3f',res.MacroAUC,res.MicroAUC));
            leg = groups;
            if isfield(res,'ROC_MacroTPR')
                leg = [leg; {'Macro ROC'}];
            end
            if isfield(res,'ROC_MicroTPR')
                leg = [leg; {'Micro ROC'}];
            end
            legend(leg,'Location','SouthEast');
            saveFig(fig3, fullfile(app.state.outdir,'FIGURES','FINAL_ROC.png'));

            if isfield(res,'ROC_MacroTPR')
                fig4 = figure('Visible','off','Color','w','Name','Final_ROC_Macro');
                hold on; grid on; axis([0 1 0 1]);
                plot(res.ROC_FPR,res.ROC_MacroTPR,'LineWidth',2.0);
                plot([0 1],[0 1],'k:');
                xlabel('FPR'); ylabel('TPR');
                title(sprintf('Final Macro ROC | AUC=%.3f',res.MacroAUC));
                saveFig(fig4, fullfile(app.state.outdir,'FIGURES','FINAL_ROC_MACRO.png'));
            end
            if isfield(res,'ROC_MicroTPR')
                fig5 = figure('Visible','off','Color','w','Name','Final_ROC_Micro');
                hold on; grid on; axis([0 1 0 1]);
                plot(res.ROC_FPR,res.ROC_MicroTPR,'LineWidth',2.0);
                plot([0 1],[0 1],'k:');
                xlabel('FPR'); ylabel('TPR');
                title(sprintf('Final Micro ROC | AUC=%.3f',res.MicroAUC));
                saveFig(fig5, fullfile(app.state.outdir,'FIGURES','FINAL_ROC_MICRO.png'));
            end
        end
    end

    function exportFinalTables(res)
        groups = app.state.data.groupNames(:);
        outxlsx = fullfile(app.state.outdir,'STEP4_FINAL','FINAL_RESULTS.xlsx');
        Tsum = table(res.Acc,res.BalAcc,res.MacroF1,res.S2,res.LowOccFrac,res.CondMed,res.FeatDimMed,res.MemMiBPerSpec,res.WallSec, getNumericScalar(res,'MacroAUC',NaN), getNumericScalar(res,'MicroAUC',NaN), ...
            'VariableNames',{'Acc','BalAcc','MacroF1','S2','LowOccFrac','CondMed','FeatDimMed','MemMiBPerSpec','WallSec','MacroAUC','MicroAUC'});
        Tcfg = struct2table(flattenStruct(res.cfg));
        rowpct = 100*(res.CMmean ./ max(1,sum(res.CMmean,2)));
        Tmetrics = table(groups,res.RecallPerClass,res.PrecisionPerClass,res.F1PerClass, ...
            'VariableNames',{'Class','Recall','Precision','F1'});
        try
            writetable(Tsum,outxlsx,'Sheet','Summary');
            writetable(Tcfg,outxlsx,'Sheet','Config');
            writetable(Tmetrics,outxlsx,'Sheet','PerClassMetrics');
            writecell([{'True_Pred'}, groups'; groups, num2cell(res.CMmean)], outxlsx,'Sheet','CM_Counts');
            writecell([{'True_Pred'}, groups'; groups, num2cell(rowpct)], outxlsx,'Sheet','CM_RowPct');
            if isfield(res,'AUCPerClass')
                Tauc = table(groups,res.AUCPerClass,'VariableNames',{'Class','AUC'});
                Tauc2 = table("MacroAUC",res.MacroAUC,'VariableNames',{'Class','AUC'});
                Tauc3 = table("MicroAUC",res.MicroAUC,'VariableNames',{'Class','AUC'});
                writetable([Tauc; Tauc2; Tauc3],outxlsx,'Sheet','ROC_AUC');
                Twide = array2table([res.ROC_FPR, res.ROC_TPR], 'VariableNames', [{'FPR'}, strcat('TPR_',matlab.lang.makeValidName(groups'))]);
                writetable(Twide,outxlsx,'Sheet','ROC_Grid');
                if isfield(res,'ROC_MacroTPR') || isfield(res,'ROC_MicroTPR')
                    macroTPR = nan(size(res.ROC_FPR));
                    microTPR = nan(size(res.ROC_FPR));
                    if isfield(res,'ROC_MacroTPR'), macroTPR = res.ROC_MacroTPR; end
                    if isfield(res,'ROC_MicroTPR'), microTPR = res.ROC_MicroTPR; end
                    TmicroMacro = table(res.ROC_FPR, macroTPR, microTPR, 'VariableNames', {'FPR','MacroTPR','MicroTPR'});
                    writetable(TmicroMacro,outxlsx,'Sheet','ROC_MicroMacro');
                end
            end
        catch MEw
            logmsg(['Excel export warning: ' MEw.message]);
        end
        save(fullfile(app.state.outdir,'STEP4_FINAL','FINAL_RESULTS_SUMMARY.mat'),'res','-v7.3');
    end

    function exportAblationSuite(Tsel, finalSelections, finalKey)
        outDir = fullfile(app.state.outdir,'ABLATION_EXPORT');
        if ~exist(outDir,'dir'), mkdir(outDir); end

        Tab = buildAblationSummaryTable(Tsel, finalSelections, finalKey);
        app.state.results.ablationSummaryTable = Tab;
        tryWriteTable(Tab, fullfile(outDir,'ABLATION_SUMMARY.xlsx'),'Summary');
        tryWriteTable(Tsel, fullfile(outDir,'ABLATION_SUMMARY.xlsx'),'Finalists');
        if isfield(app.state.results,'step2Shortlist') && ~isempty(app.state.results.step2Shortlist)
            tryWriteTable(app.state.results.step2Shortlist, fullfile(outDir,'ABLATION_SUMMARY.xlsx'),'TeacherShortlist');
        end
        if isfield(app.state.results,'step3Top') && ~isempty(app.state.results.step3Top)
            tryWriteTable(app.state.results.step3Top, fullfile(outDir,'ABLATION_SUMMARY.xlsx'),'StudentTop');
        end

        writeAblationSummaryTxt(Tab, Tsel, finalKey, fullfile(outDir,'ABLATION_SUMMARY.txt'));
        writeAblationManifest(Tab, outDir, finalKey);
        saveAblationMat(Tab, Tsel, finalSelections, finalKey, outDir);
        writeAblationPerSelectionSheets(Tsel, finalSelections, outDir);
        updateUnifiedOutputManifest(app.state.outdir, 'ablation', buildAblationManifestStruct(Tab, outDir, finalKey));
    end

    function Tab = buildAblationSummaryTable(Tsel, finalSelections, finalKey)
        Role = strings(0,1); Ablation = strings(0,1); Source = strings(0,1); CandidateID = strings(0,1);
        Acc = []; TeacherAcc = []; DeltaVsTeacher = []; RatioToTeacher = []; MacroF1 = []; WeightedF1 = [];
        Score = []; WallMsPerSpec = []; MemMiBPerSpec = []; FeatDimMed = []; SelectedAsWinner = []; Notes = strings(0,1);

        if isfield(app.state.results,'bestStep2') && ~isempty(app.state.results.bestStep2)
            s2 = app.state.results.bestStep2;
            Role(end+1,1) = "TeacherBaseline";
            Ablation(end+1,1) = "teacher_only";
            Source(end+1,1) = "Step2";
            CandidateID(end+1,1) = "STEP2_BEST";
            Acc(end+1,1) = getScalarNumericFromTableVar(s2,'Acc');
            TeacherAcc(end+1,1) = getScalarNumericFromTableVar(s2,'Acc');
            DeltaVsTeacher(end+1,1) = 0;
            RatioToTeacher(end+1,1) = 1;
            MacroF1(end+1,1) = getScalarNumericFromTableVar(s2,'MacroF1');
            WeightedF1(end+1,1) = getScalarNumericFromTableVar(s2,'WeightedF1');
            Score(end+1,1) = getScalarNumericFromTableVar(s2,'Score');
            WallMsPerSpec(end+1,1) = getScalarNumericFromTableVar(s2,'WallMsPerSpec');
            MemMiBPerSpec(end+1,1) = getScalarNumericFromTableVar(s2,'MemMiBPerSpec');
            FeatDimMed(end+1,1) = getScalarNumericFromTableVar(s2,'FeatDimMed');
            SelectedAsWinner(end+1,1) = false;
            Notes(end+1,1) = "Best teacher-only Step 2 candidate.";
        end

        roles = fieldnames(finalSelections);
        for ii = 1:numel(roles)
            role = roles{ii};
            res = finalSelections.(role);
            Role(end+1,1) = string(role);
            Ablation(end+1,1) = classifyAblationRole(role);
            Source(end+1,1) = "Step4";
            CandidateID(end+1,1) = string(ravenGetField(res,'CandidateID',role));
            Acc(end+1,1) = getStructScalar(res,'Acc',NaN);
            TeacherAcc(end+1,1) = getStructScalar(res,'AccTeacher',NaN);
            DeltaVsTeacher(end+1,1) = getStructScalar(res,'Acc',NaN) - getStructScalar(res,'AccTeacher',NaN);
            RatioToTeacher(end+1,1) = getStructScalar(res,'RatioToTeacher',NaN);
            MacroF1(end+1,1) = getStructScalar(res,'MacroF1',NaN);
            WeightedF1(end+1,1) = getStructScalar(res,'WeightedF1',NaN);
            Score(end+1,1) = getStructScalar(res,'Score',NaN);
            WallMsPerSpec(end+1,1) = getStructScalar(res,'WallMsPerSpec',NaN);
            MemMiBPerSpec(end+1,1) = getStructScalar(res,'MemMiBPerSpec',NaN);
            FeatDimMed(end+1,1) = getStructScalar(res,'FeatDimMed',NaN);
            SelectedAsWinner(end+1,1) = strcmp(role, finalKey);
            Notes(end+1,1) = describeAblationRole(role, strcmp(role, finalKey));
        end

        Tab = table(Role, Ablation, Source, CandidateID, Acc, TeacherAcc, DeltaVsTeacher, RatioToTeacher, MacroF1, WeightedF1, Score, WallMsPerSpec, MemMiBPerSpec, FeatDimMed, SelectedAsWinner, Notes);
        if ~isempty(Tab)
            Tab = sortrows(Tab, {'SelectedAsWinner','Score','Acc','MacroF1','WallMsPerSpec'}, {'descend','descend','descend','descend','ascend'});
        end
    end

    function lbl = classifyAblationRole(role)
        r = lower(string(role));
        if strcmp(r,"bestaccuracy")
            lbl = "student_accuracy_bucket";
        elseif strcmp(r,"bestscore")
            lbl = "student_score_bucket";
        elseif strcmp(r,"bestspeed")
            lbl = "student_speed_bucket";
        elseif strcmp(r,"bestmemory")
            lbl = "student_memory_bucket";
        else
            lbl = "student_other_bucket";
        end
    end

    function txt = describeAblationRole(role, isWinner)
        switch lower(string(role))
            case "bestaccuracy"
                txt = "Best Step 4 finalist ranked by student accuracy.";
            case "bestscore"
                txt = "Best Step 4 finalist ranked by composite score.";
            case "bestspeed"
                txt = "Fastest finalist above the Step 4 accuracy threshold.";
            case "bestmemory"
                txt = "Lowest-memory finalist above the Step 4 accuracy threshold.";
            otherwise
                txt = "Step 4 finalist bucket export.";
        end
        if isWinner
            txt = txt + " Selected as final winner.";
        end
    end

    function writeAblationSummaryTxt(Tab, Tsel, finalKey, txtPath)
        fid = fopen(txtPath,'w');
        if fid <= 0, return; end
        c = onCleanup(@() fclose(fid));
        fprintf(fid,'RAVEN ablation export suite\n');
        fprintf(fid,'Generated: %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
        fprintf(fid,'CodeVersion: %s\n', 'RAVEN_V1_01');
        fprintf(fid,'FinalWinner: %s\n', finalKey);
        fprintf(fid,'WinnerPolicy: %s\n', char(resolveStep4WinnerPolicy()));
        fprintf(fid,'GroupedCVRequested: %d\n', double(getNestedLogical(app.cfg, {'cv','useGroups'}, false)));
        fprintf(fid,'GroupedCVMode: %s\n', getNestedText(app.cfg, {'cv','splitMode'}, 'unknown'));
        if isfield(app.cfg.cv,'groupValidation')
            fprintf(fid,'GroupedCVStatus: %s\n', localValueToText(app.cfg.cv.groupValidation));
        end
        fprintf(fid,'\nAblation rows:\n');
        for ii = 1:height(Tab)
            fprintf(fid,'%02d. %s | Ablation=%s | Candidate=%s | Acc=%.2f%%%% | Teacher=%.2f%%%% | Delta=%.2f%%%% | MacroF1=%.2f%%%% | Score=%.4f | Time=%.4f ms/spec | Mem=%.4g MiB/spec\n', ...
                ii, char(Tab.Role(ii)), char(Tab.Ablation(ii)), char(Tab.CandidateID(ii)), 100*Tab.Acc(ii), 100*Tab.TeacherAcc(ii), 100*Tab.DeltaVsTeacher(ii), 100*Tab.MacroF1(ii), Tab.Score(ii), Tab.WallMsPerSpec(ii), Tab.MemMiBPerSpec(ii));
        end
        fprintf(fid,'\nStep4 finalist ranking:\n');
        for ii = 1:height(Tsel)
            fprintf(fid,'%02d. %s | Candidate=%s | Source=%s | Score=%.4f | Acc=%.2f%%%% | MacroF1=%.2f%%%% | Time=%.4f ms/spec | Mem=%.4g MiB/spec\n', ...
                ii, char(string(Tsel.Selection(ii))), char(string(Tsel.CandidateID(ii))), char(string(Tsel.SourceBucket(ii))), Tsel.Score(ii), 100*Tsel.StudentAcc(ii), 100*Tsel.MacroF1(ii), Tsel.WallMsPerSpec(ii), Tsel.MemMiBPerSpec(ii));
        end
    end

    function writeAblationManifest(Tab, outDir, finalKey)
        fid = fopen(fullfile(outDir,'ABLATION_MANIFEST.txt'),'w');
        if fid <= 0, return; end
        c = onCleanup(@() fclose(fid));
        fprintf(fid,'RAVEN structured ablation export\n');
        fprintf(fid,'Generated: %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
        fprintf(fid,'CodeVersion: %s\n', 'RAVEN_V1_01');
        fprintf(fid,'OutputDir: %s\n', outDir);
        fprintf(fid,'FinalWinner: %s\n', finalKey);
        fprintf(fid,'Files:\n');
        fprintf(fid,'  - ABLATION_SUMMARY.xlsx\n');
        fprintf(fid,'  - ABLATION_SUMMARY.txt\n');
        fprintf(fid,'  - ABLATION_MANIFEST.txt\n');
        fprintf(fid,'  - ABLATION_EXPORT.mat\n');
        fprintf(fid,'  - ABLATION_SELECTION_<role>.xlsx\n');
        fprintf(fid,'Rows: %d\n', height(Tab));
        if ~isempty(Tab)
            fprintf(fid,'TopRow: %s | %s | Acc=%.4f | Score=%.4f\n', char(Tab.Role(1)), char(Tab.CandidateID(1)), Tab.Acc(1), Tab.Score(1));
        end
    end

    function saveAblationMat(Tab, Tsel, finalSelections, finalKey, outDir)
        S = struct();
        S.generatedAt = datestr(now,'yyyy-mm-dd HH:MM:SS');
        S.codeVersion = 'RAVEN_V1_01';
        S.finalWinner = finalKey;
        S.winnerPolicy = char(resolveStep4WinnerPolicy());
        S.ablationSummary = Tab;
        S.finalistTable = Tsel;
        S.finalSelections = finalSelections;
        if isfield(app.state.results,'bestStep2')
            S.bestTeacher = app.state.results.bestStep2;
        end
        if isfield(app.state.results,'step2Shortlist')
            S.step2Shortlist = app.state.results.step2Shortlist;
        end
        if isfield(app.state.results,'step3Top')
            S.step3Top = app.state.results.step3Top;
        end
        if isfield(app.state.results,'step3ModeInfo')
            S.step3ModeInfo = app.state.results.step3ModeInfo;
        end
        if isfield(app,'cfg')
            S.cvCfg = app.cfg.cv;
            S.step4Cfg = app.cfg.step4;
        end
        save(fullfile(outDir,'ABLATION_EXPORT.mat'), '-struct', 'S');
    end

    function writeAblationPerSelectionSheets(Tsel, finalSelections, outDir)
        roles = fieldnames(finalSelections);
        for ii = 1:numel(roles)
            role = roles{ii};
            res = finalSelections.(role);
            path = fullfile(outDir, ['ABLATION_SELECTION_' sanitizeFilename(role) '.xlsx']);
            Tsum = table(string(role), string(ravenGetField(res,'CandidateID',role)), getStructScalar(res,'Acc',NaN), getStructScalar(res,'AccTeacher',NaN), ...
                getStructScalar(res,'RatioToTeacher',NaN), getStructScalar(res,'MacroF1',NaN), getStructScalar(res,'WeightedF1',NaN), ...
                getStructScalar(res,'Score',NaN), getStructScalar(res,'WallMsPerSpec',NaN), getStructScalar(res,'MemMiBPerSpec',NaN), ...
                'VariableNames', {'Role','CandidateID','Acc','TeacherAcc','RatioToTeacher','MacroF1','WeightedF1','Score','WallMsPerSpec','MemMiBPerSpec'});
            tryWriteTable(Tsum, path, 'Summary');
            if isfield(res,'cfg')
                tryWriteTable(struct2table(flattenStruct(res.cfg)), path, 'Config');
            end
            idx = find(strcmp(cellstr(string(Tsel.Selection)), role), 1, 'first');
            if ~isempty(idx)
                tryWriteTable(Tsel(idx,:), path, 'SelectionRow');
            end
        end
    end

    function S = flattenStruct(st)

        S = struct();
        recurseFill('', st);

        function recurseFill(prefix, val)
            if isstruct(val) && isscalar(val)
                f = fieldnames(val);
                for ii = 1:numel(f)
                    if isempty(prefix)
                        newPrefix = f{ii};
                    else
                        newPrefix = [prefix '_' f{ii}];
                    end
                    recurseFill(newPrefix, val.(f{ii}));
                end
            else
                fld = matlab.lang.makeValidName(prefix);
                S.(fld) = scalarizeValue(val);
            end
        end

        function out = scalarizeValue(v)
            if isempty(v)
                out = "";
            elseif isnumeric(v)
                if isscalar(v)
                    out = v;
                else
                    out = strtrim(num2str(v(:)'));
                end
            elseif islogical(v)
                if isscalar(v)
                    out = double(v);
                else
                    out = strtrim(num2str(double(v(:)')));
                end
            elseif ischar(v)
                out = v;
            elseif isstring(v)
                if isscalar(v)
                    out = char(v);
                else
                    out = strjoin(cellstr(v(:)'), ' | ');
                end
            elseif iscell(v)
                try
                    out = evalc('disp(v)');
                    out = strtrim(out);
                catch
                    out = 'cell';
                end
            else
                try
                    out = evalc('disp(v)');
                    out = strtrim(out);
                    if isempty(out)
                        out = class(v);
                    end
                catch
                    out = class(v);
                end
            end
        end
    end

    function writeErrorTxt(ME, context)
        try
            outdir = '';
            if isfield(app,'state') && isfield(app.state,'outdir') && ~isempty(app.state.outdir) && exist(app.state.outdir,'dir')
                outdir = app.state.outdir;
            elseif isfield(app,'cfg') && isfield(app.cfg,'io') && isfield(app.cfg.io,'saveBaseDir') && ~isempty(app.cfg.io.saveBaseDir) && exist(app.cfg.io.saveBaseDir,'dir')
                outdir = app.cfg.io.saveBaseDir;
            else
                outdir = pwd;
            end
            stamp = datestr(now,'yyyymmdd_HHMMSS');
            errPath = fullfile(outdir, ['ERROR_' stamp '.txt']);
            latestPath = fullfile(outdir, 'LATEST_ERROR.txt');
            rep = getReport(ME,'extended','hyperlinks','off');
            fid = fopen(errPath,'w');
            if fid ~= -1
                fprintf(fid,'RAVEN GUI error log\n');
                fprintf(fid,'Time: %s\n', datestr(now,31));
                fprintf(fid,'Context: %s\n', context);
                fprintf(fid,'Message: %s\n\n', ME.message);
                fprintf(fid,'%s\n', rep);
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

    function res = evaluateRavenTeacherConfig(X, y, C, teacherCfg, K, Rrepeat, seedBase, doFull)
        N = size(X,1);
        accVec = zeros(Rrepeat,1);
        balVec = zeros(Rrepeat,1);
        wtAccVec = zeros(Rrepeat,1);
        f1Vec = zeros(Rrepeat,1);
        wtF1Vec = zeros(Rrepeat,1);
        memVec = zeros(Rrepeat,1);
        predMsVec = zeros(Rrepeat,1);
        wallVec = zeros(Rrepeat,1);
        wallMsVec = zeros(Rrepeat,1);
        dimVec = zeros(Rrepeat,1);
        repeatCM = zeros(C,C,Rrepeat);
        allTrue = []; allScores = []; allPred = [];
        repeatTrue = cell(Rrepeat,1); repeatPred = cell(Rrepeat,1); repeatScores = cell(Rrepeat,1);
        for rr = 1:Rrepeat
            foldIdx = getCachedFoldIdx(y, K, rr, seedBase, 'raven_teacher');
            CMrep = zeros(C,C);
            trueRep = []; predRep = []; scoreRep = [];
            predMsFold = zeros(K,1);
            memFold = zeros(K,1);
            dimFold = zeros(K,1);
            tRep = tic;
            for f = 1:K
                art = getCachedTeacherFoldArtifacts(X, y, C, foldIdx, f, teacherCfg, seedBase, rr);
                yte = art.yte;
                yhat = art.yhatT;
                scoreTe = art.scoreTe;
                predMs = art.predMsT;
                memMiB = art.memT;
                mdlT = art.mdlT;
                predMsFold(f) = predMs;
                memFold(f) = memMiB;
                dimFold(f) = mdlT.rEff;
                CMrep = CMrep + accumarray([yte(:), yhat(:)], 1, [C C], @sum, 0);
                if doFull
                    trueRep = [trueRep; yte(:)];
                    predRep = [predRep; yhat(:)];
                    scoreRep = [scoreRep; scoreTe];
                    allTrue = [allTrue; yte(:)];
                    allPred = [allPred; yhat(:)];
                    allScores = [allScores; scoreTe];
                end
            end
            accVec(rr) = sum(diag(CMrep)) / max(1, sum(CMrep(:)));
            recall = diag(CMrep) ./ max(1, sum(CMrep,2));
            prec = diag(CMrep) ./ max(1, sum(CMrep,1)');
            f1 = 2*(prec.*recall) ./ max(1e-12, prec + recall);
            support = sum(CMrep,2);
            wClass = support ./ max(1,sum(support));
            balVec(rr) = mean(recall,'omitnan');
            wtAccVec(rr) = sum(wClass .* recall,'omitnan');
            f1Vec(rr) = mean(f1,'omitnan');
            wtF1Vec(rr) = sum(wClass .* f1,'omitnan');
            memVec(rr) = median(memFold);
            predMsVec(rr) = mean(predMsFold,'omitnan');
            wallVec(rr) = toc(tRep);
            wallMsVec(rr) = 1000*wallVec(rr)/max(1,N);
            dimVec(rr) = median(dimFold);
            repeatCM(:,:,rr) = CMrep;
            repeatTrue{rr} = trueRep;
            repeatPred{rr} = predRep;
            repeatScores{rr} = scoreRep;
        end
        CMmean = mean(repeatCM,3);
        recallMean = diag(CMmean) ./ max(1, sum(CMmean,2));
        precMean = diag(CMmean) ./ max(1, sum(CMmean,1)');
        F1class = 2*(precMean.*recallMean) ./ max(1e-12, precMean + recallMean);
        res = struct();
        res.Acc = mean(accVec);
        res.BalAcc = mean(balVec);
        res.WeightedAcc = mean(wtAccVec);
        res.MacroF1 = mean(f1Vec);
        res.WeightedF1 = mean(wtF1Vec);
        res.AccTeacher = res.Acc;
        res.RatioToTeacher = 1;
        res.S2 = nan;
        res.LowOccFrac = nan;
        res.CondMed = nan;
        res.FeatDimMed = median(dimVec);
        res.MemMiBPerSpec = median(memVec);
        res.WallSec = mean(wallVec);
        res.WallMsPerSpec = mean(wallMsVec);
        res.PredictMsPerSpec = mean(predMsVec,'omitnan');
        res.CMmean = CMmean;
        res.RecallPerClass = recallMean;
        res.PrecisionPerClass = precMean;
        res.F1PerClass = F1class;
        res.cfg = teacherCfg;
        res.Score = 0.70*res.Acc + 0.20*res.MacroF1 + 0.07*(1/(1+res.WallMsPerSpec)) + 0.03*(1/(1+res.MemMiBPerSpec));
        repScore = 0.70*accVec + 0.20*f1Vec + 0.07*(1./(1+wallMsVec)) + 0.03*(1./(1+memVec));
        res.RepeatMetrics = table((1:Rrepeat)', accVec, balVec, wtAccVec, f1Vec, wtF1Vec, repmat(nan,Rrepeat,1), repmat(nan,Rrepeat,1), repmat(nan,Rrepeat,1), ...
            dimVec, memVec, wallVec, wallMsVec, predMsVec, dimVec, repScore, ...
            'VariableNames', {'Repeat','Acc','BalAcc','WeightedAcc','MacroF1','WeightedF1','S2','LowOccFrac','CondMed','FeatDimMed','MemMiBPerSpec','WallSec','WallMsPerSpec','PredictMsPerSpec','RankMean','Score'});
        res.RepeatCM = repeatCM;
        [~,bestRep] = max(accVec + 1e-6*f1Vec - 1e-6*wallMsVec);
        res.BestRepeatIndex = bestRep;
        res.CMBest = repeatCM(:,:,bestRep);
        if doFull && ~isempty(allScores)
            [fprGrid, tprGrid, aucPerClass, microAUC, macroAUC] = makeROC(allTrue, allScores, C, app.cfg.step4.numROC);
            res.ROC_FPR = fprGrid;
            res.ROC_TPR = tprGrid;
            res.AUCPerClass = aucPerClass;
            res.MicroAUC = microAUC;
            res.MacroAUC = macroAUC;
            [bfpr, btpr, bauc, bmicro, bmacro] = makeROC(repeatTrue{bestRep}, repeatScores{bestRep}, C, app.cfg.step4.numROC);
            res.ROCbest_FPR = bfpr;
            res.ROCbest_TPR = btpr;
            res.AUCbest_PerClass = bauc;
            res.MicroAUC_Best = bmicro;
            res.MacroAUC_Best = bmacro;
        end
    end

    function res = evaluateRavenStudentConfig(X, y, C, teacherCfg, studentCfg, K, Rrepeat, seedBase, doFull)
        N = size(X,1);
        accVec = zeros(Rrepeat,1);
        accTVec = zeros(Rrepeat,1);
        balVec = zeros(Rrepeat,1);
        wtAccVec = zeros(Rrepeat,1);
        f1Vec = zeros(Rrepeat,1);
        wtF1Vec = zeros(Rrepeat,1);
        memVec = zeros(Rrepeat,1);
        predMsVec = zeros(Rrepeat,1);
        wallVec = zeros(Rrepeat,1);
        wallMsVec = zeros(Rrepeat,1);
        dimVec = zeros(Rrepeat,1);
        repeatCM = zeros(C,C,Rrepeat);
        allTrue = []; allScores = []; allPred = [];
        repeatTrue = cell(Rrepeat,1); repeatPred = cell(Rrepeat,1); repeatScores = cell(Rrepeat,1);
        for rr = 1:Rrepeat
            foldIdx = getCachedFoldIdx(y, K, rr, seedBase, 'raven_student');
            CMrep = zeros(C,C);
            accTfold = zeros(K,1);
            predMsFold = zeros(K,1);
            memFold = zeros(K,1);
            dimFold = zeros(K,1);
            trueRep = []; predRep = []; scoreRep = [];
            tRep = tic;
            for f = 1:K
                art = getCachedTeacherFoldArtifacts(X, y, C, foldIdx, f, teacherCfg, seedBase, rr);
                Str = art.Str;
                Ste = art.Ste;
                ytr = art.ytr;
                yte = art.yte;
                mdlT = art.mdlT;
                yhatT = art.yhatT;
                predMsT = art.predMsT;
                memT = art.memT;
                accTfold(f) = mean(yhatT(:) == yte(:));
                scoreT_tr = mdlT.scoreTr;
                temp2 = max(1e-6, studentCfg.temp);
                Z = scoreT_tr / temp2;
                Z = Z - max(Z,[],2);
                Pteach = exp(Z);
                Pteach = Pteach ./ max(1e-12, sum(Pteach,2));
                Yoh = zeros(size(Str,1), C);
                Yoh(sub2ind([size(Str,1) C], (1:size(Str,1))', ytr)) = 1;
                a2 = max(0,min(1,studentCfg.alpha));
                Ttr = a2*Pteach + (1-a2)*Yoh;
                mdlS = fitRavenStudent(Str, Ttr, studentCfg, seedBase + 10000*rr + 100*f);
                [yhatS, scoreS, predMsS, memS] = predictRavenStudent(mdlS, Ste);
                predMsFold(f) = predMsS;
                memFold(f) = memS;
                dimFold(f) = mdlS.featDim;
                CMrep = CMrep + accumarray([yte(:), yhatS(:)], 1, [C C], @sum, 0);
                if doFull
                    trueRep = [trueRep; yte(:)];
                    predRep = [predRep; yhatS(:)];
                    scoreRep = [scoreRep; scoreS];
                    allTrue = [allTrue; yte(:)];
                    allPred = [allPred; yhatS(:)];
                    allScores = [allScores; scoreS];
                end
            end
            accVec(rr) = sum(diag(CMrep)) / max(1, sum(CMrep(:)));
            accTVec(rr) = mean(accTfold);
            recall = diag(CMrep) ./ max(1, sum(CMrep,2));
            prec = diag(CMrep) ./ max(1, sum(CMrep,1)');
            f1 = 2*(prec.*recall) ./ max(1e-12, prec + recall);
            support = sum(CMrep,2);
            wClass = support ./ max(1,sum(support));
            balVec(rr) = mean(recall,'omitnan');
            wtAccVec(rr) = sum(wClass .* recall,'omitnan');
            f1Vec(rr) = mean(f1,'omitnan');
            wtF1Vec(rr) = sum(wClass .* f1,'omitnan');
            memVec(rr) = median(memFold);
            predMsVec(rr) = mean(predMsFold,'omitnan');
            wallVec(rr) = toc(tRep);
            wallMsVec(rr) = 1000*wallVec(rr)/max(1,N);
            dimVec(rr) = median(dimFold);
            repeatCM(:,:,rr) = CMrep;
            repeatTrue{rr} = trueRep;
            repeatPred{rr} = predRep;
            repeatScores{rr} = scoreRep;
        end
        CMmean = mean(repeatCM,3);
        recallMean = diag(CMmean) ./ max(1, sum(CMmean,2));
        precMean = diag(CMmean) ./ max(1, sum(CMmean,1)');
        F1class = 2*(precMean.*recallMean) ./ max(1e-12, precMean + recallMean);
        res = struct();
        res.Acc = mean(accVec);
        res.AccTeacher = mean(accTVec);
        res.RatioToTeacher = res.Acc / max(1e-12, res.AccTeacher);
        res.BalAcc = mean(balVec);
        res.WeightedAcc = mean(wtAccVec);
        res.MacroF1 = mean(f1Vec);
        res.WeightedF1 = mean(wtF1Vec);
        res.S2 = nan;
        res.LowOccFrac = nan;
        res.CondMed = nan;
        res.FeatDimMed = median(dimVec);
        res.MemMiBPerSpec = median(memVec);
        res.WallSec = mean(wallVec);
        res.WallMsPerSpec = mean(wallMsVec);
        res.PredictMsPerSpec = mean(predMsVec,'omitnan');
        res.CMmean = CMmean;
        res.RecallPerClass = recallMean;
        res.PrecisionPerClass = precMean;
        res.F1PerClass = F1class;
        res.cfg = struct('teacher',teacherCfg,'student',studentCfg);
        res.Score = 0.55*res.Acc + 0.20*res.MacroF1 + 0.15*min(1.25,res.RatioToTeacher)/1.25 + 0.06*(1/(1+res.WallMsPerSpec)) + 0.04*(1/(1+res.MemMiBPerSpec));
        repRatio = accVec ./ max(1e-12, accTVec);
        repScore = 0.55*accVec + 0.20*f1Vec + 0.15*min(1.25,repRatio)/1.25 + 0.06*(1./(1+wallMsVec)) + 0.04*(1./(1+memVec));
        res.RepeatMetrics = table((1:Rrepeat)', accVec, balVec, wtAccVec, f1Vec, wtF1Vec, repmat(nan,Rrepeat,1), repmat(nan,Rrepeat,1), repmat(nan,Rrepeat,1), ...
            dimVec, memVec, wallVec, wallMsVec, predMsVec, repRatio, repScore, ...
            'VariableNames', {'Repeat','Acc','BalAcc','WeightedAcc','MacroF1','WeightedF1','S2','LowOccFrac','CondMed','FeatDimMed','MemMiBPerSpec','WallSec','WallMsPerSpec','PredictMsPerSpec','RankMean','Score'});
        res.RepeatCM = repeatCM;
        [~,bestRep] = max(accVec + 1e-6*f1Vec - 1e-6*wallMsVec);
        res.BestRepeatIndex = bestRep;
        res.CMBest = repeatCM(:,:,bestRep);
        if doFull && ~isempty(allScores)
            [fprGrid, tprGrid, aucPerClass, microAUC, macroAUC] = makeROC(allTrue, allScores, C, app.cfg.step4.numROC);
            res.ROC_FPR = fprGrid;
            res.ROC_TPR = tprGrid;
            res.AUCPerClass = aucPerClass;
            res.MicroAUC = microAUC;
            res.MacroAUC = macroAUC;
            [bfpr, btpr, bauc, bmicro, bmacro] = makeROC(repeatTrue{bestRep}, repeatScores{bestRep}, C, app.cfg.step4.numROC);
            res.ROCbest_FPR = bfpr;
            res.ROCbest_TPR = btpr;
            res.AUCbest_PerClass = bauc;
            res.MicroAUC_Best = bmicro;
            res.MacroAUC_Best = bmacro;
        end
    end

    function mdlT = fitRavenTeacher(Str, ytr, teacherCfg, C)
        ntr = size(Str,1);
        mEff = min(max(2,round(teacherCfg.mLand)), ntr);
        idxLand = randperm(ntr, mEff);
        SL = Str(idxLand,:);
        A2 = sum(SL.^2,2);
        D2SS = bsxfun(@plus, A2, A2.') - 2*(SL*SL.');
        D2SS = max(D2SS,0);
        dvec = sqrt(D2SS(triu(true(size(D2SS)),1)));
        dvec = dvec(isfinite(dvec) & dvec > 0);
        med = median(dvec);
        if ~(isfinite(med) && med > 0), med = 1.0; end
        sigma_fold = teacherCfg.sigmaScale * (med/sqrt(2));
        if ~(isfinite(sigma_fold) && sigma_fold > 0), sigma_fold = 1.0; end
        gamma = 1/(2*sigma_fold^2);
        KSS = exp(-gamma * D2SS);
        KSS = (KSS + KSS.')/2;
        rReq = min(max(1,round(teacherCfg.rTeach)), mEff);
        try
            [Ur,DD] = eigs(KSS, rReq, 'la');
            lamr = max(real(diag(DD)),0);
        catch
            [Ue,DD] = eig(KSS);
            lamAll = real(diag(DD));
            [lamAll,ord] = sort(lamAll,'descend');
            Ue = Ue(:,ord);
            lamAll = max(lamAll,0);
            keep = find(lamAll > 1e-12); if isempty(keep), keep = 1; end
            rEff0 = min(rReq, numel(keep));
            Ur = Ue(:,1:rEff0);
            lamr = lamAll(1:rEff0);
        end
        keep2 = find(lamr > 1e-12); if isempty(keep2), keep2 = 1; end
        rEff = min(numel(lamr), numel(keep2));
        Ur = Ur(:,1:rEff);
        lamr = lamr(1:rEff);
        invSqrtLam = 1./sqrt(max(lamr(:).',1e-12));
        A2tr = sum(Str.^2,2);
        B2L = sum(SL.^2,2).';
        D2trL = bsxfun(@plus, A2tr, B2L) - 2*(Str*SL.');
        D2trL = max(D2trL,0);
        KtrL = exp(-gamma * D2trL);
        Phi_tr = KtrL * Ur;
        Phi_tr = bsxfun(@times, Phi_tr, invSqrtLam);
        Phi_tr = Phi_tr ./ max(1e-12, sqrt(sum(Phi_tr.^2,2)));
        tSVM = templateSVM('KernelFunction','linear','Standardize',true,'BoxConstraint',teacherCfg.boxC);
        MdlT = fitcecoc(Phi_tr, ytr, 'Learners', tSVM, 'ClassNames', 1:C, 'Coding', 'onevsall');
        [~, scoreT_tr] = predict(MdlT, Phi_tr);
        if size(scoreT_tr,2) ~= C
            tmp = zeros(size(scoreT_tr,1), C);
            tmp(:,1:min(C,size(scoreT_tr,2))) = scoreT_tr(:,1:min(C,size(scoreT_tr,2)));
            scoreT_tr = tmp;
        end
        mdlT = struct('SL',SL,'gamma',gamma,'Ur',Ur,'invSqrtLam',invSqrtLam,'classifier',MdlT, ...
            'rEff',rEff,'mEff',mEff,'scoreTr',scoreT_tr,'sigma',sigma_fold);
    end

    function [yhat, scores, predMs, memMiB] = predictRavenTeacher(mdlT, Ste)
        t0 = tic;
        A2te = sum(Ste.^2,2);
        B2L = sum(mdlT.SL.^2,2).';
        D2teL = bsxfun(@plus, A2te, B2L) - 2*(Ste*mdlT.SL.');
        D2teL = max(D2teL,0);
        KteL = exp(-mdlT.gamma * D2teL);
        Phi_te = KteL * mdlT.Ur;
        Phi_te = bsxfun(@times, Phi_te, mdlT.invSqrtLam);
        Phi_te = Phi_te ./ max(1e-12, sqrt(sum(Phi_te.^2,2)));
        [yhat, scores] = predict(mdlT.classifier, Phi_te);
        predMs = 1000*toc(t0) / max(1,size(Ste,1));
        memMiB = 8*(numel(D2teL) + numel(KteL) + numel(Phi_te) + numel(scores)) / max(1,size(Ste,1)) / 1024^2;
    end

    function mdlS = fitRavenStudent(Str, Ttr, studentCfg, seedBase)
        ntr = size(Str,1);
        dRk = size(Str,2);
        ens = max(1, round(studentCfg.ensemble));
        member = cell(ens,1);
        featDim = max(1, round(studentCfg.pHidden)) + (studentCfg.skipScale > 0) * dRk;
        for ee = 1:ens
            rng(seedBase + ee, 'twister');
            Wrand = randn(max(1,round(studentCfg.pHidden)), dRk) / sqrt(max(1,dRk));
            brand = randn(max(1,round(studentCfg.pHidden)), 1);
            ZtrH = bsxfun(@plus, Wrand*Str.', brand);
            Htr = tanh(ZtrH);
            if studentCfg.skipScale > 0
                Htr = [Htr; (studentCfg.skipScale*Str.')];
            end
            pEff = size(Htr,1);
            lam = max(1e-12, studentCfg.lamRidge);
            if pEff <= ntr
                Gp = (Htr*Htr.') + lam*eye(pEff);
                RHS = Htr * Ttr;
                ok = true;
                try, Lc = chol(Gp,'lower'); catch, ok = false; end
                if ok
                    Aout = Lc'\(Lc\RHS);
                else
                    Aout = (Gp + 1e-8*eye(pEff)) \ RHS;
                end
            else
                Gn = (Htr.'*Htr) + lam*eye(ntr);
                ok = true;
                try, Lc = chol(Gn,'lower'); catch, ok = false; end
                if ok
                    Tm = Lc'\(Lc\Ttr);
                else
                    Tm = (Gn + 1e-8*eye(ntr)) \ Ttr;
                end
                Aout = Htr * Tm;
            end
            member{ee} = struct('Wrand',Wrand,'brand',brand,'Aout',Aout);
        end
        mdlS = struct('member',{member},'skipScale',studentCfg.skipScale,'ensemble',ens,'featDim',featDim);
    end

    function [yhat, scores, predMs, memMiB] = predictRavenStudent(mdlS, Ste)
        ens = numel(mdlS.member);
        scoreSum = [];
        memBytes = 0;
        t0 = tic;
        for ee = 1:ens
            mm = mdlS.member{ee};
            ZteH = bsxfun(@plus, mm.Wrand*Ste.', mm.brand);
            Hte = tanh(ZteH);
            if mdlS.skipScale > 0
                Hte = [Hte; (mdlS.skipScale*Ste.')];
            end
            scoreNow = Hte.' * mm.Aout;
            if isempty(scoreSum)
                scoreSum = scoreNow;
            else
                scoreSum = scoreSum + scoreNow;
            end
            memBytes = memBytes + 8*(numel(ZteH) + numel(Hte) + numel(scoreNow));
        end
        scores = scoreSum / max(1,ens);
        [~, yhat] = max(scores, [], 2);
        predMs = 1000*toc(t0) / max(1,size(Ste,1));
        memMiB = memBytes / max(1,size(Ste,1)) / 1024^2;
    end

    function runBenchmarkSuite()
        setStep('Benchmark | Baseline comparison');
        if ~isfield(app.state,'data') || isempty(app.state.data)
            error('Benchmark requires preprocessed data in app.state.data.');
        end
        X = app.state.data.X_all;
        y = app.state.data.y_idx;
        C = app.state.data.C;
        methods = app.cfg.benchmark.methods;
        if isempty(methods)
            methods = {'PCA_LINSVM','PCA_LDA','PCA_RF'};
        end
        kPC = app.cfg.benchmark.kPC;
        if isempty(kPC) || ~isfinite(kPC) || kPC < 1
            if isfield(app.state,'results') && isfield(app.state.results,'bestStep1')
                kPC = getNumericScalar(app.state.results.bestStep1,'kPC',min(20,size(X,2)));
            else
                kPC = min(20,size(X,2));
            end
        end
        K = app.cfg.cv.outerK;
        if isfield(app.cfg.benchmark,'outerK') && ~isempty(app.cfg.benchmark.outerK)
            K = app.cfg.benchmark.outerK;
        end
        Rrepeat = app.cfg.cv.repeats;
        if isfield(app.cfg.benchmark,'repeats') && ~isempty(app.cfg.benchmark.repeats)
            Rrepeat = app.cfg.benchmark.repeats;
        end
        seedBase = app.cfg.cv.seedBase + 7000;
        outDir = fullfile(app.state.outdir,'BENCHMARKS');
        if ~exist(outDir,'dir'), mkdir(outDir); end

        rows = cell(numel(methods),1);
        groupVecNow = getCurrentGroupVector(numel(y));
        useParB = isParallelReady(numel(methods));
        if useParB
            logmsg(sprintf('Benchmark parallel ACTIVE across %d methods.', numel(methods)));
            noteAction(sprintf('Benchmark | parallel batch running (%d methods)', numel(methods)));
            parfor ii = 1:numel(methods)
                m = methods{ii};
                rows{ii} = raven_eval_benchmark_worker(X, y, C, m, kPC, K, Rrepeat, seedBase + 100*ii, app.cfg.benchmark, app.cfg.cv.splitMode, groupVecNow);
                rows{ii}.kPC = kPC;
            end
            completeAction(sprintf('Benchmark | parallel batch finished (%d methods)', numel(methods)));
        else
            for ii = 1:numel(methods)
                m = methods{ii};
                checkPauseStop();
                noteAction(sprintf('Benchmark | %s (%d/%d)', m, ii, numel(methods)));
                logmsg(sprintf('Benchmark | %s | kPC=%d | K=%d | repeats=%d', m, kPC, K, Rrepeat));
                rows{ii} = raven_eval_benchmark_worker(X, y, C, m, kPC, K, Rrepeat, seedBase + 100*ii, app.cfg.benchmark, app.cfg.cv.splitMode, groupVecNow);
                rows{ii}.kPC = kPC;
                completeAction(sprintf('Benchmark | %s done (%d/%d)', m, ii, numel(methods)));
            end
        end
        for ii = 1:numel(methods)
            rr = rows{ii};
            if isempty(rr), continue; end
            setLiveStatus('Current action', sprintf('Benchmark | %s | %s', rr.Method, formatActionMetrics(rr.Acc, rr.WeightedF1, rr.MacroF1, rr.Score)));
            logmsg(sprintf('Benchmark | %s | Acc=%.2f%% | WeightedF1=%.2f%% | MacroF1=%.2f%% | Score=%.4f', rr.Method, 100*rr.Acc, 100*rr.WeightedF1, 100*rr.MacroF1, rr.Score));
        end
        if isfield(app.state,'results') && isfield(app.state.results,'finalWinnerRecord') && ~isempty(app.state.results.finalWinnerRecord)
            rows{end+1,1} = makeWinnerBenchmarkRow(app.state.results.finalWinnerRecord, kPC);
        end
        Tbench = benchmarkRowsToTable(rows);
        app.state.results.benchmarkRows = rows;
        app.state.results.benchmarkTable = Tbench;
        exportBenchmarkBundle(Tbench, rows, outDir, kPC, K, Rrepeat, methods);
        setSummary('Benchmark', sprintf('%d methods | best Acc=%s', height(Tbench), summarizeBestBenchmark(Tbench)));
        logmsg('Benchmark integration finished.');
    end

    function row = evaluateBenchmarkMethod(X, y, C, methodName, kPC, K, Rrepeat, seedBase)
        N = size(X,1);
        accVec = zeros(Rrepeat,1);
        balVec = zeros(Rrepeat,1);
        wtAccVec = zeros(Rrepeat,1);
        f1Vec = zeros(Rrepeat,1);
        wtF1Vec = zeros(Rrepeat,1);
        wallVec = zeros(Rrepeat,1);
        predMsVec = nan(Rrepeat,1);
        memVec = nan(Rrepeat,1);
        aucVec = nan(Rrepeat,1);
        for rr = 1:Rrepeat
            foldIdx = getCachedFoldIdx(y, K, rr, seedBase, ['benchmark_' lower(methodName)]);
            CMrep = zeros(C,C);
            repScores = [];
            repTrue = [];
            predFold = nan(K,1);
            memFold = nan(K,1);
            tRep = tic;
            for f = 1:K
                [Str, Ste, ytr, yte] = getCachedFoldPCA(X, y, foldIdx, f, kPC, ['benchmark_' lower(methodName)]);
                [mdl, predictFcn, modelBytes] = fitBenchmarkModel(Str, ytr, C, methodName);
                tPred = tic;
                [yhat, scores] = predictFcn(Ste);
                predFold(f) = 1000*toc(tPred) / max(1,numel(yte));
                memFold(f) = modelBytes / max(1,numel(yte)) / 1024^2;
                if size(scores,2) ~= C
                    scores = padScoreMatrix(scores, C, yhat);
                end
                repTrue = [repTrue; yte];
                repScores = [repScores; scores];
                for jj = 1:numel(yte)
                    CMrep(yte(jj), yhat(jj)) = CMrep(yte(jj), yhat(jj)) + 1;
                end
            end
            accVec(rr) = sum(diag(CMrep))/max(1,sum(CMrep(:)));
            recall = diag(CMrep) ./ max(1,sum(CMrep,2));
            prec = diag(CMrep) ./ max(1,sum(CMrep,1)');
            f1 = 2*(prec.*recall) ./ max(1e-12,prec+recall);
            support = sum(CMrep,2);
            wClass = support ./ max(1,sum(support));
            balVec(rr) = mean(recall,'omitnan');
            wtAccVec(rr) = sum(wClass .* recall,'omitnan');
            f1Vec(rr) = mean(f1,'omitnan');
            wtF1Vec(rr) = sum(wClass .* f1,'omitnan');
            wallVec(rr) = toc(tRep);
            predMsVec(rr) = mean(predFold,'omitnan');
            memVec(rr) = mean(memFold,'omitnan');
            try
                [~,~,~,microAUC,macroAUC] = makeROC(repTrue, repScores, C, 100);
                aucVec(rr) = macroAUC;
            catch
                aucVec(rr) = NaN;
            end
        end
        row = struct();
        row.Method = methodName;
        row.kPC = kPC;
        row.Acc = mean(accVec,'omitnan');
        row.BalAcc = mean(balVec,'omitnan');
        row.WeightedAcc = mean(wtAccVec,'omitnan');
        row.MacroF1 = mean(f1Vec,'omitnan');
        row.WeightedF1 = mean(wtF1Vec,'omitnan');
        row.Score = 100*row.MacroF1 + 20*row.BalAcc + 5*row.Acc - 0.02*mean(wallVec,'omitnan') - 0.2*mean(memVec,'omitnan');
        row.PredictMsPerSpec = mean(predMsVec,'omitnan');
        row.MemMiBPerSpec = mean(memVec,'omitnan');
        row.WallSec = mean(wallVec,'omitnan');
        row.MacroAUC = mean(aucVec,'omitnan');
        row.Source = 'Benchmark';
    end

    function [mdl, predictFcn, modelBytes] = fitBenchmarkModel(Str, ytr, C, methodName)
        mdl = [];
        predictFcn = [];
        switch upper(methodName)
            case 'PCA_LINSVM'
                tSVM = templateSVM('KernelFunction','linear','Standardize',true,'BoxConstraint',app.cfg.benchmark.boxC);
                mdl = fitcecoc(Str, ytr, 'Learners', tSVM, 'ClassNames', 1:C, 'Coding','onevsall');
                try
                    mdlCal = fitPosterior(mdl, Str, ytr);
                    mdl = mdlCal;
                catch
                end
                predictFcn = @(Xin) predictBenchmarkECOC(mdl, Xin, C);
            case 'PCA_LDA'
                mdl = fitcdiscr(Str, ytr, 'DiscrimType','pseudoLinear', 'ClassNames', 1:C);
                predictFcn = @(Xin) predictBenchmarkLDA(mdl, Xin, C);
            case 'PCA_RF'
                tree = templateTree('MaxNumSplits', max(2, round(app.cfg.benchmark.maxSplits)));
                mdl = fitcensemble(Str, ytr, 'Method','Bag', 'NumLearningCycles', max(10, round(app.cfg.benchmark.numTrees)), 'Learners', tree, 'ClassNames', 1:C);
                predictFcn = @(Xin) predictBenchmarkEnsemble(mdl, Xin, C);
            otherwise
                error('Unsupported benchmark method: %s', methodName);
        end
        s = whos('mdl');
        modelBytes = s.bytes;
    end

    function [yhat, scores] = predictBenchmarkECOC(mdl, Xin, C)
        [yhat, scores] = predict(mdl, Xin);
        if size(scores,2) ~= C
            scores = padScoreMatrix(scores, C, yhat);
        end
    end

    function [yhat, scores] = predictBenchmarkLDA(mdl, Xin, C)
        [yhat, scores] = predict(mdl, Xin);
        if size(scores,2) ~= C
            scores = padScoreMatrix(scores, C, yhat);
        end
    end

    function [yhat, scores] = predictBenchmarkEnsemble(mdl, Xin, C)
        [yhat, scores] = predict(mdl, Xin);
        if iscell(yhat)
            yhat = str2double(yhat);
        end
        if size(scores,2) ~= C
            scores = padScoreMatrix(scores, C, yhat);
        end
    end

    function scores = padScoreMatrix(scores, C, yhat)
        if isempty(scores)
            scores = zeros(numel(yhat), C);
            for ii = 1:numel(yhat)
                if yhat(ii) >= 1 && yhat(ii) <= C
                    scores(ii,yhat(ii)) = 1;
                end
            end
            return;
        end
        if size(scores,2) < C
            scores(:,end+1:C) = 0;
        elseif size(scores,2) > C
            scores = scores(:,1:C);
        end
    end

    function row = makeWinnerBenchmarkRow(F, kPC)
        row = struct();
        row.Method = 'RAVEN_FINAL';
        row.kPC = kPC;
        row.Acc = getStructScalar(F,'Acc',NaN);
        row.BalAcc = NaN;
        row.WeightedAcc = getStructScalar(F,'WeightedAcc',NaN);
        row.MacroF1 = getStructScalar(F,'MacroF1',NaN);
        row.WeightedF1 = getStructScalar(F,'WeightedF1',NaN);
        row.Score = getStructScalar(F,'Score',NaN);
        row.PredictMsPerSpec = getStructScalar(F,'TimePerSpec',NaN);
        row.MemMiBPerSpec = getStructScalar(F,'MemoryPerSpec',NaN);
        row.WallSec = NaN;
        row.MacroAUC = NaN;
        row.Source = 'RAVEN';
    end

    function x = getStructScalar(S, fieldName, defaultVal)
        x = defaultVal;
        if nargin < 3, defaultVal = NaN; end
        if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
            v = S.(fieldName);
            if isnumeric(v) || islogical(v)
                x = double(v(1));
            end
        end
    end

    function T = benchmarkRowsToTable(rows)
        rows = rows(~cellfun('isempty',rows));
        Method = strings(0,1); kPC = []; Acc = []; BalAcc = []; WeightedAcc = []; MacroF1 = []; WeightedF1 = []; Score = []; PredictMsPerSpec = []; MemMiBPerSpec = []; WallSec = []; MacroAUC = []; Source = strings(0,1);
        for ii = 1:numel(rows)
            r = rows{ii};
            Method(end+1,1) = string(r.Method);
            kPC(end+1,1) = getStructScalar(r,'kPC',NaN);
            Acc(end+1,1) = getStructScalar(r,'Acc',NaN);
            BalAcc(end+1,1) = getStructScalar(r,'BalAcc',NaN);
            WeightedAcc(end+1,1) = getStructScalar(r,'WeightedAcc',NaN);
            MacroF1(end+1,1) = getStructScalar(r,'MacroF1',NaN);
            WeightedF1(end+1,1) = getStructScalar(r,'WeightedF1',NaN);
            Score(end+1,1) = getStructScalar(r,'Score',NaN);
            PredictMsPerSpec(end+1,1) = getStructScalar(r,'PredictMsPerSpec',NaN);
            MemMiBPerSpec(end+1,1) = getStructScalar(r,'MemMiBPerSpec',NaN);
            WallSec(end+1,1) = getStructScalar(r,'WallSec',NaN);
            MacroAUC(end+1,1) = getStructScalar(r,'MacroAUC',NaN);
            if isfield(r,'Source'), Source(end+1,1) = string(r.Source); else, Source(end+1,1) = "Benchmark"; end
        end
        T = table(Method, kPC, Acc, BalAcc, WeightedAcc, MacroF1, WeightedF1, Score, PredictMsPerSpec, MemMiBPerSpec, WallSec, MacroAUC, Source);
        if ~isempty(T)
            T = sortrows(T, {'Source','Score','Acc','MacroF1','PredictMsPerSpec'}, {'ascend','descend','descend','descend','ascend'});
        end
    end

    function exportBenchmarkBundle(Tbench, rows, outDir, kPC, K, Rrepeat, methods)
        if ~exist(outDir,'dir'), mkdir(outDir); end
        tryWriteTable(Tbench, fullfile(outDir,'BENCHMARK_RESULTS.xlsx'),'Benchmarks');
        tryWriteTable(Tbench, fullfile(outDir,'BENCHMARK_RESULTS.xlsx'),'Summary');
        writeBenchmarkSummaryTxt(Tbench, fullfile(outDir,'BENCHMARK_SUMMARY.txt'));
        writeBenchmarkManifest(Tbench, outDir, kPC, K, Rrepeat, methods);
        writeBenchmarkMethodSheets(Tbench, outDir);
        saveBenchmarkMat(Tbench, rows, outDir, kPC, K, Rrepeat, methods);
        updateUnifiedOutputManifest(app.state.outdir, 'benchmark', buildBenchmarkManifestStruct(Tbench, outDir, kPC, K, Rrepeat, methods));
    end

    function writeBenchmarkManifest(Tbench, outDir, kPC, K, Rrepeat, methods)
        txtPath = fullfile(outDir,'BENCHMARK_MANIFEST.txt');
        fid = fopen(txtPath, 'w');
        if fid < 0, return; end
        cleaner = onCleanup(@() fclose(fid));
        fprintf(fid,'RAVEN structured benchmark export\n');
        fprintf(fid,'Generated: %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
        fprintf(fid,'CodeVersion: %s\n', 'RAVEN_V1_01');
        fprintf(fid,'OutputDir: %s\n', outDir);
        fprintf(fid,'MethodsRequested: %s\n', strjoin(cellstr(string(methods)), ', '));
        fprintf(fid,'kPC: %g\n', kPC);
        fprintf(fid,'OuterFolds: %g\n', K);
        fprintf(fid,'Repeats: %g\n', Rrepeat);
        fprintf(fid,'GroupedCVRequested: %d\n', double(getNestedLogical(app.cfg, {'cv','useGroups'}, false)));
        fprintf(fid,'GroupedCVMode: %s\n', getNestedText(app.cfg, {'cv','splitMode'}, 'unknown'));
        fprintf(fid,'NRows: %d\n', height(Tbench));
        fprintf(fid,'Files:\n');
        fprintf(fid,'  - BENCHMARK_RESULTS.xlsx\n');
        fprintf(fid,'  - BENCHMARK_SUMMARY.txt\n');
        fprintf(fid,'  - BENCHMARK_MANIFEST.txt\n');
        fprintf(fid,'  - BENCHMARK_EXPORT.mat\n');
        fprintf(fid,'  - BENCHMARK_METHOD_<method>.xlsx\n');
        fprintf(fid,'\nRankingOrder: Source asc, Score desc, Acc desc, MacroF1 desc, PredictMsPerSpec asc\n');
        if ~isempty(Tbench)
            fprintf(fid,'\nTopRows:\n');
            topN = min(5,height(Tbench));
            for ii = 1:topN
                fprintf(fid,'  %d) %s | Source=%s | Acc=%.4f | MacroF1=%.4f | Score=%.4f | PredMs/spec=%.4f | MemMiB/spec=%.4f\n', ...
                    ii, char(Tbench.Method(ii)), char(Tbench.Source(ii)), Tbench.Acc(ii), Tbench.MacroF1(ii), Tbench.Score(ii), Tbench.PredictMsPerSpec(ii), Tbench.MemMiBPerSpec(ii));
            end
        end
    end

    function writeBenchmarkMethodSheets(Tbench, outDir)
        if isempty(Tbench), return; end
        vars = Tbench.Properties.VariableNames;
        for ii = 1:height(Tbench)
            rowTab = Tbench(ii,:);
            methodName = sanitizeFilename(toText(rowTab.Method(1)));
            xlsxPath = fullfile(outDir, ['BENCHMARK_METHOD_' methodName '.xlsx']);
            tryWriteTable(rowTab, xlsxPath, 'Summary');
            metaNames = {'Method';'Source';'ExportedAt';'Rank';'ScoreOrderNote'};
            metaVals = {toText(rowTab.Method(1)); toText(rowTab.Source(1)); datestr(now,'yyyy-mm-dd HH:MM:SS'); num2str(ii); 'Sorted in BENCHMARK_RESULTS.xlsx'};
            Tmeta = table(metaNames, metaVals, 'VariableNames', {'Field','Value'});
            tryWriteTable(Tmeta, xlsxPath, 'Metadata');
            Tlong = table(string(vars(:)), strings(numel(vars),1), 'VariableNames', {'Metric','Value'});
            for jj = 1:numel(vars)
                Tlong.Value(jj) = string(localValueToText(rowTab.(vars{jj})(1)));
            end
            tryWriteTable(Tlong, xlsxPath, 'LongFormat');
        end
    end

    function saveBenchmarkMat(Tbench, rows, outDir, kPC, K, Rrepeat, methods)
        S = struct();
        S.generatedAt = datestr(now,'yyyy-mm-dd HH:MM:SS');
        S.codeVersion = 'RAVEN_V1_01';
        S.outputDir = outDir;
        S.methodsRequested = methods;
        S.kPC = kPC;
        S.outerK = K;
        S.repeats = Rrepeat;
        S.groupedCVRequested = getNestedLogical(app.cfg, {'cv','useGroups'}, false);
        S.groupedCVMode = getNestedText(app.cfg, {'cv','splitMode'}, 'unknown');
        if isfield(app,'state') && isfield(app.state,'results')
            if isfield(app.state.results,'step3ModeInfo')
                S.step3ModeInfo = app.state.results.step3ModeInfo;
            end
            if isfield(app.state.results,'finalWinnerRecord')
                S.finalWinnerRecord = app.state.results.finalWinnerRecord;
            end
        end
        if isfield(app,'cfg')
            S.benchmarkCfg = app.cfg.benchmark;
            S.cvCfg = app.cfg.cv;
        end
        S.rows = rows;
        S.table = Tbench;
        save(fullfile(outDir,'BENCHMARK_EXPORT.mat'), '-struct', 'S');
    end

    function tf = getNestedLogical(S, fieldPath, defaultVal)
        tf = defaultVal;
        try
            v = getNestedField(S, fieldPath, defaultVal);
            if islogical(v)
                tf = v(1);
            elseif isnumeric(v)
                tf = logical(v(1));
            end
        catch
            tf = defaultVal;
        end
    end

    function txt = getNestedText(S, fieldPath, defaultVal)
        txt = defaultVal;
        try
            txt = toText(getNestedField(S, fieldPath, defaultVal));
            if isempty(txt), txt = defaultVal; end
        catch
            txt = defaultVal;
        end
    end

    function v = getNestedField(S, fieldPath, defaultVal)
        v = defaultVal;
        cur = S;
        for ii = 1:numel(fieldPath)
            key = fieldPath{ii};
            if ~isstruct(cur) || ~isfield(cur, key)
                v = defaultVal;
                return;
            end
            cur = cur.(key);
        end
        v = cur;
    end

    function txt = localValueToText(v)
        if isstring(v)
            txt = char(v(1));
        elseif ischar(v)
            txt = v;
        elseif isnumeric(v) || islogical(v)
            if isempty(v)
                txt = '';
            elseif isscalar(v)
                txt = num2str(double(v));
            else
                txt = mat2str(v);
            end
        elseif iscell(v)
            try
                txt = strjoin(cellfun(@localValueToText, v, 'UniformOutput', false), ', ');
            catch
                txt = '[cell]';
            end
        else
            txt = class(v);
        end
    end

    function safe = sanitizeFilename(txt)
        safe = regexprep(toText(txt), '[^A-Za-z0-9_\-]+', '_');
        safe = regexprep(safe, '_+', '_');
        safe = regexprep(safe, '^_+|_+$', '');
        if isempty(safe)
            safe = 'unnamed';
        end
    end

    function writeBenchmarkSummaryTxt(Tbench, txtPath)
        fid = fopen(txtPath, 'w');
        if fid < 0, return; end
        cleaner = onCleanup(@() fclose(fid));
        fprintf(fid,'Benchmark summary\n');
        fprintf(fid,'Generated: %s\n\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
        for ii = 1:height(Tbench)
            fprintf(fid,'%s | Source=%s | kPC=%g | Acc=%.4f | WeightedAcc=%.4f | MacroF1=%.4f | WeightedF1=%.4f | Score=%.4f | PredMs/spec=%.4f | MemMiB/spec=%.4f\n', ...
                char(Tbench.Method(ii)), char(Tbench.Source(ii)), Tbench.kPC(ii), Tbench.Acc(ii), Tbench.WeightedAcc(ii), Tbench.MacroF1(ii), Tbench.WeightedF1(ii), ...
                Tbench.Score(ii), Tbench.PredictMsPerSpec(ii), Tbench.MemMiBPerSpec(ii));
        end
    end

    function txt = summarizeBestBenchmark(Tbench)
        txt = 'n/a';
        if isempty(Tbench) || ~ismember('Acc', Tbench.Properties.VariableNames), return; end
        [mx,ix] = max(Tbench.Acc);
        if isempty(ix) || ~isfinite(mx), return; end
        txt = sprintf('%s (%.2f%%)', char(Tbench.Method(ix)), 100*mx);
    end

    function onClose(~,~)
        if app.state.isRunning
            q = questdlg('Pipeline is still running. Close anyway?','RAVEN','Yes','No','No');
            if ~strcmpi(q,'Yes')
                return;
            end
        end
        delete(app.ui.fig);
    end
    function txt = getScalarTextFromTableVar(Trow, varName)
        txt = '';
        if ~istable(Trow) || height(Trow) < 1 || ~ismember(varName, Trow.Properties.VariableNames)
            return;
        end
        v = Trow.(varName);
        if iscell(v)
            if isempty(v)
                txt = '';
            else
                txt = char(string(v{1}));
            end
        elseif isstring(v)
            if isempty(v)
                txt = '';
            else
                txt = char(v(1));
            end
        elseif ischar(v)
            txt = v;
        else
            txt = char(string(v(1)));
        end
    end

    function x = getScalarNumericFromTableVar(Trow, varName)
        x = NaN;
        if ~istable(Trow) || height(Trow) < 1 || ~ismember(varName, Trow.Properties.VariableNames)
            return;
        end
        v = Trow.(varName);
        if iscell(v)
            if isempty(v)
                x = NaN;
            else
                x = double(v{1});
            end
        else
            x = double(v(1));
        end
    end

end

