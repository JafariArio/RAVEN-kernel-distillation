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
