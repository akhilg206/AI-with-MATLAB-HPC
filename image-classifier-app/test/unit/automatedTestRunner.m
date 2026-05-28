% Runs app tests, for usage with a CI/CD test runner.
%
% This should not be used for interactively running tests in MATLAB. For
% that, use image-classifier-app\test\runAppTests.m.

% Copyright 2025 The MathWorks, Inc.

import matlab.unittest.fixtures.PathFixture

% Get the folder where the current test file is located
folderOfTheTest = iGetFilePath();
% Get the parent folder, which is assumed to contain the MLAPP file
sourcePath = fileparts(fileparts(folderOfTheTest));
% Add the source directories to path
tc = matlab.unittest.TestCase.forInteractiveUse;
tc.applyFixture(PathFixture(sourcePath, IncludeSubfolders=true));

% Create a test suite
suite = testsuite('Name', 't*', IncludeSubfolders=true);

% Create a test runner
runner = matlab.unittest.TestRunner.withTextOutput;

% Add a test runner plugin that will fail the job if any tests fail
runner.addPlugin(matlab.unittest.plugins.FailOnWarningsPlugin);

% Add a test runner plugin that will output the test results in XML format
artifactsPath = icreateArtifactsPathIfNeeded(folderOfTheTest);
runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat(...
    fullfile(artifactsPath, 'results.xml')));

% Add the source directories to path
tc = matlab.unittest.TestCase.forInteractiveUse;
tc.applyFixture(PathFixture(artifactsPath, IncludeSubfolders=true));

% Run the test suite
tr = runner.run(suite);

% Check if any tests have failed
if ~isempty(find([tr.Failed], 1))
    exit(1);
else
    exit(0);
end

function path = iGetFilePath()
filePath = mfilename('fullpath');
path = fileparts(filePath);
end

function path = icreateArtifactsPathIfNeeded(folderOfTheTest)
path = fullfile(folderOfTheTest, 'artifacts', version('-release'));
if ~isfolder(path)
    mkdir(path);
end
end

