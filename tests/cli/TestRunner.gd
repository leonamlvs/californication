extends SceneTree

const MAIN_SCENE_PATH := "res://main/Main.tscn"
const INPUT_ROUTER_SCRIPT := preload("res://autoload/InputRouter.gd")
const PRESENTATION_ROOT_SCENE := preload("res://presentation/PresentationRoot.tscn")
const GAME_FLOW_SCRIPT := preload("res://autoload/GameFlow.gd")
const GAME_FLOW_PLACEHOLDER_SCENE := preload("res://ui/menus/GameFlowPlaceholder.tscn")

var _failed := false


func _initialize() -> void:
	var suite := _requested_suite()
	match suite:
		"task_01": _run_task_01()
		"task_02": _run_task_02()
		"task_03": _run_task_03()
		_: _run_task_00()


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
		NodePath("PresentationRoot/GameFrame/WorldContainer/GameViewport/World"),
		NodePath("PresentationRoot/GameFrame/FrontendLayer"),
		NodePath("PresentationRoot/GameFrame/OverlayLayer"),
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


func _run_task_02() -> void:
	var presentation := PRESENTATION_ROOT_SCENE.instantiate() as PresentationRoot
	root.add_child(presentation)

	var desktop := presentation.preview_layout(Vector2(960, 720), false)
	_assert(not desktop.mobile_flex, "Reference desktop unexpectedly selected mobile-flex mode.")
	_assert(desktop.frame_rect.size == Vector2(960, 720), "Reference desktop frame is not 960 x 720.")
	_assert(desktop.hud_profile == RunnerHUD.Profile.FULL, "Reference desktop did not select FULL HUD.")

	var wide_desktop := presentation.preview_layout(Vector2(1600, 900), false)
	_assert(not wide_desktop.mobile_flex, "Wide desktop unexpectedly selected mobile-flex mode.")
	_assert(is_equal_approx(wide_desktop.frame_rect.size.x / wide_desktop.frame_rect.size.y, 4.0 / 3.0), "Desktop frame is stretched instead of 4:3.")

	var tablet := presentation.preview_layout(Vector2(1024, 768), true)
	_assert(not tablet.mobile_flex and tablet.hud_profile == RunnerHUD.Profile.FULL, "4:3 tablet should retain desktop FULL presentation.")

	var landscape_phone := presentation.preview_layout(Vector2(844, 390), true)
	_assert(landscape_phone.mobile_flex and landscape_phone.hud_profile == RunnerHUD.Profile.MEDIUM, "Landscape phone did not select mobile-flex MEDIUM profile.")
	_assert(not presentation.hud.scenario_panel.visible, "MEDIUM profile kept scenario panel visible.")

	var narrow_phone := presentation.preview_layout(Vector2(360, 640), true)
	_assert(narrow_phone.mobile_flex and narrow_phone.hud_profile == RunnerHUD.Profile.COMPACT, "Narrow phone did not select mobile-flex COMPACT profile.")
	_assert(not presentation.hud.coordinate_panel.visible and not presentation.hud.scenario_panel.visible, "COMPACT profile kept optional panels visible.")
	_assert(presentation.hud.pause_button.custom_minimum_size.x >= 56.0 and presentation.hud.pause_button.custom_minimum_size.y >= 56.0, "Pause target is smaller than 56 x 56.")

	var inset_phone := presentation.preview_layout(Vector2(390, 844), true, Vector4(20, 30, 20, 30))
	_assert(inset_phone.safe_rect.position == Vector2(20, 30) and inset_phone.safe_rect.size == Vector2(350, 784), "Safe inset simulation produced an incorrect usable rectangle.")
	_assert(presentation.frontend_safe_guide.mandatory_guides_fit(), "Frontend mandatory composition guides leave the safe region.")

	var intents: Array[StringName] = []
	InputRouter.intent_requested.connect(func(intent: StringName) -> void: intents.append(intent))
	InputRouter.set_usable_viewport_size(Vector2(100, 100))
	InputRouter._unhandled_input(_touch_event(0, Vector2.ZERO, true))
	presentation.hud.pause_button._gui_input(_touch_event(0, Vector2(70, 0), false))
	InputRouter._unhandled_input(_touch_event(0, Vector2(70, 0), false))
	_assert(intents.is_empty(), "HUD pause target leaked a touch gesture into gameplay.")
	InputRouter.intent_requested.disconnect(InputRouter.intent_requested.get_connections().back().callable)

	presentation.queue_free()
	_finish("Task 02 responsive UI test passed.")


