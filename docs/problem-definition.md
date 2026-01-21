# Problem definition

Use real building sensor data to model and control indoor temperature.

- Reference: target temperature
- Output: measured indoor temperature
- Input: heater valve level (0–100%)
- Controller: discrete PID in Simulink with saturation/anti-windup

Success = good tracking + stable behavior + reasonable valve activity.
