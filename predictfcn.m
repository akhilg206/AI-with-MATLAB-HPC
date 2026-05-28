function [score, infTime] = predictfcn(inputImage) %#codegen


persistent net;
if isempty(net)
    net = coder.loadDeepLearningNetwork("finetundedNet.mat");
end

i = imresize(inputImage, [227,227]);
i = single(i);

tStart = tic;
score = predict(net, i);
infTime = toc(tStart);
end
