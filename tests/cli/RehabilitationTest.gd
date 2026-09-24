extends Node

const MAIN := preload("res://main/Main.tscn")
const RUNNER := preload("res://gameplay/runner/Runner.tscn")
var failures: Array[String] = []
var main: Node
var render := false
var capture_index := 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	render = OS.get_cmdline_user_args().has("--render")
	ScenarioManager.reset_for_tests()
	GameFlow.development_jump_to_state(GameFlow.BOOT)
	main = MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.runner.set_physics_process(false)
	main.generator.set_physics_process(false)
	main.generator.randomize_runtime_seed = false
	main.coordinator.set_physics_process(false)
	main.run_intro.set_process(false)
	main.logo_frontend.set_process(false)
	var island: IslandFrontendController = main.world.get_node("IslandFrontend")
	island.set_process(false)
	_check(GameFlow.current_state == GameFlow.LOADING, "Production bootstrap did not start loading")
	_check(main.generator.active_segments.is_empty() and not main.generator.visible and not main.runner.visible, "Gameplay leaked into frontend")
	_check(main.find_child("GameFlowPlaceholder", true, false) == null and main.find_child("PlaceholderBlock", true, false) == null, "Debug composition leaked")
	island.advance_for_test(island.loading_duration)
	island.advance_for_test(island.intro_duration)
	_check(GameFlow.current_state == GameFlow.ISLAND_ATTRACT, "Intro did not reach attract")
	await _capture("island")
	await get_tree().process_frame
	InputRouter.request_intent(InputRouter.INTENT_CONFIRM)
	_check(GameFlow.current_state == GameFlow.LOGO_REVEAL, "Attract confirm failed")
	main.logo_frontend.advance_for_test(4.5)
	await _capture("logo")
	main.logo_frontend.advance_for_test(4.0)
	await get_tree().process_frame
	await _capture("selection")
	_check(GameFlow.current_state == GameFlow.CHARACTER_SELECT_ACTIVE, "Reveal did not reach Player Select")
	_check(main.logo_frontend.carousel_controller.confirm_selection(), "Player Select rejected confirmation")
	# A capture resumes after frame_post_draw; its deferred state work can run
	# after the next process_frame signal. Wait for the actual state barrier.
	for frame: int in range(3):
		if GameFlow.current_state == GameFlow.RUN_INTRO:
			break
		await get_tree().process_frame
	_check(GameFlow.current_state == GameFlow.RUN_INTRO and main.generator.suspended, "Run intro protection failed")
	main.run_intro._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	main.run_intro.advance_for_test(2.0)
	_check(GameFlow.current_state == GameFlow.RUNNING and main.gameplay_camera.current, "Run intro did not settle")
	_check(main.failure.active_scenario == ScenarioManager.active_definition, "Failure service was not rebound")
	await _validate_scenario()
	var first_hazard := INF
	for segment: TrackSegment in main.generator.active_segments:
		for obstacle: ObstacleBase in segment.active_obstacles:
			first_hazard = minf(first_hazard, obstacle.forward_distance)
	_check(first_hazard / main.runner.current_speed >= 2.5 and first_hazard / main.runner.current_speed <= 4.0, "Opening hazard outside 2.5–4 second window")
	await _capture("boulevard")
	InputRouter.request_intent(InputRouter.INTENT_PAUSE)
	_check(GameFlow.current_state == GameFlow.PAUSED, "Routed pause failed")
	var time_before: float = main.generator.run_stats.elapsed_seconds
	await _capture("pause")
	_check(main.generator.run_stats.elapsed_seconds == time_before, "Pause advanced timer")
	await get_tree().process_frame
	InputRouter.request_intent(InputRouter.INTENT_PAUSE)
	_check(GameFlow.current_state == GameFlow.RUNNING, "Routed resume toggled twice")
	await get_tree().process_frame
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	_check(main.runner.target_lane_index == 2, "Native key event did not reach shared InputRouter")
	key.pressed = false
	Input.parse_input_event(key)
	main.runner.reset_for_run()
	# First-run token goes through the real generator update, not its dev shortcut.
	main.runner.set_invulnerable(true)
	main.coordinator.step_simulation(56.0)
	var token: TransitionToken = main.coordinator.active_token
	_check(token != null, "First-run token was not offered")
	if token != null:
		main.runner.position = Vector3.ZERO
		main.runner.logical_forward_distance = token.forward_distance
		main.generator.step_simulation(token.forward_distance, main.runner.current_speed, 0.1)
	_check(GameFlow.current_state == GameFlow.SCENARIO_TRANSITION, "Generator did not collect token")
	_check(main.generator.run_stats.score >= 1000, "Transition bonus missing")
	await _finish_cinematic()
	_check(ScenarioManager.active_scenario_id != &"boulevard" and GameFlow.current_state == GameFlow.RUNNING, "First-run shuffle handoff failed")
	var seen: Array[StringName] = [&"boulevard", ScenarioManager.active_scenario_id]
	for index: int in range(7):
		await _validate_scenario()
		main.coordinator.development_force_token_collection()
		await _finish_cinematic()
		_check(not seen.has(ScenarioManager.active_scenario_id), "Shuffle repeated before visiting all eight destinations")
		seen.append(ScenarioManager.active_scenario_id)
	await _validate_scenario()
	_check(seen.size() == 9, "Not all nine scenarios visited")
	# Real obstacle evaluation must autonomously reach Game Over.
	main.runner.set_invulnerable(false)
	var hit := preload("res://gameplay/obstacles/ObstacleBlock.tscn").instantiate() as ObstacleBase
	main.world.add_child(hit)
	hit.definition = hit.definition.duplicate() as ObstacleDefinition
	hit.definition.allowed_movement_modes = [main.runner.current_movement_mode]
	hit.reset_for_spawn(main.runner.logical_forward_distance, 1)
	main.runner.position = Vector3.ZERO
	hit.step_simulation(main.runner, 0.0)
	_check(GameFlow.current_state == GameFlow.FAILURE_TRANSITION, "Collision did not start failure presentation")
	await get_tree().create_timer(0.55).timeout
	_check(GameFlow.current_state == GameFlow.LAVA_GAME_OVER, "Failure did not automatically reach Game Over")
	await _capture("failure")
	InputRouter.request_intent(InputRouter.INTENT_CONFIRM)
	_check(GameFlow.current_state == GameFlow.RUN_INTRO and ScenarioManager.active_scenario_id == &"boulevard", "Retry did not prepare fresh Boulevard")
	_check(main.runner.run_elapsed == 0.0 and main.generator.run_stats.score == 0, "Retry did not reset progress and score")
	main.run_intro.advance_for_test(2.0)
	main.runner.request_obstacle_hit(ObstacleHitEvent.new())
	await get_tree().create_timer(0.55).timeout
	InputRouter.request_intent(InputRouter.INTENT_DOWN)
	InputRouter.request_intent(InputRouter.INTENT_CONFIRM)
	_check(GameFlow.current_state == GameFlow.ISLAND_ATTRACT and not main.generator.visible and ScenarioManager.active_definition == null, "Island return did not clean up gameplay")
	if not render:
		_test_runner_rates()
		await _soak()
	print("REHABILITATION_%s checks: production flow, nine scenarios, camera, runner rates, generation" % ("PASS" if failures.is_empty() else "FAIL"))
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _finish_cinematic() -> void:
	var cinematic: ScenarioTransitionController = main.coordinator.active_cinematic
	if cinematic == null:
		_check(false, "No active cinematic")
		return
	cinematic.set_process(false)
	_check(not main.runner.visible, "Frozen runner visible beside cinematic subject")
	for index: int in range(12):
		cinematic._process(cinematic.duration / 12.0)
		if index == 5:
			await _capture("transition_" + String(ScenarioManager.active_scenario_id))
	if main.coordinator.active_cinematic != null:
		cinematic.force_complete()
	await get_tree().create_timer(0.27).timeout
	_check(main.gameplay_camera.current and main.runner.visible and not main.runner.movement_suspended, "Handoff did not settle camera and runner")

