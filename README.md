# HVAC Control (Data → Model ID → PI Control → PLC)

This repo documents a small end-to-end controls project:
1) extract and preprocess HVAC time-series data,
2) identify a simple discrete-time plant model,
3) tune/test a PI controller in Simulink,
4) port the same logic into an OpenPLC Structured Text program (OpenPLC Runtime v4) for PLC-style simulation.

## Data source

Primary dataset: Photon Energy office-building temperature control dataset hosted on Hugging Face. :contentReference[oaicite:0]{index=0}

Link:
https://huggingface.co/datasets/ml-photonenergy/Photon-Energy-office-building-temperature-control/tree/main

Note: the raw dataset is large. This repo does not include the full raw dump; it includes processed subsets used for modeling/control.

## Repo structure

- `data/raw/`
  - placeholder only (raw data not committed)
- `data/processed/`
  - processed CSVs used for training/validation/testing and control experiments
- `scripts/`
  - R scripts for extraction, merge/resample, and dataset generation
- `matlab/`
  - MATLAB scripts for plant identification and exporting parameters
- `simulink/`
  - Simulink models used to simulate and tune the PI controller
- `PLC/`
  - OpenPLC Runtime v4 project files and Structured Text program (to be added next)

## What the controller does

- PI controller with:
  - error deadband
  - actuator saturation (e.g., command limited to [-1, 1])
  - integrator clamping to prevent runaway
- Heating and cooling supported (different plant gains for heat vs cool)
- Discrete-time simulation uses a simple identified model of the form:
  - T(k+1) = a*T(k) + b*u(k) + c
  - with separate b for heating vs cooling

## OpenPLC / PLC implementation

Goal: reproduce the same PI logic and the same discrete-time plant update inside OpenPLC Structured Text, running under OpenPLC Runtime v4 on Windows.

Planned contents in `PLC/`:
- the OpenPLC project export
- the Structured Text program used for simulation
- a short note on cycle time / sample tick configuration

## Results

Add plots/screenshots under:
- `results/figures/`
- `results/notes.md` (optional short write-up of what each figure shows)

Recommended minimum screenshots:
- setpoint vs indoor temperature (step schedule test)
- control command (show saturation + sign changes for heat/cool)
- sample index / sample tick timing (to prove the PLC timing matches the intended sample time)

Example embedding in this README after you add images:
- `![Setpoint vs Indoor Temp](results/figures/setpoint_vs_temp.png)`
- `![Control Command](results/figures/control_command.png)`

## How to run (high level)

- Run the R scripts in `scripts/` to generate `data/processed/` outputs
- Run `matlab/identify_plant.m` to identify/record plant parameters
- Open the Simulink models in `simulink/` to simulate and tune PI behavior
- (Next) Load the PLC program into OpenPLC Runtime v4 and watch variables in the debugger
