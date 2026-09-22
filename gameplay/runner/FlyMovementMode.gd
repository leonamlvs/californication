class_name FlyMovementMode
extends MovementMode

## FLY combines the shared x-lane controller with temporary 3D altitude.
func handle_intent(runner: RunnerController, intent: StringName) -> bool:
	match intent:
		InputRouter.INTENT_LEFT: return runner._request_lane_delta(-1)
		InputRouter.INTENT_RIGHT: return runner._request_lane_delta(1)
		InputRouter.INTENT_UP: return runner._begin_swim_depth(RunnerStateSpace.Posture.RISE)
		InputRouter.INTENT_DOWN: return runner._begin_swim_depth(RunnerStateSpace.Posture.DIVE)
	return false
func physics_step(runner: RunnerController, delta: float) -> void:
	runner._advance_swim_state(delta)
