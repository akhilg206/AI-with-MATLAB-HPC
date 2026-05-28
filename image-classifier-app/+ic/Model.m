classdef Model < handle
    % Backend for image classification training.
    %
    % This class contains methods to perform the standard image
    % classification workflow, using pretrained networks or custom-built
    % networks. It is intended for usage from the Image Classifier App.
    
    %   Copyright 2025-2026 The MathWorks, Inc.

    properties
        % ValidationFraction
        % Fraction of data to use in the validation split. The rest of the
        % data will be used in the training split.
        ValidationFraction = 0.3;

        % True if we are using a grayscale image with a 3-channel network,
        % e.g. an RGB pretrained SqueezeNet being used for grayscale image
        % classification. This requires specific settings for data
        % augmentation.
        RequiresGray2RGB = false;
    end

    properties(Dependent, SetAccess = private)
        % NumClasses
        % Number of unique classes in the classification problem
        NumClasses

        % ValidationLabels
        % Returns a string vector of readable labels of the validation
        % data, for example ["Mathworks Cap - 1"; "Mathworks Cap - 2"];
        ValidationLabels
    end

    properties(SetAccess = private)
        Data

        TrainingData
        ValidationData
        CurrentDatastoreFolderName
        CurrentDatastoreVariableName
        CurrentAugmentationSettings

        UntrainedNetwork
        CurrentNetworkName

        TrainingOptions = trainingOptions("sgdm");
        CurrentSolver
        CurrentSetTrainingOptions

        TrainedNetwork

        TrainingResults

        NumImages
    end

    properties(Access = private)
        DataType

        NetworkType

        DataClassLabels

        ImageAugmenter = imageDataAugmenter();
    end

    methods
        function setDataFromFilePath(this, folderPath)
            % Create a datastore given a folder path.
            %
            % Within the folder, images should be stored in subfolders
            % whose name is the class name.
            %
            % folderPath: string naming the folder containing image
            % subfolders

            this.CurrentDatastoreFolderName = folderPath;
            this.CurrentDatastoreVariableName = [];

            this.Data = imageDatastore(folderPath, IncludeSubfolders=true, LabelSource="foldernames");
            this.DataType = "image-datastore";
            this.NumImages = length(this.Data.Labels);

            [this.TrainingData, this.ValidationData] = ... 
                splitEachLabel(this.Data, 1 - this.ValidationFraction);

            this.DataClassLabels = unique(this.TrainingData.Labels);

            this.RequiresGray2RGB = false;
        end

        function validateWorkspaceDatastore(~, varName)
            ws = matlab.lang.Workspace.baseWorkspace();

            % Check variable exists at all
            if ~ismember(varName, variables(ws).Name)
                error("Variable '%s' not found.", varName);
            end

            % Check variable is an initialized dlnetwork
            [~,imds] = evaluateAndCapture(ws, varName);
            if ~isa(imds, "matlab.io.datastore.ImageDatastore")
                error("Variable '%s' should be a matlab.io.datastore.ImageDatastore, but was of class '%s'.", ...
                    varName, class(imds));
            end
        end

        function setDataFromWorkspace(this, imdsName)
            % Choose a datastore from the base workspace

            ws = matlab.lang.Workspace.baseWorkspace();
            [~, imds] = evaluateAndCapture(ws, imdsName);

            this.CurrentDatastoreFolderName = [];
            this.CurrentDatastoreVariableName = imdsName;

            this.Data = imds;
            this.DataType = "workspace-datastore";

            this.NumImages = length(this.Data.Labels);

            [this.TrainingData, this.ValidationData] = ... 
                splitEachLabel(this.Data, 1 - this.ValidationFraction);

            this.DataClassLabels = unique(this.TrainingData.Labels);

            this.RequiresGray2RGB = false;
        end

        function summary = summarizeData(this)
            % Returns a struct summarizing the data.
            
            summary = struct( ...
                NumTrainingObs = length(this.TrainingData.Labels), ...
                NumValidationObs = length(this.ValidationData.Labels), ...
                NumClasses = length(unique(this.TrainingData.Labels)), ...
                ClassLabels = string(unique(this.TrainingData.Labels)));

            summary.TrainingClassDistribution = histcounts(this.TrainingData.Labels);
            summary.ValidationClassDistribution = histcounts(this.ValidationData.Labels);
        end

        function setValidationFraction(this, validationFraction)
            % Changes the validation split.
            %
            % validationFraction: value between 0 and 1 setting fraction to
            % use as validation data

            this.ValidationFraction = validationFraction;

            [this.TrainingData, this.ValidationData] = ... 
                splitEachLabel(this.Data, 1 - this.ValidationFraction);
        end

        function setAugmentations(this, varargin)
            % Set image augmentations.
            %
            % varargin: list of NVP args, the same as for
            % 'imageDataAugmenter'.

            this.ImageAugmenter = imageDataAugmenter(varargin{:});
            this.CurrentAugmentationSettings = varargin;
        end

        function preview = previewData(this, numPreviewImages)
            % Generate data for previewing augmented data.
            %
            % Result is a struct containing fields:
            % - PreviewImages: cell array of images
            % - IsRGB: logical specifying if images are RGB
            %
            % numPreviewImages: number of images to include in the
            % preview.

            % Generate previews of augmented images
            augmentedImages = cell(numPreviewImages, 1);
            label = categorical.empty(numPreviewImages, 0);
            idx = randi(this.NumImages, numPreviewImages);
            for i=1:numPreviewImages
                [img, label(i)] = this.getImageByIndex(idx(i));
                if size(img, 3) == 1
                    img = repmat(img, 1, 1, 3);
                end
                augmentedImages{i} = this.ImageAugmenter.augment(img);
            end

            preview = struct( ...
                PreviewImages={augmentedImages}, ...
                PreviewClasses=label, ...
                IsRGB=true);
        end

        function setNetworkFromPretrained(this, networkName)

            this.UntrainedNetwork = imagePretrainedNetwork(networkName, ...
                NumClasses=this.NumClasses);
            this.CurrentNetworkName = networkName;
            this.NetworkType = "pretrained";
        end

        function validateWorkspaceNetwork(this, varName)

            ws = matlab.lang.Workspace.baseWorkspace();

            % Check variable exists at all
            if ~ismember(varName, variables(ws).Name)
                error("ic:NoWorkspaceVar", "Variable '%s' not found.", varName);
            end

            % Check variable is an initialized dlnetwork
            [~,net] = evaluateAndCapture(ws, varName);
            if ~isa(net, "dlnetwork")
                error("ic:NotADLNetwork", "Variable '%s' should be a dlnetwork, but was of class '%s'.", ...
                    varName, class(net));
            end

            if ~net.Initialized
                error("ic:UninitializedNetwork", "Network '%s' must be initialized.", varName);
            end

            % Check we can propagate data through the network.
            inputLayer = getLayer(net, net.InputNames{1});
            if ~isa(inputLayer, "nnet.cnn.layer.ImageInputLayer")
                error("ic:WrongInputType", "Network '%s' does not have an image input layer.", varName);
            end
            networkInputSize = inputLayer.InputSize;

            % Handle the case we have greyscale data, and we are trying to
            % train on a 3-channel pretrained network.
            colorPreprocessing = "none";
            if numel(networkInputSize) > 2 && networkInputSize(3) == 3
                % We have a 3-channel image network, probably pretrained
                % RGB network
                img = preview(this.Data);
                if size(img, 3) == 1
                    % We need gray2rgb color preprocessing
                    colorPreprocessing = "gray2rgb";  
                end
            end

            % Create augmented data
            augImds = augmentedImageDatastore(networkInputSize(1:2), ...
                this.TrainingData, ColorPreprocessing=colorPreprocessing);
            result = read(augImds);
            img = result.input{1};
            try
                pred = predict(net, dlarray(single(img), "SSCB"));
            catch err
                error("ic:UnableToPredict", "Unable to predict on a single image with the selected network.\n\nError: %s", ...
                    err.message);
            end

            % Check we have right format and right size
            if ~strcmp(dims(pred), "CB")
                error("Expected network output to be a 'CB' dlarray, but the format was %s.", ...
                    dims(pred));
            end
            
            if size(pred, 1) ~= this.NumClasses
                error("ic:WrongNumClasses", "Expected network output to have %i classes, but it had %i classes.\n\n" + ...
                    "If you used the <code>imagePretrainedNetwork</code> function, don't forget to" + ...
                    " set the <code>NumClasses</code> parameter to %i.", ...
                    this.NumClasses, size(pred,1), this.NumClasses);
            end
        end

        function setNetworkFromWorkspace(this, netName)
            ws = matlab.lang.Workspace.baseWorkspace();
            [~, this.UntrainedNetwork] = evaluateAndCapture(ws, netName);
            this.CurrentNetworkName = netName;
            this.NetworkType = "workspace";
        end

        function net = createTemplateNetwork(this)
            
            % As a first guess at input size, use the size of the first
            % image in the training set.

            inputSize = size(readimage(this.TrainingData, 1));
            outputSize = this.NumClasses;

            net = dlnetwork([ ...
                imageInputLayer(inputSize);
                ], Initialize=false);

            net = addLayers(net, [ ...
                fullyConnectedLayer(outputSize); ...
                softmaxLayer]);
        end

        function updateTrainingOptions(this, solver, varargin)

            % Apply default training options first.
            this.TrainingOptions = trainingOptions(solver, ...
                ValidationData=this.ValidationData, ...
                Plots="training-progress", ...
                Metric="accuracy", ...
                Verbose=false);

            % Apply customized training options second.
            %
            % This allows defaults to be overridden, which is beneficial
            % for testing, e.g. tests may not want to show the progress
            % plot.
            for i=1:(length(varargin)/2)
                this.TrainingOptions.(varargin{2*i-1}) = varargin{2*i};
            end

            this.CurrentSolver = solver;
            this.CurrentSetTrainingOptions = varargin;
        end

        function train(this)
            
            inputLayer = getLayer(this.UntrainedNetwork, this.UntrainedNetwork.InputNames{1});
            networkInputSize = inputLayer.InputSize;

            % Handle the case we have greyscale data, and we are trying to
            % train on a 3-channel pretrained network.            
            if numel(networkInputSize) > 2 && networkInputSize(3) == 3
                % We have a 3-channel image network, probably pretrained
                % RGB network
                img = preview(this.Data);
                if size(img, 3) == 1
                    % We need gray2rgb color preprocessing
                    colorPreprocessing = "gray2rgb";  
                    this.RequiresGray2RGB = true;
                else
                    colorPreprocessing = "none";
                end
            end

            % Create augmented training data
            augImdsTrain = augmentedImageDatastore(networkInputSize(1:2), ...
                this.TrainingData, DataAugmentation=this.ImageAugmenter, ...
                ColorPreprocessing=colorPreprocessing);

            % We also need to update the validation data with any color
            % preprocessing
            this.TrainingOptions.ValidationData = ...
                augmentedImageDatastore(networkInputSize(1:2), ...
                this.ValidationData, ...
                colorPreprocessing=colorPreprocessing);

            [this.TrainedNetwork, this.TrainingResults] = trainnet( ...
                augImdsTrain, this.UntrainedNetwork, "crossentropy", this.TrainingOptions);
        end

        function results = predictOnImage(this, img)
            
            inputSize = this.TrainedNetwork.Layers(1).InputSize;
            img = imresize(img, inputSize(1:2));

            % Note we aren't currently enabling GPU inference for 1 image.
            scores = predict(this.TrainedNetwork, single(img));

            predLabel = scores2label(scores, this.DataClassLabels, 2);
            [predScore, maxChannelIdx] = max(scores);

            results = struct( ...
                PredictedLabel = predLabel, ...
                PredictedLabelScore = predScore, ...
                PredictedLabelChannel = maxChannelIdx, ...
                Scores = scores, ...
                Labels = this.DataClassLabels, ...
                Image = img);
        end

        function results = predict(this, dataSplit, observationIndex)
            
            if strcmp(dataSplit, "training")
                imds = this.TrainingData;
            else
                imds = this.ValidationData;
            end

            inputSize = this.TrainedNetwork.Layers(1).InputSize;
            img = imresize(imds.readimage(observationIndex), inputSize(1:2));

            if this.RequiresGray2RGB
                img = repmat(img, [1 1 3]);
            end

            % Note we aren't currently enabling GPU inference for 1 image.
            scores = predict(this.TrainedNetwork, single(img));

            predLabel = scores2label(scores, this.DataClassLabels, 2);
            [predScore, maxChannelIdx] = max(scores);

            results = struct( ...
                PredictedLabel = predLabel, ...
                PredictedLabelScore = predScore, ...
                PredictedLabelChannel = maxChannelIdx, ...
                Scores = scores, ...
                Labels = this.DataClassLabels, ...
                Image = img);
        end

        function results = confusionMatrix(this, dataSplit)

            [augImds, imds] = this.getDataForInference(dataSplit);

            scores = minibatchpredict(this.TrainedNetwork, augImds);
            predLabels = scores2label(scores, this.DataClassLabels, 2);
            trueLabels = imds.Labels;

            cm = confusionmat(trueLabels, predLabels);

            results = struct( ...
                ConfusionMatrix = cm, ...
                ClassLabels = this.DataClassLabels);
        end

        function results = interpret(this, dataSplit, imageIndex, technique)
            predictionResults = this.predict(dataSplit, imageIndex);

            fcn = str2func(technique);
            map = fcn(this.TrainedNetwork, predictionResults.Image, predictionResults.PredictedLabelChannel);

            results = struct( ...
                Image = predictionResults.Image, ...
                PredictedLabel = predictionResults.PredictedLabel, ...
                PredictedLabelScore = predictionResults.PredictedLabelScore, ...
                PredictedLabelChannel = predictionResults.PredictedLabelChannel, ...
                Map = map);
        end

        function s = getStructForExport(this)
            s = struct( ...
                TrainedModel = this.TrainedNetwork, ...
                TrainingResults = this.TrainingResults);
        end

        function code = generateCodeForTraining(this)

            code = [
                this.generatePreambleCode();
                this.generateNetworkCode();
                this.generateDataCode();
                this.generateTrainingOptsCode();
                this.generateTrainnetCode();
                this.generateInferenceCode();
            ];

        end

    end

    methods
        function value = get.NumClasses(this)
            if ~isempty(this.Data)
                value = length(unique(this.Data.Labels));
            else
                value = 0;
            end
        end

        function value = get.ValidationLabels(this)
            % Returns readable validation labels, e.g. "Class1 - 1",
            % "Class1 - 2" etc.

            if ~isempty(this.Data)
                labels = string(this.ValidationData.Labels);
                classes = string(unique(this.ValidationData.Labels));

                value = string.empty();

                for i=1:length(classes)
                    value = [value; 
                        (classes(i) + " - " + string(1:sum(classes(i) == labels)))'];
                end
            else
                value = "";
            end
        end
    end

    methods(Access = private)
        function [img, label] = getImageByIndex(this, idx)
            img = this.Data.readimage(idx);
            label = this.Data.Labels(idx);
        end

        function [augImds, imds] = getDataForInference(this, trainValSplit)

            if strcmp(trainValSplit, "training")
                imds = this.TrainingData;
            else
                imds = this.ValidationData;
            end

            if this.RequiresGray2RGB
                colorPreprocessing = "gray2rgb";
            else
                colorPreprocessing = "none";
            end

            inputSize = this.TrainedNetwork.Layers(1).InputSize;
            augImds = augmentedImageDatastore(inputSize(1:2), imds, ...
                ColorPreprocessing=colorPreprocessing);
        end
    end

    methods(Access = private)
        function code = generatePreambleCode(this)
            code = [
                "%% Classify images with deep neural network";
                "% Autogenerated by MATLAB on " + string(datetime("now"));
                newline()];
        end

        function code = generateNetworkCode(this)
            if this.NetworkType == "workspace"
                netCode = sprintf("net = %s;", this.CurrentNetworkName);
            else
                netCode = sprintf("net = imagePretrainedNetwork(""%s"", NumClasses=%i);", ...
                    this.CurrentNetworkName, this.NumClasses);
            end

            code = [
                "%% Create network";
                netCode;
                newline()];
        end

        function code = generateDataCode(this)

            if this.DataType == "image-datastore"
                dsCode = sprintf("imds = imageDatastore(""%s"", IncludeSubfolders=true, LabelSource='foldername');", ...
                    this.CurrentDatastoreFolderName);
            else
                dsCode = sprintf("imds = %s;", this.CurrentDatastoreVariableName);
            end

            % We need different augmentedImageDatastore code for if we have
            % grayscale data we are converting to RGB, vs RGB data.
            if this.RequiresGray2RGB
                augImdsTrainLine = sprintf("augImdsTrain = augmentedImageDatastore(inputSize, imdsTrain, DataAugmentation=augmenter, ColorPreprocessing=""gray2rgb"");");
                augImdsValLine = "augImdsVal = augmentedImageDatastore(inputSize, imdsVal, ColorPreprocessing=""gray2rgb"");";
            else
                augImdsTrainLine = sprintf("augImdsTrain = augmentedImageDatastore(inputSize, imdsTrain, DataAugmentation=augmenter);");
                augImdsValLine = "augImdsVal = augmentedImageDatastore(inputSize, imdsVal);";
            end

            code = [
                "%% Create image datastore";
                dsCode;
                sprintf("[imdsTrain, imdsVal] = splitEachLabel(imds, %.3f);", ...
                1-this.ValidationFraction);
                "inputSize = net.Layers(1).InputSize(1:2);";
                sprintf("augmenter = imageDataAugmenter(%s);", iParseCellArgsToString(this.CurrentAugmentationSettings));
                augImdsTrainLine;
                augImdsValLine;
                newline()];
        end

        function code = generateTrainingOptsCode(this)
            trainingOpts= [this.CurrentSetTrainingOptions, ...
                {"ValidationData", "augImdsVal", "Plots", 'training-progress', "Metrics", 'accuracy', "Verbose", "false"}];
            code = [
                "%% Specify training options";
                sprintf("opts = trainingOptions(""%s"", %s);", ...
                this.CurrentSolver, iParseCellArgsToString(trainingOpts));
                newline()];
        end

        function code = generateTrainnetCode(this)
            code = [
                "%% Train network with crossentropy loss";
                "net = trainnet(augImdsTrain, net, ""crossentropy"", opts);";
                newline()];
        end

        function code = generateInferenceCode(this)
            code = [
                "%% Predict with network";
                "% Predict on a single image"
                "data = preview(augImdsVal);";
                "trueLabels = imdsVal.Labels;";
                "img = data{1,1}{1};"
                "predScores = predict(net, single(img));";
                "figure;";
                "predictedLabel = scores2label(predScores, categories(trueLabels));";
                "imshow(img); title(""Prediction: "" + string(predictedLabel));"
                newline()
                "% Predict on many images and plot confusion matrix.";
                "% Use this to evaluate network performance on a held-out test set."
                "scores = minibatchpredict(net, augImdsVal);";
                "trueLabels = imdsVal.Labels;";
                "predictedLabels = scores2label(scores, categories(trueLabels));";
                "figure;";
                "confusionchart(trueLabels, predictedLabels);"];
        end
    end

end

function str = iParseCellArgsToString(args)
% Parse a cell array of arguments to a string representation suitable for
% MATLAB codegen

str = "";
for i=1:2:length(args)-2
str = str + args{i} + "=";
str = str + iParseArgToString(args{i+1}) + ",..." + newline;
end
str = str + args{end-1} + "=";
str = str + iParseArgToString(args{end});
end

function str = iParseArgToString(arg)

if isstring(arg)
    str = arg;
elseif ischar(arg)
    str = """" + arg + """";
else
    str = string(arg);
    if ~isscalar(str)
        str = "[" + join(str, " ") + "]";
    end
end

end