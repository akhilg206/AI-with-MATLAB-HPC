classdef AppTester < handle
    % Test tool for programmatically interacting with the app.
    
    %   Copyright 2025 The MathWorks, Inc.
    properties
        % Test
        % Instance of the matlab.unittest.TestCase. This is needed for
        % interacting with widgets via test.press() etc.
        %
        % Set this after constructing the tester but before using it.
        Test
    end

    properties(Access = private)
        % App
        % Underlying AppDesigner app
        App

        % ParentFigure
        % UIFigure holding the app
        ParentFigure
    end

    methods
        function this = AppTester(app)
            this.App = app;
            this.ParentFigure = findall(groot, Tag='IMAGECLASSIFIER_UIFIGURE');

            this.App.IsTesting = true;
        end

        function maximizeAppWindow(tester)
            tester.App.UIFigure.WindowState = 'maximized';
        end

        function delete(tester)
            % On deletion, clean up the app and figure.
            delete(tester.App);
            delete(tester.ParentFigure);
        end

        function importExampleData(tester)
            widget = tester.App.LoadExampleDataButton;
            tester.Test.press(widget);
        end

        function importDataFromWorkspace(tester)
            % This method automates the process of importing data from the MATLAB workspace into the app
            % by simulating user interactions with the "Import Data from Workspace" dialog.

            % Click the "Import Data from Workspace" button in the app
            tester.clickImportDataFromWorkspaceButton();

            % Wait until the "Choose workspace data" dialog appears
            tester.waitUntil(@() ~isempty(findall(groot, 'Type', 'figure', 'Name', 'Choose workspace data')), iIsTrue);

            % Find the dialog figure
            dialogFigure = findall(groot, 'Type', 'figure', 'Name', 'Choose workspace data');

            % Find the dropdown for selecting workspace variables
            variableDropdown = findall(dialogFigure, 'Type', 'uidropdown');

            % Wait until the dropdown value is 'images'
            tester.waitUntil(@() isequal(variableDropdown.Value, 'images'), iIsTrue);

            % Find the OK button in the dialog
            okButton = findall(dialogFigure, 'Type', 'uibutton', 'Text', 'OK');

            % Wait until the OK button is enabled
            tester.waitUntil(@() strcmp(okButton.Enable, 'on'), iIsTrue);

            % Press the OK button to complete the import
            tester.Test.press(okButton);
        end

        function loadNetworkFromWorkspace(tester)
            % This method automates importing a neural network from the MATLAB workspace into the app
            % by simulating user interactions with the "Choose workspace network" dialog.

            % Click the "Import Network from Workspace" button in the app
            tester.clickImportNetworkFromWorkspaceButton();

            % Wait until the "Choose workspace network" dialog appears
            tester.waitUntil(@() ~isempty(findall(groot, 'Type', 'figure', 'Name', 'Choose workspace network')), iIsTrue);

            % Find the dialog figure
            dialogFigure = findall(groot, 'Type', 'figure', 'Name', 'Choose workspace network');

            % Find the dropdown for selecting workspace variables
            variableDropdown = findall(dialogFigure, 'Type', 'uidropdown');

            % Wait until the dropdown value is 'net'
            tester.waitUntil(@() isequal(variableDropdown.Value, 'net'), iIsTrue);

            % Find the OK button in the dialog
            okButton = findall(dialogFigure, 'Type', 'uibutton', 'Text', 'OK');

            % Wait until the OK button is enabled
            tester.waitUntil(@() strcmp(okButton.Enable, 'on'), iIsTrue);

            % Press the OK button to complete the import
            tester.Test.press(okButton);

            % Dismiss any alert dialog that appears after importing
            tester.dismissUIAlert();
        end

        function switchToTab(tester, tabName)
            % Find the tab with Title as tabName
            allTabs = tester.App.MainTabGroup.Children;
            idx = strcmp({allTabs.Title}, tabName);
            modelTab = allTabs(idx);

            % Set as selected
            tester.App.MainTabGroup.SelectedTab = modelTab;
        end

        function clickImportNetworkFromWorkspaceButton(tester)
            widget = tester.App.FromWorkspaceButton;
            tester.Test.press(widget);
        end

        function clickImportDataFromWorkspaceButton(tester)
            widget = tester.App.ImportDatastorefromworkspaceButton;
            tester.Test.press(widget);
        end

        function clickConfusionMatrixButton(tester)
            widget = tester.App.ConfusionMatrixButton;
            tester.Test.press(widget);
        end

        function clickPredictButton(tester)
            widget = tester.App.PredictButton;
            tester.Test.press(widget);
        end

        function clickInterpretButton(tester)
            widget = tester.App.InterpretButton;
            tester.Test.press(widget);
        end

        function clickPretrainedNetworkModel(tester)
            widget = tester.App.ChoosePretrainedButton;
            tester.Test.press(widget);
        end

        function clickQuickTrainNetwork(tester)
            widget = tester.App.QuickStartButton;
            tester.Test.press(widget);
        end

        function train(tester)
            % This method trains the network with the current settings
            widget = tester.App.TrainButton;
            tester.Test.press(widget);

            tester.dismissUIAlert();
        end

        function setNumEpoch(tester, numEpoch)
            % This method sets the number of epoch for training, which allows
            % user to do rapid training of a single epoch.
            widget = tester.App.TrainingOptionssWidgets.MaxEpochsSpinner;
            tester.Test.type(widget, numEpoch);
        end

        function exportToWorkspace(tester)
            widget = tester.App.ExporttoWorkspaceButton;
            tester.Test.press(widget);

            tester.dismissUIAlert();
        end

        function setValidationFractionValue(tester, value)
            tester.App.Model.setValidationFraction(value);
        end

        function turnOffXRelection(tester)
            widget = tester.App.AugmentationSettingsWidgets.RandXReflectionWidget;
            tester.Test.choose(widget, 'Off');
        end

        function chooseNetwork(tester, value)
            widget = tester.App.NetworkSettingsWidgets.NetworkDropdown;
            tester.Test.choose(widget, value);
        end

        function setInitialLearnRate(tester, value)
            widget = tester.App.TrainingOptionssWidgets.InitialLearnRateSpinner;
            tester.Test.type(widget, value);
        end

        function toggleShowAdvancedOptsCheckbox(tester)
            widget = tester.App.TrainingOptionssWidgets.showAdvancedOptsCheckbox;
            tester.Test.choose(widget, true);
        end

        function setSolver(tester, value)
            widget = tester.App.TrainingOptionssWidgets.SolverDropdown;
            tester.Test.choose(widget, value);
        end

        function setMiniBatchSize(tester, value)
            widget = tester.App.TrainingOptionssWidgets.MinibatchSizeSpinner;
            tester.Test.type(widget, value);
        end

        function setImageIndexInInterpretability(tester, value)
            widget = tester.App.InterpretabilityWidgets.ImageIndexDropdown;
            tester.Test.choose(widget, value);
        end

        function setImageIndexInPrediction(tester, value)
            widget = tester.App.ImagePredictionWidgets.ImageIndexDropdown;
            tester.Test.choose(widget, value);
        end

        function setTechnique(tester, value)
            widget = tester.App.InterpretabilityWidgets.TechniqueDropdown;
            tester.Test.choose(widget, value);
        end

        function runInterpretability(tester)
            widget = tester.findWidgetByTag('RUN_INTERPRETABILITYBUTTON');
            tester.Test.press(widget);
        end

        function isVisible = isClassHistogramBarAxesVisible(tester)
            barObjs = findobj(tester.App.ClassHistogramAxes, 'Type', 'Bar');
            isVisible = strcmp(barObjs(1).Visible, 'on') && strcmp(barObjs(2).Visible, 'on');
        end

        function count = getNumTrainingInPlot(tester)
            barObjs = findobj(tester.App.ClassHistogramAxes, 'Type', 'Bar');
            count = sum(barObjs(2).YData);
        end

        function count = getNumValidationInPlot(tester)
            barObjs = findobj(tester.App.ClassHistogramAxes, 'Type', 'Bar');
            count = sum(barObjs(1).YData);
        end

        function count = getNumClassesInPlot(tester)
            barObjs = findobj(tester.App.ClassHistogramAxes, 'Type', 'Bar');
            count = size(barObjs(1).YData,2);
        end

        function count = getNumTrainingInSummary(tester)
            count = tester.App.Model.summarizeData.NumTrainingObs();
        end

        function isVisible = isImagePredictionClassScoreAxesVisible(tester)
            classScoreAxes = tester.getPredictionClassScoreAxes;
            isVisible = strcmp(classScoreAxes.Visible(), 'on');
        end

        function count = getNumValidationInSummary(tester)
            count =  tester.App.Model.summarizeData.NumValidationObs();
        end

        function count = getNumClassesInSummary(tester)
            count =  tester.App.Model.summarizeData.NumClasses();
        end

        function network = getUntrainedNetwork(tester)
            network = tester.App.Model.UntrainedNetwork;
        end

        function results = getConfusionMatrixResults(tester)
            results = tester.App.ConfusionMatrixResults.ConfusionMatrix;
        end

        function results = getConfusionMatrixClassLabels(tester)
            results = tester.App.ConfusionMatrixResults.ClassLabels;
        end

        function label = getCategoryLabelWithHighestScoreFromConfusionMatrix(tester)
            colSums = sum(tester.getConfusionMatrixResults, 1); % Sum each column
            [~, idx] = max(colSums);   % Find index of maximum sum
            labels = tester.getConfusionMatrixClassLabels();
            label = string(labels(idx));
        end

        function [classLabel, highestScore] = getClassLabelWithHighestScoreFromClassScoreAxes(tester)
            [highestScore, idx] = max([tester.getPredictionClassScoreAxes.Children.YData]);
            classLabel = [tester.getPredictionClassScoreAxes.Children.XData];
            classLabel = classLabel(idx);
        end

        function results = getPredictionResults(tester)
            results = tester.App.PredictionResults;
        end

        function axes = getPredictionImageAxes(tester)
            axes = tester.App.ImagePredictionWidgets.ImageAxes;
        end

        function axes = getPredictionClassScoreAxes(tester)
            axes = tester.App.ImagePredictionWidgets.ClassScoreAxes;
        end

        function results = getInterpretabilityResults(tester)
            results = tester.App.InterpretabilityResults;
        end

        function status = getTrainingStatus(tester)
            status = tester.App.NetworkSettingsWidgets.MetricsInfoLabel.Text;
        end
    end

    methods(Access = private)
        function widget = findWidgetByTag(tester, tag)
            % This method finds a UI component within the app's main figure by its Tag property
            widget = findall(tester.App.UIFigure, Tag=tag);
        end

        function dismissUIAlert(tester)
            % This method dismisses any UIAlert
            tester.Test.dismissDialog('uialert', tester.ParentFigure);
        end

        function waitUntil(tester, functionHandle, constraint, varargin)
            % This method waits until the condition getting met by the evaluated function
            tester.Test.assertThat(functionHandle, iEventually(constraint, 'WithTimeoutOf', 60), varargin{:});
        end
    end
end

% Constraints
function constraint = iIsTrue()
constraint = matlab.unittest.constraints.IsTrue();
end

function constraint = iEventually(varargin)
constraint = matlab.unittest.constraints.Eventually(varargin{:});
end

