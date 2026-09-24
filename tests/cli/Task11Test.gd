extends Node

var BAY: ScenarioDefinition = preload("res://data/scenarios/san_francisco_bay.tres").duplicate(true)
const FIXTURE_B := preload("res://dev/fixtures/fixture_scenario_b.tres")
const RUN_CAPABILITIES := preload("res://data/track/run_capabilities.tres")
const SEA_ARCH := preload("res://data/obstacles/bay_sea_arch.tres")
const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const COORDINATOR_SCENE := preload("res://gameplay/transitions/TransitionCoordinator.tscn")
const HUD_SCENE := preload("res://ui/hud/HUD.tscn")
const OBSTACLE_SCENE := preload("res://gameplay/obstacles/ObstacleBlock.tscn")

var _failed := false


func _ready() -> void:
	_run()
	if _failed:
		get_tree().quit(1)
		return
	print("Task 11 San Francisco Bay / SWIM test passed.")
	get_tree().quit(0)


func _run() -> void:
	# Fixture routing is test-owned; production transitions use the shuffle bag.
	BAY.transition_definition.next_scenario_policy = TransitionDefinition.NextScenarioPolicy.EXPLICIT
	BAY.transition_definition.next_scenario_ids = [&"fixture_b"]
	_assert(BAY.is_valid_definition(), "Bay scenario definition is invalid.")
	_assert(BAY.movement_profile.movement_mode == &"SWIM" and BAY.movement_capability_profile.movement_mode == &"SWIM", "Bay does not declare SWIM through shared movement data.")
	_assert(BAY.movement_capability_profile.supports_rise and BAY.movement_capability_profile.supports_dive, "Bay capabilities do not expose both vertical depth states.")

	var runner := RUNNER_SCENE.instantiate() as RunnerController
	add_child(runner)
	runner.movement_profile = BAY.movement_profile
	_assert(runner.set_movement_mode(&"SWIM"), "Shared runner could not install SWIM.")
	runner.reset_for_run()
	_assert(runner.request_up(), "SWIM did not accept rise input.")
	_assert(not runner.request_up(), "Repeated rise input accumulated an unbounded depth action.")
	_assert(runner.request_right(), "SWIM did not accept shared Right input while rising.")
	runner.step_simulation(0.1)
	_assert(runner.swim_depth_state == RunnerStateSpace.Posture.RISE and runner.position.y > 0.0 and runner.position.x > 0.0, "SWIM rise and simultaneous lateral motion did not remain active together.")
	_assert(runner.request_down(), "Opposing dive input did not replace the temporary rise.")
	runner.step_simulation(BAY.movement_profile.vertical_action_duration)
	_assert(runner.swim_depth_state == RunnerStateSpace.Posture.DIVE and runner.position.y < 0.0, "SWIM dive did not remain within the configured underwater volume.")
	_assert(runner.position.y <= BAY.movement_profile.vertical_rise_offset and runner.position.y >= -BAY.movement_profile.vertical_dive_offset, "SWIM depth escaped its profile bounds.")
	runner.step_simulation(BAY.movement_profile.vertical_hold_duration + BAY.movement_profile.vertical_neutral_return_duration + 0.1)
	_assert(runner.swim_depth_state == RunnerStateSpace.Posture.GROUND and is_zero_approx(runner.position.y), "SWIM did not return to neutral depth.")

	var validator := PatternValidator.new()
	for segment: SegmentDefinition in BAY.segment_library:
		_assert(segment.is_valid_definition(), "Bay underwater segment is invalid.")
		for pattern: PatternDefinition in segment.eligible_patterns:
			var result := validator.validate_pattern(pattern, BAY.movement_capability_profile, BAY.base_speed, BAY.movement_capability_profile.initial_state_mask())
			_assert(result.is_valid, "Bay pattern %s is not valid for SWIM." % pattern.id)
			_assert(not validator.validate_pattern(pattern, RUN_CAPABILITIES, BAY.base_speed, RUN_CAPABILITIES.initial_state_mask()).is_valid, "Bay SWIM pattern was accepted for RUN capabilities.")
	var rise_result := validator.validate_pattern(load("res://data/patterns/bay_rise_arch.tres"), BAY.movement_capability_profile, BAY.base_speed, BAY.movement_capability_profile.initial_state_mask())
	_assert((rise_result.exit_state_mask & RunnerStateSpace.all_lanes_for_posture(RunnerStateSpace.Posture.RISE)) != 0, "Vertical RISE states did not participate in pattern validation.")

	var arch := OBSTACLE_SCENE.instantiate() as ObstacleBase
	arch.definition = SEA_ARCH
	add_child(arch)
	arch.reset_for_spawn(5.0, 1, 0.0, RunnerStateSpace.Posture.RISE)
	runner.reset_for_run()
	runner.request_up()
	runner.step_simulation(0.1)
	runner.logical_forward_distance = 5.0
	var arch_event := arch.step_simulation(runner, 0.0)
	_assert(arch_event != null and arch_event.was_avoided, "A valid SWIM rise did not avoid its vertical Bay obstacle.")
	arch.queue_free()

	var scenario_root := Node3D.new()
	add_child(scenario_root)
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	_assert(ScenarioManager.register_scenario(BAY), "Bay did not register as production content.")
	_assert(ScenarioManager.register_scenario(FIXTURE_B, true), "Bay handoff fixture did not register.")
	_assert(ScenarioManager.load_scenario(BAY.id), "Bay did not load.")
	var generator := GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	generator.set_runner(runner)
	_assert(generator.configure_for_scenario(BAY), "Generator rejected Bay configuration.")
	generator.reset_generator(1111, 0.0, runner.current_speed)
	_assert(generator.configuration_is_valid() and generator.capability_profile == BAY.movement_capability_profile, "Generator did not install Bay vertical capabilities.")
	for pattern_id: StringName in generator.generation_history:
		_assert(pattern_id.begins_with("bay_"), "Generator selected a non-Bay SWIM pattern.")

	var hud := HUD_SCENE.instantiate() as RunnerHUD
	add_child(hud)
	hud.bind_run_stats(generator.run_stats)
	var coordinator := COORDINATOR_SCENE.instantiate() as TransitionCoordinator
	add_child(coordinator)
	coordinator.configure_services(runner, generator, generator.run_stats, hud)
	_assert(coordinator.begin_scenario(BAY, true), "Coordinator rejected Bay.")
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(coordinator.development_force_token_collection(), "Bay token did not start the shark-wave transition.")
	var cinematic := coordinator.active_cinematic as BayWaveTransition
	_assert(cinematic != null and cinematic.is_running, "Bay did not instantiate its wave transition.")
	_assert(runner.is_invulnerable and runner.movement_suspended and not GameFlow.gameplay_input_enabled, "Bay cinematic is not input-locked and protected.")
	_assert(cinematic.find_children("*", "RunnerController", true, false).is_empty() and cinematic.find_children("*", "ObstacleBase", true, false).is_empty() and cinematic.find_children("*", "CollectibleBase", true, false).is_empty(), "Bay cinematic contains normal gameplay entities.")
	cinematic._process(0.9)
	cinematic._process(0.9)
	cinematic._process(0.1)
	cinematic._process(0.1)
	_assert(cinematic.stage_history == [BayWaveTransition.Stage.SURFACE, BayWaveTransition.Stage.SHARK_WAVE, BayWaveTransition.Stage.LAUNCH], "Bay shark-wave stage order is incorrect.")
	_assert(not cinematic.shark_wave.visible, "Bay shark-wave content did not tear down after launch.")
	_assert(coordinator.development_force_complete_cinematic(), "Bay cinematic completion hook failed.")
	_assert(GameFlow.current_state == GameFlow.RUNNING and ScenarioManager.active_scenario_id == FIXTURE_B.id, "Bay did not hand off to the registered fixture target.")

	ScenarioManager.reset_for_tests()
	runner.queue_free()
	generator.queue_free()
	hud.queue_free()
	coordinator.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr(message)
