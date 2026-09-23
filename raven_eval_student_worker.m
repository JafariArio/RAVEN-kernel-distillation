function res = raven_eval_student_worker(varargin)
if nargin >= 4 && isstruct(local_unwrap_parallel_input(varargin{1}))
    cache = local_unwrap_parallel_input(varargin{1});
    if isfield(cache,'isTeacherCache') && cache.isTeacherCache
        studentCfg = varargin{2};
        doFull = varargin{3};
        numROC = varargin{4};
        res = local_eval_from_cache(cache, studentCfg, doFull, numROC);
        return;
    end
end
X = varargin{1}; y = varargin{2}; C = varargin{3}; teacherCfg = varargin{4}; studentCfg = varargin{5};
K = varargin{6}; Rrepeat = varargin{7}; seedBase = varargin{8}; doFull = varargin{9}; numROC = varargin{10}; splitMode = varargin{11}; groupVector = varargin{12};
cache = raven_build_teacher_cache(X, y, C, teacherCfg, K, Rrepeat, seedBase, splitMode, groupVector);
res = local_eval_from_cache(cache, studentCfg, doFull, numROC);
res.cfg.teacher = teacherCfg;
end

function res = local_eval_from_cache(cache, studentCfg, doFull, numROC)
C = cache.C; K = cache.K; Rrepeat = cache.Rrepeat; N = cache.N;
accVec = zeros(Rrepeat,1); accTVec = zeros(Rrepeat,1); balVec = zeros(Rrepeat,1); wtAccVec = zeros(Rrepeat,1); f1Vec = zeros(Rrepeat,1); wtF1Vec = zeros(Rrepeat,1); memVec = zeros(Rrepeat,1); predMsVec = zeros(Rrepeat,1); wallVec = zeros(Rrepeat,1); wallMsVec = zeros(Rrepeat,1); dimVec = zeros(Rrepeat,1); repeatCM = zeros(C,C,Rrepeat); allTrue=[]; allScores=[]; allPred=[]; repeatTrue=cell(Rrepeat,1); repeatPred=cell(Rrepeat,1); repeatScores=cell(Rrepeat,1);
for rr = 1:Rrepeat
    CMrep = zeros(C,C); accTfold=zeros(K,1); predMsFold=zeros(K,1); memFold=zeros(K,1); dimFold=zeros(K,1); trueRep=[]; predRep=[]; scoreRep=[]; tRep=tic;
    for f = 1:K
        fd = cache.folds(rr,f);
        Str = fd.Str; ytr = fd.ytr; yte = fd.yte; Ste = fd.Ste;
        temp2 = max(1e-6, studentCfg.temp); Z = fd.scoreT_tr / temp2; Z = Z - max(Z,[],2); Pteach = exp(Z); Pteach = Pteach ./ max(1e-12, sum(Pteach,2)); Yoh = zeros(size(Str,1), C); Yoh(sub2ind([size(Str,1) C], (1:size(Str,1))', ytr)) = 1; a2 = max(0,min(1,studentCfg.alpha)); Ttr = a2*Pteach + (1-a2)*Yoh;
        mdlS = local_fit_student(Str, Ttr, studentCfg, cache.seedBase + 10000*rr + 100*f);
        [yhatS, scoreS, predMsS, memS] = local_predict_student(mdlS, Ste);
        accTfold(f) = fd.teacherAcc;
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
    accVec(rr) = sum(diag(CMrep)) / max(1, sum(CMrep(:))); accTVec(rr) = mean(accTfold); recall = diag(CMrep) ./ max(1, sum(CMrep,2)); prec = diag(CMrep) ./ max(1, sum(CMrep,1)'); f1 = 2*(prec.*recall) ./ max(1e-12, prec + recall); support = sum(CMrep,2); wClass = support ./ max(1,sum(support)); balVec(rr)=mean(recall,'omitnan'); wtAccVec(rr)=sum(wClass.*recall,'omitnan'); f1Vec(rr)=mean(f1,'omitnan'); wtF1Vec(rr)=sum(wClass.*f1,'omitnan'); memVec(rr)=median(memFold); predMsVec(rr)=mean(predMsFold,'omitnan'); wallVec(rr)=toc(tRep); wallMsVec(rr)=1000*wallVec(rr)/max(1,N); dimVec(rr)=median(dimFold); repeatCM(:,:,rr)=CMrep; repeatTrue{rr}=trueRep; repeatPred{rr}=predRep; repeatScores{rr}=scoreRep;
end
CMmean = mean(repeatCM,3); recallMean = diag(CMmean) ./ max(1, sum(CMmean,2)); precMean = diag(CMmean) ./ max(1, sum(CMmean,1)'); F1class = 2*(precMean.*recallMean) ./ max(1e-12, precMean + recallMean);
res = struct(); res.Acc = mean(accVec); res.AccTeacher = mean(accTVec); res.RatioToTeacher = res.Acc / max(1e-12, res.AccTeacher); res.BalAcc = mean(balVec); res.WeightedAcc = mean(wtAccVec); res.MacroF1 = mean(f1Vec); res.WeightedF1 = mean(wtF1Vec); res.S2=nan; res.LowOccFrac=nan; res.CondMed=nan; res.FeatDimMed=median(dimVec); res.MemMiBPerSpec=median(memVec); res.WallSec=mean(wallVec); res.WallMsPerSpec=mean(wallMsVec); res.PredictMsPerSpec=mean(predMsVec,'omitnan'); res.CMmean=CMmean; res.RecallPerClass=recallMean; res.PrecisionPerClass=precMean; res.F1PerClass=F1class; res.cfg = struct('teacher',cache.teacherCfg,'student',studentCfg); res.Score = 0.55*res.Acc + 0.20*res.MacroF1 + 0.15*min(1.25,res.RatioToTeacher)/1.25 + 0.06*(1/(1+res.WallMsPerSpec)) + 0.04*(1/(1+res.MemMiBPerSpec)); repRatio = accVec ./ max(1e-12, accTVec); repScore = 0.55*accVec + 0.20*f1Vec + 0.15*min(1.25,repRatio)/1.25 + 0.06*(1./(1+wallMsVec)) + 0.04*(1./(1+memVec));
res.RepeatMetrics = table((1:Rrepeat)', accVec, balVec, wtAccVec, f1Vec, wtF1Vec, repmat(nan,Rrepeat,1), repmat(nan,Rrepeat,1), repmat(nan,Rrepeat,1), dimVec, memVec, wallVec, wallMsVec, predMsVec, repRatio, repScore, 'VariableNames', {'Repeat','Acc','BalAcc','WeightedAcc','MacroF1','WeightedF1','S2','LowOccFrac','CondMed','FeatDimMed','MemMiBPerSpec','WallSec','WallMsPerSpec','PredictMsPerSpec','RankMean','Score'}); res.RepeatCM=repeatCM; [~,bestRep]=max(accVec + 1e-6*f1Vec - 1e-6*wallMsVec); res.BestRepeatIndex=bestRep; res.CMBest=repeatCM(:,:,bestRep);
if doFull && ~isempty(allScores)
    [fprGrid, tprGrid, aucPerClass, microAUC, macroAUC, microTPR, macroTPR] = local_make_roc(allTrue, allScores, C, numROC);
    res.ROC_FPR=fprGrid; res.ROC_TPR=tprGrid; res.AUCPerClass=aucPerClass; res.MicroAUC=microAUC; res.MacroAUC=macroAUC; res.ROC_MicroTPR=microTPR; res.ROC_MacroTPR=macroTPR;
    [bfpr, btpr, bauc, bmicro, bmacro, bmicroTPR, bmacroTPR] = local_make_roc(repeatTrue{bestRep}, repeatScores{bestRep}, C, numROC);
    res.ROCbest_FPR=bfpr; res.ROCbest_TPR=btpr; res.AUCbest_PerClass=bauc; res.MicroAUC_Best=bmicro; res.MacroAUC_Best=bmacro; res.ROCbest_MicroTPR=bmicroTPR; res.ROCbest_MacroTPR=bmacroTPR;
end
end

function v = local_unwrap_parallel_input(v)
try
    if isa(v, 'parallel.pool.Constant')
        v = v.Value;
    end
catch
end
end

function mdlS = local_fit_student(Str, Ttr, studentCfg, seedBase)
ntr=size(Str,1); dRk=size(Str,2); ens=max(1, round(studentCfg.ensemble)); member=cell(ens,1); featDim=max(1, round(studentCfg.pHidden)) + (studentCfg.skipScale > 0) * dRk;
for ee = 1:ens
    rng(seedBase + ee,'twister'); Wrand = randn(max(1,round(studentCfg.pHidden)), dRk) / sqrt(max(1,dRk)); brand = randn(max(1,round(studentCfg.pHidden)), 1); ZtrH = bsxfun(@plus, Wrand*Str.', brand); Htr = tanh(ZtrH); if studentCfg.skipScale > 0, Htr = [Htr; (studentCfg.skipScale*Str.')]; end; pEff = size(Htr,1); lam = max(1e-12, studentCfg.lamRidge); if pEff <= ntr, Gp = (Htr*Htr.') + lam*eye(pEff); RHS = Htr * Ttr; ok = true; try, Lc = chol(Gp,'lower'); catch, ok = false; end; if ok, Aout = Lc'\(Lc\RHS); else, Aout = (Gp + 1e-8*eye(pEff)) \ RHS; end; else, Gn = (Htr.'*Htr) + lam*eye(ntr); ok = true; try, Lc = chol(Gn,'lower'); catch, ok = false; end; if ok, Tm = Lc'\(Lc\Ttr); else, Tm = (Gn + 1e-8*eye(ntr)) \ Ttr; end; Aout = Htr * Tm; end; member{ee}=struct('Wrand',Wrand,'brand',brand,'Aout',Aout); end
mdlS = struct('member',{member},'skipScale',studentCfg.skipScale,'ensemble',ens,'featDim',featDim); end
function [yhat, scores, predMs, memMiB] = local_predict_student(mdlS, Ste)
ens = numel(mdlS.member); scoreSum=[]; memBytes=0; t0=tic; for ee=1:ens, mm=mdlS.member{ee}; ZteH = bsxfun(@plus, mm.Wrand*Ste.', mm.brand); Hte = tanh(ZteH); if mdlS.skipScale > 0, Hte = [Hte; (mdlS.skipScale*Ste.')]; end; scoreNow = Hte.' * mm.Aout; if isempty(scoreSum), scoreSum = scoreNow; else, scoreSum = scoreSum + scoreNow; end; memBytes = memBytes + 8*(numel(ZteH)+numel(Hte)+numel(scoreNow)); end; scores = scoreSum / max(1,ens); [~, yhat] = max(scores, [], 2); predMs = 1000*toc(t0) / max(1,size(Ste,1)); memMiB = memBytes / max(1,size(Ste,1)) / 1024^2; end
function [fprGrid, tprGrid, aucPerClass, microAUC, macroAUC, microTPR, macroTPR] = local_make_roc(Y, Scores, C, numROC)
if isempty(Scores) || size(Scores,2) ~= C, fprGrid = linspace(0,1,numROC)'; tprGrid=zeros(numROC,C); aucPerClass=0.5*ones(C,1); microAUC=0.5; macroAUC=0.5; microTPR=fprGrid; macroTPR=fprGrid; return; end
fprGrid = linspace(0,1,numROC)'; tprGrid=zeros(numROC,C); aucPerClass=zeros(C,1);
for c=1:C
    ybin=(Y==c); sc=Scores(:,c); [~, idx] = sort(sc,'descend'); yord = ybin(idx); P=sum(yord); Nn=numel(yord)-P;
    if P==0 || Nn==0
        fpr=[0;1]; tpr=[0;1]; auc=0.5;
    else
        tp=cumsum(yord==1); fp=cumsum(yord==0); tpr=[0; tp/max(1,P); 1]; fpr=[0; fp/max(1,Nn); 1]; [fpr, tpr] = local_prepare_interp_xy(fpr, tpr); auc=trapz(fpr,tpr);
    end
    tprGrid(:,c)=local_safe_interp_curve(fpr,tpr,fprGrid); aucPerClass(c)=auc;
end
macroTPR=mean(tprGrid,2,'omitnan'); macroAUC=mean(aucPerClass,'omitnan'); Yoh=zeros(numel(Y),C); Yoh(sub2ind([numel(Y),C],(1:numel(Y))',Y(:)))=1; yflat=Yoh(:); sflat=Scores(:); [~,idx] = sort(sflat,'descend'); yord=yflat(idx); P=sum(yord); Nn=numel(yord)-P; if P==0 || Nn==0, microTPR=fprGrid; microAUC=0.5; else, tp=cumsum(yord==1); fp=cumsum(yord==0); tpr=[0; tp/max(1,P); 1]; fpr=[0; fp/max(1,Nn); 1]; [fpr, tpr] = local_prepare_interp_xy(fpr, tpr); microTPR=local_safe_interp_curve(fpr,tpr,fprGrid); microAUC=trapz(fpr,tpr); end; end
function yq = local_safe_interp_curve(x, y, xq)
[x, y] = local_prepare_interp_xy(x, y); yq = interp1(x, y, xq, 'linear', 'extrap'); yq = min(max(yq,0),1); end
function [x, y] = local_prepare_interp_xy(x, y)
x = x(:); y = y(:); keep = isfinite(x) & isfinite(y); x = x(keep); y = y(keep);
if isempty(x), x = [0;1]; y = [0;1]; return; end
[x, ord] = sort(x, 'ascend'); y = y(ord); y = min(max(y,0),1); y = cummax(y);
[xu, ~, ic] = unique(x, 'stable'); yu = accumarray(ic, y, [], @max); x = xu; y = yu;
if x(1) > 0, x = [0; x]; y = [0; y]; elseif x(1) < 0, x(1) = 0; end
if x(end) < 1, x = [x; 1]; y = [y; 1]; elseif x(end) > 1, x(end) = 1; end
if numel(x) < 2 || any(diff(x) <= 0), x = [0;1]; y = [0;1]; end
end
