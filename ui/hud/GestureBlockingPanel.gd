extends Panel

## HUD visual regions are GUI-owned, so a gesture cannot begin on them.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		InputRouter.cancel_active_swipe()
		accept_event()
