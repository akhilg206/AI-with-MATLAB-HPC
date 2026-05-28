function selectedVariable = variablePickerDialog(dlgTitle, prompt, filterFcn, opts)

    %   Copyright 2025-2026 The MathWorks, Inc.

arguments
    dlgTitle 
    prompt 
    filterFcn 
    opts.IsTesting = false % test flag with default setting as false
end
% Returns the variable selected from a dropdown containing workspace
% variables
%
% This uses waitfor to block MATLAB until a uifigure dialog is either
% closed, or OK is clicked.
%
% dlgTitle: Dialog title
% prompt: string telling the user what variable to select
% filterFcn: function handle. This receives each row of the table returned by
% variables(matlab.lang.workspace.baseWorkspace()), and should return true
% if that variable is suitable for selection.
% 
% Example:
% x = "string1"; y = "string2";
% chosenVar = variablePickerDialog("Choose a variable",  ...
%     "Pick a string from the workspace", ...
%     @(x)strcmp(x.Class, "string"));

%   Copyright 2025 The MathWorks, Inc.

[items, hasSuitableVariables] = iFindSuitableVariables(filterFcn);

% Create figure
fig = uifigure(Name=dlgTitle);
fig.Position(4) = 120;

% Create UI components
mainLayout = uigridlayout(fig, ...
    RowHeight={'fit', 'fit', 'fit'}, ...
    ColumnWidth={'1x'});
uilabel(mainLayout, Text=prompt, Interpreter="html");
dropdown = uidropdown(mainLayout, Items=items);

buttonLayout = uigridlayout(mainLayout, ...
    RowHeight={'1x'}, ColumnWidth={'1x', 100}, Padding=5);
okButton = uibutton(buttonLayout, Text="OK", ...
    ButtonPushedFcn=@okButtonClicked, Enable=hasSuitableVariables);
okButton.Layout.Column = 2;

% To capture the value of the chosen variable, use a nested function which
% also traps the dropdown.
chosenVariable = string.empty();

    function okButtonClicked(~, ~)
        chosenVariable = string(dropdown.Value);
        close(fig);
    end
if opts.IsTesting
    % In testing mode, select the first item.
    % For testing mode, we cannot block the thread with waitfor() as that prevents 
    % the test from continuing to run.
   selectedVariable = items(1);
else
    % waitfor on a figure handle will block until the figure is closed.
    waitfor(fig);
    % If the OK button was pressed, we have selected a variable.
    selectedVariable = chosenVariable;
end

end

function [items, hasSuitableVariables] = iFindSuitableVariables(filterFcn)
% List suitable variables which match filterFcn

% Find out what workspace variables we have.
ws = matlab.lang.Workspace.baseWorkspace();
vars = variables(ws);

% For each variable, does it pass the filter
items = string.empty();
for i=1:height(vars)
    if filterFcn(vars(i, :))
        items(end+1, 1) = vars{i, "Name"};
    end
end

% Handle edge case that nothing passes the filter
hasSuitableVariables = ~isempty(items);
if ~hasSuitableVariables
    items = "<No suitable variables>";
end
end