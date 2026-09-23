function build_RAVEN_V1_01_core_from_modules(coreDir)
    if nargin < 1 || isempty(coreDir)
        here = fileparts(mfilename('fullpath'));
        coreDir = fullfile(here,'RAVEN_core');
    end

    srcDir = fullfile(coreDir,'source_modules');
    outFile = fullfile(coreDir,'RAVEN_V1_01_core.m');

    if ~exist(srcDir,'dir')
        error('RAVEN:MissingSourceModules','Cannot find source module folder: %s', srcDir);
    end
    if ~exist(coreDir,'dir')
        mkdir(coreDir);
    end

    moduleFiles = { ...
        '00_startup_and_state.m', ...
        '01_default_config.m', ...
        '02_main_ui_and_license.m', ...
        '03_configuration_validation_io.m', ...
        '04_advanced_editor_and_preprocessing_preview.m', ...
        '05_project_run_and_cache_callbacks.m', ...
        '06_pipeline_steps_and_selection.m', ...
        '07_data_loading_and_preprocessing.m', ...
        '08_grouped_cv_output_and_manifests.m', ...
        '09_cv_adapter_and_evaluation_engine.m', ...
        '10_plots_exports_and_ablation.m', ...
        '11_ui_status_progress_and_logging.m', ...
        '12_blind_test_module.m', ...
        '13_teacher_student_and_benchmark_module.m', ...
        '14_close_and_final_end.m'};

    fid = fopen(outFile,'w');
    if fid < 0
        error('RAVEN:BuildFailed','Cannot write generated core file: %s', outFile);
    end
    cleaner = onCleanup(@() fclose(fid));
    nl = char(10);

    for k = 1:numel(moduleFiles)
        fp = fullfile(srcDir,moduleFiles{k});
        if ~exist(fp,'file')
            error('RAVEN:MissingModule','Missing source module: %s', fp);
        end
        txt = fileread(fp);
        fprintf(fid,'%s',txt);
        if isempty(txt) || txt(end) ~= nl
            fprintf(fid,'%s',nl);
        end
        fprintf(fid,'%s',nl);
    end

    fprintf('RAVEN build complete: %s%s', outFile, nl);
end