func _validate_scenario() -> void:
	var definition: ScenarioDefinition = ScenarioManager.active_definition
	_check(main.runner.current_movement_mode == definition.movement_mode, "Mode binding: " + String(definition.id))
	_check(main.camera_rig.profile == definition.camera_profile, "Camera binding: " + String(definition.id))
	_check(main.gameplay_camera.get_viewport().get_camera_3d() == main.gameplay_camera, "Competing gameplay camera ownership")
	_check(main.failure.active_scenario == definition, "Failure binding: " + String(definition.id))
	_check(AudioManager.active_ambience == definition.ambience_profile.id, "Ambience binding: " + String(definition.id))
	var non_safe := 0
	var safe := 0
	var validator := PatternValidator.new()
	for segment: SegmentDefinition in definition.segment_library:
		for pattern: PatternDefinition in segment.eligible_patterns:
			if pattern.safe_fallback:
				safe += 1
			elif not pattern.obstacle_placements.is_empty():
				non_safe += 1
			for speed: float in [definition.base_speed, definition.max_speed]:
				var result := validator.validate_pattern(pattern, definition.movement_capability_profile, speed, definition.movement_capability_profile.initial_state_mask())
				_check(result.is_valid, "Pattern invalid: %s %s" % [pattern.id, result.reason])
	_check(safe >= 1 and non_safe >= 2, "Scenario has empty-only/insufficient content: " + String(definition.id))
	_check(main.generator.active_track_has_no_holes(), "Handoff track has holes")
	main.camera_rig.kick(100.0)
	_check(main.camera_rig.impulse <= 0.75, "Camera impulse unbounded")
	main.camera_rig._process(0.1)
	_check(absf(main.gameplay_camera.rotation_degrees.z) <= main.camera_rig.profile.roll_limit + 0.01, "Camera roll exceeded profile")
	main.camera_rig.settle()
	await _capture(String(definition.id))

