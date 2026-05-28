# Deep Learning Image Classifier App

## Overview
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=matlab-deep-learning/image-classifier-app)

This repo contains an [App Designer](https://www.mathworks.com/help/matlab/ref/appdesigner.html) app for training an image classification deep neural networks in MATLAB. Using this app, you can:

- 🖼️ Import, visualize, and augment data
- ⚡ Quickly transfer learn with the SqueezeNet pretrained network
- 🛠️ Modify pretrained networks for transfer learning with Deep Network Designer
- 📥 Import networks from the workspace
- 🔍 Explain predictions with explainability techniques like Grad-CAM and LIME
- 🧾 Generate MATLAB code for training an image classifier

 You can also edit and customize the app code for your own task.

## Requirements
 - [MATLAB &reg; R2025a](https://www.mathworks.com/products/matlab.html) or later
 - [Deep Learning Toolbox&trade;](https://www.mathworks.com/products/deep-learning.html)
 - (Optional) [Parallel Computing Toolbox&trade;](https://www.mathworks.com/products/parallel-computing.html) to train models on GPU
 - (Optional) [Image Processing Toolbox&trade;](https://www.mathworks.com/products/image-processing.html) to use the `imageLIME` interpretability function

## Using the App
Import data and apply standard augmentations.

![Image of data document](/images/imageClassifier_Data.png)

Choose a pretrained model, edit or build a model in Deep Network Designer, or import a model from the workspace.

![Image of data document](/images/imageClassifier_Model.png)

Train the model, predict on data, and try out interpretability techniques.

![Image of data document](/images/imageClassifier_Interpret.png)

## Get Started

### Open the App

To open the app, run the opening function at the MATLAB command line.
```
ImageClassifer;
```

### Edit the App

To modify the app, run `appdesigner("ImageClassifier.mlapp")`.

*Copyright 2026 The MathWorks, Inc.*
