extends Node

const MAIN_SCENE := preload("res://main/Main.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameFlow.development_jump_to_state(GameFlow.BOOT)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var root: PresentationRoot = main.presentation_root
	var intro: RunIntroController = root.get_node("GameFrame/WorldContainer/GameViewport/World/RunIntroController")
	var runner: RunnerController = root.get_node("GameFrame/WorldContainer/GameViewport/World/Runner")
	var generator: TrackGenerator = root.get_node("GameFrame/WorldContainer/GameViewport/World/TrackGenerator")
	var gameplay_camera: Camera3D = root.get_node("GameFrame/WorldContainer/GameViewport/World/Camera3D")
	var logo: LogoRevealController = root.get_node("GameFrame/WorldContainer/GameViewport/World/LogoPresentationRig")
	intro.set_process(false)
	logo.set_process(false)

	GameFlow.development_jump_to_state(GameFlow.CHARACTER_SELECT_ENTER)
	await get_tree().process_frame
	logo.carousel_controller.set_process(false)
	_assert(GameFlow.current_state == GameFlow.CHARACTER_SELECT_ACTIVE, "Player Select did not reach its active state before Run Intro.")
	_assert(logo.carousel_controller.confirm_selection(), "Selected character could not be confirmed.")
	await get_tree().process_frame
	_assert(GameFlow.current_state == GameFlow.RUN_INTRO, "CHARACTER_CONFIRMED did not automatically enter RUN_INTRO.")
	_assert(ScenarioManager.active_scenario_id == GameFlow.BOULEVARD_ID, "Run Intro did not prepare Boulevard.")
	_assert(generator.suspended and runner.movement_suspended and runner.is_invulnerable, "Runner or generator unlocked before the camera settled.")
	_assert(not GameFlow.gameplay_input_enabled and not GameFlow.run_timer_enabled, "Input or timer unlocked during Run Intro.")
	_assert(generator.active_segments.front().pattern.safe_fallback, "Boulevard Run Intro did not establish a safe opening runway.")
	var selected_id := GameFlow.selected_character_id
	var time_before: float = generator.run_stats.elapsed_seconds
	generator.step_simulation(runner.logical_forward_distance, runner.current_speed, 2.0)
	_assert(is_equal_approx(generator.run_stats.elapsed_seconds, time_before), "Run timer advanced before RUNNING.")
	InputRouter.request_intent(InputRouter.INTENT_RIGHT)
	_assert(GameFlow.current_state == GameFlow.RUN_INTRO, "Gameplay movement input changed state during Run Intro.")
	_assert(not gameplay_camera.current and logo.logo_camera.current, "Camera did not remain on the selected character during the push.")

	intro.advance_for_test(intro.push_duration)
	_assert(intro.stage == RunIntroController.Stage.HOLD and logo.player_select_presenter.root_control.modulate.a <= 0.01, "Player UI did not fade by the front-character hold.")
	intro.advance_for_test(intro.front_hold_duration)
	intro.advance_for_test(intro.orbit_duration)
	_assert(GameFlow.current_state == GameFlow.RUNNING, "Run Intro did not settle into RUNNING.")
	_assert(GameFlow.gameplay_input_enabled and GameFlow.run_timer_enabled and not generator.suspended, "Gameplay did not unlock only after Run Intro settled.")
	_assert(gameplay_camera.current and not logo.visible, "Camera or frontend did not clear after the handoff.")
	_assert(main.character_presenter.cosmetic.matches_definition(_definition_for_id(selected_id)), "Gameplay runner identity does not match the selected character.")
	_assert(FileAccess.get_file_as_string("res://gameplay/runner/RunnerController.gd").to_lower().find("run_intro") == -1, "RunnerController contains Run Intro choreography.")

	GameFlow.development_jump_to_state(GameFlow.TRY_AGAIN)
	_assert(GameFlow.choose_try_again(true), "Retry YES did not request a fresh run.")
	_assert(GameFlow.current_state == GameFlow.RUN_INTRO and ScenarioManager.active_scenario_id == GameFlow.BOULEVARD_ID, "Retry YES did not return directly to Boulevard Run Intro.")
	intro.development_complete_run_intro()
	_assert(GameFlow.current_state == GameFlow.RUNNING, "Dev Run Intro completion shortcut did not settle the retry.")

	GameFlow.development_jump_to_state(GameFlow.CHARACTER_CONFIRMED)
	_assert(intro.development_enter_run_intro(), "Dev Run Intro entry shortcut did not start.")
	intro._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_assert(GameFlow.current_state == GameFlow.RUN_INTRO and runner.movement_suspended, "Focus loss unexpectedly unlocked gameplay.")
	intro._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	intro.advance_for_test(2.0)
	_assert(GameFlow.current_state == GameFlow.RUNNING, "Refocused Run Intro did not settle.")

	main.queue_free()
	if failures.is_empty():
		print("TASK26_PASS")
		get_tree().quit(0)
	else:
		for failure_message: String in failures:
			push_error(failure_message)
		get_tree().quit(1)


func _definition_for_id(character_id: StringName) -> CharacterDefinition:
	for definition: CharacterDefinition in RunIntroController.CHARACTERS:
		if definition.id == character_id:
			return definition
	return null


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
