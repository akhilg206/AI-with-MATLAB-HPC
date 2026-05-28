classdef Guide
    % Contains info on deep learning concepts for use in the Image
    % Classifier app.

    %   Copyright 2025-2026 The MathWorks, Inc.

    properties(Access = private)
        Tips = [
            "Use the Deep Network Designer app to interactively build a deep neural network.";
            "When training a model, a larger MinibatchSize can allow faster convergence, but training may be less stable.";
            "When using image data, use augmentations to increase the effective size of the dataset, helping the network better generalize.";
            "Use Plots='training-progress' in the trainingOptions to display a live plot of the model loss, which helps you catch overfitting early."
            ];

        CatalogEntries = dictionary()

        WebLinkEntries = dictionary()
    end

    methods
        function this = Guide()

            catalogEntries = [
                "ImportFromFolder", "Select a folder containing folders of image by class.";
                "LoadExampleData", "Load the example 'MerchData' data set. This is a small dataset for learning about image classification.";
                "QuickTrainNetwork", "Transfer learn quickly with a pretrained SqueezeNet image classification network.";
                "FromAppNetwork", "Choose a network from Deep Network Designer, including pretrained image classifiers like GoogleNet or ResNet-101.";
                "FromWorkspaceNetwork", "Import a network from the workspace, including a pretrained image classifier modified for your dataset with Deep Network Designer";
                "FromScratchNetwork", "Build a network from scratch in Deep Network Designer";
                "DataAugmentation", "Augmentations are randomly applied to the data to increase the effective dataset size.";
                "PickingPretrainedNetwork", "Start with a small pretrained network like SqueezeNet. If that gives poor accuracy, move to a larger network like NasNetLarge.";

                % Training options
                "InitialLearnRate", "Learn rate used by the solver. A higher value gives faster convergence, but may give worse final results and less stable training.";
                "MinibatchSize", "Number of images passed to the network in each training iteration. A higher value gives faster convergence, but requires more memory.";
                "MaxEpochs", "Number of complete passes through the training data. A higher value means training takes longer, but may give more accurate results." + ...
                "\n\nYou can stop training early by clicking the Stop button in the training progress plot.";
                "ExecutionEnvironent", iExecutionEnvironmentStr();
                ];
            this.CatalogEntries = dictionary( ...
                catalogEntries(:, 1), catalogEntries(:, 2));

            webLinkEntries = [
                "ImageAugmentation", "https://www.mathworks.com/help/deeplearning/ref/imagedataaugmenter.html";
                "PretrainedNetwork", "https://uk.mathworks.com/help/deeplearning/ug/pretrained-convolutional-neural-networks.html";
                "Interpretability", "https://uk.mathworks.com/help/deeplearning/visualization-and-interpretability.html";
                "TrainingOptions", "https://uk.mathworks.com/help/deeplearning/ref/trainingoptions.html";
                "DeepLearningTipsAndTricks", "https://uk.mathworks.com/help/deeplearning/ug/deep-learning-tips-and-tricks.html";
                ];
            this.WebLinkEntries = dictionary( ...
                webLinkEntries(:, 1), webLinkEntries(:, 2));
        end

        function tip = getTip(this)
            idx = randi(length(this.Tips));
            tip = this.Tips(idx);
        end

        function str = getHelpFor(this, id)
            str = sprintf(this.CatalogEntries(id));
        end

        function url = getWebLinkFor(this, id)
            url = this.WebLinkEntries(id);
        end
    end
end

function str = iExecutionEnvironmentStr()
if canUseGPU
    gpuInfo = "Your machine has a compatible GPU. See 'doc canUseGPU()' for more info.";
else
    gpuInfo = "Your machine does not have a compatible GPU. See 'doc canUseGPU()' for more info.";
end

str = sprintf("Device used for training." + ...
    "\n'auto': use GPU if compatible." + ...
    "\n'gpu': Always try to use GPU." + ...
    "\n'cpu': Use CPU not GPU." + ...
    "\n\n%s", gpuInfo);
end