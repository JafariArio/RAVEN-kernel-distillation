function cache = raven_build_teacher_cache(X, y, C, teacherCfg, K, Rrepeat, seedBase, splitMode, groupVector)
X = local_unwrap_parallel_input(X);
y = local_unwrap_parallel_input(y);
groupVector = local_unwrap_parallel_input(groupVector);

N = size(X,1);
folds = repmat(struct('Str',[],'Ste',[],'ytr',[],'yte',[],'Ttr',[],'teacherAcc',nan,'teacherPredictMsPerSpec',nan,'teacherMemMiBPerSpec',nan), Rrepeat, K);
accTVec = zeros(Rrepeat,1);
predMsVec = zeros(Rrepeat,1);
memVec = zeros(Rrepeat,1);
for rr = 1:Rrepeat
    foldIdx = local_make_folds_with_seed(y, K, groupVector, splitMode, seedBase + rr);
    accTfold = zeros(K,1);
    predMsFold = zeros(K,1);
    memFold = zeros(K,1);
    for f = 1:K
        tr = foldIdx ~= f; te = foldIdx == f;
        [Str, Ste, ytr, yte] = local_fold_pca(X, y, tr, te, teacherCfg.kPC);
        mdlT = local_fit_teacher(Str, ytr, teacherCfg, C, seedBase + 1000*rr + f);
        [yhatT, ~, predMsT, memT] = local_predict_teacher(mdlT, Ste);
        accTfold(f) = mean(yhatT(:) == yte(:));
        predMsFold(f) = predMsT;
        memFold(f) = memT;
        scoreT_tr = mdlT.scoreTr;
        temp2 = max(1e-6, 1);
        folds(rr,f).Str = Str;
        folds(rr,f).Ste = Ste;
        folds(rr,f).ytr = ytr;
        folds(rr,f).yte = yte;
        folds(rr,f).scoreT_tr = scoreT_tr;
        folds(rr,f).teacherAcc = accTfold(f);
        folds(rr,f).teacherPredictMsPerSpec = predMsT;
        folds(rr,f).teacherMemMiBPerSpec = memT;
    end
    accTVec(rr) = mean(accTfold);
    predMsVec(rr) = mean(predMsFold,'omitnan');
    memVec(rr) = median(memFold);
end
cache = struct();
cache.isTeacherCache = true;
cache.C = C;
cache.K = K;
cache.Rrepeat = Rrepeat;
cache.seedBase = seedBase;
cache.teacherCfg = teacherCfg;
cache.folds = folds;
cache.AccTeacher = mean(accTVec);
cache.TeacherPredictMsPerSpec = mean(predMsVec,'omitnan');
cache.TeacherMemMiBPerSpec = median(memVec);
cache.N = N;
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
if nargin < 4 || isempty(mode), mode = 'stratified'; end
if strcmpi(mode,'grouped') && ~isempty(groupIDs) && numel(groupIDs) == numel(y)
    [gNorm, missingMask] = local_normalize_groups(groupIDs);
    if ~any(missingMask) && numel(unique(gNorm,'stable')) >= K
        foldIdx = local_make_grouped_stratified_folds(y, gNorm, K); return;
    end
end
foldIdx = local_make_stratified_folds(y,K); end
function [gNorm, missingMask] = local_normalize_groups(gRaw)
if isnumeric(gRaw) || islogical(gRaw), gNorm = string(gRaw(:)); missingMask = isnan(double(gRaw(:)));
elseif isstring(gRaw), gNorm = gRaw(:); missingMask = ismissing(gNorm);
elseif iscell(gRaw)
    gNorm = strings(numel(gRaw),1); missingMask = false(numel(gRaw),1);
    for ii=1:numel(gRaw), try sval = strtrim(char(string(gRaw{ii}))); catch, sval=''; end; if isempty(sval), missingMask(ii)=true; else, gNorm(ii)=string(sval); end, end
else
    try gNorm = string(gRaw(:)); missingMask = ismissing(gNorm); catch, gNorm = strings(numel(gRaw),1); missingMask = true(numel(gRaw),1); end
