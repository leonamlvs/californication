extends Control

## State-owned ordinary tap continuation. It is visible only while Island Attract waits.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		InputRouter.cancel_active_swipe()
		GameFlow.handle_intent(InputRouter.INTENT_CONFIRM)
		accept_event()
