extends Control

func _ready() -> void:
	GameFlow.state_changed.connect(func(_previous: StringName, next: StringName): visible = next == GameFlow.ISLAND_ATTRACT)
	visible = GameFlow.current_state == GameFlow.ISLAND_ATTRACT

## State-owned ordinary tap continuation. It is visible only while Island Attract waits.
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		InputRouter.cancel_active_swipe()
		GameFlow.handle_intent(InputRouter.INTENT_CONFIRM)
		accept_event()
