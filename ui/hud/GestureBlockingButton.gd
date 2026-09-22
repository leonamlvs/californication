extends Button

## Future pause behavior is separate; this preserves the shared gesture contract now.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		InputRouter.cancel_active_swipe()
		accept_event()
