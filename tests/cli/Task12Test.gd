extends Node

var SEQUOIA: ScenarioDefinition = preload("res://data/scenarios/sequoia.tres").duplicate(true)
const FIXTURE_A := preload("res://dev/fixtures/fixture_scenario_a.tres")
const RUN_CAPABILITIES := preload("res://data/track/run_capabilities.tres")
const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const COORDINATOR_SCENE := preload("res://gameplay/transitions/TransitionCoordinator.tscn")
const HUD_SCENE := preload("res://ui/hud/HUD.tscn")
const CART_TRANSITION_SCRIPT := preload("res://scenarios/sequoia/SequoiaMiningCartTransition.gd")

var _failed := false


func _ready() -> void:
	_run()
	if _failed:
		get_tree().quit(1)
		return
	print("Task 12 Sequoia mining-cart test passed.")
	get_tree().quit(0)


func _run() -> void:
	# Fixture routing is test-owned; production transitions use the shuffle bag.
	SEQUOIA.transition_definition.next_scenario_policy = TransitionDefinition.NextScenarioPolicy.EXPLICIT
	SEQUOIA.transition_definition.next_scenario_ids = [&"fixture_a"]
	_assert(SEQUOIA.is_valid_definition(), "Sequoia scenario definition is invalid.")
	_assert(SEQUOIA.movement_mode == &"RUN" and SEQUOIA.movement_profile.movement_mode == &"RUN", "Sequoia did not reuse the shared RUN profile contract.")
	_assert(SEQUOIA.obstacle_library.is_valid_library(), "Sequoia obstacle library is invalid.")
	var validator := PatternValidator.new()
	for segment: SegmentDefinition in SEQUOIA.segment_library:
		_assert(segment.is_valid_definition(), "Sequoia forest segment is invalid.")
		for pattern: PatternDefinition in segment.eligible_patterns:
			for speed in [SEQUOIA.base_speed, SEQUOIA.max_speed]:
				_assert(validator.validate_pattern(pattern, RUN_CAPABILITIES, speed, RUN_CAPABILITIES.initial_state_mask()).is_valid, "Sequoia pattern %s is invalid at %.1f m/s." % [pattern.id, speed])
			if not pattern.safe_fallback:
				_assert(pattern.obstacle_placements[0].obstacle.motion_pattern != ObstacleDefinition.MotionPattern.STATIC, "Sequoia timing pattern is not a moving crosser/sweeper.")

	var runner := RUNNER_SCENE.instantiate() as RunnerController
	add_child(runner)
	runner.movement_profile = SEQUOIA.movement_profile
	_assert(runner.set_movement_mode(&"RUN"), "Shared runner could not install Sequoia RUN.")
	runner.reset_for_run()
	_assert(runner.request_left(), "Sequoia RUN did not retain shared lane input.")

	var scenario_root := Node3D.new()
	add_child(scenario_root)
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	_assert(ScenarioManager.register_scenario(SEQUOIA), "Sequoia did not register as production content.")
	_assert(ScenarioManager.register_scenario(FIXTURE_A, true), "Sequoia handoff fixture did not register.")
	_assert(ScenarioManager.load_scenario(SEQUOIA.id), "Sequoia did not load.")
	var generator := GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	generator.set_runner(runner)
	_assert(generator.configure_for_scenario(SEQUOIA), "Generator rejected Sequoia configuration.")
	generator.reset_generator(1212, 0.0, runner.current_speed)
	_assert(generator.configuration_is_valid(), "Sequoia generator configuration is invalid.")
	for pattern_id: StringName in generator.generation_history:
		_assert(pattern_id.begins_with("sequoia_"), "Generator selected a non-Sequoia forest pattern.")

	var hud := HUD_SCENE.instantiate() as RunnerHUD
	add_child(hud)
	hud.bind_run_stats(generator.run_stats)
	var coordinator := COORDINATOR_SCENE.instantiate() as TransitionCoordinator
	add_child(coordinator)
	coordinator.configure_services(runner, generator, generator.run_stats, hud)
	_assert(coordinator.begin_scenario(SEQUOIA, true), "Coordinator rejected Sequoia.")
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(coordinator.development_force_token_collection(), "Sequoia token did not start its mining-cart cinematic.")
	var cinematic: ScenarioTransitionController = coordinator.active_cinematic
	_assert(cinematic != null and cinematic.is_running, "Sequoia did not instantiate its mining-cart cinematic.")
	_assert(runner.is_invulnerable and runner.movement_suspended and not GameFlow.gameplay_input_enabled and not runner.request_right(), "Mining-cart cinematic is not input-locked and protected.")
	_assert(cinematic.find_children("*", "RunnerController", true, false).is_empty() and cinematic.find_children("*", "ObstacleBase", true, false).is_empty() and cinematic.find_children("*", "CollectibleBase", true, false).is_empty(), "Mining-cart cinematic contains normal gameplay entities.")
	var route_a: Vector3 = cinematic.call("_sample_cart_route", 0.55)
	var route_b: Vector3 = cinematic.call("_sample_cart_route", 0.55)
	_assert(route_a.is_equal_approx(route_b), "Mining-cart route is not deterministic.")
	cinematic._process(0.9)
	cinematic._process(0.9)
	cinematic._process(0.4)
	cinematic._process(0.4)
	cinematic._process(0.1)
	_assert(cinematic.get("stage_history") == [CART_TRANSITION_SCRIPT.Stage.CAVE_ENTRY, CART_TRANSITION_SCRIPT.Stage.CART_ROUTE, CART_TRANSITION_SCRIPT.Stage.CART_EXIT], "Mining-cart cinematic stage order is incorrect.")
	_assert(coordinator.development_force_complete_cinematic(), "Mining-cart cinematic completion hook failed.")
	_assert(GameFlow.current_state == GameFlow.RUNNING and ScenarioManager.active_scenario_id == FIXTURE_A.id, "Mining-cart cinematic did not hand off to the registered fixture target.")
	_assert(coordinator.active_cinematic == null and cinematic.get_parent() == null and cinematic.is_queued_for_deletion(), "Cave/cart content was not unloaded before normal play resumed.")

	_assert(ScenarioManager.load_scenario(SEQUOIA.id), "Sequoia could not be loaded for a repeat transition.")
	runner.movement_profile = SEQUOIA.movement_profile
	runner.set_movement_mode(SEQUOIA.movement_mode)
	runner.reset_for_run()
	generator.configure_for_scenario(SEQUOIA)
	generator.reset_generator(1213, 0.0, runner.current_speed)
	coordinator.begin_scenario(SEQUOIA, true)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(coordinator.development_force_token_collection() and coordinator.development_force_complete_cinematic(), "Repeated mining-cart transition did not cleanly restart.")
	_assert(coordinator.active_cinematic == null, "Repeated mining-cart transition leaked cinematic state.")

	ScenarioManager.reset_for_tests()
	runner.queue_free()
	generator.queue_free()
	hud.queue_free()
	coordinator.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr(message)
