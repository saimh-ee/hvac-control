PROGRAM main
VAR
	plantA : real := 0.999951185242347;
	plantBHeat : real := 0.020589313234843;
	plantBCool : real := 0.006176793970453;
	plantBiasC : real := -0.001383511783900;
	controllerKp : real := 0.9;
	controllerKi : real := 1.75e-5;
	errorDeadbandDegC : real := 0.25;
	controlOutputMin : real := -1.0;
	controlOutputMax : real := 1.0;
	integratorStateMin : real := -1.0;
	integratorStateMax : real := 1.0;
	setpointTemperature : real := 23.0;
	indoorTemperature : real := 20.0;
	trackingErrorDegC : real := 0.0;
	integratorState : real := 0.0;
	controlCommandUnsat : real := 0.0;
	controlCommand : real := 0.0;
	effectivePlantB : real := 0.0;
	sampleIndex : dint := 0;
	sampleTimerEnable : bool := TRUE;
	sampleTick : bool := FALSE;
	sampleTimer : TON;
END_VAR

sampleTimerEnable := NOT sampleTimer.Q;
sampleTimer(IN := sampleTimerEnable, PT := T#5s);
sampleTick := sampleTimer.Q;

IF sampleTick THEN
  sampleIndex := sampleIndex + 1;

  IF sampleIndex < 4 THEN
    setpointTemperature := 23.0;
  ELSIF sampleIndex < 8 THEN
    setpointTemperature := 21.0;
  ELSIF sampleIndex < 12 THEN
    setpointTemperature := 24.0;
  ELSIF sampleIndex < 16 THEN
    setpointTemperature := 22.5;
  ELSIF sampleIndex < 20 THEN
    setpointTemperature := 20;
  ELSIF sampleIndex < 24 THEN
    setpointTemperature := 24;
  
  ELSE
    setpointTemperature := 22.0;
  END_IF;

  trackingErrorDegC := setpointTemperature - indoorTemperature;

  IF ABS(trackingErrorDegC) < errorDeadbandDegC THEN
    trackingErrorDegC := 0.0;
  END_IF;

  integratorState := integratorState + controllerKi * trackingErrorDegC;

  IF integratorState > integratorStateMax THEN
    integratorState := integratorStateMax;
  ELSIF integratorState < integratorStateMin THEN
    integratorState := integratorStateMin;
  END_IF;

  controlCommandUnsat := controllerKp * trackingErrorDegC + integratorState;

  controlCommand := controlCommandUnsat;

  IF controlCommand > controlOutputMax THEN
    controlCommand := controlOutputMax;
  ELSIF controlCommand < controlOutputMin THEN
    controlCommand := controlOutputMin;
  END_IF;

  IF controlCommand >= 0.0 THEN
    effectivePlantB := plantBHeat;
  ELSE
    effectivePlantB := plantBCool;
  END_IF;

  indoorTemperature := plantA * indoorTemperature + effectivePlantB * controlCommand + plantBiasC;
END_IF;

END_PROGRAM