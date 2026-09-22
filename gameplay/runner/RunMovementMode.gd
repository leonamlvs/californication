class_name RunMovementMode
extends MovementMode

## RUN interprets the shared directional contract; no scenario or art identity is involved.
func handle_intent(runner: RunnerController, intent: StringName) -> bool:
	match intent:
		InputRouter.INTENT_LEFT:
			return runner._request_lane_delta(-1)
		InputRouter.INTENT_RIGHT:
			return runner._request_lane_delta(1)
		InputRouter.INTENT_UP:
			return runner._begin_jump()
		InputRouter.INTENT_DOWN:
			return runner._begin_slide()
	return false


func physics_step(runner: RunnerController, delta: float) -> void:
	runner._advance_run_state(delta)
