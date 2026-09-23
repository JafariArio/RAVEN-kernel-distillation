function res = raven_eval_teacher_worker(X, y, C, teacherCfg, K, Rrepeat, seedBase, doFull, numROC, splitMode, groupVector)
X = local_unwrap_parallel_input(X);
y = local_unwrap_parallel_input(y);
groupVector = local_unwrap_parallel_input(groupVector);

N = size(X,1);
accVec = zeros(Rrepeat,1); balVec = zeros(Rrepeat,1); wtAccVec = zeros(Rrepeat,1);
f1Vec = zeros(Rrepeat,1); wtF1Vec = zeros(Rrepeat,1); memVec = zeros(Rrepeat,1);
predMsVec = zeros(Rrepeat,1); wallVec = zeros(Rrepeat,1); wallMsVec = zeros(Rrepeat,1); dimVec = zeros(Rrepeat,1);
repeatCM = zeros(C,C,Rrepeat); allTrue=[]; allScores=[]; allPred=[]; repeatTrue=cell(Rrepeat,1); repeatPred=cell(Rrepeat,1); repeatScores=cell(Rrepeat,1);
for rr = 1:Rrepeat
    foldIdx = local_make_folds_with_seed(y, K, groupVector, splitMode, seedBase + rr);
    CMrep = zeros(C,C); trueRep=[]; predRep=[]; scoreRep=[]; predMsFold=zeros(K,1); memFold=zeros(K,1); dimFold=zeros(K,1);
    tRep = tic;
    for f = 1:K
        tr = foldIdx ~= f; te = foldIdx == f;
        [Str, Ste, ytr, yte] = local_fold_pca(X, y, tr, te, teacherCfg.kPC);
        mdlT = local_fit_teacher(Str, ytr, teacherCfg, C, seedBase + 1000*rr + f);
        [yhat, scoreTe, predMs, memMiB] = local_predict_teacher(mdlT, Ste);
        predMsFold(f) = predMs; memFold(f) = memMiB; dimFold(f) = mdlT.rEff;
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
    support = sum(CMrep,2); wClass = support ./ max(1,sum(support));
    balVec(rr) = mean(recall,'omitnan'); wtAccVec(rr) = sum(wClass .* recall,'omitnan');
    f1Vec(rr) = mean(f1,'omitnan'); wtF1Vec(rr) = sum(wClass .* f1,'omitnan');
    memVec(rr) = median(memFold); predMsVec(rr) = mean(predMsFold,'omitnan'); wallVec(rr) = toc(tRep); wallMsVec(rr) = 1000*wallVec(rr)/max(1,N); dimVec(rr) = median(dimFold);
    repeatCM(:,:,rr) = CMrep; repeatTrue{rr}=trueRep; repeatPred{rr}=predRep; repeatScores{rr}=scoreRep;
