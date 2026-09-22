extends Node

const HUD_SCENE := preload("res://ui/hud/HUD.tscn")
const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const SUPPORTED_SIZES: Array[Vector2] = [
	Vector2(960, 720),
	Vector2(844, 390),
	Vector2(360, 640),
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	var runner := RUNNER_SCENE.instantiate() as RunnerController
	get_tree().root.add_child(runner)
	var hud := HUD_SCENE.instantiate() as RunnerHUD
	get_tree().root.add_child(hud)
	var stats := RunStats.new()
	get_tree().root.add_child(stats)
	stats.reset_for_fresh_run()
	stats.award_normal_pickup()
	stats.step_simulation(65.0, 12.0, true)
	hud.bind_run_stats(stats)
	await get_tree().process_frame

	InputRouter.intent_requested.emit(InputRouter.INTENT_PAUSE)
	_assert(GameFlow.current_state == GameFlow.PAUSED, "Runtime pause intent was rejected from RUNNING.")
	await get_tree().process_frame
	_assert(GameFlow.current_state == GameFlow.PAUSED, "Opening pause intent leaked forward and immediately resumed the run.")
	var frozen_distance := runner.logical_forward_distance
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert(GameFlow.current_state == GameFlow.PAUSED, "Pause did not enter PAUSED.")
	_assert(not GameFlow.gameplay_input_enabled and not GameFlow.run_timer_enabled, "Pause did not freeze gameplay input and timer.")
	_assert(is_equal_approx(runner.logical_forward_distance, frozen_distance), "Runner advanced while paused.")

	var pause := hud.pause_overlay
	_assert(pause.visible, "HUD did not reveal the pause overlay while PAUSED.")
	_assert(pause.portraits.size() == 4, "Pause overlay did not provide four portraits.")
	_assert(pause.pause_score_label.text == "SCORE 000220", "Pause score did not bind live run metrics.")
	_assert(pause.pause_time_label.text == "TIME 00:01:05", "Pause time did not bind live run metrics.")
	for portrait: Button in pause.portraits:
		_assert(portrait.icon != null and portrait.text.is_empty(), "Pause portrait is not a face-only control.")

	# Exercise the production InputRouter signal path rather than calling the controller directly.
	InputRouter.intent_requested.emit(InputRouter.INTENT_DOWN)
	_assert(pause.portrait_index == 1, "Runtime Down intent did not move to the next portrait.")
	InputRouter.intent_requested.emit(InputRouter.INTENT_CONFIRM)
	_assert(GameFlow.selected_character_index == 1, "Runtime Confirm did not immediately apply the cosmetic selection.")
	_assert(pause.focus_target == PauseController.FocusTarget.BACK, "Portrait confirmation did not focus BACK.")

	GameFlow.development_jump_to_state(GameFlow.PAUSED)
	pause.focus_target = PauseController.FocusTarget.PORTRAITS
	InputRouter.intent_requested.emit(InputRouter.INTENT_LEFT)
	_assert(pause.focus_target == PauseController.FocusTarget.SFX, "Left from portraits did not reach SFX LEVEL.")
	AudioManager.set_effects_volume(0.5)
	InputRouter.intent_requested.emit(InputRouter.INTENT_CONFIRM)
	InputRouter.intent_requested.emit(InputRouter.INTENT_RIGHT)
	_assert(AudioManager.sfx_step == 6, "SFX did not use discrete runtime adjustment steps.")
	_assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioManager.SFX_BUS)), "Nonzero SFX step left the bus muted.")
	_assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioManager.SFX_BUS)), linear_to_db(0.6)), "SFX step did not reach the mixer bus.")
	InputRouter.intent_requested.emit(InputRouter.INTENT_CONFIRM)
	_assert(not pause.adjusting_audio, "SFX adjustment mode did not exit.")

	pause.focus_target = PauseController.FocusTarget.MUSIC
	pause.adjusting_audio = true
	AudioManager.set_music_volume(0.0)
	InputRouter.intent_requested.emit(InputRouter.INTENT_LEFT)
	_assert(AudioManager.music_step == 0 and AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioManager.MUSIC_BUS)), "Music lower bound did not mute its mixer bus.")

	# Touch +/- acts directly and GestureBlockingButton cancels the underlying swipe.
	var leaked_intents: Array[StringName] = []
	var capture := func(intent: StringName) -> void: leaked_intents.append(intent)
	InputRouter.intent_requested.connect(capture)
	InputRouter.set_usable_viewport_size(Vector2(100, 100))
	InputRouter._unhandled_input(_touch_event(0, Vector2.ZERO, true))
	pause.music_plus_button._gui_input(_touch_event(0, Vector2(80, 0), false))
	InputRouter._unhandled_input(_touch_event(0, Vector2(80, 0), false))
	_assert(leaked_intents.is_empty(), "Pause touch target leaked a gameplay swipe.")
	InputRouter.intent_requested.disconnect(capture)
	pause.music_plus_button.emit_signal("pressed")
	_assert(AudioManager.music_step == 1, "Touch plus did not directly adjust MUSIC LEVEL.")

	for supported_size: Vector2 in SUPPORTED_SIZES:
		hud.size = supported_size
		pause.size = supported_size
		pause.apply_available_size(supported_size)
		await get_tree().process_frame
		_assert(_fits(pause.summary, supported_size), "Score/Time leave the pause safe area at %s." % supported_size)
		_assert(_fits(pause.portraits_grid, supported_size), "Portraits leave the pause safe area at %s." % supported_size)
		_assert(_fits(pause.actions, supported_size), "Pause actions leave the safe area at %s." % supported_size)
		for button: Button in pause.portraits + [pause.sfx_minus_button, pause.sfx_button, pause.sfx_plus_button, pause.music_minus_button, pause.music_button, pause.music_plus_button, pause.back_button, pause.exit_button]:
			_assert(button.size.x >= 56.0 and button.size.y >= 56.0, "Pause touch target is smaller than 56x56 at %s." % supported_size)

	# Exact resume retains TRANSITION_READY rather than degrading to RUNNING.
	GameFlow.development_jump_to_state(GameFlow.TRANSITION_READY)
	_assert(GameFlow.pause_run(), "Pause from TRANSITION_READY was rejected.")
	_assert(GameFlow.resume_run() and GameFlow.current_state == GameFlow.TRANSITION_READY, "Pause did not resume the exact transition-ready state.")

	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	GameFlow.pause_run()
	pause.exit_button.emit_signal("pressed")
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT, "EXIT RUN did not route through GameFlow to Island Attract.")

	var pause_source := FileAccess.get_file_as_string("res://ui/hud/PauseOverlay.tscn").to_upper()
	for forbidden: String in ["MASTER", "STRENGTH", "STAMINA", "AGILITY", "CHARISMA", "RHYTHM", "DESCRIPTION", "CHARACTER MENU", "SOUND MENU"]:
		_assert(pause_source.find(forbidden) == -1, "Pause overlay exposes forbidden content: %s." % forbidden)

	runner.queue_free()
	hud.queue_free()
	stats.queue_free()
	if failures.is_empty():
		print("TASK20_PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		get_tree().quit(1)


func _fits(control: Control, bounds: Vector2) -> bool:
	var rect := control.get_rect()
	return rect.position.x >= -0.01 and rect.position.y >= -0.01 and rect.end.x <= bounds.x + 0.01 and rect.end.y <= bounds.y + 0.01


func _touch_event(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
