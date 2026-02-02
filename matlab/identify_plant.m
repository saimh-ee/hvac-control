clear; clc; close all;

%% ============================================================
%  HVAC CONTROL — PLANT IDENTIFICATION + SIMULINK INPUTS
%
%  What this script does:
%   1) Loads split_train / split_val / split_test (preprocessed, uniform Ts)
%   2) Identifies a discrete plant model on TRAIN only:
%        T_in(k+1) = a*T_in(k) + b*u(k) + c
%   3) Evaluates one-step prediction RMSE on TRAIN / VAL / TEST (no retuning)
%   4) Builds Simulink "From Workspace" structs for setpoint:
%        - Tset_sig_raw : raw setpoint
%        - Tset_sig     : median-of-3 de-spiked setpoint (recommended)
%   5) Saves plain variables to identified_plant_params.mat for Simulink:
%        a, b, c, sampleTimeSeconds, Kp, Ki, Kb, b_heat, b_cool, etc.
%
%  Notes:
%   - a, b, c are used directly in Simulink Gain blocks.
%   - Kp, Ki, Kb are user-defined controller parameters (not identified).
%   - Optional extension: asymmetric heating/cooling gain:
%        b_heat = b
%        b_cool = coolingGainRatio * b
%% ============================================================


%% ----------------------------
%  Repo paths (edit if needed)
%  ----------------------------
repoRoot = "C:\Users\saimh\Desktop\hvac-control";
processedDataDir = fullfile(repoRoot, "data", "processed");

trainSplitPath = fullfile(processedDataDir, "split_train.mat");
valSplitPath   = fullfile(processedDataDir, "split_val.mat");
testSplitPath  = fullfile(processedDataDir, "split_test.mat");


%% ----------------------------
%  Discrete sample time (fixed)
%  ----------------------------
sampleTimeSeconds = 300; % Ts = 5 minutes


%% ----------------------------
%  Controller gains (EDIT HERE)
%  ----------------------------
Kp = 3;          % proportional gain
Ki = 6.5e-5;     % integral gain
Kb = 1;          % back-calculation coefficient (if your block uses it)


%% ----------------------------
%  Cooling model extension (EDIT HERE)
%  If you allow u in [-1, 1], define different effectiveness for cooling:
%   - heating uses b_heat
%   - cooling uses b_cool (usually smaller magnitude)
%  ----------------------------
coolingGainRatio = 0.3;   % gamma (0.1 to 0.5 is a reasonable starting range)


%% ============================================================
%  Load dataset splits
%  Expected fields per split:
%    t_sec (Nx1), T_in (Nx1), T_set (Nx1), u (Nx1)
%  Optional: valve, e, etc.
%% ============================================================
trainSplit = load(trainSplitPath);
valSplit   = load(valSplitPath);
testSplit  = load(testSplitPath);


%% ============================================================
%  TRAIN split integrity checks
%% ============================================================
requiredFields = ["t_sec","T_in","T_set","u"];
assert(all(isfield(trainSplit, requiredFields)), ...
    "Train split must contain fields: %s", strjoin(requiredFields, ", "));

timeSecondsTrain  = trainSplit.t_sec(:);
indoorTempTrain   = trainSplit.T_in(:);
setpointTrainRaw  = trainSplit.T_set(:);
heaterCmdTrain    = trainSplit.u(:);

numSamplesTrain = numel(indoorTempTrain);

assert(numel(timeSecondsTrain) == numSamplesTrain, "Train: t_sec length must match T_in length.");
assert(numel(setpointTrainRaw) == numSamplesTrain, "Train: T_set length must match T_in length.");
assert(numel(heaterCmdTrain)   == numSamplesTrain, "Train: u length must match T_in length.");
assert(all(diff(timeSecondsTrain) >= 0), "Train: t_sec must be nondecreasing.");

% Warn if time step isn't ~Ts (do not hard fail)
medianTimeStep = median(diff(timeSecondsTrain));
if abs(medianTimeStep - sampleTimeSeconds) > 1e-6
    warning("Train t_sec step is %.6f s, expected %d s. Check resampling.", ...
        medianTimeStep, sampleTimeSeconds);
end


%% ============================================================
%  1) Plant identification on TRAIN only
%     Model: T_in(k+1) = a*T_in(k) + b*u(k) + c
%% ============================================================
nextIndoorTempTrain = indoorTempTrain(2:end); % T_in(k+1)

regressionMatrixTrain = [ ...
    indoorTempTrain(1:end-1), ...   % T_in(k)
    heaterCmdTrain(1:end-1),  ...   % u(k)
    ones(numSamplesTrain-1, 1) ...  % constant term
];

identifiedTheta = regressionMatrixTrain \ nextIndoorTempTrain;

a = identifiedTheta(1);
b = identifiedTheta(2);
c = identifiedTheta(3);

fprintf("Identified discrete model:\n");
fprintf("  T_in(k+1) = %.6f * T_in(k) + %.6f * u(k) + %.6f\n", a, b, c);

% Asymmetric heating/cooling gains for Simulink (if you implement piecewise b)
b_heat = b;
b_cool = coolingGainRatio * b;


