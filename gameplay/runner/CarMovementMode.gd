class_name CarMovementMode
extends MovementMode

## CAR keeps the shared lane controller. Up is a declared ramp jump; Down is
## intentionally unused so survival never depends on braking or crouching.
func handle_intent(runner: RunnerController, intent: StringName) -> bool:
	match intent:
		InputRouter.INTENT_LEFT:
			return runner._request_lane_delta(-1)
		InputRouter.INTENT_RIGHT:
			return runner._request_lane_delta(1)
		InputRouter.INTENT_UP:
			return runner._begin_jump()
	return false


func physics_step(runner: RunnerController, delta: float) -> void:
	runner._advance_run_state(delta)
