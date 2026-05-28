% Run app tests interactively in MATLAB.

% Copyright 2026 The MathWorks, Inc.

tests = testsuite(pwd, IncludeSubfolders=true);
run(tests);