%% ============================================================
%  2) One-step prediction RMSE on TRAIN / VAL / TEST
%     (Uses the identified a,b,c without retuning.)
%% ============================================================
[~, ~, trainRmse] = one_step_prediction_metrics(trainSplit.T_in(:), trainSplit.u(:), a, b, c);
[valPredictedTemp, valPredictionError, valRmse] = one_step_prediction_metrics(valSplit.T_in(:), valSplit.u(:), a, b, c);
[~, ~, testRmse]  = one_step_prediction_metrics(testSplit.T_in(:), testSplit.u(:), a, b, c);

fprintf("TRAIN one-step RMSE: %.4f degC\n", trainRmse);
fprintf("VAL   one-step RMSE: %.4f degC\n", valRmse);
fprintf("TEST  one-step RMSE: %.4f degC\n", testRmse);


%% ----------------------------
%  Plots (Validation split only)
%  ----------------------------
figure;
plot(valSplit.T_in(:), "LineWidth", 1); hold on;
plot(valPredictedTemp, "LineWidth", 1);
grid on;
xlabel("Sample k");
ylabel("T_{in} (degC)");
title("Validation: measured vs one-step predicted");
legend("Measured","Predicted");

figure;
plot(valPredictionError, "LineWidth", 1);
grid on;
xlabel("Sample k");
ylabel("Prediction error (degC)");
title("Validation: one-step prediction error");


%% ============================================================
%  3) Setpoint cleanup (TRAIN): median-of-3 de-spike
%     Removes isolated one-sample "needle" glitches.
%% ============================================================
setpointTrainFiltered = median_filter_3point(setpointTrainRaw);


%% ============================================================
%  4) Build Simulink 'From Workspace' structs (TRAIN setpoint)
%
%  In Simulink, set From Workspace "Data" to:
%    - Tset_sig     (filtered; recommended)
%    - Tset_sig_raw (raw; for comparison)
%% ============================================================
Tset_sig_raw = make_simulink_signal_struct(timeSecondsTrain, setpointTrainRaw);
Tset_sig     = make_simulink_signal_struct(timeSecondsTrain, setpointTrainFiltered);


%% ============================================================
%  5) Suggested Simulink run settings derived from TRAIN
%% ============================================================
T0         = indoorTempTrain(1);        % set Unit Delay IC = T0
simStopTime = timeSecondsTrain(end);    % set model StopTime = simStopTime


%% ============================================================
%  6) Save everything Simulink needs (plain variables)
%% ============================================================
identifiedParamsPath = fullfile(processedDataDir, "identified_plant_params.mat");

fitMetrics = struct();
fitMetrics.trainOneStepRmse = trainRmse;
fitMetrics.valOneStepRmse   = valRmse;
fitMetrics.testOneStepRmse  = testRmse;

save(identifiedParamsPath, ...
    "a","b","c","sampleTimeSeconds", ...           % plant + timing
    "Kp","Ki","Kb", ...                            % controller gains (user-defined)
    "b_heat","b_cool","coolingGainRatio", ...      % cooling extension parameters
    "Tset_sig","Tset_sig_raw", ...                 % setpoint signals
    "T0","simStopTime", ...                        % sim suggestions
    "fitMetrics" ...
);

fprintf("Saved: %s\n", identifiedParamsPath);


%% ============================================================
%  Local functions
%% ============================================================

function [predictedTemp, predictionError, rmseDegC] = one_step_prediction_metrics(indoorTemp, heaterCmd, a, b, c)
%ONE_STEP_PREDICTION_METRICS
% One-step predictor:
%   predictedTemp(1) = indoorTemp(1)
%   predictedTemp(k) = a*indoorTemp(k-1) + b*heaterCmd(k-1) + c, for k>=2
% RMSE is computed over k = 2..end.

    indoorTemp = indoorTemp(:);
    heaterCmd  = heaterCmd(:);

    assert(numel(indoorTemp) == numel(heaterCmd), "T_in and u must have same length.");

    predictedTemp = zeros(size(indoorTemp));
    predictedTemp(1) = indoorTemp(1);
    predictedTemp(2:end) = a * indoorTemp(1:end-1) + b * heaterCmd(1:end-1) + c;

    predictionError = indoorTemp - predictedTemp;
    rmseDegC = sqrt(mean(predictionError(2:end).^2));
end


function filtered = median_filter_3point(signal)
%MEDIAN_FILTER_3POINT
% Removes isolated one-sample spikes using a 3-point median filter.
% Endpoints are preserved.

    signal = signal(:);
    N = numel(signal);
    assert(N >= 3, "Signal too short for 3-point median filter.");

    filtered = signal;
    filtered(2:N-1) = median([signal(1:N-2), signal(2:N-1), signal(3:N)], 2);
end


function sig = make_simulink_signal_struct(timeSeconds, values)
%MAKE_SIMULINK_SIGNAL_STRUCT
% Creates a struct accepted by Simulink 'From Workspace':
%   sig.time = timeSeconds
%   sig.signals.values = values
%   sig.signals.dimensions = 1

    timeSeconds = timeSeconds(:);
    values      = values(:);

    assert(numel(timeSeconds) == numel(values), "Time vector and values must be same length.");
    assert(all(diff(timeSeconds) >= 0), "Time vector must be nondecreasing.");

    sig = struct();
    sig.time = timeSeconds;
    sig.signals = struct();
    sig.signals.values = values;
    sig.signals.dimensions = 1;
end
