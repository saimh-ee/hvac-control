# HVAC Control (Data → Model ID → PI Control → PLC)

End-to-end controls project:
- preprocess HVAC time-series data
- identify a simple discrete-time plant model
- tune/test a PI controller in Simulink
- port the same logic into OpenPLC Structured Text (OpenPLC Runtime v4 on Windows)

## Data source
Photon Energy office-building temperature control dataset (Hugging Face):
https://huggingface.co/datasets/ml-photonenergy/Photon-Energy-office-building-temperature-control/tree/main

Raw dataset is large, so this repo only includes processed subsets.

## Repo structure
- `data/raw/` placeholder only (raw not committed)
- `data/processed/` processed CSVs used for ID + control tests
- `scripts/` R scripts for extract/merge/resample/splits
- `matlab/` plant identification + parameter export
- `simulink/` PI simulation models
- `PLC/` OpenPLC Runtime v4 project + ST program

## Identified plant model
Discrete-time update used in Simulink + PLC:
- T(k+1) = a*T(k) + b*u(k) + c
- b is different for heating vs cooling

Final parameters:
- a = 0.999951185242347
- b_heat = 0.020589313234843
- b_cool = 0.006176793970453
- c = -0.001383511783900

## Controller (PI) setup
- Kp = 0.9
- Ki = 1.75e-5
- deadband = ±0.25 °C
- command saturation = [-1, 1]
- integrator clamp = [-1, 1]
- heat if u ≥ 0, cool if u < 0 (switches b)

Timing notes:
- PLC task can run fast (e.g., 20 ms), but the control/plant “sample tick” is set to 5 minutes (T#300s) to match the dataset timestep.

## How to run (high level)
1) Run scripts in `scripts/` to generate `data/processed/`
2) Run `matlab/identify_plant.m` to confirm/regen the plant parameters
3) Open `simulink/hvac_pid.slx` to simulate the PI controller
4) Open `PLC/hvac_control_plc/` in OpenPLC Editor and run via OpenPLC Runtime v4
   - watch variables in the debugger (setpointTemperature, indoorTemperature, controlCommand, sampleIndex)

Quick sanity checks I used:
- sampleIndex increases at the intended sample tick
- indoorTemperature moves toward setpoint on schedule changes
- controlCommand stays within [-1, 1] and flips sign for heating/cooling