func _test_runner_rates() -> void:
	for profile: MovementProfile in [preload("res://data/movement_profiles/run_default.tres"), preload("res://data/movement_profiles/snowboard_default.tres"), preload("res://data/movement_profiles/swim_default.tres"), preload("res://data/movement_profiles/car_default.tres"), preload("res://data/movement_profiles/fly_default.tres")]:
		for hz: int in [30, 60, 120]:
			var runner := RUNNER.instantiate() as RunnerController
			add_child(runner)
			runner.set_physics_process(false)
			runner.adopt_profile(profile)
			runner.request_left()
			runner.step_simulation(profile.lane_change_duration)
			runner.request_right()
			runner.request_right()
			for frame: int in range(hz):
				runner.step_simulation(1.0 / hz)
			_check(runner.current_lane_index == 2, "Lane queue: %s %d Hz" % [profile.movement_mode, hz])
			runner.request_left()
			runner.step_simulation(1.0 / hz)
			runner.request_right()
			runner.step_simulation(profile.lane_change_duration)
			_check(runner.current_lane_index == 2, "Opposing input stranded runner")
			runner.reset_for_run()
			runner.request_up()
			for frame: int in range(hz * 2):
				runner.step_simulation(1.0 / hz)
			_check(is_zero_approx(runner.position.y), "Vertical mode did not settle")
			runner.reset_for_run()
			if profile.movement_mode not in [&"SWIM", &"FLY"]:
				runner.request_up()
				runner.step_simulation(profile.jump_duration - 0.06)
				runner.request_up()
				for frame: int in range(ceili(0.09 * hz)):
					runner.step_simulation(1.0 / hz)
				_check(runner.is_jumping, "Near-landing action buffer lost: %d Hz" % hz)
				runner.reset_for_run()
			else:
				var starts := [0]
				runner.action_started.connect(func(_action: StringName): starts[0] += 1)
				runner.request_up()
				runner.step_simulation(profile.vertical_action_duration + profile.vertical_hold_duration - 0.06)
				runner.request_up()
				for frame: int in range(ceili(0.1 * hz)):
					runner.step_simulation(1.0 / hz)
				_check(starts[0] == 2, "Rise buffer did not survive the hold boundary")
				runner.reset_for_run()
			for frame: int in range(hz * 150):
				runner.step_simulation(1.0 / hz)
			_check(absf(runner.current_speed - profile.max_speed) < 0.001, "Speed ramp did not reach max")
			_check(absf(runner.logical_forward_distance - (profile.base_speed + profile.max_speed) * 75.0) < 0.1, "Frame-rate-dependent distance")
			runner.queue_free()

