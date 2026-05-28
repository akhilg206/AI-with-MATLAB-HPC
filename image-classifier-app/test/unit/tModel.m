classdef tModel < matlab.unittest.TestCase
    % Unit tests for ic.Model.
    %
    % These tests verify that the app backend works as intended, without
    % opening the UI.

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

    methods(Test)
        function canSetDataFromFilePath(test)
            % We should be able to create a dataset from specifying a
            % folder path.

            model = test.createSpecimen();

            % Use example data included in the repo.
            filePath = fullfile(pwd, '..', '..', 'Data/MerchData');
            
            model.setDataFromFilePath(filePath);

            % We should have created a datastore with the right number of
            % classes.
            expectedNumClasses = 5;
            test.verifyEqual(model.NumClasses, expectedNumClasses);
        end

        function canSetDataFromWorkspace(test)
            % We should be able to create a dataset from specifying a
            % variable name in the workspace.

            model = test.createSpecimen();

            % Use example data included in the repo.
            filePath = fullfile(pwd, '..', '..', 'Data/MerchData');
            imds = imageDatastore(filePath, ...
                IncludeSubfolders=true, LabelSource="foldernames");

            % Put the datastore into the workspace and delete it as a
            % teardown.
            assignin("base", "imds", imds);
            test.addTeardown(@()evalin("base", "clear imds"));

            model.setDataFromWorkspace("imds");

            % We should have created a datastore with the right number of
            % classes.
            expectedNumClasses = 5;
            test.verifyEqual(model.NumClasses, expectedNumClasses);
        end

        function summarizesData(test)
            % We should be able to generate a summary of the data.

            model = test.createSpecimen();
            test.importTestData(model);

            summary = model.summarizeData();

            % Check we have the right value for one field.
            test.verifyEqual(summary.NumClasses, 5);

            % Check we have the expected list of fields
            expectedFieldNames = ["NumTrainingObs", "NumValidationObs", ...
                "NumClasses", "ClassLabels", "TrainingClassDistribution", ...
                "ValidationClassDistribution"];
            test.verifyEqual(string(fieldnames(summary))', expectedFieldNames);
        end

        function setsValidationFraction(test)
            % We should be able to set the fraction of validation data.

            model = test.createSpecimen();
            test.importTestData(model);

            % Change the validation fraction
            model.setValidationFraction(0.6);

            % Check we get the right number of images in each split.
            expectedNumTrainingImages = 30;
            expectedNumValidationImages = 45;
            test.verifyLength(model.TrainingData.Labels, expectedNumTrainingImages);
            test.verifyLength(model.ValidationData.Labels, expectedNumValidationImages);
        end

        function previewsData(test)
            % We should be able to return a struct containing preview data
            % to display.

            model = test.createSpecimen();
            test.importTestData(model);

            numPreviewImages = 5;
            preview = model.previewData(numPreviewImages);

            test.verifyLength(preview.PreviewImages, numPreviewImages);
            test.verifyLength(preview.PreviewClasses, numPreviewImages);
            test.verifyTrue(preview.IsRGB);  % For now support RGB only
        end

        function setsNetworkFromPretrainedNetName(test)
            % We should be able to choose an imagePretrainedNetwork by
            % name.

            model = test.createSpecimen();
            test.importTestData(model);

            model.setNetworkFromPretrained("squeezenet");

            % We should have a pretrained SqueezeNet with 5 classes.
            net = model.UntrainedNetwork;
            test.verifyEqual(net.Layers(end-4).NumFilters, 5);
        end

        function validatesNetworkFromWorkspace(test)
            % We should be able to error-check that a network we're going
            % to import from the workspace is valid for usage.

            model = test.createSpecimen();
            test.importTestData(model);

            % Positive case: network is usable.
            net = imagePretrainedNetwork(NumClasses=5);
            test.setUpWorkspaceVar(net, "net");
            model.validateWorkspaceNetwork("net");

            % Negative cases

            % Not a variable
            test.verifyError(@()model.validateWorkspaceNetwork("net2"), ...
                "ic:NoWorkspaceVar");

            % Not a dlnetwork
            var = ones(5);
            test.setUpWorkspaceVar(var, "var");
            test.verifyError(@()model.validateWorkspaceNetwork("var"), ...
                "ic:NotADLNetwork");

            % Not initialized
            net2 = dlnetwork();
            test.setUpWorkspaceVar(net2, "net2");
            test.verifyError(@()model.validateWorkspaceNetwork("net2"), ...
                "ic:UninitializedNetwork");

            % Wrong sort of input layer
            net3 = dlnetwork([featureInputLayer(5)]);
            test.setUpWorkspaceVar(net3, "net3");
            test.verifyError(@()model.validateWorkspaceNetwork("net3"), ...
                "ic:WrongInputType");

            % Not compatible with this data
            net4 = dlnetwork([imageInputLayer([5 5])]);
            test.setUpWorkspaceVar(net4, "net4");
            test.verifyError(@()model.validateWorkspaceNetwork("net4"), ...
                "ic:UnableToPredict");

            % Wrong output size
            net4 = imagePretrainedNetwork(NumClasses=10);
            test.setUpWorkspaceVar(net4, "net4");
            test.verifyError(@()model.validateWorkspaceNetwork("net4"), ...
                "ic:WrongNumClasses");
        end

        function usesNetworkFromWorkspace(test)
            % We should be able to import and use a network from the
            % workspace.

            model = test.createSpecimen();
            test.importTestData(model);

            myNet = imagePretrainedNetwork(NumClasses=5);
            test.setUpWorkspaceVar(myNet, "myNet");
            model.setNetworkFromWorkspace("myNet");

            test.verifyEqual(model.CurrentNetworkName, "myNet");
        end

        function canSetTrainingOptions(test)
            % We should be able to set training options.

            model = test.createSpecimen();
            model.updateTrainingOptions("adam", InitialLearnRate=20, MaxEpochs=17);

            test.verifyClass(model.TrainingOptions, "nnet.cnn.TrainingOptionsADAM");
            test.verifyEqual(model.TrainingOptions.InitialLearnRate, 20);
            test.verifyEqual(model.TrainingOptions.MaxEpochs, 17);
        end

        function trainsNetwork(test)
            % We should be able to train the network.

            model = test.createSpecimen();
            test.importTestData(model);
            model.setAugmentations(RandRotation=[-5 5]);
            model.setNetworkFromPretrained("squeezenet");
            test.configureModelForFastTraining(model);

            test.assertEmpty(model.TrainedNetwork);
            model.train();

            test.verifyNotEmpty(model.TrainedNetwork);
        end

        function secondTrainingSuccessful(test)
            % Training the model twice with no setting changes should work
            % as intended.

            model = test.createSpecimen();
            test.importTestData(model);
            model.setAugmentations(RandRotation=[-5 5]);
            model.setNetworkFromPretrained("squeezenet");
            test.configureModelForFastTraining(model);

            model.train();
            model.train();

            test.verifyNotEmpty(model.TrainedNetwork);
        end

        function predictsOnImage(test)
            % We should be able to perform inference on a single new image.

            model = test.createTrainedSpecimen();
            img = readimage(model.ValidationData, 3);

            results = model.predictOnImage(img);
            test.verifyLength(results.Scores, 5);
        end

        function predictsOnIndex(test)
            % We should be able to predict on an image in the train or val
            % split.

            model = test.createTrainedSpecimen();
            results = model.predict("validation", 3);

            test.verifyLength(results.Scores, 5);
        end

        function computesConfusionMatrix(test)
            % We should be able to compute a confusion matrix on the train
            % or val split.

            model = test.createTrainedSpecimen();
            results = model.confusionMatrix("validation");

            test.verifySize(results.ConfusionMatrix, [5 5]);
            test.verifySize(results.ClassLabels, [5 1]);
        end

        function computesInterpretabilityMap(test)
            % We should be able to compute an interpretability map e.g.
            % gradCAM on an image in the train/val split.

            model = test.createTrainedSpecimen();
            results = model.interpret("validation", 1, "gradCAM");

            test.verifySize(results.Map, [227 227]);
        end

        function createsStructForExport(test)
            % We should be able to create a struct for workspace export
            % containing the network and training results.

            model = test.createTrainedSpecimen();
            results = model.getStructForExport();

            test.verifyClass(results.TrainedModel, "dlnetwork");
            test.verifyClass(results.TrainingResults, "deep.TrainingInfo");
        end

        function generatesTrainingCode(test)
            % We should be able to generate MATLAB code for training the
            % network.

            model = test.createTrainedSpecimen();
            code = model.generateCodeForTraining();

            test.verifyClass(code, "string");
            test.verifyEqual(code(end), "confusionchart(trueLabels, predictedLabels);");
        end
    end

    methods(Access = private)
        function specimen = createSpecimen(~)
            % Create an instance of the app model.

            specimen = ic.Model();
        end

        function specimen = createTrainedSpecimen(test)
            % Create an instance of the app model, then train it on 5-class
            % example data.

            specimen = test.createSpecimen();
            test.importTestData(specimen);

            specimen.setAugmentations(RandRotation=[-5 5]);
            specimen.setNetworkFromPretrained("squeezenet");
            test.configureModelForFastTraining(specimen);

            specimen.train();
        end

        function importTestData(test, model)
            % Import the 55-image MerchData example dataset.

            filePath = fullfile(pwd, '..', '..', 'Data/MerchData');
            imds = imageDatastore(filePath, ...
                IncludeSubfolders=true, LabelSource="foldernames");

            % Put the datastore into the workspace and delete it as a
            % teardown.
            assignin("base", "imds", imds);
            test.addTeardown(@()evalin("base", "clear imds"));

            model.setDataFromWorkspace("imds");
        end

        function setUpWorkspaceVar(test, var, varName)
            % Add a variable to the base workspace, and clean it up after
            % the test.

            assignin("base", varName, var);
            test.addTeardown(@()evalin("base", "clear " + varName));
        end

        function configureModelForFastTraining(~, model)
            % Configure the model for fast training to avoid long-running
            % tests.
            
            model.updateTrainingOptions("sgdm", MaxEpochs=1, Plots="none");
        end
    end
end