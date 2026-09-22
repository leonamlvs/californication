extends SceneTree

const MAIN_SCENE_PATH := "res://main/Main.tscn"
const INPUT_ROUTER_SCRIPT := preload("res://autoload/InputRouter.gd")

var _failed := false


func _initialize() -> void:
	var suite := _requested_suite()
	if suite == "task_01":
		_run_task_01()
		return
	_run_task_00()


func _run_task_00() -> void:
	var main_scene := ResourceLoader.load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		_fail("Could not load %s." % MAIN_SCENE_PATH)
		_finish("Task 00 foundation smoke test passed.")
		return

	var main_instance := main_scene.instantiate()
	root.add_child(main_instance)

	var required_nodes: Array[NodePath] = [
		NodePath("PresentationRoot"),
		NodePath("PresentationRoot/World"),
		NodePath("PresentationRoot/FrontendLayer"),
		NodePath("PresentationRoot/OverlayLayer"),
	]
	for required_node: NodePath in required_nodes:
		if main_instance.get_node_or_null(required_node) == null:
			_fail("Main scene is missing required composition node: %s" % required_node)
			main_instance.queue_free()
			_finish("Task 00 foundation smoke test passed.")
			return

	_assert_web_export_foundation()
	main_instance.queue_free()
	_finish("Task 00 foundation smoke test passed.")


func _run_task_01() -> void:
	var router := INPUT_ROUTER_SCRIPT.new()
	root.add_child(router)
	# SceneTree scripts run their assertions during initialization, before the
	# isolated node receives its normal ready notification.
	router._ensure_input_map()
	var intents: Array[StringName] = []
	router.intent_requested.connect(func(intent: StringName) -> void: intents.append(intent))

	for action: StringName in router.ACTION_TO_INTENT:
		_assert(InputMap.has_action(action), "InputMap is missing action %s." % action)

	_assert(router.classify_swipe(Vector2.ZERO, Vector2(-7.0, 0.0), Vector2(100.0, 100.0)) == router.INTENT_LEFT, "Left swipe did not emit left intent.")
	_assert(router.classify_swipe(Vector2.ZERO, Vector2(7.0, 0.0), Vector2(100.0, 100.0)) == router.INTENT_RIGHT, "Right swipe did not emit right intent.")
	_assert(router.classify_swipe(Vector2.ZERO, Vector2(0.0, -7.0), Vector2(100.0, 100.0)) == router.INTENT_UP, "Up swipe did not emit up intent.")
	_assert(router.classify_swipe(Vector2.ZERO, Vector2(0.0, 7.0), Vector2(100.0, 100.0)) == router.INTENT_DOWN, "Down swipe did not emit down intent.")
	_assert(router.classify_swipe(Vector2.ZERO, Vector2(5.0, 0.0), Vector2(100.0, 100.0)).is_empty(), "Swipe below threshold emitted an intent.")

	_assert(_keyboard_intent(router, intents, KEY_A) == router.INTENT_LEFT, "A did not use the left intent path.")
	_assert(_keyboard_intent(router, intents, KEY_RIGHT) == router.INTENT_RIGHT, "Right arrow did not use the right intent path.")
	_assert(_keyboard_intent(router, intents, KEY_W) == router.INTENT_UP, "W did not use the up intent path.")
	_assert(_keyboard_intent(router, intents, KEY_DOWN) == router.INTENT_DOWN, "Down arrow did not use the down intent path.")

	var gamepad_event := InputEventJoypadButton.new()
	gamepad_event.button_index = JoyButton.JOY_BUTTON_DPAD_LEFT
	gamepad_event.pressed = true
	intents.clear()
	router._unhandled_input(gamepad_event)
	_assert(intents == [router.INTENT_LEFT], "Gamepad D-pad did not use the left intent path.")

	intents.clear()
	router.set_usable_viewport_size(Vector2(100.0, 100.0))
	router._unhandled_input(_touch_event(0, Vector2.ZERO, true))
	router.cancel_active_swipe()
	router._unhandled_input(_touch_event(0, Vector2(80.0, 0.0), false))
	_assert(intents.is_empty(), "Cancelled GUI swipe emitted a gameplay intent.")

	intents.clear()
	router._unhandled_input(_touch_event(0, Vector2.ZERO, true))
	router._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	router._unhandled_input(_touch_event(0, Vector2(80.0, 0.0), false))
	_assert(intents.is_empty(), "Application focus loss left a swipe active.")

	intents.clear()
	router._unhandled_input(_touch_event(0, Vector2.ZERO, true))
	router._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	router._unhandled_input(_touch_event(0, Vector2(80.0, 0.0), false))
	_assert(intents.is_empty(), "Window or iframe focus loss left a swipe active.")

	router._unhandled_input(_touch_event(0, Vector2.ZERO, true))
	router._unhandled_input(_touch_event(1, Vector2(10.0, 10.0), true))
	router._unhandled_input(_touch_event(0, Vector2(80.0, 0.0), false))
	router._unhandled_input(_touch_event(1, Vector2(10.0, 10.0), false))
	_assert(intents.is_empty(), "Multi-touch gesture emitted a gameplay intent.")

	router.queue_free()
	_finish("Task 01 input abstraction test passed.")


func _assert_web_export_foundation() -> void:
	var export_config := ConfigFile.new()
	var load_error := export_config.load("res://export_presets.cfg")
	_assert(load_error == OK, "Could not load export_presets.cfg.")
	if load_error != OK:
		return

	_assert(export_config.get_value("preset.0", "platform", "") == "Web", "Preset 0 is not a Web export.")
	_assert(export_config.get_value("preset.0", "export_path", "") == "build/web/index.html", "Web export entry point is not build/web/index.html.")
	_assert(export_config.get_value("preset.0", "exclude_filter", "") == "ref/*, build/*", "Reference images or generated builds are not excluded from Web export.")
	_assert(not export_config.get_value("preset.0.options", "variant/thread_support", true), "Web thread support would require cross-origin isolation.")
	_assert(not export_config.get_value("preset.0.options", "variant/extensions_support", true), "Web extension support is unexpectedly enabled.")
	_assert(export_config.get_value("preset.0.options", "vram_texture_compression/for_desktop", false), "Desktop Web texture compression is disabled.")
	_assert(export_config.get_value("preset.0.options", "html/canvas_resize_policy", -1) == 2, "Web canvas is not configured to adapt to its host viewport.")
	_assert(not export_config.get_value("preset.0.options", "progressive_web_app/enabled", true), "PWA mode is unexpectedly enabled.")


func _requested_suite() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			return argument.trim_prefix("--suite=")
	return "task_00"


func _touch_event(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _keyboard_intent(router: Node, intents: Array[StringName], keycode: Key) -> StringName:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	intents.clear()
	router._unhandled_input(event)
	return intents[0] if not intents.is_empty() else &""


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	printerr(message)


func _finish(success_message: String) -> void:
	if _failed:
		quit(1)
		return
	print(success_message)
	quit(0)
