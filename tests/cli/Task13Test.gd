extends Node

const FILMING_SETS := preload("res://data/scenarios/filming_sets.tres")
const FIXTURE_B := preload("res://dev/fixtures/fixture_scenario_b.tres")
const RUN_CAPABILITIES := preload("res://data/track/run_capabilities.tres")
const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const COORDINATOR_SCENE := preload("res://gameplay/transitions/TransitionCoordinator.tscn")
const HUD_SCENE := preload("res://ui/hud/HUD.tscn")
const FILM_TRANSITION_SCRIPT := preload("res://scenarios/filming_sets/FilmingSetsTransition.gd")

var _failed := false


func _ready() -> void:
	_run()
	if _failed:
		get_tree().quit(1)
		return
	print("Task 13 Filming Sets test passed.")
	get_tree().quit(0)


func _run() -> void:
	_assert(FILMING_SETS.is_valid_definition(), "Filming Sets scenario definition is invalid.")
	_assert(FILMING_SETS.movement_mode == &"RUN" and FILMING_SETS.movement_profile.movement_mode == &"RUN", "Filming Sets did not reuse shared RUN data.")
	var validator := PatternValidator.new()
	for segment: SegmentDefinition in FILMING_SETS.segment_library:
		_assert(segment.is_valid_definition(), "Backlot segment is invalid.")
		for pattern: PatternDefinition in segment.eligible_patterns:
			_assert(validator.validate_pattern(pattern, RUN_CAPABILITIES, FILMING_SETS.base_speed, RUN_CAPABILITIES.initial_state_mask()).is_valid, "Backlot pattern %s is not solvable." % pattern.id)

	var runner := RUNNER_SCENE.instantiate() as RunnerController
	add_child(runner)
	runner.movement_profile = FILMING_SETS.movement_profile
	_assert(runner.set_movement_mode(&"RUN"), "Shared runner could not install Filming Sets RUN.")
	runner.reset_for_run()

	var scenario_root := Node3D.new()
	add_child(scenario_root)
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	_assert(ScenarioManager.register_scenario(FILMING_SETS), "Filming Sets did not register as production content.")
	_assert(ScenarioManager.register_scenario(FIXTURE_B, true), "Filming Sets handoff fixture did not register.")
	_assert(ScenarioManager.load_scenario(FILMING_SETS.id), "Filming Sets did not load.")
	var generator := GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	generator.set_runner(runner)
	_assert(generator.configure_for_scenario(FILMING_SETS), "Generator rejected Filming Sets configuration.")
	generator.reset_generator(1313, 0.0, runner.current_speed)
	_assert(generator.configuration_is_valid(), "Filming Sets generator configuration is invalid.")

	var hud := HUD_SCENE.instantiate() as RunnerHUD
	add_child(hud)
	hud.bind_run_stats(generator.run_stats)
	var coordinator := COORDINATOR_SCENE.instantiate() as TransitionCoordinator
	add_child(coordinator)
	coordinator.configure_services(runner, generator, generator.run_stats, hud)
	_assert(coordinator.begin_scenario(FILMING_SETS, true), "Coordinator rejected Filming Sets.")
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(coordinator.development_force_token_collection(), "Filming Sets token did not start the soundstage transition.")
	var cinematic: ScenarioTransitionController = coordinator.active_cinematic
	_assert(cinematic != null and cinematic.is_running, "Filming Sets did not instantiate its multi-set cinematic.")
	_assert(cinematic.find_children("*", "RunnerController", true, false).is_empty() and cinematic.find_children("PresentationProxy", "MeshInstance3D", true, false).size() == 1, "Filming Sets created more than one player/presentation context.")
	_assert(runner.is_invulnerable and runner.movement_suspended and not GameFlow.gameplay_input_enabled and not runner.request_up(), "Filming Sets cinematic is not input-locked and protected.")
	cinematic._process(0.8)
	cinematic._process(0.8)
	cinematic._process(0.8)
	cinematic._process(0.1)
	_assert(cinematic.get("stage_history") == [FILM_TRANSITION_SCRIPT.Stage.SPACE_ACTION, FILM_TRANSITION_SCRIPT.Stage.GLAMOROUS_ROMANTIC, FILM_TRANSITION_SCRIPT.Stage.WORKSHOP, FILM_TRANSITION_SCRIPT.Stage.EXIT_DOOR], "Filming Sets stage order is incorrect.")
	_assert(cinematic.get_node("%ExitDoor").visible, "Filming Sets did not expose the final exit-door stage.")
	_assert(coordinator.development_force_complete_cinematic(), "Filming Sets cinematic completion hook failed.")
	_assert(GameFlow.current_state == GameFlow.RUNNING and ScenarioManager.active_scenario_id == FIXTURE_B.id, "Filming Sets did not hand off to the registered fixture target.")
	_assert(coordinator.active_cinematic == null and cinematic.get_parent() == null and cinematic.is_queued_for_deletion(), "Filming Sets cinematic was not detached for cleanup.")

	_assert(ScenarioManager.load_scenario(FILMING_SETS.id), "Filming Sets could not be loaded for a repeat transition.")
	runner.movement_profile = FILMING_SETS.movement_profile
	runner.set_movement_mode(FILMING_SETS.movement_mode)
	runner.reset_for_run()
	generator.configure_for_scenario(FILMING_SETS)
	generator.reset_generator(1314, 0.0, runner.current_speed)
	coordinator.begin_scenario(FILMING_SETS, true)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(coordinator.development_force_token_collection() and coordinator.development_force_complete_cinematic(), "Repeated Filming Sets transition did not cleanly restart.")
	_assert(coordinator.active_cinematic == null, "Repeated Filming Sets cleanup leaked cinematic state.")

	ScenarioManager.reset_for_tests()
	runner.queue_free()
	generator.queue_free()
	hud.queue_free()
	coordinator.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr(message)
