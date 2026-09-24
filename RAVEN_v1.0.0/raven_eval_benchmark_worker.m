function row = raven_eval_benchmark_worker(X, y, C, methodName, kPC, K, Rrepeat, seedBase, benchmarkCfg, splitMode, groupVector)
X = local_unwrap_parallel_input(X);
y = local_unwrap_parallel_input(y);
groupVector = local_unwrap_parallel_input(groupVector);

N = size(X,1); accVec=zeros(Rrepeat,1); balVec=zeros(Rrepeat,1); wtAccVec=zeros(Rrepeat,1); f1Vec=zeros(Rrepeat,1); wtF1Vec=zeros(Rrepeat,1); wallVec=zeros(Rrepeat,1); predMsVec=nan(Rrepeat,1); memVec=nan(Rrepeat,1); aucVec=nan(Rrepeat,1);
for rr = 1:Rrepeat
    foldIdx = local_make_folds_with_seed(y,K,groupVector,splitMode,seedBase+rr); CMrep=zeros(C,C); repScores=[]; repTrue=[]; predFold=nan(K,1); memFold=nan(K,1); tRep=tic;
    for f = 1:K
        tr = foldIdx ~= f; te = foldIdx == f; [Str, Ste, ytr, yte] = local_fold_pca(X, y, tr, te, kPC);
        [mdl, predictFcn, modelBytes] = local_fit_benchmark(Str, ytr, C, methodName, benchmarkCfg);
        tPred = tic; [yhat, scores] = predictFcn(Ste); predFold(f) = 1000*toc(tPred) / max(1,numel(yte)); memFold(f) = modelBytes / max(1,numel(yte)) / 1024^2;
        if size(scores,2) ~= C, scores = local_pad_scores(scores, C, yhat); end
        repTrue = [repTrue; yte];
        repScores = [repScores; scores];
        for jj=1:numel(yte), CMrep(yte(jj), yhat(jj)) = CMrep(yte(jj), yhat(jj)) + 1; end
    end
    accVec(rr)=sum(diag(CMrep))/max(1,sum(CMrep(:))); recall=diag(CMrep) ./ max(1,sum(CMrep,2)); prec=diag(CMrep) ./ max(1,sum(CMrep,1)'); f1=2*(prec.*recall) ./ max(1e-12,prec+recall); support=sum(CMrep,2); wClass=support ./ max(1,sum(support)); balVec(rr)=mean(recall,'omitnan'); wtAccVec(rr)=sum(wClass .* recall,'omitnan'); f1Vec(rr)=mean(f1,'omitnan'); wtF1Vec(rr)=sum(wClass .* f1,'omitnan'); wallVec(rr)=toc(tRep); predMsVec(rr)=mean(predFold,'omitnan'); memVec(rr)=mean(memFold,'omitnan'); try [~,~,~,~,macroAUC] = local_make_roc(repTrue, repScores, C, 100); aucVec(rr)=macroAUC; catch, aucVec(rr)=NaN; end
end
row = struct(); row.Method = methodName; row.kPC = kPC; row.Acc = mean(accVec,'omitnan'); row.BalAcc = mean(balVec,'omitnan'); row.WeightedAcc = mean(wtAccVec,'omitnan'); row.MacroF1 = mean(f1Vec,'omitnan'); row.WeightedF1 = mean(wtF1Vec,'omitnan'); row.Score = 100*row.MacroF1 + 20*row.BalAcc + 5*row.Acc - 0.02*mean(wallVec,'omitnan') - 0.2*mean(memVec,'omitnan'); row.PredictMsPerSpec = mean(predMsVec,'omitnan'); row.MemMiBPerSpec = mean(memVec,'omitnan'); row.WallSec = mean(wallVec,'omitnan'); row.MacroAUC = mean(aucVec,'omitnan'); row.Source = 'Benchmark';
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
rng(seed,'twister'); foldIdx = local_make_folds(y, K, groupIDs, mode); end
function foldIdx = local_make_folds(y, K, groupIDs, mode)
if nargin < 4 || isempty(mode), mode='stratified'; end
if strcmpi(mode,'grouped') && ~isempty(groupIDs) && numel(groupIDs)==numel(y)
    try [gNorm, missingMask] = local_normalize_groups(groupIDs); if ~any(missingMask) && numel(unique(gNorm,'stable'))>=K, foldIdx = local_make_grouped_stratified_folds(y,gNorm,K); return; end; catch, end
end
foldIdx = local_make_stratified_folds(y,K); end
function [gNorm, missingMask] = local_normalize_groups(gRaw)
if isnumeric(gRaw) || islogical(gRaw), gNorm=string(gRaw(:)); missingMask=isnan(double(gRaw(:))); elseif isstring(gRaw), gNorm=gRaw(:); missingMask=ismissing(gNorm); else, gNorm=string(gRaw(:)); missingMask=ismissing(gNorm); end; if numel(missingMask) ~= numel(gNorm), missingMask=false(size(gNorm)); end; end
function foldIdx = local_make_grouped_stratified_folds(y, groupIDs, K)
y=y(:); groupIDs=groupIDs(:); [G,~,gix] = unique(groupIDs,'stable'); groupClass=zeros(numel(G),1); for gi=1:numel(G), yy=y(gix==gi); ux=unique(yy(:)'); n=zeros(size(ux)); for ii=1:numel(ux), n(ii)=sum(yy==ux(ii)); end; [~,ix]=max(n); groupClass(gi)=ux(ix); end; foldByGroup=zeros(numel(G),1); cls=unique(groupClass)'; for cc=cls, giList=find(groupClass==cc); giList=giList(randperm(numel(giList))); for ii=1:numel(giList), foldByGroup(giList(ii))=mod(ii-1,K)+1; end, end; foldIdx=foldByGroup(gix); end
function foldIdx = local_make_stratified_folds(y,K)
foldIdx=zeros(numel(y),1); classes=unique(y(:))'; for c=classes, idx=find(y==c); idx=idx(randperm(numel(idx))); edges=round(linspace(0,numel(idx),K+1)); for f=1:K, if edges(f)<edges(f+1), foldIdx(idx(edges(f)+1:edges(f+1)))=f; end, end, end; end
function [Str, Ste, ytr, yte] = local_fold_pca(X, y, tr, te, kPC)
ytr=y(tr); yte=y(te); Xtr=X(tr,:); Xte=X(te,:); mu=mean(Xtr,1); Xtrc=bsxfun(@minus,Xtr,mu); Xtec=bsxfun(@minus,Xte,mu); kEff=min([kPC,size(Xtrc,1)-1,size(Xtrc,2)]); if kEff < 1, kEff = 1; end; [coeff, scoreTr] = pca(Xtrc,'NumComponents',kEff,'Centered',false); Str=scoreTr(:,1:kEff); Ste=Xtec * coeff(:,1:kEff); end
function [mdl, predictFcn, modelBytes] = local_fit_benchmark(Str, ytr, C, methodName, benchmarkCfg)
switch upper(methodName)
    case 'PCA_LINSVM'
        tSVM = templateSVM('KernelFunction','linear','Standardize',true,'BoxConstraint',benchmarkCfg.boxC);
        mdl = fitcecoc(Str, ytr, 'Learners', tSVM, 'ClassNames', 1:C, 'Coding','onevsall');
        try mdl = fitPosterior(mdl, Str, ytr); catch, end
        predictFcn = @(Xin) local_predict_ecoc(mdl, Xin, C);
    case 'PCA_LDA'
        mdl = fitcdiscr(Str, ytr, 'DiscrimType','pseudoLinear', 'ClassNames', 1:C);
        predictFcn = @(Xin) local_predict_lda(mdl, Xin, C);
    case 'PCA_RF'
        tree = templateTree('MaxNumSplits', max(2, round(benchmarkCfg.maxSplits)));
        mdl = fitcensemble(Str, ytr, 'Method','Bag', 'NumLearningCycles', max(10, round(benchmarkCfg.numTrees)), 'Learners', tree, 'ClassNames', 1:C);
        predictFcn = @(Xin) local_predict_ensemble(mdl, Xin, C);
    otherwise
        error('Unsupported benchmark method: %s', methodName);
end
s=whos('mdl'); modelBytes = s.bytes; end
function [yhat, scores] = local_predict_ecoc(mdl, Xin, C), [yhat, scores] = predict(mdl, Xin); if size(scores,2) ~= C, scores = local_pad_scores(scores, C, yhat); end, end
function [yhat, scores] = local_predict_lda(mdl, Xin, C), [yhat, scores] = predict(mdl, Xin); if size(scores,2) ~= C, scores = local_pad_scores(scores, C, yhat); end, end
function [yhat, scores] = local_predict_ensemble(mdl, Xin, C), [yhat, scores] = predict(mdl, Xin); if iscell(yhat), yhat = str2double(yhat); end; if size(scores,2) ~= C, scores = local_pad_scores(scores, C, yhat); end, end
function scores = local_pad_scores(scores, C, yhat)
if isempty(scores), scores=zeros(numel(yhat),C); for ii=1:numel(yhat), if yhat(ii)>=1 && yhat(ii)<=C, scores(ii,yhat(ii))=1; end, end; return; end
if size(scores,2) < C, scores(:,end+1:C)=0; elseif size(scores,2) > C, scores = scores(:,1:C); end
end
function [fprGrid, tprGrid, aucPerClass, microAUC, macroAUC] = local_make_roc(Y, Scores, C, numROC)
if isempty(Scores) || size(Scores,2) ~= C, fprGrid = linspace(0,1,numROC)'; tprGrid=zeros(numROC,C); aucPerClass=0.5*ones(C,1); microAUC=0.5; macroAUC=0.5; return; end
fprGrid=linspace(0,1,numROC)'; tprGrid=zeros(numROC,C); aucPerClass=zeros(C,1); for c=1:C, ybin=(Y==c); sc=Scores(:,c); [~,idx]=sort(sc,'descend'); yord=ybin(idx); P=sum(yord); Nn=numel(yord)-P; if P==0 || Nn==0, fpr=[0;1]; tpr=[0;1]; auc=0.5; else, tp=cumsum(yord==1); fp=cumsum(yord==0); tpr=[0; tp/max(1,P); 1]; fpr=[0; fp/max(1,Nn); 1]; [fpr, tpr] = local_prepare_interp_xy(fpr, tpr); auc=trapz(fpr,tpr); end; tprGrid(:,c)=local_safe_interp_curve(fpr,tpr,fprGrid); aucPerClass(c)=auc; end; macroAUC=mean(aucPerClass,'omitnan'); Yoh=zeros(numel(Y),C); Yoh(sub2ind([numel(Y),C],(1:numel(Y))',Y(:)))=1; yflat=Yoh(:); sflat=Scores(:); [~,idx]=sort(sflat,'descend'); yord=yflat(idx); P=sum(yord); Nn=numel(yord)-P; if P==0 || Nn==0, microAUC=0.5; else, tp=cumsum(yord==1); fp=cumsum(yord==0); tpr=[0; tp/max(1,P); 1]; fpr=[0; fp/max(1,Nn); 1]; [fpr, tpr] = local_prepare_interp_xy(fpr, tpr); microAUC=trapz(fpr,tpr); end
end
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