end
CMmean = mean(repeatCM,3); recallMean = diag(CMmean) ./ max(1, sum(CMmean,2)); precMean = diag(CMmean) ./ max(1, sum(CMmean,1)'); F1class = 2*(precMean.*recallMean) ./ max(1e-12, precMean + recallMean);
res = struct();
res.Acc = mean(accVec); res.BalAcc = mean(balVec); res.WeightedAcc = mean(wtAccVec); res.MacroF1 = mean(f1Vec); res.WeightedF1 = mean(wtF1Vec);
res.AccTeacher = res.Acc; res.RatioToTeacher = 1; res.S2 = nan; res.LowOccFrac = nan; res.CondMed = nan; res.FeatDimMed = median(dimVec); res.MemMiBPerSpec = median(memVec);
res.WallSec = mean(wallVec); res.WallMsPerSpec = mean(wallMsVec); res.PredictMsPerSpec = mean(predMsVec,'omitnan'); res.CMmean = CMmean; res.RecallPerClass = recallMean; res.PrecisionPerClass = precMean; res.F1PerClass = F1class; res.cfg = teacherCfg;
res.Score = 0.70*res.Acc + 0.20*res.MacroF1 + 0.07*(1/(1+res.WallMsPerSpec)) + 0.03*(1/(1+res.MemMiBPerSpec));
repScore = 0.70*accVec + 0.20*f1Vec + 0.07*(1./(1+wallMsVec)) + 0.03*(1./(1+memVec));
res.RepeatMetrics = table((1:Rrepeat)', accVec, balVec, wtAccVec, f1Vec, wtF1Vec, repmat(nan,Rrepeat,1), repmat(nan,Rrepeat,1), repmat(nan,Rrepeat,1), dimVec, memVec, wallVec, wallMsVec, predMsVec, dimVec, repScore, ...
    'VariableNames', {'Repeat','Acc','BalAcc','WeightedAcc','MacroF1','WeightedF1','S2','LowOccFrac','CondMed','FeatDimMed','MemMiBPerSpec','WallSec','WallMsPerSpec','PredictMsPerSpec','RankMean','Score'});
res.RepeatCM = repeatCM; [~,bestRep] = max(accVec + 1e-6*f1Vec - 1e-6*wallMsVec); res.BestRepeatIndex = bestRep; res.CMBest = repeatCM(:,:,bestRep);
if doFull && ~isempty(allScores)
    [fprGrid, tprGrid, aucPerClass, microAUC, macroAUC, microTPR, macroTPR] = local_make_roc(allTrue, allScores, C, numROC);
    res.ROC_FPR = fprGrid; res.ROC_TPR = tprGrid; res.AUCPerClass = aucPerClass; res.MicroAUC = microAUC; res.MacroAUC = macroAUC; res.ROC_MicroTPR = microTPR; res.ROC_MacroTPR = macroTPR;
    [bfpr, btpr, bauc, bmicro, bmacro, bmicroTPR, bmacroTPR] = local_make_roc(repeatTrue{bestRep}, repeatScores{bestRep}, C, numROC);
    res.ROCbest_FPR = bfpr; res.ROCbest_TPR = btpr; res.AUCbest_PerClass = bauc; res.MicroAUC_Best = bmicro; res.MacroAUC_Best = bmacro; res.ROCbest_MicroTPR = bmicroTPR; res.ROCbest_MacroTPR = bmacroTPR;
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

function foldIdx = local_make_folds_with_seed(y, K, groupIDs, mode, seed)
st = rng; cleanup = onCleanup(@() rng(st));
rng(seed,'twister');
foldIdx = local_make_folds(y, K, groupIDs, mode);
end
function foldIdx = local_make_folds(y, K, groupIDs, mode)
if nargin < 4 || isempty(mode), mode = 'stratified'; end
if strcmpi(mode,'grouped') && ~isempty(groupIDs) && numel(groupIDs) == numel(y)
    [gNorm, missingMask] = local_normalize_groups(groupIDs);
    if ~any(missingMask)
        if numel(unique(gNorm,'stable')) >= K
            foldIdx = local_make_grouped_stratified_folds(y, gNorm, K); return;
        end
    end
end
foldIdx = local_make_stratified_folds(y,K);
end
function [gNorm, missingMask] = local_normalize_groups(gRaw)
if isnumeric(gRaw) || islogical(gRaw), gNorm = string(gRaw(:)); missingMask = isnan(double(gRaw(:)));
elseif isstring(gRaw), gNorm = gRaw(:); missingMask = ismissing(gNorm);
elseif iscell(gRaw)
    gNorm = strings(numel(gRaw),1); missingMask = false(numel(gRaw),1);
    for ii=1:numel(gRaw)
        try sval = strtrim(char(string(gRaw{ii}))); catch, sval=''; end
        if isempty(sval), missingMask(ii)=true; else, gNorm(ii)=string(sval); end
    end
else
    try gNorm = string(gRaw(:)); missingMask = ismissing(gNorm); catch, gNorm = strings(numel(gRaw),1); missingMask = true(numel(gRaw),1); end
end
if numel(missingMask) ~= numel(gNorm), missingMask = false(size(gNorm)); end
end
function foldIdx = local_make_grouped_stratified_folds(y, groupIDs, K)
y = y(:); groupIDs = groupIDs(:); [G,~,gix] = unique(groupIDs,'stable'); groupClass = zeros(numel(G),1);
for gi=1:numel(G)
    yy = y(gix==gi); ux = unique(yy(:)'); n = zeros(size(ux));
    for ii=1:numel(ux), n(ii) = sum(yy==ux(ii)); end
    [~,ix] = max(n); groupClass(gi)=ux(ix);
end
foldByGroup = zeros(numel(G),1); cls = unique(groupClass)';
for cc = cls
    giList = find(groupClass==cc); giList = giList(randperm(numel(giList)));
    for ii=1:numel(giList), foldByGroup(giList(ii)) = mod(ii-1,K)+1; end
end
foldIdx = foldByGroup(gix);
end
function foldIdx = local_make_stratified_folds(y,K)
foldIdx = zeros(numel(y),1); classes = unique(y(:))';
for c = classes
    idx = find(y==c); idx = idx(randperm(numel(idx))); edges = round(linspace(0,numel(idx),K+1));
    for f = 1:K
        if edges(f) < edges(f+1), foldIdx(idx(edges(f)+1:edges(f+1))) = f; end
    end
end
end
function [Str, Ste, ytr, yte] = local_fold_pca(X, y, tr, te, kPC)
ytr = y(tr); yte = y(te); Xtr = X(tr,:); Xte = X(te,:); mu = mean(Xtr,1); Xtrc = bsxfun(@minus, Xtr, mu); Xtec = bsxfun(@minus, Xte, mu);
kEff = min([kPC, size(Xtrc,1)-1, size(Xtrc,2)]); if kEff < 1, kEff = 1; end
[coeff, scoreTr] = pca(Xtrc, 'NumComponents', kEff, 'Centered', false); Str = scoreTr(:,1:kEff); Ste = Xtec * coeff(:,1:kEff);
end
function mdlT = local_fit_teacher(Str, ytr, teacherCfg, C, seed)
rng(seed,'twister'); ntr = size(Str,1); mEff = min(max(2,round(teacherCfg.mLand)), ntr); idxLand = randperm(ntr, mEff); SL = Str(idxLand,:);
A2 = sum(SL.^2,2); D2SS = bsxfun(@plus, A2, A2.') - 2*(SL*SL.'); D2SS = max(D2SS,0); dvec = sqrt(D2SS(triu(true(size(D2SS)),1))); dvec = dvec(isfinite(dvec) & dvec > 0); med = median(dvec); if ~(isfinite(med) && med > 0), med = 1.0; end
sigma_fold = teacherCfg.sigmaScale * (med/sqrt(2)); if ~(isfinite(sigma_fold) && sigma_fold > 0), sigma_fold = 1.0; end; gamma = 1/(2*sigma_fold^2);
KSS = exp(-gamma * D2SS); KSS = (KSS + KSS.')/2; rReq = min(max(1,round(teacherCfg.rTeach)), mEff);
try, [Ur,DD] = eigs(KSS, rReq, 'la'); lamr = max(real(diag(DD)),0); catch, [Ue,DD] = eig(KSS); lamAll = real(diag(DD)); [lamAll,ord] = sort(lamAll,'descend'); Ue = Ue(:,ord); lamAll = max(lamAll,0); keep = find(lamAll > 1e-12); if isempty(keep), keep = 1; end; rEff0 = min(rReq, numel(keep)); Ur = Ue(:,1:rEff0); lamr = lamAll(1:rEff0); end
keep2 = find(lamr > 1e-12); if isempty(keep2), keep2 = 1; end; rEff = min(numel(lamr), numel(keep2)); Ur = Ur(:,1:rEff); lamr = lamr(1:rEff); invSqrtLam = 1./sqrt(max(lamr(:).',1e-12));
A2tr = sum(Str.^2,2); B2L = sum(SL.^2,2).'; D2trL = bsxfun(@plus, A2tr, B2L) - 2*(Str*SL.'); D2trL = max(D2trL,0); KtrL = exp(-gamma * D2trL); Phi_tr = KtrL * Ur; Phi_tr = bsxfun(@times, Phi_tr, invSqrtLam); Phi_tr = Phi_tr ./ max(1e-12, sqrt(sum(Phi_tr.^2,2)));
tSVM = templateSVM('KernelFunction','linear','Standardize',true,'BoxConstraint',teacherCfg.boxC); MdlT = fitcecoc(Phi_tr, ytr, 'Learners', tSVM, 'ClassNames', 1:C, 'Coding', 'onevsall'); [~, scoreT_tr] = predict(MdlT, Phi_tr); if size(scoreT_tr,2) ~= C, tmp=zeros(size(scoreT_tr,1),C); tmp(:,1:min(C,size(scoreT_tr,2))) = scoreT_tr(:,1:min(C,size(scoreT_tr,2))); scoreT_tr = tmp; end
mdlT = struct('SL',SL,'gamma',gamma,'Ur',Ur,'invSqrtLam',invSqrtLam,'classifier',MdlT,'rEff',rEff,'mEff',mEff,'scoreTr',scoreT_tr,'sigma',sigma_fold);
end
function [yhat, scores, predMs, memMiB] = local_predict_teacher(mdlT, Ste)
t0 = tic; A2te = sum(Ste.^2,2); B2L = sum(mdlT.SL.^2,2).'; D2teL = bsxfun(@plus, A2te, B2L) - 2*(Ste*mdlT.SL.'); D2teL = max(D2teL,0); KteL = exp(-mdlT.gamma * D2teL); Phi_te = KteL * mdlT.Ur; Phi_te = bsxfun(@times, Phi_te, mdlT.invSqrtLam); Phi_te = Phi_te ./ max(1e-12, sqrt(sum(Phi_te.^2,2))); [yhat, scores] = predict(mdlT.classifier, Phi_te); predMs = 1000*toc(t0) / max(1,size(Ste,1)); memMiB = 8*(numel(D2teL) + numel(KteL) + numel(Phi_te) + numel(scores)) / max(1,size(Ste,1)) / 1024^2;
end
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
