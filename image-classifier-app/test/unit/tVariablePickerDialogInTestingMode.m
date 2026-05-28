classdef tVariablePickerDialogInTestingMode < matlab.unittest.TestCase
    % Unit tests for ic.VariablePickerDialog.
    %
    % These tests verify that the variablePickerDialog method backend works as intended in testing mode,
    % without opening the UI.

    %   Copyright 2025 The MathWorks, Inc.
    methods (TestMethodSetup)
        function addParentFolderPath(test)
            % This method sets up the MATLAB path for the test by adding the folder containing the MLAPP file
            % (and its subfolders) to the MATLAB search path for the duration of the test.

            % Get the folder where the current test file is located
            folderOfTheTest = fileparts(mfilename("fullpath"));

            % Get the parent folder, which is assumed to contain the MLAPP file
            folderWhereTheMLAPPFileLives = fileparts(fileparts(folderOfTheTest));

            % Create a path fixture to temporarily add the MLAPP folder (and its subfolders) to the MATLAB path
            pathFixture = matlab.unittest.fixtures.PathFixture(folderWhereTheMLAPPFileLives, IncludeSubfolders=true);

            % Apply the path fixture so the MLAPP and its dependencies are available during the test
            test.applyFixture(pathFixture);
        end
    end

    methods(TestMethodTeardown)
        function closeFigure(~)
            % Delete Test figure
            figs = findall(groot, 'Type', 'figure', 'Name', 'Test');
            delete(figs);
        end

        function clearWorkspace(~)
            % Clean up base workspace after each test
            evalin('base', 'clear');
        end
        
    end

    methods(Test)
        function testSelectDlnetworkVariableInTestingMode(test)
            % Create dlnetwork variable in base workspace
            evalin('base', 'x = 43; y = []; z = iCreateSimpleDLnetwork();');

            % Filter: only dlnetwork class
            filterFcn = @(x)strcmp(x.Class, "dlnetwork");

            % Call variablePickerDialog method
            chosenNetwork = test.createSpecimen("Test", ...
                "Select a dlnetwork", filterFcn);

            % Only x and z are dlnetwork, so z  should be picked
            test.verifyEqual(chosenNetwork, "z");
        end

        function testSelectImageDatastoreInTestingMode(test)
            % Create variables in base workspace
            evalin('base', ...
            'w = "str"; x = matlab.io.datastore.ImageDatastore("sherlock.jpg"); y = cell(1);');

            % Filter: only ImageDatastore class
            filterFcn = @(v) strcmp(v.Class, "matlab.io.datastore.ImageDatastore");

            % Call variablePickerDialog method
            selectedVar = test.createSpecimen("Test", ...
                "Pick a ImageDatastore variable", filterFcn);
            
            % Should select the first image data store variable, "x"
            test.verifyEqual(selectedVar, "x");
        end

        function testNoSuitableVariablesInTestingMode(test)
            % Only numeric variables in base workspace
            evalin('base', "a = 1; b = iCreateSimpleDLnetwork(); c = 'abc';");

            % Filter: only ImageDatastore class
            filterFcn = @(v) strcmp(v.Class, "matlab.io.datastore.ImageDatastore");

            % Call variablePickerDialog method
            selectedVar = test.createSpecimen("Test", ...
                "Select a ImageDatastore variable", filterFcn);

            % No suitable image data store variable can be found
            test.verifyEqual(selectedVar, "<No suitable variables>");
        end

        function testFirstItemIsReturnedInTestingMode(test)
            % Create multiple matching variables
            evalin('base', 'foo = iCreateSimpleDLnetwork(); bar = iCreateSimpleDLnetwork();');

            % Filter: only dlnetwork class
            filterFcn = @(v) strcmp(v.Class, "dlnetwork");

            % Call variablePickerDialog method
            selectedVar = test.createSpecimen("Test", ...
                "Pick a dlnetwork variable", filterFcn);

            % The first variable in alphabetical order is "bar"
            % But variables() returns in order of creation, 
            % so "foo" then "bar".
            % Let's check which is first
            vars = evalin('base', 'who');
            test.verifyEqual(selectedVar, string(vars{1}));
        end
    end

    methods(Access = private)
        function specimen = createSpecimen(~, dlgTitle, prompt, filterFcn)
            specimen = ic.variablePickerDialog(dlgTitle, ...
                prompt, filterFcn, IsTesting = true);
        end
    end

end

% Helper function
function net = iCreateSimpleDLnetwork()
% Define layers for a simple feedforward network
layers = [
    featureInputLayer(1,"Name","input")        % 1 input feature
    fullyConnectedLayer(8,"Name","fc1")        % 8 neurons
    reluLayer("Name","relu1")
    fullyConnectedLayer(1,"Name","fc2")        % 1 output neuron
    ];

% Convert to a layer graph
lgraph = layerGraph(layers);

% Create a dlnetwork object
net = dlnetwork(lgraph);
end