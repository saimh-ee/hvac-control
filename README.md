# HVAC Control (MATLAB/Simulink)

Closed-loop temperature control project using the *Photon Energy Office Building Temperature Control* dataset.

## Goal
Model a building zone (valve level → indoor temperature) and design a discrete PID controller in Simulink with actuator saturation.

## Pipeline
1. Import + clean raw CSV into a single zone time series
2. Resample to fixed Ts
3. Identify a simple plant model
4. Build Simulink closed-loop PID + robustness tests

## Repo layout
- `data/raw/` raw CSVs (not modified)
- `data/processed/` cleaned `.mat`
- `matlab/` scripts for prep + ID + plots
- `simulink/` Simulink model