end
if numel(missingMask) ~= numel(gNorm), missingMask = false(size(gNorm)); end; end
function foldIdx = local_make_grouped_stratified_folds(y, groupIDs, K)
y = y(:); groupIDs = groupIDs(:); [G,~,gix] = unique(groupIDs,'stable'); groupClass = zeros(numel(G),1);
for gi=1:numel(G), yy = y(gix==gi); ux = unique(yy(:)'); n=zeros(size(ux)); for ii=1:numel(ux), n(ii)=sum(yy==ux(ii)); end; [~,ix] = max(n); groupClass(gi)=ux(ix); end
foldByGroup = zeros(numel(G),1); cls = unique(groupClass)'; for cc = cls, giList = find(groupClass==cc); giList = giList(randperm(numel(giList))); for ii=1:numel(giList), foldByGroup(giList(ii)) = mod(ii-1,K)+1; end, end; foldIdx = foldByGroup(gix); end
function foldIdx = local_make_stratified_folds(y,K)
foldIdx = zeros(numel(y),1); classes = unique(y(:))'; for c = classes, idx = find(y==c); idx = idx(randperm(numel(idx))); edges = round(linspace(0,numel(idx),K+1)); for f=1:K, if edges(f) < edges(f+1), foldIdx(idx(edges(f)+1:edges(f+1))) = f; end, end, end; end
function [Str, Ste, ytr, yte] = local_fold_pca(X, y, tr, te, kPC)
ytr = y(tr); yte = y(te); Xtr = X(tr,:); Xte = X(te,:); mu = mean(Xtr,1); Xtrc = bsxfun(@minus, Xtr, mu); Xtec = bsxfun(@minus, Xte, mu); kEff = min([kPC, size(Xtrc,1)-1, size(Xtrc,2)]); if kEff < 1, kEff = 1; end; [coeff, scoreTr] = pca(Xtrc, 'NumComponents', kEff, 'Centered', false); Str = scoreTr(:,1:kEff); Ste = Xtec * coeff(:,1:kEff); end
function mdlT = local_fit_teacher(Str, ytr, teacherCfg, C, seed)
rng(seed,'twister'); ntr = size(Str,1); mEff = min(max(2,round(teacherCfg.mLand)), ntr); idxLand = randperm(ntr, mEff); SL = Str(idxLand,:); A2 = sum(SL.^2,2); D2SS = bsxfun(@plus, A2, A2.') - 2*(SL*SL.'); D2SS = max(D2SS,0); dvec = sqrt(D2SS(triu(true(size(D2SS)),1))); dvec = dvec(isfinite(dvec) & dvec > 0); med = median(dvec); if ~(isfinite(med) && med > 0), med = 1.0; end; sigma_fold = teacherCfg.sigmaScale * (med/sqrt(2)); if ~(isfinite(sigma_fold) && sigma_fold > 0), sigma_fold = 1.0; end; gamma = 1/(2*sigma_fold^2); KSS = exp(-gamma * D2SS); KSS = (KSS + KSS.')/2; rReq = min(max(1,round(teacherCfg.rTeach)), mEff);
try, [Ur,DD] = eigs(KSS, rReq, 'la'); lamr = max(real(diag(DD)),0); catch, [Ue,DD] = eig(KSS); lamAll = real(diag(DD)); [lamAll,ord] = sort(lamAll,'descend'); Ue = Ue(:,ord); lamAll = max(lamAll,0); keep = find(lamAll > 1e-12); if isempty(keep), keep = 1; end; rEff0 = min(rReq, numel(keep)); Ur = Ue(:,1:rEff0); lamr = lamAll(1:rEff0); end
keep2 = find(lamr > 1e-12); if isempty(keep2), keep2 = 1; end; rEff = min(numel(lamr), numel(keep2)); Ur = Ur(:,1:rEff); lamr = lamr(1:rEff); invSqrtLam = 1./sqrt(max(lamr(:).',1e-12)); A2tr = sum(Str.^2,2); B2L = sum(SL.^2,2).'; D2trL = bsxfun(@plus, A2tr, B2L) - 2*(Str*SL.'); D2trL = max(D2trL,0); KtrL = exp(-gamma * D2trL); Phi_tr = KtrL * Ur; Phi_tr = bsxfun(@times, Phi_tr, invSqrtLam); Phi_tr = Phi_tr ./ max(1e-12, sqrt(sum(Phi_tr.^2,2))); tSVM = templateSVM('KernelFunction','linear','Standardize',true,'BoxConstraint',teacherCfg.boxC); MdlT = fitcecoc(Phi_tr, ytr, 'Learners', tSVM, 'ClassNames', 1:C, 'Coding', 'onevsall'); [~, scoreT_tr] = predict(MdlT, Phi_tr); if size(scoreT_tr,2) ~= C, tmp=zeros(size(scoreT_tr,1),C); tmp(:,1:min(C,size(scoreT_tr,2))) = scoreT_tr(:,1:min(C,size(scoreT_tr,2))); scoreT_tr = tmp; end; mdlT = struct('SL',SL,'gamma',gamma,'Ur',Ur,'invSqrtLam',invSqrtLam,'classifier',MdlT,'rEff',rEff,'mEff',mEff,'scoreTr',scoreT_tr,'sigma',sigma_fold); end
function [yhat, scores, predMs, memMiB] = local_predict_teacher(mdlT, Ste)
t0=tic; A2te=sum(Ste.^2,2); B2L=sum(mdlT.SL.^2,2).'; D2teL=bsxfun(@plus,A2te,B2L)-2*(Ste*mdlT.SL.'); D2teL=max(D2teL,0); KteL=exp(-mdlT.gamma * D2teL); Phi_te=KteL * mdlT.Ur; Phi_te=bsxfun(@times,Phi_te,mdlT.invSqrtLam); Phi_te=Phi_te ./ max(1e-12, sqrt(sum(Phi_te.^2,2))); [yhat,scores]=predict(mdlT.classifier,Phi_te); predMs = 1000*toc(t0) / max(1,size(Ste,1)); memMiB = 8*(numel(D2teL)+numel(KteL)+numel(Phi_te)+numel(scores)) / max(1,size(Ste,1)) / 1024^2; end
