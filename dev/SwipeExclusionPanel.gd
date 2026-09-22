extends Panel

## Demonstrates the contract used by future HUD/menu controls: consumed UI input
## cancels an in-progress swipe before it can become gameplay input.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		InputRouter.cancel_active_swipe()
		accept_event()
