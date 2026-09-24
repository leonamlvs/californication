extends Node

## Normalizes keyboard, gamepad, and unhandled touch gestures into shared intents.
## Gameplay consumers must subscribe to `intent_requested` and never inspect devices.

signal intent_requested(intent: StringName)

const INTENT_LEFT: StringName = &"left"
const INTENT_RIGHT: StringName = &"right"
const INTENT_UP: StringName = &"up"
const INTENT_DOWN: StringName = &"down"
const INTENT_PAUSE: StringName = &"pause"
const INTENT_CONFIRM: StringName = &"confirm"
const INTENT_BACK: StringName = &"back"

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_UP: StringName = &"move_up"
const ACTION_MOVE_DOWN: StringName = &"move_down"
const ACTION_PAUSE: StringName = &"pause"
const ACTION_CONFIRM: StringName = &"confirm"
const ACTION_BACK: StringName = &"back"

const ACTION_TO_INTENT: Dictionary[StringName, StringName] = {
	ACTION_MOVE_LEFT: INTENT_LEFT,
	ACTION_MOVE_RIGHT: INTENT_RIGHT,
	ACTION_MOVE_UP: INTENT_UP,
	ACTION_MOVE_DOWN: INTENT_DOWN,
	ACTION_PAUSE: INTENT_PAUSE,
	ACTION_CONFIRM: INTENT_CONFIRM,
	ACTION_BACK: INTENT_BACK,
}

## The swipe distance is measured against the shorter currently usable dimension.
@export_range(0.01, 0.25, 0.005) var swipe_threshold_ratio: float = 0.06

var _active_touch_index: int = -1
var _active_touch_count: int = 0
var _swipe_start_position := Vector2.ZERO
var _swipe_usable_size := Vector2.ZERO
var _gesture_cancelled := false
var _usable_viewport_size_override := Vector2.ZERO
var is_dispatching_intent := false


func _ready() -> void:
	_ensure_input_map()
	get_viewport().size_changed.connect(cancel_active_swipe)


func _notification(what: int) -> void:
	# A Web build can lose either canvas/window focus inside the itch.io iframe or
	# application focus when the browser tab is backgrounded. Neither may leave a
	# partially recorded swipe alive for the next interaction.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_active_swipe()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return

	if event is InputEventScreenDrag:
		if _active_touch_index >= 0 and event.index != _active_touch_index:
			cancel_active_swipe()
		elif _active_touch_index >= 0 and not _gesture_cancelled:
			var intent := classify_swipe(_swipe_start_position, event.position, _swipe_usable_size)
			if not intent.is_empty():
				request_intent(intent)
				_gesture_cancelled = true
		return

	if event is InputEventKey and event.echo:
		return

	if event.is_pressed():
		_emit_mapped_action(event)


## Emits an intent only when it is part of the shared input contract.
func request_intent(intent: StringName) -> void:
	if ACTION_TO_INTENT.values().has(intent):
		is_dispatching_intent = true
		intent_requested.emit(intent)
		is_dispatching_intent = false


## Allows the responsive UI layer to provide its safe, usable input rectangle.
## A zero size restores the current viewport as the swipe reference.
func set_usable_viewport_size(size: Vector2) -> void:
	_usable_viewport_size_override = size.max(Vector2.ZERO)


## GUI controls should call this when they consume a pointer sequence.
func cancel_active_swipe() -> void:
	_active_touch_index = -1
	_active_touch_count = 0
	_swipe_start_position = Vector2.ZERO
	_swipe_usable_size = Vector2.ZERO
	_gesture_cancelled = true