func _run_task_03() -> void:
	var flow := _new_game_flow()
	var rejected: Array[StringName] = []
	flow.transition_rejected.connect(func(_from: StringName, requested: StringName, _reason: String) -> void: rejected.append(requested))
	_assert(not flow.request_transition(flow.RUNNING), "Illegal BOOT to RUNNING transition was accepted.")
	_assert(rejected == [flow.RUNNING], "Illegal transition did not emit a diagnostic signal.")

	_assert(flow.begin_session() and flow.current_state == flow.LOADING, "Session did not enter LOADING.")
	_assert(flow.advance_placeholder() and flow.current_state == flow.ISLAND_INTRO, "LOADING did not advance to ISLAND_INTRO.")
	_assert(flow.advance_placeholder() and flow.current_state == flow.ISLAND_ATTRACT, "ISLAND_INTRO did not advance to ISLAND_ATTRACT.")
	_assert(not flow.gameplay_input_enabled and not flow.run_timer_enabled, "Island attract enabled gameplay prematurely.")
	_assert(flow.handle_intent(InputRouter.INTENT_CONFIRM) and flow.current_state == flow.LOGO_REVEAL, "Island confirm did not advance exactly once.")
	_assert(not flow.handle_intent(InputRouter.INTENT_CONFIRM) and flow.current_state == flow.LOGO_REVEAL, "Entry input leaked into a second frontend state.")
	flow._unlock_entry_input()
	_assert(flow.advance_placeholder() and flow.current_state == flow.CHARACTER_SELECT_ENTER, "Logo stage did not advance to character-select entry.")
	_assert(flow.advance_placeholder() and flow.current_state == flow.CHARACTER_SELECT_ACTIVE, "Character-select entry did not reach active selection.")
	var selected_before := flow.selected_character_id
	_assert(flow.handle_intent(InputRouter.INTENT_RIGHT), "Character selection intent was not accepted.")
	_assert(flow.current_state == flow.CHARACTER_SELECT_ACTIVE and flow.selected_character_id != selected_before, "Selection intent incorrectly confirmed or did not change character.")
	flow._unlock_entry_input()
	_assert(flow.handle_intent(InputRouter.INTENT_CONFIRM) and flow.current_state == flow.CHARACTER_CONFIRMED, "Character confirm did not enter CHARACTER_CONFIRMED.")
	_assert(not flow.gameplay_input_enabled and not flow.run_timer_enabled, "Character confirmation enabled gameplay prematurely.")
	_assert(not flow.report_run_intro_ready(true, true), "RUN_INTRO readiness was accepted before RUN_INTRO.")
	_assert(flow.start_new_run() and flow.current_state == flow.RUN_INTRO, "Confirmed character did not enter RUN_INTRO.")
	_assert(not flow.report_run_intro_ready(true, false) and not flow.report_run_intro_ready(false, true), "Partial RUN_INTRO readiness enabled gameplay.")
	_assert(flow.report_run_intro_ready(true, true) and flow.current_state == flow.RUNNING, "Complete RUN_INTRO readiness did not enter RUNNING.")
	_assert(flow.gameplay_input_enabled and flow.run_timer_enabled, "RUNNING did not enable gameplay and timer.")
	_assert(flow.pause_run() and flow.current_state == flow.PAUSED, "Pause transition failed.")
	_assert(flow.resume_run() and flow.current_state == flow.RUNNING, "Resume transition failed.")
	_assert(flow.fail_run() and flow.advance_placeholder() and flow.advance_placeholder(), "Failure placeholder path did not reach TRY_AGAIN.")
	_assert(flow.current_state == flow.TRY_AGAIN, "Failure path did not reach TRY_AGAIN.")
	var retained_character := flow.selected_character_id
	_assert(flow.choose_try_again(false) and flow.current_state == flow.ISLAND_ATTRACT, "Retry NO did not return to island attract.")
	_assert(flow.selected_character_id == retained_character and flow.intro_seen, "Retry NO did not preserve session character/intro state.")
	flow.queue_free()

	var retry_flow := _new_game_flow()
	_reach_running(retry_flow)
	var retry_character := retry_flow.selected_character_id
	retry_flow.fail_run()
	retry_flow.advance_placeholder()
	retry_flow.advance_placeholder()
	_assert(retry_flow.choose_try_again(true) and retry_flow.current_state == retry_flow.RUN_INTRO, "Retry YES did not prepare RUN_INTRO.")
	_assert(retry_flow.prepared_run_target == retry_flow.BOULEVARD_ID and retry_flow.selected_character_id == retry_character, "Retry YES did not preserve character or prepare Boulevard.")
	retry_flow.queue_free()

	var touch_placeholder := GAME_FLOW_PLACEHOLDER_SCENE.instantiate()
	root.add_child(touch_placeholder)
	_assert(GameFlow.current_state == GameFlow.LOADING, "Placeholder scene did not begin the global session in LOADING.")
	GameFlow.advance_placeholder()
	GameFlow.advance_placeholder()
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT, "Global placeholder flow did not reach Island Attract.")
	touch_placeholder.touch_confirm_surface._gui_input(_touch_event(0, Vector2(100, 100), true))
	_assert(GameFlow.current_state == GameFlow.LOGO_REVEAL, "Ordinary Island Attract touch did not advance once through the state-owned surface.")
	touch_placeholder.queue_free()
	_finish("Task 03 GameFlow state test passed.")


func _new_game_flow() -> Node:
	var flow := GAME_FLOW_SCRIPT.new()
	root.add_child(flow)
	return flow


func _reach_running(flow: Node) -> void:
	_assert(flow.begin_session(), "Could not start GameFlow session.")
	_assert(flow.advance_placeholder(), "Could not enter ISLAND_INTRO.")
	_assert(flow.advance_placeholder(), "Could not enter ISLAND_ATTRACT.")
	_assert(flow.request_transition(flow.LOGO_REVEAL), "Could not enter LOGO_REVEAL.")
	_assert(flow.request_transition(flow.CHARACTER_SELECT_ENTER), "Could not enter CHARACTER_SELECT_ENTER.")
	_assert(flow.request_transition(flow.CHARACTER_SELECT_ACTIVE), "Could not enter CHARACTER_SELECT_ACTIVE.")
	_assert(flow.set_selected_character(&"placeholder_03"), "Could not select placeholder character.")
	_assert(flow.request_transition(flow.CHARACTER_CONFIRMED), "Could not confirm placeholder character.")
	_assert(flow.start_new_run(), "Could not begin RUN_INTRO.")
	_assert(flow.report_run_intro_ready(true, true), "Could not enter RUNNING after readiness.")


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
