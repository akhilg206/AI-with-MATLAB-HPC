classdef tImageClassifierWorkflows < matlab.uitest.TestCase
    % System level tests for Image Classifier AppDesigner app
    %
    % These verify end-to-end workflows work in the UI, clicking buttons to
    % e.g. train networks.

    %   Copyright 2025 The MathWorks, Inc.
    properties(Access = private)
        % App
        % AppDesigner app object
        App

        % AppTester
        % Test tool with convenience methods for performing app actions
        AppTester
    end

    methods (TestClassSetup)
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

    methods(TestMethodSetup)
        function setup(test)
            test.createAppTester();
        end
    end

    methods(TestMethodTeardown)
        function teardown(test)
            test.deleteAppTesterAndPlots();
        end
    end

    methods(Test)
        function canCompleteSimpleEndToEndWorkflow(test)
            % This test is to cover a simple end to end workflow: it imports data, configures
            % training options, trains a model, verifies results at each stage (including
            % confusion matrix and interpretability), and exports the final model.

            % Import example data into the app
            test.AppTester.importExampleData();

            % Assert that class histogram is visible
            test.assertThat(@() test.AppTester.isClassHistogramBarAxesVisible, ...
                iEventually(iIsTrue()));

            % Verify summary and histogram values
            test.verifyValuesInSummaryAndClassHistogramPlot();

            % Set validation data fraction to 20%
            test.AppTester.setValidationFractionValue(0.2);

            % Turn off X reflection (data augmentation option)
            test.AppTester.turnOffXRelection();

            % Select the option for quick-training with SqueezeNet.
            test.AppTester.clickQuickTrainNetwork();

            % Set initial learning rate to 0.1
            test.AppTester.setInitialLearnRate(0.1);

            % Set number of training epochs to 1
            test.AppTester.setNumEpoch(1);

            % Set mini-batch size to 40
            test.AppTester.setMiniBatchSize(40);

            % Show advanced training options
            test.AppTester.toggleShowAdvancedOptsCheckbox();

            % Set optimizer/solver to 'adam'
            test.AppTester.setSolver("adam");

            % Start training the model
            test.AppTester.train();

            % Verify that training completed
            test.verifyTrue(contains(test.AppTester.getTrainingStatus, 'Training complete'));

            % Show confusion matrix
            test.AppTester.clickConfusionMatrixButton();

            % Verify the confusion matrix results
            test.verifyConfusionMatrixResults();

            % Click predict to start prediction
            test.AppTester.clickPredictButton();

            % Assert that prediction scores are visible
            test.assertThat(@() test.AppTester.isImagePredictionClassScoreAxesVisible(), ...
                iEventually(iIsTrue()));

            % Verify prediction results
            test.verifyPredictionResults();

            % Select the 3rd image for prediction
            test.AppTester.setImageIndexInPrediction(3);

            % Verify prediction results for selected image
            test.verifyPredictionResults();

            % Switch to interpretability tab
            test.AppTester.clickInterpretButton();

            % Verify interpretability results
            test.verifyInterpretabilityResults();

            % Select the 2nd image for interpretability
            test.AppTester.setImageIndexInInterpretability(2);

            % Choose 'imageLIME' interpretability technique
            test.AppTester.setTechnique("imageLIME");

            % Run interpretability analysis
            test.AppTester.runInterpretability();

            % Export the trained model to the workspace
            test.AppTester.exportToWorkspace();

            % Ensure model variable is cleared after test
            test.addTeardown(@test.clearModelVariable);

            % We should end up with a model in the workspace.
            test.verifyWorkspaceContainsExportedModel('model');
        end

        function canCompleteWorkflowUsingImportedDataAndModel(test)
            % This test is about a workflow for importing image data and a network from the workspace,
            % configuring and training the network in the app, verifying training, prediction,
            % and interpretability results, and finally exporting the trained model.

            % Load image data and a network to the MATLAB workspace
            test.loadImageAndDataToWorkspace();

            % Import the data from the workspace into the app
            test.AppTester.importDataFromWorkspace();

            % Assert that the class histogram is visible in the app
            test.assertThat(@() test.AppTester.isClassHistogramBarAxesVisible, ...
                iEventually(iIsTrue()));

            % Verify summary and class histogram plot values
            test.verifyValuesInSummaryAndClassHistogramPlot();

            % Load the network from the workspace into the app
            test.AppTester.loadNetworkFromWorkspace();

            % Verify that the untrained network in the app matches the one in the base workspace
            test.verifyEqual(evalin('base', 'net'), test.AppTester.getUntrainedNetwork);

            % Set the initial learning rate to 0.5
            test.AppTester.setInitialLearnRate(0.5);

            % Set the number of epochs to 1 to shorten the training process
            test.AppTester.setNumEpoch(1);

            % Set the mini-batch size to 30
            test.AppTester.setMiniBatchSize(30);

            % Show advanced training options in the app
            test.AppTester.toggleShowAdvancedOptsCheckbox();

            % Set the model solver to 'rmsprop'
            test.AppTester.setSolver("rmsprop");

            % Start training the model
            test.AppTester.train();

            % Verify that training has completed successfully
            test.verifyTrue(contains(test.AppTester.getTrainingStatus, 'Training complete'));

            % Open the confusion matrix after training
            test.AppTester.clickConfusionMatrixButton();

            % Verify the confusion matrix results
            test.verifyConfusionMatrixResults();

            % Start the prediction process
            test.AppTester.clickPredictButton();

            % Assert that the image prediction class score axes are visible
            test.assertThat(@() test.AppTester.isImagePredictionClassScoreAxesVisible(), ...
                iEventually(iIsTrue()));

            % Verify the prediction results
            test.verifyPredictionResults();

            % Select the third image for prediction
            test.AppTester.setImageIndexInPrediction(3);

            % Verify prediction results for the selected image
            test.verifyPredictionResults();

            % Switch to the interpretability results tab
            test.AppTester.clickInterpretButton();

            % Verify interpretability results
            test.verifyInterpretabilityResults();

            % Select the third image for interpretability analysis
            test.AppTester.setImageIndexInInterpretability(3);

            % Set the interpretability technique to 'occlusionSensitivity'
            test.AppTester.setTechnique("occlusionSensitivity");

            % Run interpretability analysis
            test.AppTester.runInterpretability();

            % Verify the interpretability results after analysis
            test.verifyInterpretabilityResults();

            % Export the trained model to the workspace
            test.AppTester.exportToWorkspace();

            % Ensure the model variable is cleared from the workspace after the test
            test.addTeardown(@test.clearModelVariable);

            % We should end up with a model in the workspace.
            test.verifyWorkspaceContainsExportedModel('model');
        end

        function canCompleteReselectDataAndModelWorkflow(test)
            % This test covers 2 separate workflows to ensure user can
            % re-select data and model after first model gets trained.
            % First, importing example data, training a model, and
            % making predictions.
            % Then, importing new data from the workspace, configuring and training
            % a different model, verifying results, and exporting the trained model.

            % Import example data into the app
            test.AppTester.importExampleData();

            % Assert that the class histogram bar axes are visible
            test.assertThat(@() test.AppTester.isClassHistogramBarAxesVisible, iEventually(iIsTrue()));

            % Verify summary and class histogram plot values
            test.verifyValuesInSummaryAndClassHistogramPlot();

            % Select the quick-train network model option
            test.AppTester.clickQuickTrainNetwork();

            % Set the initial learning rate to 0.6
            test.AppTester.setInitialLearnRate(0.6);

            % Set the number of epochs to 2
            test.AppTester.setNumEpoch(2);

            % Set the mini-batch size to 30
            test.AppTester.setMiniBatchSize(30);

            % Train the model
            test.AppTester.train();

            % Verify that training has completed
            test.verifyTrue(contains(test.AppTester.getTrainingStatus, 'Training complete'));

            % Click the predict button to start prediction
            test.AppTester.clickPredictButton();

            % Assert that the image prediction class score axes are visible
            test.assertThat(@() test.AppTester.isImagePredictionClassScoreAxesVisible(), iEventually(iIsTrue()));

            % Load new image data and a network to the workspace
            test.loadImageAndDataToWorkspace();

            % Import the new data from the workspace into the app
            test.AppTester.importDataFromWorkspace();

            % Assert that the class histogram bar axes are visible for the new data
            test.assertThat(@() test.AppTester.isClassHistogramBarAxesVisible, iEventually(iIsTrue()));

            % Verify summary and class histogram plot values for the new data
            test.verifyValuesInSummaryAndClassHistogramPlot();

            % Switch to the 'Model' tab in the app
            test.AppTester.switchToTab('Model');

            % Set the initial learning rate to 0.5
            test.AppTester.setInitialLearnRate(0.5);

            % Set the number of epochs to 1
            test.AppTester.setNumEpoch(1);

            % Set the mini-batch size to 30
            test.AppTester.setMiniBatchSize(30);

            % Train the model with the new configuration
            test.AppTester.train();

            % Verify that training has completed for the new model
            test.verifyTrue(contains(test.AppTester.getTrainingStatus, 'Training complete'));

            % Click the confusion matrix button to view results
            test.AppTester.clickConfusionMatrixButton();

            % Verify the confusion matrix results
            test.verifyConfusionMatrixResults();

            % Export the trained model to the workspace
            test.AppTester.exportToWorkspace();

            % Ensure model variable is cleared after the test
            test.addTeardown(@test.clearModelVariable);

            % We should end up with a model in the workspace.
            test.verifyWorkspaceContainsExportedModel('model');
        end

        function canCompleteCloseAndRelaunchAppWorkflow(test)
            % This test is to cover two consecutive workflows:
            % 1) Importing data from the workspace, training a model, and cleaning up the app.
            % 2) Recreating the app, importing example data, loading a network from the workspace,
            % training, verifying results, and exporting the trained model.

            % Load image data and a network to the MATLAB workspace
            test.loadImageAndDataToWorkspace();

            % Import the data from the workspace into the app
            test.AppTester.importDataFromWorkspace();

            % Assert that the class histogram is visible in the app
            test.assertThat(@() test.AppTester.isClassHistogramBarAxesVisible, ...
                iEventually(iIsTrue()));

            % Verify summary and class histogram plot values
            test.verifyValuesInSummaryAndClassHistogramPlot();

            % Select the quick-train network model option
            test.AppTester.clickQuickTrainNetwork();

            % Set the initial learning rate to 0.5
            test.AppTester.setInitialLearnRate(0.5);

            % Set the number of epochs to 1 to shorten the training process
            test.AppTester.setNumEpoch(1);

            % Set the mini-batch size to 32
            test.AppTester.setMiniBatchSize(32);

            % Train the model
            test.AppTester.train();

            % Verify that training has completed
            test.verifyTrue(contains(test.AppTester.getTrainingStatus, 'Training complete'));

            % Close current app running session by deleting the current app tester instance
            % and any open plots
            test.deleteAppTesterAndPlots();

            % Create a new app tester instance
            test.createAppTester();

            % Import example data into the new app instance
            test.AppTester.importExampleData();

            % Assert that the class histogram is visible for the example data
            test.assertThat(@() test.AppTester.isClassHistogramBarAxesVisible, iEventually(iIsTrue()));

            % Load the network from the workspace into the app
            test.AppTester.loadNetworkFromWorkspace();

            % Verify that the untrained network in the app matches the one in the base workspace
            test.verifyEqual(evalin('base', 'net'), test.AppTester.getUntrainedNetwork);

            % Set the initial learning rate to 0.5
            test.AppTester.setInitialLearnRate(0.5);

            % Set the number of epochs to 1
            test.AppTester.setNumEpoch(1);

            % Set the mini-batch size to 30
            test.AppTester.setMiniBatchSize(30);

            % Train the model with the new configuration
            test.AppTester.train();

            % Verify that training has completed for the new model
            test.verifyTrue(contains(test.AppTester.getTrainingStatus, 'Training complete'));

            % Click the confusion matrix button to view results
            test.AppTester.clickConfusionMatrixButton();

            % Verify the confusion matrix results
            test.verifyConfusionMatrixResults();

            % Export the trained model to the workspace
            test.AppTester.exportToWorkspace();

            % Ensure model variable is cleared after the test
            test.addTeardown(@test.clearModelVariable);

            % We should end up with a model in the workspace.
            test.verifyWorkspaceContainsExportedModel('model');
        end
    end

    methods(Access = private)
        function createAppTester(test)
            % This method creates an ImageClassifier app instance, wraps it with a test helper class,
            % sets up the testing context, and maximizes the app window for testing.

            % Create an instance of the ImageClassifier app
            app = ImageClassifier();

            % Create an AppTester instance to facilitate automated testing of the app
            test.AppTester = ictester.AppTester(app);

            % Give the AppTester access to the current test instance for test utilities (e.g., test.press())
            test.AppTester.Test = test;

            % Maximize the app window to ensure all UI elements are visible during testing
            test.AppTester.maximizeAppWindow();
        end

        function deleteAppTesterAndPlots(test)
            % On this test method teardown, delete the tester (which deletes the
            % app), as well as any open figures.

            delete(test.AppTester);

            % We might have open training plot(s); delete any.
            figs = findall(groot, Type='figure');
            delete(figs);
        end

        function verifyValuesInSummaryAndClassHistogramPlot(test)
            % This method verifies consistency between the values shown in the app's summary and plot
            % for the number of training samples, validation samples, and classes.

            % Check that the number of training samples in the plot matches the summary
            test.verifyEqual(test.AppTester.getNumTrainingInPlot(), test.AppTester.getNumTrainingInSummary());

            % Check that the number of validation samples in the plot matches the summary
            test.verifyEqual(test.AppTester.getNumValidationInPlot(), test.AppTester.getNumValidationInSummary());

            % Check that the number of classes in the plot matches the summary
            test.verifyEqual(test.AppTester.getNumClassesInPlot(), test.AppTester.getNumClassesInSummary());
        end

        function verifyWorkspaceContainsExportedModel(test, varName)
            % This method retrieves a variable from the MATLAB base workspace, then verifies
            % that it is a struct and that its 'TrainedModel' field is a dlnetwork object.

            % Get a handle to the MATLAB base workspace
            ws = matlab.lang.Workspace.baseWorkspace();

            % Evaluate and capture the variable named 'varName' from the workspace
            [~, var] = evaluateAndCapture(ws, varName);

            % Verify that the variable is a struct
            test.verifyClass(var, 'struct');

            % Verify that the 'TrainedModel' field of the struct is a 'dlnetwork' object
            test.verifyClass(var.TrainedModel, 'dlnetwork');
        end

        function verifyConfusionMatrixResults(test)
            % This method verifies that the confusion matrix and its class labels have the expected sizes.

            % Verify that the confusion matrix results are a 5x5 matrix
            test.verifyEqual(size(test.AppTester.getConfusionMatrixResults()), [5 5]);

            % Verify that the confusion matrix class labels are a 5x1 vector
            test.verifyEqual(size(test.AppTester.getConfusionMatrixClassLabels()), [5 1]);
        end

        function verifyInterpretabilityResults(test)
            % This method verifies that the predicted label from interpretability results matches the
            % highest scoring category label from the confusion matrix, and that the predicted label
            % score matches between interpretability and prediction results.

            % Verify that the predicted label from interpretability results matches the category label
            % with the highest score from the confusion matrix
            test.verifyEqual(string(test.AppTester.getInterpretabilityResults().PredictedLabel), ...
                test.AppTester.getCategoryLabelWithHighestScoreFromConfusionMatrix());

            % Verify that the predicted label score from interpretability results matches the score
            % from the prediction results
            test.verifyEqual(test.AppTester.getInterpretabilityResults().PredictedLabelScore, ...
                test.AppTester.getPredictionResults().PredictedLabelScore);
        end

        function verifyPredictionResults(test)
            % This method verifies the consistency of prediction results, ensuring the predicted label
            % matches the highest scoring category from the confusion matrix, the predicted label score
            % matches the highest score from the class score axes, and that the labels vector is the expected size.

            % Verify that the predicted label matches the category label with the highest score from the confusion matrix
            test.verifyEqual(string(test.AppTester.getPredictionResults().PredictedLabel), ...
                test.AppTester.getCategoryLabelWithHighestScoreFromConfusionMatrix());

            % Get the highest score from the class score axes
            [~, highestScore] = test.AppTester.getClassLabelWithHighestScoreFromClassScoreAxes();

            % Verify that the predicted label score matches the highest score from the class score axes
            test.verifyEqual(test.AppTester.getPredictionResults().PredictedLabelScore, highestScore);

            % Verify that the labels vector from prediction results is a 5x1 vector
            test.verifyEqual(size(test.AppTester.getPredictionResults().Labels), [5 1]);
        end

        function clearModelVariable(test)
            % If we exported a variable named 'model', clean it up.

            % If nothing got exported, this is a no-op. We can't used
            % matlab.lang.workspace.baseWorkspace(), because that provides a copy of
            % the base workspace, so won't really clear the variable
            test.addTeardown(@()iClearFromBaseWorkspace('model'));
        end

        function tempFolder = createTempFolder(test)

            % This method creates a temporary folder for the test, ensuring any files or folders created
            % during the test are isolated and automatically cleaned up afterwards.

            % Apply a temporary folder fixture, which creates and manages a temp folder for this test
            fixture = test.applyFixture(iTemporaryFolder());

            % Get the path to the temporary folder
            tempFolder = fixture.Folder;
        end

        function populateTempFolder(~, tempFolder)
            % We need to create some image dataset in the test. 
            % What we do is to generate
            % 5 images, one for each class. Then, write them to the
            % tempFolder we created during the test setup.

            nClasses = 5;

            for i = 1:nClasses
                % Create a path for the image in the tempFolder. Each 5
                % images will represent a different class.
                classFolderPath = fullfile(tempFolder, sprintf("%d", i));
                mkdir(classFolderPath);
                for j  = 1:5
                    image = ones(227, 227, 3)*i;
                    imwrite(image, fullfile(classFolderPath, sprintf('image_%d.jpg', j)));
                end
            end
        end

        function loadImageAndDataToWorkspace(test)
            % This method creates and populates a temporary folder with test data, loads an image datastore,
            % creates a simple deep learning network, assigns both to the MATLAB base workspace, and
            % ensures cleanup of these variables after the test.

            % Create a temporary folder for the test
            tempFolder = test.createTempFolder();

            % Populate the temporary folder with test images or data
            test.populateTempFolder(tempFolder);

            % Load images from the temporary folder into a datastore
            images = iLoadDatastore(tempFolder);

            % Create a simple deep learning network for testing
            net = iCreateSimpleDLNetwork();

            % Assign the images datastore to the base workspace
            iAssignVariableToBaseWorkspace('images', images);

            % Assign the network to the base workspace
            iAssignVariableToBaseWorkspace('net', net);

            % Ensure the 'images' variable is cleared from the base workspace after the test
            test.addTeardown(@()iClearFromBaseWorkspace('images'));

            % Ensure the 'net' variable is cleared from the base workspace after the test
            test.addTeardown(@()iClearFromBaseWorkspace('net'));
        end

    end
end

% Helper functions
function iClearFromBaseWorkspace(varname)
evalin('base',sprintf('clear %s',varname));
end

function iAssignVariableToBaseWorkspace(varname, value)
assignin('base', varname, value);
end

function fixture = iTemporaryFolder(varargin)
fixture = matlab.unittest.fixtures.TemporaryFolderFixture(varargin{:});
end

function net = iCreateSimpleDLNetwork()
layers = [
    imageInputLayer([227 227 3], 'Name', 'input')    % [height width channels]
    convolution2dLayer(3, 8, 'Padding', 'same', 'Name', 'conv1')
    batchNormalizationLayer('Name', 'bn1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(5, 'Name', 'fc')             % produce 5 output classes
    softmaxLayer('Name', 'softmax')
    ];

net = dlnetwork(layers);
end

function images = iLoadDatastore(dataFolder)
images = imageDatastore(dataFolder, ...
    'IncludeSubfolders',true,'LabelSource','foldernames');
end

% Constraints
function constraint = iIsTrue()
constraint = matlab.unittest.constraints.IsTrue();
end

function constraint = iEventually(varargin)
constraint = matlab.unittest.constraints.Eventually(varargin{:});
end