## Pure swipe classification used by the CLI suite and future input fixtures.
func classify_swipe(start_position: Vector2, end_position: Vector2, usable_size: Vector2) -> StringName:
	var shorter_dimension := minf(usable_size.x, usable_size.y)
	if shorter_dimension <= 0.0:
		return &""

	var displacement := end_position - start_position
	if displacement.length() < shorter_dimension * swipe_threshold_ratio:
		return &""

	if absf(displacement.x) >= absf(displacement.y):
		return INTENT_RIGHT if displacement.x > 0.0 else INTENT_LEFT
	return INTENT_DOWN if displacement.y > 0.0 else INTENT_UP


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_active_touch_count += 1
		if _active_touch_count == 1:
			_active_touch_index = event.index
			_swipe_start_position = event.position
			_swipe_usable_size = _get_usable_viewport_size()
			_gesture_cancelled = false
		else:
			_gesture_cancelled = true
		return

	if _active_touch_count > 0:
		_active_touch_count -= 1
	if event.index != _active_touch_index:
		if _active_touch_count == 0:
			_reset_touch_state()
		return

	if not _gesture_cancelled:
		request_intent(classify_swipe(_swipe_start_position, event.position, _swipe_usable_size))
	_reset_touch_state()


func _emit_mapped_action(event: InputEvent) -> void:
	for action: StringName in ACTION_TO_INTENT:
		if event.is_action_pressed(action, false):
			request_intent(ACTION_TO_INTENT[action])
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return


func _get_usable_viewport_size() -> Vector2:
	if _usable_viewport_size_override.x > 0.0 and _usable_viewport_size_override.y > 0.0:
		return _usable_viewport_size_override
	return get_viewport().get_visible_rect().size


func _reset_touch_state() -> void:
	_active_touch_index = -1
	_active_touch_count = 0
	_swipe_start_position = Vector2.ZERO
	_swipe_usable_size = Vector2.ZERO
	_gesture_cancelled = false


func _ensure_input_map() -> void:
	_register_action(ACTION_MOVE_LEFT, [_key_event(KEY_A), _key_event(KEY_LEFT), _joy_button_event(JoyButton.JOY_BUTTON_DPAD_LEFT), _joy_axis_event(JoyAxis.JOY_AXIS_LEFT_X, -1.0)])
	_register_action(ACTION_MOVE_RIGHT, [_key_event(KEY_D), _key_event(KEY_RIGHT), _joy_button_event(JoyButton.JOY_BUTTON_DPAD_RIGHT), _joy_axis_event(JoyAxis.JOY_AXIS_LEFT_X, 1.0)])
	_register_action(ACTION_MOVE_UP, [_key_event(KEY_W), _key_event(KEY_UP), _joy_button_event(JoyButton.JOY_BUTTON_DPAD_UP), _joy_axis_event(JoyAxis.JOY_AXIS_LEFT_Y, -1.0)])
	_register_action(ACTION_MOVE_DOWN, [_key_event(KEY_S), _key_event(KEY_DOWN), _joy_button_event(JoyButton.JOY_BUTTON_DPAD_DOWN), _joy_axis_event(JoyAxis.JOY_AXIS_LEFT_Y, 1.0)])
	_register_action(ACTION_PAUSE, [_key_event(KEY_P), _key_event(KEY_ESCAPE), _joy_button_event(JoyButton.JOY_BUTTON_START)])
	_register_action(ACTION_CONFIRM, [_key_event(KEY_ENTER), _key_event(KEY_SPACE), _joy_button_event(JoyButton.JOY_BUTTON_A)])
	_register_action(ACTION_BACK, [_key_event(KEY_BACKSPACE), _joy_button_event(JoyButton.JOY_BUTTON_B)])


func _register_action(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for input_event: InputEvent in events:
		if not InputMap.action_has_event(action, input_event):
			InputMap.action_add_event(action, input_event)


func _key_event(keycode: Key) -> InputEventKey:
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	return input_event


func _joy_button_event(button: JoyButton) -> InputEventJoypadButton:
	var input_event := InputEventJoypadButton.new()
	input_event.button_index = button
	return input_event


func _joy_axis_event(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var input_event := InputEventJoypadMotion.new()
	input_event.axis = axis
	input_event.axis_value = direction
	return input_event
