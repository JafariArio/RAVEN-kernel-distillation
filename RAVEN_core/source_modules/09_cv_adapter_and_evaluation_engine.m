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
