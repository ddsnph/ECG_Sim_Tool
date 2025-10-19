function run_all_tests
% Run all tests from any working directory, fixed RNG for determinism
thisDir  = fileparts(mfilename('fullpath'));    % .../tests
repoRoot = fileparts(thisDir);                  % repo root
addpath(fullfile(repoRoot,'ecg'));
addpath(thisDir);
rng(0,'twister');

try
    run(fullfile(thisDir,'test_rr_hr_accuracy.m'));
    run(fullfile(thisDir,'test_detection_pr.m'));
    run(fullfile(thisDir,'test_edge_cases.m'));
    disp('All tests passed.');
catch ME
    disp(getReport(ME,'extended'));
    error('Tests failed.');
end
end