func _soak() -> void:
	for definition: ScenarioDefinition in [main.BOULEVARD, main.SIERRA, main.BAY, main.SEQUOIA, main.FILMING_SETS, main.GOLDEN_GATE, main.HOLLYWOOD, main.GRASS, main.EARTHQUAKE]:
		main.runner.adopt_profile(definition.movement_profile)
		main.runner.reset_for_run()
		main.runner.set_invulnerable(true)
		main.generator.configure_for_scenario(definition)
		main.generator.reset_generator(777, 0.0, definition.base_speed)
		var stable_pool: Array[int] = []
		for second: int in range(600):
			main.runner.step_simulation(1.0)
			main.generator.step_simulation(main.runner.logical_forward_distance, main.runner.current_speed, 1.0)
			_check(main.generator.active_track_has_no_holes(), "Soak hole: " + String(definition.id))
			_check(main.generator.active_segments.size() <= main.generator.maximum_expected_active_segments(), "Soak unbounded active window")
			for segment: TrackSegment in main.generator.active_segments:
				for obstacle: ObstacleBase in segment.active_obstacles:
					_check(obstacle.definition.is_mode_supported(definition.movement_mode), "Unsupported obstacle during soak")
			if second == 300:
				stable_pool.assign([main.generator.pool.created_segment_count, main.generator.pool.created_obstacle_count, main.generator.pool.created_collectible_count])
			if second % 60 == 0:
				await get_tree().process_frame
		_check(main.generator.pool.created_segment_count == stable_pool[0], "Segment pool grew after warmup")
		_check(main.generator.pool.created_obstacle_count <= stable_pool[1] + main.generator.maximum_expected_pooled_obstacles(), "Obstacle pool exceeded per-library bound")
		_check(main.generator.pool.created_collectible_count <= stable_pool[2] + 16, "Pickup pool grew without a bound")
		_check(main.generator._ordinary_safe_count * 5 <= main.generator._ordinary_count, "Ordinary safe-pattern rate exceeded 20 percent")
		print("SOAK_PASS %s 600 seconds" % definition.id)

func _capture(label: String) -> void:
	if not render:
		return
	if GameFlow.gameplay_input_enabled:
		main.runner._update_presentation(1.0 / 60.0)
	for dimensions: Vector2i in [Vector2i(960, 720), Vector2i(844, 390), Vector2i(360, 640)]:
		get_window().size = dimensions
		main.presentation_root.debug_force_touch_capable = dimensions.x != 960
		for frame: int in range(5):
			await get_tree().process_frame
		main.presentation_root._refresh_layout()
		main.camera_rig.settle()
		await RenderingServer.frame_post_draw
		var path := "res://.godot/rehab-%02d-%s-%dx%d.png" % [capture_index, label, dimensions.x, dimensions.y]
		get_viewport().get_texture().get_image().save_png(path)
	capture_index += 1
