extends Node

var SIERRA: ScenarioDefinition = preload("res://data/scenarios/sierra_nevada.tres").duplicate(true)
const SIERRA_SOURCE := preload("res://data/scenarios/sierra_nevada.tres")
const FIXTURE_A := preload("res://dev/fixtures/fixture_scenario_a.tres")
const RUN_CAPABILITIES := preload("res://data/track/run_capabilities.tres")
const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const COORDINATOR_SCENE := preload("res://gameplay/transitions/TransitionCoordinator.tscn")
const HUD_SCENE := preload("res://ui/hud/HUD.tscn")

var _failed := false


func _ready() -> void:
	_run()
	if _failed:
		get_tree().quit(1)
		return
	print("Task 10 Sierra Nevada / SNOWBOARD test passed.")
	get_tree().quit(0)


func _run() -> void:
	var sierra_source_snapshot := _library_snapshot(SIERRA_SOURCE)
	var sierra_fixture_snapshot := _library_snapshot(SIERRA)
	var target_snapshot := _library_snapshot(FIXTURE_A)
	# Fixture routing is test-owned; production transitions use the shuffle bag.
	SIERRA.transition_definition.next_scenario_policy = TransitionDefinition.NextScenarioPolicy.EXPLICIT
	SIERRA.transition_definition.next_scenario_ids = [&"fixture_a"]
	_assert(SIERRA.is_valid_definition(), "Sierra scenario definition is invalid.")
	_assert(SIERRA.movement_profile.movement_mode == &"SNOWBOARD" and SIERRA.movement_capability_profile.movement_mode == &"SNOWBOARD", "Sierra does not declare SNOWBOARD through shared movement data.")
	_assert(SIERRA.movement_profile.lane_change_duration > 0.18, "Snowboard carve is not looser than the RUN baseline.")
	_assert(SIERRA.obstacle_library.is_valid_library(), "Snowboard obstacle library is invalid.")

	var runner := RUNNER_SCENE.instantiate() as RunnerController
	add_child(runner)
	runner.movement_profile = SIERRA.movement_profile
	_assert(runner.set_movement_mode(&"SNOWBOARD"), "Shared runner could not install SNOWBOARD.")
	runner.reset_for_run()
	_assert(runner.current_movement_mode == &"SNOWBOARD", "Runner did not report SNOWBOARD mode.")
	_assert(runner.request_right(), "Snowboard did not accept shared Right input.")
	runner.step_simulation(0.18)
	_assert(runner.current_lane_index == 1 and runner.position.x > 0.0 and runner.position.x < SIERRA.movement_profile.lane_spacing, "Snowboard carve did not retain profile-driven in-flight lateral motion.")
	runner.step_simulation(0.10)
	_assert(runner.current_lane_index == 2, "Snowboard carve did not settle in the target lane.")
	runner.reset_for_run()
	_assert(runner.request_up(), "Snowboard did not accept shared Jump input.")
	runner.step_simulation(SIERRA.movement_profile.jump_duration * 0.5)
	_assert(runner.is_jumping and runner.position.y > 0.0, "Snowboard jump did not use the shared runner vertical path.")
	runner.step_simulation(SIERRA.movement_profile.jump_duration)
	_assert(runner.request_down() and runner.is_sliding, "Snowboard crouch did not use the shared low path.")

	var validator := PatternValidator.new()
	for segment: SegmentDefinition in SIERRA.segment_library:
		_assert(segment.is_valid_definition(), "Sierra snow route segment is invalid.")
		for pattern: PatternDefinition in segment.eligible_patterns:
			var result := validator.validate_pattern(pattern, SIERRA.movement_capability_profile, SIERRA.base_speed, SIERRA.movement_capability_profile.initial_state_mask())
			_assert(result.is_valid, "Sierra pattern %s is not valid for SNOWBOARD." % pattern.id)
			_assert(not validator.validate_pattern(pattern, RUN_CAPABILITIES, 12.0, RUN_CAPABILITIES.initial_state_mask()).is_valid, "Sierra SNOWBOARD pattern was accepted for RUN capabilities.")

	var scenario_root := Node3D.new()
	add_child(scenario_root)
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	_assert(ScenarioManager.register_scenario(SIERRA), "Sierra did not register as production content.")
	_assert(ScenarioManager.register_scenario(FIXTURE_A, true), "Sierra handoff fixture did not register.")
	_assert(ScenarioManager.load_scenario(SIERRA.id), "Sierra did not load.")
	var generator := GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	generator.set_runner(runner)
	_assert(generator.configure_for_scenario(SIERRA), "Generator rejected Sierra configuration.")
	generator.reset_generator(1010, 0.0, runner.current_speed)
	_assert(generator.configuration_is_valid() and generator.capability_profile == SIERRA.movement_capability_profile, "Generator did not install Sierra capabilities.")
	for pattern_id: StringName in generator.generation_history:
		_assert(pattern_id.begins_with("sierra_"), "Generator selected a non-Sierra pattern for SNOWBOARD.")

	var hud := HUD_SCENE.instantiate() as RunnerHUD
	add_child(hud)
	hud.bind_run_stats(generator.run_stats)
	var coordinator := COORDINATOR_SCENE.instantiate() as TransitionCoordinator
	add_child(coordinator)
	coordinator.configure_services(runner, generator, generator.run_stats, hud)
	_assert(coordinator.begin_scenario(SIERRA, true), "Coordinator rejected Sierra.")
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(coordinator.development_force_token_collection(), "Sierra token did not start the train transition.")
	var cinematic := coordinator.active_cinematic as SierraTrainTransition
	_assert(cinematic != null and cinematic.is_running, "Sierra did not instantiate its train transition.")
	_assert(runner.is_invulnerable and runner.movement_suspended and not GameFlow.gameplay_input_enabled, "Sierra cinematic is not input-locked and protected.")
	_assert(cinematic.find_children("*", "RunnerController", true, false).is_empty() and cinematic.find_children("*", "ObstacleBase", true, false).is_empty() and cinematic.find_children("*", "CollectibleBase", true, false).is_empty(), "Sierra cinematic contains gameplay entities.")
	cinematic._process(0.9)
	cinematic._process(0.9)
	cinematic._process(0.1)
	cinematic._process(0.1)
	_assert(cinematic.stage_history == [SierraTrainTransition.Stage.FALL_ONTO_TRAIN, SierraTrainTransition.Stage.TUNNEL_CROSSING, SierraTrainTransition.Stage.JUMP_AWAY], "Sierra train cinematic stage order is incorrect.")
	_assert(not cinematic.tunnel.visible, "Sierra tunnel did not tear down after the jump-away stage.")
	_assert(coordinator.development_force_complete_cinematic(), "Sierra cinematic completion hook failed.")
	_assert(GameFlow.current_state == GameFlow.RUNNING and ScenarioManager.active_scenario_id == FIXTURE_A.id, "Sierra did not hand off to the registered fixture target.")
	_assert(_library_snapshot(SIERRA_SOURCE) == sierra_source_snapshot and _library_snapshot(SIERRA) == sierra_fixture_snapshot and _library_snapshot(FIXTURE_A) == target_snapshot, "Handoff mutated an authored pattern library.")
	_assert(generator.active_track_has_no_holes() and generator.active_segments.back().end_distance >= generator.current_logical_distance + generator.ahead_distance, "Handoff did not build a contiguous track window.")
	var opening: TrackSegment = generator.active_segments.front()
	_assert(opening.definition.is_valid_definition() and opening.definition.eligible_patterns.size() == 1 and opening.definition.eligible_patterns[0] == opening.pattern, "Temporary opening segment has an invalid pattern contract.")
	_assert(opening.definition != FIXTURE_A.segment_library[0] and opening.pattern != generator.fallback_pattern, "Temporary opening reused an authored resource.")
	for segment: TrackSegment in generator.active_segments:
		for obstacle: ObstacleBase in segment.active_obstacles:
			_assert(obstacle.forward_distance >= generator.current_logical_distance + coordinator.safe_runway_distance, "Handoff spawned a hazard inside the protected opening.")
	_assert(generator.prepare_safe_runway(coordinator.safe_runway_distance), "Repeated safe-runway preparation failed.")
	_assert(_library_snapshot(FIXTURE_A) == target_snapshot and generator.active_track_has_no_holes(), "Repeated safe-runway preparation changed fixture content or broke track continuity.")
	var saved_fallback := generator.fallback_pattern
	generator.fallback_pattern = null
	_assert(not generator.prepare_safe_runway(coordinator.safe_runway_distance) and generator.suspended, "Failed runway preparation did not stop generation.")
	generator.fallback_pattern = saved_fallback
	generator.set_suspended(false)

	_assert(ScenarioManager.load_scenario(SIERRA.id), "Sierra could not be loaded for a repeat transition.")
	runner.movement_profile = SIERRA.movement_profile
	runner.set_movement_mode(SIERRA.movement_mode)
	runner.reset_for_run()
	generator.configure_for_scenario(SIERRA)
	generator.reset_generator(1011, 0.0, runner.current_speed)
	coordinator.begin_scenario(SIERRA, true)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(coordinator.development_force_token_collection() and coordinator.development_force_complete_cinematic(), "Repeated Sierra transition did not cleanly restart.")
	_assert(ScenarioManager.active_scenario_id == FIXTURE_A.id and coordinator.active_cinematic == null, "Repeated Sierra transition leaked its cinematic lifecycle.")
	_assert(_library_snapshot(SIERRA_SOURCE) == sierra_source_snapshot and _library_snapshot(SIERRA) == sierra_fixture_snapshot and _library_snapshot(FIXTURE_A) == target_snapshot, "Source-to-fixture-to-source handoff changed an authored pattern library.")
	_assert(generator.active_track_has_no_holes() and generator.active_segments.front().definition.is_valid_definition(), "Repeated handoff left an invalid or discontinuous opening.")

	ScenarioManager.reset_for_tests()
	runner.queue_free()
	generator.queue_free()
	hud.queue_free()
	coordinator.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr(message)


func _library_snapshot(definition: ScenarioDefinition) -> Array:
	var snapshot: Array = []
	for segment: SegmentDefinition in definition.segment_library:
		var patterns: Array = []
		for pattern: PatternDefinition in segment.eligible_patterns:
			patterns.append([pattern.get_instance_id(), pattern.id, pattern.length])
		snapshot.append([segment.get_instance_id(), segment.id, segment.length, patterns])
	return snapshot
