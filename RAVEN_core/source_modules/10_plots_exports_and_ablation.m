    function makeStep1Plot(T)
        fig = figure('Visible','off','Color','w','Name','Step1');
        yyaxis left; plot(T.kPC,100*T.MacroF1,'-o','LineWidth',1.5); ylabel('MacroF1 (%)');
        yyaxis right; plot(T.kPC,T.WallSec,'-s','LineWidth',1.5); ylabel('Wall time (s)');
        xlabel('kPC'); grid on; title('Step 1 | Embedding search');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP1_kPC.png'));
    end

    function makeStep2Plot(T)
        fig = figure('Visible','off','Color','w','Name','Step2');
        scatter(T.mLand, 100*T.Acc, 90, T.rTeach, 'filled'); colorbar; grid on;
        xlabel('mLand'); ylabel('Teacher accuracy (%)');
        title('Step 2 | Teacher search');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP2_teacher_search.png'));
    end

    function makeStep3Plot(T)
        fig = figure('Visible','off','Color','w','Name','Step3');
        scatter(T.FeatDimMed,100*T.MacroF1,80,T.WallSec,'filled'); colorbar; grid on;
        xlabel('Median feature dimension'); ylabel('MacroF1 (%)'); title('Step 3 | Accuracy vs feature dimension');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP3_dim_vs_F1.png'));
    end

    function buildStep3BestTeacherComparison(T3, teacherShort)
        if isempty(T3) || isempty(teacherShort)
            return;
        end
        bestTeacherID = 1;
        bestTeacherMask = (T3.TeacherID == bestTeacherID);
        if ~any(bestTeacherMask)
            return;
        end
        trow = teacherShort(1,:);
        teacherAcc = getScalarNumericFromTableVar(trow, 'Acc');
        teacherWall = getScalarNumericFromTableVar(trow, 'WallMsPerSpec');
        teacherMem = getScalarNumericFromTableVar(trow, 'MemMiBPerSpec');
        teacherPredict = getScalarNumericFromTableVar(trow, 'PredictMsPerSpec');
        teacherScore = getScalarNumericFromTableVar(trow, 'Score');
        teacherMacroF1 = getScalarNumericFromTableVar(trow, 'MacroF1');
        teacherWeightedF1 = getScalarNumericFromTableVar(trow, 'WeightedF1');
        teacherSummary = sprintf('T%02d[k=%d,m=%d,r=%d,s=%.3g,C=%.3g]', bestTeacherID, double(trow.kPC), double(trow.mLand), double(trow.rTeach), double(trow.sigmaScale), double(trow.BoxC_T));

        Tbest = T3(bestTeacherMask,:);
        nBest = height(Tbest);
        TeacherSummary = repmat(string(teacherSummary), nBest, 1);
        TeacherAcc = repmat(teacherAcc, nBest, 1);
        TeacherMacroF1 = repmat(teacherMacroF1, nBest, 1);
        TeacherWeightedF1 = repmat(teacherWeightedF1, nBest, 1);
        TeacherWallMsPerSpec = repmat(teacherWall, nBest, 1);
        TeacherMemMiBPerSpec = repmat(teacherMem, nBest, 1);
        TeacherPredictMsPerSpec = repmat(teacherPredict, nBest, 1);
        TeacherScore = repmat(teacherScore, nBest, 1);
        StudentPredictMsPerSpec = Tbest.PredictMsPerSpec;
        StudentMemMiBPerSpec = Tbest.MemMiBPerSpec;
        StudentVsTeacherAccRatio = safeDivideVector(Tbest.Acc, teacherAcc);
        StudentVsTeacherTimeRatio = safeDivideVector(StudentPredictMsPerSpec, teacherPredict);
        StudentVsTeacherMemoryRatio = safeDivideVector(StudentMemMiBPerSpec, teacherMem);
        AccuracyDeltaPctPts = 100*(Tbest.Acc - teacherAcc);
        TimeReductionPct = 100*(1 - StudentVsTeacherTimeRatio);
        MemoryReductionPct = 100*(1 - StudentVsTeacherMemoryRatio);
        FasterThanTeacher = StudentVsTeacherTimeRatio < 1;
        LowerMemoryThanTeacher = StudentVsTeacherMemoryRatio < 1;
        Tcompare = table(Tbest.CandidateID, TeacherSummary, TeacherAcc, Tbest.Acc, StudentVsTeacherAccRatio, AccuracyDeltaPctPts, ...
            TeacherMacroF1, Tbest.MacroF1, TeacherWeightedF1, Tbest.WeightedF1, TeacherWallMsPerSpec, Tbest.WallMsPerSpec, ...
            TeacherPredictMsPerSpec, StudentPredictMsPerSpec, StudentVsTeacherTimeRatio, TimeReductionPct, ...
            TeacherMemMiBPerSpec, StudentMemMiBPerSpec, StudentVsTeacherMemoryRatio, MemoryReductionPct, ...
            TeacherScore, Tbest.Score, Tbest.pHidden, Tbest.lamRidge, Tbest.alpha, Tbest.temp, Tbest.skipScale, Tbest.ensemble, FasterThanTeacher, LowerMemoryThanTeacher, ...
            'VariableNames', {'CandidateID','TeacherSummary','TeacherAcc','StudentAcc','StudentPerTeacherAccRatio','AccuracyDeltaPctPts', ...
            'TeacherMacroF1','StudentMacroF1','TeacherWeightedF1','StudentWeightedF1','TeacherWallMsPerSpec_Search','StudentWallMsPerSpec_Search', ...
            'TeacherPredictMsPerSpec','StudentPredictMsPerSpec','StudentPerTeacherTimeRatio','TimeReductionPct', ...
            'TeacherMemMiBPerSpec','StudentMemMiBPerSpec','StudentPerTeacherMemoryRatio','MemoryReductionPct', ...
            'TeacherScore','StudentScore','pHidden','lamRidge','alpha','temp','skipScale','ensemble','FasterThanTeacher','LowerMemoryThanTeacher'});
        Tcompare = sortrows(Tcompare, {'StudentPerTeacherAccRatio','StudentPerTeacherTimeRatio','StudentPerTeacherMemoryRatio','StudentScore'}, {'descend','ascend','ascend','descend'});
        app.state.results.step3BestTeacherComparison = Tcompare;
        save(fullfile(app.state.outdir,'STEP3_LOCALAPPROX','STEP3_BEST_TEACHER_COMPARISON.mat'),'Tcompare','-v7.3');
        compareXlsx = fullfile(app.state.outdir,'STEP3_LOCALAPPROX','STEP3_BEST_TEACHER_COMPARISON.xlsx');
        tryWriteTable(Tcompare, compareXlsx, 'BestTeacherCompare');
        try
            writetable(table(string(teacherSummary), teacherAcc, teacherMacroF1, teacherWeightedF1, teacherWall, teacherMem, teacherPredict, teacherScore, ...
                'VariableNames', {'TeacherSummary','TeacherAcc','TeacherMacroF1','TeacherWeightedF1','TeacherWallMsPerSpec','TeacherMemMiBPerSpec','TeacherPredictMsPerSpec','TeacherScore'}), compareXlsx, 'Sheet', 'TeacherBaseline');
            writetable(Tcompare, fullfile(app.state.outdir,'STEP3_LOCALAPPROX','STEP3_RESULTS.xlsx'), 'Sheet', 'BestTeacherCompare');
        catch
        end

        fig = figure('Visible','off','Color','w','Name','Step3BestTeacher_AccVsTime');
        scatter(Tcompare.StudentPerTeacherAccRatio, Tcompare.StudentPerTeacherTimeRatio, 80, Tcompare.StudentPerTeacherMemoryRatio, 'filled');
        grid on; colorbar;
        hold on; yline(1,'--');
        xlabel('Student accuracy / teacher accuracy'); ylabel('Student predict time / teacher predict time');
        xline(1,'--');
        title('Step 3 | Best teacher | Accuracy ratio vs time ratio');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP3_bestTeacher_accuracy_vs_time.png'));

        fig = figure('Visible','off','Color','w','Name','Step3BestTeacher_AccVsMemory');
        scatter(Tcompare.StudentPerTeacherAccRatio, Tcompare.StudentPerTeacherMemoryRatio, 80, Tcompare.StudentPerTeacherTimeRatio, 'filled');
        grid on; colorbar;
        hold on; yline(1,'--');
        xlabel('Student accuracy / teacher accuracy'); ylabel('Student memory / teacher memory');
        xline(1,'--');
        title('Step 3 | Best teacher | Accuracy ratio vs memory ratio');
        saveFig(fig, fullfile(app.state.outdir,'FIGURES','STEP3_bestTeacher_accuracy_vs_memory.png'));
    end

    function out = safeDivideVector(num, den)
        out = num ./ max(1e-12, den);
        out(~isfinite(out)) = NaN;
    end

    function makeSelectionPlots(res, outSub)
        groups = app.state.data.groupNames(:);
        C = numel(groups);

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_AccuracyOverRepeats']);
        plot(res.RepeatMetrics.Repeat, 100*res.RepeatMetrics.Acc, '-o','LineWidth',1.5); grid on;
        xlabel('Repeat'); ylabel('Accuracy (%)');
        title(sprintf('%s | Accuracy over repeats', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Accuracy_over_repeats.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_TimePerSpec']);
        plot(res.RepeatMetrics.Repeat, res.RepeatMetrics.WallMsPerSpec, '-o','LineWidth',1.5); grid on;
        xlabel('Repeat'); ylabel('Wall ms / spectrum');
        title(sprintf('%s | Wall time per spectrum', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Time_msPerSpec.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_MemoryPerSpec']);
        plot(res.RepeatMetrics.Repeat, res.RepeatMetrics.MemMiBPerSpec, '-o','LineWidth',1.5); grid on;
        xlabel('Repeat'); ylabel('MiB / spectrum');
        title(sprintf('%s | Memory per spectrum', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Memory_MiBPerSpec.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_CM_BEST_counts']);
        imagesc(res.CMBest); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True');
        title(sprintf('%s | Confusion BEST run (counts)', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Confusion_BEST_counts.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_CM_BEST_rowpct']);
        rowpctBest = 100*(res.CMBest ./ max(1,sum(res.CMBest,2)));
        imagesc(rowpctBest,[0 100]); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True');
        title(sprintf('%s | Confusion BEST run (row %%)', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Confusion_BEST_rowpct.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_CM_AVG_counts']);
        imagesc(res.CMmean); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True');
        title(sprintf('%s | Confusion AVG (counts)', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Confusion_AVG_counts.png'));

        fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_CM_AVG_rowpct']);
        rowpctAvg = 100*(res.CMmean ./ max(1,sum(res.CMmean,2)));
        imagesc(rowpctAvg,[0 100]); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True');
        title(sprintf('%s | Confusion AVG (row %%)', res.SelectionName));
        saveFig(fig, fullfile(outSub,'Confusion_AVG_rowpct.png'));

        if app.cfg.step4.makeROC && isfield(res,'ROC_TPR')
            fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_ROC_AVG']);
            hold on; grid on; axis([0 1 0 1]);
            for c = 1:C
                plot(res.ROC_FPR,res.ROC_TPR(:,c),'LineWidth',1.2);
            end
            plot([0 1],[0 1],'k:');
            xlabel('FPR'); ylabel('TPR');
            title(sprintf('%s | ROC AVG | MacroAUC=%.3f | MicroAUC=%.3f', res.SelectionName, res.MacroAUC, res.MicroAUC));
            legend(groups,'Location','SouthEast');
            saveFig(fig, fullfile(outSub,'ROC_AVG.png'));

            fig = figure('Visible','off','Color','w','Name',[res.SelectionName '_ROC_BEST']);
            hold on; grid on; axis([0 1 0 1]);
            for c = 1:C
                plot(res.ROCbest_FPR,res.ROCbest_TPR(:,c),'LineWidth',1.2);
            end
            plot([0 1],[0 1],'k:');
            xlabel('FPR'); ylabel('TPR');
            title(sprintf('%s | ROC BEST run | MacroAUC=%.3f | MicroAUC=%.3f', res.SelectionName, res.MacroAUC_Best, res.MicroAUC_Best));
            legend(groups,'Location','SouthEast');
            saveFig(fig, fullfile(outSub,'ROC_BEST.png'));
        end
    end

    function exportSelectionTables(res, outSub)
        groups = app.state.data.groupNames(:);
        outxlsx = fullfile(outSub, [res.SelectionName '_Report.xlsx']);

        Tsetting = struct2table(flattenStruct(res.cfg));
        Tsetting.Selection = {res.SelectionName};
        Tsetting.TotalWallSec = res.WallSec;

        Tmacro = table(res.Acc, res.BalAcc, res.WeightedAcc, res.MacroF1, res.WeightedF1, res.Score, res.S2, res.LowOccFrac, res.CondMed, ...
            res.FeatDimMed, res.MemMiBPerSpec, res.WallSec, res.WallMsPerSpec, res.PredictMsPerSpec, ...
            'VariableNames', {'MeanAcc','MeanBalAcc','MeanWeightedAcc','MeanMacroF1','MeanWeightedF1','MeanScore','MeanS2','MeanLowOccFrac', ...
            'MeanCondMed','MeanFeatDimMed','MeanMemMiBPerSpec','MeanWallSec','MeanWallMsPerSpec','MeanPredictMsPerSpec'});

        AUC = nan(numel(groups),1);
        if isfield(res,'AUCPerClass'), AUC = res.AUCPerClass; end
        Tper = table(groups, res.RecallPerClass, res.PrecisionPerClass, res.F1PerClass, AUC, ...
            'VariableNames', {'Class','Recall','Precision','F1','AUC'});

        try
            writetable(res.RepeatMetrics, outxlsx, 'Sheet','Runs');
            writetable(Tsetting, outxlsx, 'Sheet','Setting');
            writetable(Tmacro, outxlsx, 'Sheet','Macro');
            writetable(Tper, outxlsx, 'Sheet','PerClass');

            rowpctBest = 100*(res.CMBest ./ max(1,sum(res.CMBest,2)));
            rowpctAvg = 100*(res.CMmean ./ max(1,sum(res.CMmean,2)));
            writecell([{'True_Pred'}, groups'; groups, num2cell(res.CMBest)], outxlsx, 'Sheet','CM_Counts_BEST');
            writecell([{'True_Pred'}, groups'; groups, num2cell(rowpctBest)], outxlsx, 'Sheet','CM_RowPct_BEST');
            writecell([{'True_Pred'}, groups'; groups, num2cell(res.CMmean)], outxlsx, 'Sheet','CM_Counts_AVG');
            writecell([{'True_Pred'}, groups'; groups, num2cell(rowpctAvg)], outxlsx, 'Sheet','CM_RowPct_AVG');

            if isfield(res,'AUCPerClass')
                Tauc = table(groups, res.AUCPerClass, res.AUCbest_PerClass, 'VariableNames', {'Class','AUC_AVG','AUC_BEST'});
                Tauc2 = table("MacroAUC", res.MacroAUC, res.MacroAUC_Best, 'VariableNames', {'Class','AUC_AVG','AUC_BEST'});
                Tauc3 = table("MicroAUC", res.MicroAUC, res.MicroAUC_Best, 'VariableNames', {'Class','AUC_AVG','AUC_BEST'});
                writetable([Tauc; Tauc2; Tauc3], outxlsx, 'Sheet','ROC_AUC');

                TrocAvg = array2table([res.ROC_FPR, res.ROC_TPR], 'VariableNames', [{'FPR'}, strcat('TPR_',matlab.lang.makeValidName(groups'))]);
                writetable(TrocAvg, outxlsx, 'Sheet','ROC_Grid_AVG');

                TrocBest = array2table([res.ROCbest_FPR, res.ROCbest_TPR], 'VariableNames', [{'FPR'}, strcat('TPR_',matlab.lang.makeValidName(groups'))]);
                writetable(TrocBest, outxlsx, 'Sheet','ROC_Grid_BEST');
            end
        catch MEw
            logmsg(['Excel export warning: ' MEw.message]);
        end

        save(fullfile(outSub,'FINAL_RESULTS_SUMMARY.mat'),'res','-v7.3');
    end

    function exportStep4SelectionSummary(Tsel, finalSelections)
        outxlsx = fullfile(app.state.outdir,'STEP4_FINAL','STEP4_SELECTION_SUMMARY.xlsx');
        outtxt = fullfile(app.state.outdir,'STEP4_FINAL','STEP4_FINALISTS.txt');
        try
            writetable(Tsel, outxlsx, 'Sheet','SelectionSummary');
            fn = fieldnames(finalSelections);
            for i = 1:numel(fn)
                res = finalSelections.(fn{i});
                Tcfg = struct2table(flattenStruct(res.cfg));
                writetable(Tcfg, outxlsx, 'Sheet', ['Config_' fn{i}]);
            end
        catch MEw
            logmsg(['Step4 summary export warning: ' MEw.message]);
        end
        fid = fopen(outtxt,'w');
        if fid > 0
            fprintf(fid, 'Step 4 finalists\n');
            fprintf(fid, 'Winner policy: %s\n', char(resolveStep4WinnerPolicy()));
            fprintf(fid, 'Top finalists per bucket: %d\n\n', max(1, round(app.cfg.step4.topFinalistsPerBucket)));
            for i = 1:height(Tsel)
                fprintf(fid, '%02d. %s | %s | Candidate=%s | Acc=%.2f%% | WeightedAcc=%.2f%% | MacroF1=%.2f%% | WeightedF1=%.2f%% | Score=%.4f | Time=%.4f ms/spec | Mem=%.4g MiB/spec\n', ...
                    i, char(string(Tsel.Selection(i))), char(string(Tsel.SourceBucket(i))), char(string(Tsel.CandidateID(i))), ...
                    100*Tsel.StudentAcc(i), 100*Tsel.WeightedAcc(i), 100*Tsel.MacroF1(i), 100*Tsel.WeightedF1(i), Tsel.Score(i), Tsel.WallMsPerSpec(i), Tsel.MemMiBPerSpec(i));
            end
            fclose(fid);
        end
    end

    function winnerPolicy = resolveStep4WinnerPolicy()
        winnerPolicy = "bestscore";
        if isfield(app.cfg.step4,'winnerPolicy') && ~isempty(app.cfg.step4.winnerPolicy)
            winnerPolicy = string(app.cfg.step4.winnerPolicy);
        elseif isfield(app.cfg.step4,'finalSelectionPolicy') && ~isempty(app.cfg.step4.finalSelectionPolicy)
            winnerPolicy = string(app.cfg.step4.finalSelectionPolicy);
        end
        winnerPolicy = lower(winnerPolicy);
    end

    function exportStep4WinnerText(finalKey, res, finalWinnerRecord, Tsel)
        outtxt = fullfile(app.state.outdir,'STEP4_FINAL','STEP4_WINNER.txt');
        fid = fopen(outtxt,'w');
        if fid <= 0
            return;
        end
        fprintf(fid, 'Step 4 winner\n');
        fprintf(fid, 'Selection: %s\n', finalKey);
        fprintf(fid, 'Winner policy: %s\n', char(resolveStep4WinnerPolicy()));
        fprintf(fid, 'CandidateID: %s\n', res.CandidateID);
        fprintf(fid, 'SourceBucket: %s\n', finalWinnerRecord.SourceBucket);
        fprintf(fid, 'RankInBucket: %d\n', finalWinnerRecord.RankInBucket);
        fprintf(fid, 'StudentAcc: %.2f%%\n', 100*res.Acc);
        fprintf(fid, 'TeacherAcc: %.2f%%\n', 100*res.AccTeacher);
        fprintf(fid, 'WeightedAcc: %.2f%%\n', 100*res.WeightedAcc);
        fprintf(fid, 'MacroF1: %.2f%%\n', 100*res.MacroF1);
        fprintf(fid, 'WeightedF1: %.2f%%\n', 100*res.WeightedF1);
        fprintf(fid, 'Score: %.4f\n', res.Score);
        fprintf(fid, 'WallMsPerSpec: %.4f\n', res.WallMsPerSpec);
        fprintf(fid, 'MemMiBPerSpec: %.4g\n', res.MemMiBPerSpec);
        fprintf(fid, 'FeatDimMed: %d\n', round(res.FeatDimMed));
        fprintf(fid, '\nFinalist order after winner sort:\n');
        for i = 1:height(Tsel)
            fprintf(fid, '%02d. %s | Candidate=%s | Score=%.4f | Acc=%.2f%% | WeightedAcc=%.2f%% | WeightedF1=%.2f%%\n', i, char(string(Tsel.Selection(i))), char(string(Tsel.CandidateID(i))), Tsel.Score(i), 100*Tsel.StudentAcc(i), 100*Tsel.WeightedAcc(i), 100*Tsel.WeightedF1(i));
        end
        fclose(fid);
    end

    function makeFinalPlots(res)
        groups = app.state.data.groupNames(:);
        C = numel(groups);
        fig1 = figure('Visible','off','Color','w','Name','Final_CM_counts');
        imagesc(res.CMmean); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True'); title('Average confusion matrix');
        saveFig(fig1, fullfile(app.state.outdir,'FIGURES','FINAL_CM_counts.png'));

        fig2 = figure('Visible','off','Color','w','Name','Final_CM_rowpct');
        rowpct = 100*(res.CMmean ./ max(1,sum(res.CMmean,2)));
        imagesc(rowpct,[0 100]); axis square; colorbar;
        set(gca,'XTick',1:C,'XTickLabel',groups,'YTick',1:C,'YTickLabel',groups);
        xtickangle(45); xlabel('Predicted'); ylabel('True'); title('Average confusion matrix (row %)');
        saveFig(fig2, fullfile(app.state.outdir,'FIGURES','FINAL_CM_rowpct.png'));

        if app.cfg.step4.makeROC && isfield(res,'ROC_TPR')
            fig3 = figure('Visible','off','Color','w','Name','Final_ROC');
            hold on; grid on; axis([0 1 0 1]);
            for c = 1:C
                plot(res.ROC_FPR,res.ROC_TPR(:,c),'LineWidth',1.2);
            end
            if isfield(res,'ROC_MacroTPR')
                plot(res.ROC_FPR,res.ROC_MacroTPR,'k-','LineWidth',2.0);
            end
            if isfield(res,'ROC_MicroTPR')
                plot(res.ROC_FPR,res.ROC_MicroTPR,'k--','LineWidth',2.0);
            end
            plot([0 1],[0 1],'k:');
            xlabel('FPR'); ylabel('TPR');
            title(sprintf('ROC | MacroAUC=%.3f | MicroAUC=%.3f',res.MacroAUC,res.MicroAUC));
            leg = groups;
            if isfield(res,'ROC_MacroTPR')
                leg = [leg; {'Macro ROC'}];
            end
            if isfield(res,'ROC_MicroTPR')
                leg = [leg; {'Micro ROC'}];
            end
            legend(leg,'Location','SouthEast');
            saveFig(fig3, fullfile(app.state.outdir,'FIGURES','FINAL_ROC.png'));

            if isfield(res,'ROC_MacroTPR')
                fig4 = figure('Visible','off','Color','w','Name','Final_ROC_Macro');
                hold on; grid on; axis([0 1 0 1]);
                plot(res.ROC_FPR,res.ROC_MacroTPR,'LineWidth',2.0);
                plot([0 1],[0 1],'k:');
                xlabel('FPR'); ylabel('TPR');
                title(sprintf('Final Macro ROC | AUC=%.3f',res.MacroAUC));
                saveFig(fig4, fullfile(app.state.outdir,'FIGURES','FINAL_ROC_MACRO.png'));
            end
            if isfield(res,'ROC_MicroTPR')
                fig5 = figure('Visible','off','Color','w','Name','Final_ROC_Micro');
                hold on; grid on; axis([0 1 0 1]);
                plot(res.ROC_FPR,res.ROC_MicroTPR,'LineWidth',2.0);
                plot([0 1],[0 1],'k:');
                xlabel('FPR'); ylabel('TPR');
                title(sprintf('Final Micro ROC | AUC=%.3f',res.MicroAUC));
                saveFig(fig5, fullfile(app.state.outdir,'FIGURES','FINAL_ROC_MICRO.png'));
            end
        end
    end

    function exportFinalTables(res)
        groups = app.state.data.groupNames(:);
        outxlsx = fullfile(app.state.outdir,'STEP4_FINAL','FINAL_RESULTS.xlsx');
        Tsum = table(res.Acc,res.BalAcc,res.MacroF1,res.S2,res.LowOccFrac,res.CondMed,res.FeatDimMed,res.MemMiBPerSpec,res.WallSec, getNumericScalar(res,'MacroAUC',NaN), getNumericScalar(res,'MicroAUC',NaN), ...
            'VariableNames',{'Acc','BalAcc','MacroF1','S2','LowOccFrac','CondMed','FeatDimMed','MemMiBPerSpec','WallSec','MacroAUC','MicroAUC'});
        Tcfg = struct2table(flattenStruct(res.cfg));
        rowpct = 100*(res.CMmean ./ max(1,sum(res.CMmean,2)));
        Tmetrics = table(groups,res.RecallPerClass,res.PrecisionPerClass,res.F1PerClass, ...
            'VariableNames',{'Class','Recall','Precision','F1'});
        try
            writetable(Tsum,outxlsx,'Sheet','Summary');
            writetable(Tcfg,outxlsx,'Sheet','Config');
            writetable(Tmetrics,outxlsx,'Sheet','PerClassMetrics');
            writecell([{'True_Pred'}, groups'; groups, num2cell(res.CMmean)], outxlsx,'Sheet','CM_Counts');
            writecell([{'True_Pred'}, groups'; groups, num2cell(rowpct)], outxlsx,'Sheet','CM_RowPct');
            if isfield(res,'AUCPerClass')
                Tauc = table(groups,res.AUCPerClass,'VariableNames',{'Class','AUC'});
                Tauc2 = table("MacroAUC",res.MacroAUC,'VariableNames',{'Class','AUC'});
                Tauc3 = table("MicroAUC",res.MicroAUC,'VariableNames',{'Class','AUC'});
                writetable([Tauc; Tauc2; Tauc3],outxlsx,'Sheet','ROC_AUC');
                Twide = array2table([res.ROC_FPR, res.ROC_TPR], 'VariableNames', [{'FPR'}, strcat('TPR_',matlab.lang.makeValidName(groups'))]);
                writetable(Twide,outxlsx,'Sheet','ROC_Grid');
                if isfield(res,'ROC_MacroTPR') || isfield(res,'ROC_MicroTPR')
                    macroTPR = nan(size(res.ROC_FPR));
                    microTPR = nan(size(res.ROC_FPR));
                    if isfield(res,'ROC_MacroTPR'), macroTPR = res.ROC_MacroTPR; end
                    if isfield(res,'ROC_MicroTPR'), microTPR = res.ROC_MicroTPR; end
                    TmicroMacro = table(res.ROC_FPR, macroTPR, microTPR, 'VariableNames', {'FPR','MacroTPR','MicroTPR'});
                    writetable(TmicroMacro,outxlsx,'Sheet','ROC_MicroMacro');
                end
            end
        catch MEw
            logmsg(['Excel export warning: ' MEw.message]);
        end
        save(fullfile(app.state.outdir,'STEP4_FINAL','FINAL_RESULTS_SUMMARY.mat'),'res','-v7.3');
    end

    function exportAblationSuite(Tsel, finalSelections, finalKey)
        outDir = fullfile(app.state.outdir,'ABLATION_EXPORT');
        if ~exist(outDir,'dir'), mkdir(outDir); end

        Tab = buildAblationSummaryTable(Tsel, finalSelections, finalKey);
        app.state.results.ablationSummaryTable = Tab;
        tryWriteTable(Tab, fullfile(outDir,'ABLATION_SUMMARY.xlsx'),'Summary');
        tryWriteTable(Tsel, fullfile(outDir,'ABLATION_SUMMARY.xlsx'),'Finalists');
        if isfield(app.state.results,'step2Shortlist') && ~isempty(app.state.results.step2Shortlist)
            tryWriteTable(app.state.results.step2Shortlist, fullfile(outDir,'ABLATION_SUMMARY.xlsx'),'TeacherShortlist');
        end
        if isfield(app.state.results,'step3Top') && ~isempty(app.state.results.step3Top)
            tryWriteTable(app.state.results.step3Top, fullfile(outDir,'ABLATION_SUMMARY.xlsx'),'StudentTop');
        end

        writeAblationSummaryTxt(Tab, Tsel, finalKey, fullfile(outDir,'ABLATION_SUMMARY.txt'));
        writeAblationManifest(Tab, outDir, finalKey);
        saveAblationMat(Tab, Tsel, finalSelections, finalKey, outDir);
        writeAblationPerSelectionSheets(Tsel, finalSelections, outDir);
        updateUnifiedOutputManifest(app.state.outdir, 'ablation', buildAblationManifestStruct(Tab, outDir, finalKey));
    end

    function Tab = buildAblationSummaryTable(Tsel, finalSelections, finalKey)
        Role = strings(0,1); Ablation = strings(0,1); Source = strings(0,1); CandidateID = strings(0,1);
        Acc = []; TeacherAcc = []; DeltaVsTeacher = []; RatioToTeacher = []; MacroF1 = []; WeightedF1 = [];
        Score = []; WallMsPerSpec = []; MemMiBPerSpec = []; FeatDimMed = []; SelectedAsWinner = []; Notes = strings(0,1);

        if isfield(app.state.results,'bestStep2') && ~isempty(app.state.results.bestStep2)
            s2 = app.state.results.bestStep2;
            Role(end+1,1) = "TeacherBaseline";
            Ablation(end+1,1) = "teacher_only";
            Source(end+1,1) = "Step2";
            CandidateID(end+1,1) = "STEP2_BEST";
            Acc(end+1,1) = getScalarNumericFromTableVar(s2,'Acc');
            TeacherAcc(end+1,1) = getScalarNumericFromTableVar(s2,'Acc');
            DeltaVsTeacher(end+1,1) = 0;
            RatioToTeacher(end+1,1) = 1;
            MacroF1(end+1,1) = getScalarNumericFromTableVar(s2,'MacroF1');
            WeightedF1(end+1,1) = getScalarNumericFromTableVar(s2,'WeightedF1');
            Score(end+1,1) = getScalarNumericFromTableVar(s2,'Score');
            WallMsPerSpec(end+1,1) = getScalarNumericFromTableVar(s2,'WallMsPerSpec');
            MemMiBPerSpec(end+1,1) = getScalarNumericFromTableVar(s2,'MemMiBPerSpec');
            FeatDimMed(end+1,1) = getScalarNumericFromTableVar(s2,'FeatDimMed');
            SelectedAsWinner(end+1,1) = false;
            Notes(end+1,1) = "Best teacher-only Step 2 candidate.";
        end

        roles = fieldnames(finalSelections);
        for ii = 1:numel(roles)
            role = roles{ii};
            res = finalSelections.(role);
            Role(end+1,1) = string(role);
            Ablation(end+1,1) = classifyAblationRole(role);
            Source(end+1,1) = "Step4";
            CandidateID(end+1,1) = string(ravenGetField(res,'CandidateID',role));
            Acc(end+1,1) = getStructScalar(res,'Acc',NaN);
            TeacherAcc(end+1,1) = getStructScalar(res,'AccTeacher',NaN);
            DeltaVsTeacher(end+1,1) = getStructScalar(res,'Acc',NaN) - getStructScalar(res,'AccTeacher',NaN);
            RatioToTeacher(end+1,1) = getStructScalar(res,'RatioToTeacher',NaN);
            MacroF1(end+1,1) = getStructScalar(res,'MacroF1',NaN);
            WeightedF1(end+1,1) = getStructScalar(res,'WeightedF1',NaN);
            Score(end+1,1) = getStructScalar(res,'Score',NaN);
            WallMsPerSpec(end+1,1) = getStructScalar(res,'WallMsPerSpec',NaN);
            MemMiBPerSpec(end+1,1) = getStructScalar(res,'MemMiBPerSpec',NaN);
            FeatDimMed(end+1,1) = getStructScalar(res,'FeatDimMed',NaN);
            SelectedAsWinner(end+1,1) = strcmp(role, finalKey);
            Notes(end+1,1) = describeAblationRole(role, strcmp(role, finalKey));
        end

        Tab = table(Role, Ablation, Source, CandidateID, Acc, TeacherAcc, DeltaVsTeacher, RatioToTeacher, MacroF1, WeightedF1, Score, WallMsPerSpec, MemMiBPerSpec, FeatDimMed, SelectedAsWinner, Notes);
        if ~isempty(Tab)
            Tab = sortrows(Tab, {'SelectedAsWinner','Score','Acc','MacroF1','WallMsPerSpec'}, {'descend','descend','descend','descend','ascend'});
        end
    end

    function lbl = classifyAblationRole(role)
        r = lower(string(role));
        if strcmp(r,"bestaccuracy")
            lbl = "student_accuracy_bucket";
        elseif strcmp(r,"bestscore")
            lbl = "student_score_bucket";
        elseif strcmp(r,"bestspeed")
            lbl = "student_speed_bucket";
        elseif strcmp(r,"bestmemory")
            lbl = "student_memory_bucket";
        else
            lbl = "student_other_bucket";
        end
    end

    function txt = describeAblationRole(role, isWinner)
        switch lower(string(role))
            case "bestaccuracy"
                txt = "Best Step 4 finalist ranked by student accuracy.";
            case "bestscore"
                txt = "Best Step 4 finalist ranked by composite score.";
            case "bestspeed"
                txt = "Fastest finalist above the Step 4 accuracy threshold.";
            case "bestmemory"
                txt = "Lowest-memory finalist above the Step 4 accuracy threshold.";
            otherwise
                txt = "Step 4 finalist bucket export.";
        end
        if isWinner
            txt = txt + " Selected as final winner.";
        end
    end

    function writeAblationSummaryTxt(Tab, Tsel, finalKey, txtPath)
        fid = fopen(txtPath,'w');
        if fid <= 0, return; end
        c = onCleanup(@() fclose(fid));
        fprintf(fid,'RAVEN ablation export suite\n');
        fprintf(fid,'Generated: %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
        fprintf(fid,'CodeVersion: %s\n', 'RAVEN_V1_01');
        fprintf(fid,'FinalWinner: %s\n', finalKey);
        fprintf(fid,'WinnerPolicy: %s\n', char(resolveStep4WinnerPolicy()));
        fprintf(fid,'GroupedCVRequested: %d\n', double(getNestedLogical(app.cfg, {'cv','useGroups'}, false)));
        fprintf(fid,'GroupedCVMode: %s\n', getNestedText(app.cfg, {'cv','splitMode'}, 'unknown'));
        if isfield(app.cfg.cv,'groupValidation')
            fprintf(fid,'GroupedCVStatus: %s\n', localValueToText(app.cfg.cv.groupValidation));
        end
        fprintf(fid,'\nAblation rows:\n');
        for ii = 1:height(Tab)
            fprintf(fid,'%02d. %s | Ablation=%s | Candidate=%s | Acc=%.2f%%%% | Teacher=%.2f%%%% | Delta=%.2f%%%% | MacroF1=%.2f%%%% | Score=%.4f | Time=%.4f ms/spec | Mem=%.4g MiB/spec\n', ...
                ii, char(Tab.Role(ii)), char(Tab.Ablation(ii)), char(Tab.CandidateID(ii)), 100*Tab.Acc(ii), 100*Tab.TeacherAcc(ii), 100*Tab.DeltaVsTeacher(ii), 100*Tab.MacroF1(ii), Tab.Score(ii), Tab.WallMsPerSpec(ii), Tab.MemMiBPerSpec(ii));
        end
        fprintf(fid,'\nStep4 finalist ranking:\n');
        for ii = 1:height(Tsel)
            fprintf(fid,'%02d. %s | Candidate=%s | Source=%s | Score=%.4f | Acc=%.2f%%%% | MacroF1=%.2f%%%% | Time=%.4f ms/spec | Mem=%.4g MiB/spec\n', ...
                ii, char(string(Tsel.Selection(ii))), char(string(Tsel.CandidateID(ii))), char(string(Tsel.SourceBucket(ii))), Tsel.Score(ii), 100*Tsel.StudentAcc(ii), 100*Tsel.MacroF1(ii), Tsel.WallMsPerSpec(ii), Tsel.MemMiBPerSpec(ii));
        end
    end

    function writeAblationManifest(Tab, outDir, finalKey)
        fid = fopen(fullfile(outDir,'ABLATION_MANIFEST.txt'),'w');
        if fid <= 0, return; end
        c = onCleanup(@() fclose(fid));
        fprintf(fid,'RAVEN structured ablation export\n');
        fprintf(fid,'Generated: %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
        fprintf(fid,'CodeVersion: %s\n', 'RAVEN_V1_01');
        fprintf(fid,'OutputDir: %s\n', outDir);
        fprintf(fid,'FinalWinner: %s\n', finalKey);
        fprintf(fid,'Files:\n');
        fprintf(fid,'  - ABLATION_SUMMARY.xlsx\n');
        fprintf(fid,'  - ABLATION_SUMMARY.txt\n');
        fprintf(fid,'  - ABLATION_MANIFEST.txt\n');
        fprintf(fid,'  - ABLATION_EXPORT.mat\n');
        fprintf(fid,'  - ABLATION_SELECTION_<role>.xlsx\n');
        fprintf(fid,'Rows: %d\n', height(Tab));
        if ~isempty(Tab)
            fprintf(fid,'TopRow: %s | %s | Acc=%.4f | Score=%.4f\n', char(Tab.Role(1)), char(Tab.CandidateID(1)), Tab.Acc(1), Tab.Score(1));
        end
    end

    function saveAblationMat(Tab, Tsel, finalSelections, finalKey, outDir)
        S = struct();
        S.generatedAt = datestr(now,'yyyy-mm-dd HH:MM:SS');
        S.codeVersion = 'RAVEN_V1_01';
        S.finalWinner = finalKey;
        S.winnerPolicy = char(resolveStep4WinnerPolicy());
        S.ablationSummary = Tab;
        S.finalistTable = Tsel;
        S.finalSelections = finalSelections;
        if isfield(app.state.results,'bestStep2')
            S.bestTeacher = app.state.results.bestStep2;
        end
        if isfield(app.state.results,'step2Shortlist')
            S.step2Shortlist = app.state.results.step2Shortlist;
        end
        if isfield(app.state.results,'step3Top')
            S.step3Top = app.state.results.step3Top;
        end
        if isfield(app.state.results,'step3ModeInfo')
            S.step3ModeInfo = app.state.results.step3ModeInfo;
        end
        if isfield(app,'cfg')
            S.cvCfg = app.cfg.cv;
            S.step4Cfg = app.cfg.step4;
        end
        save(fullfile(outDir,'ABLATION_EXPORT.mat'), '-struct', 'S');
    end

    function writeAblationPerSelectionSheets(Tsel, finalSelections, outDir)
        roles = fieldnames(finalSelections);
        for ii = 1:numel(roles)
            role = roles{ii};
            res = finalSelections.(role);
            path = fullfile(outDir, ['ABLATION_SELECTION_' sanitizeFilename(role) '.xlsx']);
            Tsum = table(string(role), string(ravenGetField(res,'CandidateID',role)), getStructScalar(res,'Acc',NaN), getStructScalar(res,'AccTeacher',NaN), ...
                getStructScalar(res,'RatioToTeacher',NaN), getStructScalar(res,'MacroF1',NaN), getStructScalar(res,'WeightedF1',NaN), ...
                getStructScalar(res,'Score',NaN), getStructScalar(res,'WallMsPerSpec',NaN), getStructScalar(res,'MemMiBPerSpec',NaN), ...
                'VariableNames', {'Role','CandidateID','Acc','TeacherAcc','RatioToTeacher','MacroF1','WeightedF1','Score','WallMsPerSpec','MemMiBPerSpec'});
            tryWriteTable(Tsum, path, 'Summary');
            if isfield(res,'cfg')
                tryWriteTable(struct2table(flattenStruct(res.cfg)), path, 'Config');
            end
            idx = find(strcmp(cellstr(string(Tsel.Selection)), role), 1, 'first');
            if ~isempty(idx)
                tryWriteTable(Tsel(idx,:), path, 'SelectionRow');
            end
        end
    end

    function S = flattenStruct(st)

        S = struct();
        recurseFill('', st);

        function recurseFill(prefix, val)
            if isstruct(val) && isscalar(val)
                f = fieldnames(val);
                for ii = 1:numel(f)
                    if isempty(prefix)
                        newPrefix = f{ii};
                    else
                        newPrefix = [prefix '_' f{ii}];
                    end
                    recurseFill(newPrefix, val.(f{ii}));
                end
            else
                fld = matlab.lang.makeValidName(prefix);
                S.(fld) = scalarizeValue(val);
            end
        end

        function out = scalarizeValue(v)
            if isempty(v)
                out = "";
            elseif isnumeric(v)
                if isscalar(v)
                    out = v;
                else
                    out = strtrim(num2str(v(:)'));
                end
            elseif islogical(v)
                if isscalar(v)
                    out = double(v);
                else
                    out = strtrim(num2str(double(v(:)')));
                end
            elseif ischar(v)
                out = v;
            elseif isstring(v)
                if isscalar(v)
                    out = char(v);
                else
                    out = strjoin(cellstr(v(:)'), ' | ');
                end
            elseif iscell(v)
                try
                    out = evalc('disp(v)');
                    out = strtrim(out);
                catch
                    out = 'cell';
                end
            else
                try
                    out = evalc('disp(v)');
                    out = strtrim(out);
                    if isempty(out)
                        out = class(v);
                    end
                catch
                    out = class(v);
                end
            end
        end
    end

    function writeErrorTxt(ME, context)
        try
            outdir = '';
            if isfield(app,'state') && isfield(app.state,'outdir') && ~isempty(app.state.outdir) && exist(app.state.outdir,'dir')
                outdir = app.state.outdir;
            elseif isfield(app,'cfg') && isfield(app.cfg,'io') && isfield(app.cfg.io,'saveBaseDir') && ~isempty(app.cfg.io.saveBaseDir) && exist(app.cfg.io.saveBaseDir,'dir')
                outdir = app.cfg.io.saveBaseDir;
            else
                outdir = pwd;
            end
            stamp = datestr(now,'yyyymmdd_HHMMSS');
            errPath = fullfile(outdir, ['ERROR_' stamp '.txt']);
            latestPath = fullfile(outdir, 'LATEST_ERROR.txt');
            rep = getReport(ME,'extended','hyperlinks','off');
            fid = fopen(errPath,'w');
            if fid ~= -1
                fprintf(fid,'RAVEN GUI error log\n');
                fprintf(fid,'Time: %s\n', datestr(now,31));
                fprintf(fid,'Context: %s\n', context);
                fprintf(fid,'Message: %s\n\n', ME.message);
                fprintf(fid,'%s\n', rep);
                fclose(fid);
            end
            fid = fopen(latestPath,'w');
            if fid ~= -1
                fprintf(fid,'RAVEN GUI error log\n');
                fprintf(fid,'Time: %s\n', datestr(now,31));
                fprintf(fid,'Context: %s\n', context);
                fprintf(fid,'Message: %s\n\n', ME.message);
                fprintf(fid,'%s\n', rep);
                fclose(fid);
            end
            logmsg(['Error log saved: ' errPath]);
        catch MEw
            logmsg(['Could not write error txt: ' MEw.message]);
        end
    end
