    function onClose(~,~)
        if app.state.isRunning
            q = questdlg('Pipeline is still running. Close anyway?','RAVEN','Yes','No','No');
            if ~strcmpi(q,'Yes')
                return;
            end
        end
        delete(app.ui.fig);
    end
    function txt = getScalarTextFromTableVar(Trow, varName)
        txt = '';
        if ~istable(Trow) || height(Trow) < 1 || ~ismember(varName, Trow.Properties.VariableNames)
            return;
        end
        v = Trow.(varName);
        if iscell(v)
            if isempty(v)
                txt = '';
            else
                txt = char(string(v{1}));
            end
        elseif isstring(v)
            if isempty(v)
                txt = '';
            else
                txt = char(v(1));
            end
        elseif ischar(v)
            txt = v;
        else
            txt = char(string(v(1)));
        end
    end

    function x = getScalarNumericFromTableVar(Trow, varName)
        x = NaN;
        if ~istable(Trow) || height(Trow) < 1 || ~ismember(varName, Trow.Properties.VariableNames)
            return;
        end
        v = Trow.(varName);
        if iscell(v)
            if isempty(v)
                x = NaN;
            else
                x = double(v{1});
            end
        else
            x = double(v(1));
        end
    end

end
