function RAVEN_V1_01()
    here = fileparts(mfilename('fullpath'));
    coreDir = fullfile(here,'RAVEN_core');
    srcDir  = fullfile(coreDir,'source_modules');
    coreFile = fullfile(coreDir,'RAVEN_V1_01_core.m');

    addpath(here);
    addpath(coreDir);

    if ~exist(coreDir,'dir')
        error('RAVEN:MissingCoreDir','Missing RAVEN_core folder: %s', coreDir);
    end
    if ~exist(srcDir,'dir')
        error('RAVEN:MissingSourceModules','Missing modular source folder: %s', srcDir);
    end

    if ~exist(coreFile,'file') || ravenNeedsModuleRebuild(coreFile,srcDir)
        build_RAVEN_V1_01_core_from_modules(coreDir);
        clear RAVEN_V1_01_core;
    end

    RAVEN_V1_01_core();
end

function tf = ravenNeedsModuleRebuild(coreFile, srcDir)
    tf = false;
    dCore = dir(coreFile);
    if isempty(dCore)
        tf = true;
        return;
    end
    dMods = dir(fullfile(srcDir,'*.m'));
    if isempty(dMods)
        tf = true;
        return;
    end
    coreTime = dCore.datenum;
    modTimes = [dMods.datenum];
    if any(modTimes > coreTime)
        tf = true;
    end
end
