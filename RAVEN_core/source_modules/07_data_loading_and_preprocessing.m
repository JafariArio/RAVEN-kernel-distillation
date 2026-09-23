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
