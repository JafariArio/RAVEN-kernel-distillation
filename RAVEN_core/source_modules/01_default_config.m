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
