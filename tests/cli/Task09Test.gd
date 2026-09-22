extends Node

const BOULEVARD := preload("res://data/scenarios/boulevard.tres")
const FIXTURE_A := preload("res://dev/fixtures/fixture_scenario_a.tres")
const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const COORDINATOR_SCENE := preload("res://gameplay/transitions/TransitionCoordinator.tscn")
const HUD_SCENE := preload("res://ui/hud/HUD.tscn")
const RUN_CAPABILITIES := preload("res://data/track/run_capabilities.tres")

var _failed := false


func _ready() -> void:
	_run()
	if _failed:
		get_tree().quit(1)
		return
	print("Task 09 Boulevard scenario test passed.")
	get_tree().quit(0)


func _run() -> void:
	_assert(BOULEVARD.is_valid_definition(), "Boulevard scenario definition is invalid.")
	var camera_profile := BOULEVARD.camera_profile as CameraProfile
	_assert(camera_profile != null and camera_profile.is_valid_profile(), "Boulevard camera profile is invalid.")
	var environment := BOULEVARD.environment_scene.instantiate() as BoulevardEnvironment
	add_child(environment)
	for lane: int in BOULEVARD.movement_profile.lane_count:
		_assert(environment.is_lane_on_sidewalk(lane, BOULEVARD.movement_profile.capsule_radius), "Boulevard lane %d leaves the sidewalk." % lane)
	_assert(environment.traffic_start_x > environment.sidewalk_half_width, "Boulevard traffic visual overlaps the sidewalk lane bounds.")

	var validator := PatternValidator.new()
	for segment: SegmentDefinition in BOULEVARD.segment_library:
		_assert(segment.is_valid_definition(), "Boulevard sidewalk segment is invalid.")
		for pattern: PatternDefinition in segment.eligible_patterns:
			var result := validator.validate_pattern(pattern, RUN_CAPABILITIES, 10.0, RunnerStateSpace.all_lanes_for_posture(RunnerStateSpace.Posture.GROUND))
			_assert(result.is_valid, "Boulevard pattern %s is not solvable." % pattern.id)
			for placement: PatternObstaclePlacement in pattern.obstacle_placements:
				_assert(placement.lane >= 0 and environment.is_lane_on_sidewalk(placement.lane, BOULEVARD.movement_profile.capsule_radius), "Boulevard pattern %s requires traffic entry." % pattern.id)

	var scenario_root := Node3D.new()
	add_child(scenario_root)
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	_assert(ScenarioManager.register_scenario(BOULEVARD), "Boulevard did not register as production content.")
	_assert(ScenarioManager.register_scenario(FIXTURE_A, true), "Boulevard development handoff fixture did not register.")
	_assert(ScenarioManager.production_scenario_ids() == [BOULEVARD.id], "Boulevard production registration is incorrect.")
	_assert(ScenarioManager.load_scenario(BOULEVARD.id), "Boulevard did not load.")

	var runner := RUNNER_SCENE.instantiate() as RunnerController
	add_child(runner)
	var generator := GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	generator.set_runner(runner)
	_assert(generator.configure_for_scenario(BOULEVARD), "Generator rejected Boulevard configuration.")
	_assert(generator.fallback_pattern.id == &"boulevard_safe_recovery", "Generator did not install Boulevard's safe recovery pattern.")
	generator.reset_generator(909, 0.0, runner.current_speed)
	_assert(generator.configuration_is_valid(), "Boulevard generator configuration is invalid.")
	var hud := HUD_SCENE.instantiate() as RunnerHUD
	add_child(hud)
	hud.bind_run_stats(generator.run_stats)
	var coordinator := COORDINATOR_SCENE.instantiate() as TransitionCoordinator
	add_child(coordinator)
	coordinator.configure_services(runner, generator, generator.run_stats, hud)
	_assert(coordinator.begin_scenario(BOULEVARD, true), "Coordinator rejected Boulevard.")
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(coordinator.development_force_token_collection(), "Boulevard token did not start its curbside transition.")
	var cinematic := coordinator.active_cinematic as BoulevardCurbsideTransition
	_assert(cinematic != null and cinematic.is_running, "Boulevard did not instantiate its curbside cinematic.")
	_assert(cinematic.find_children("*", "RunnerController", true, false).is_empty() and cinematic.find_children("*", "ObstacleBase", true, false).is_empty() and cinematic.find_children("*", "CollectibleBase", true, false).is_empty(), "Boulevard cinematic contains gameplay entities.")
	_assert(runner.is_invulnerable and runner.movement_suspended and not GameFlow.gameplay_input_enabled, "Boulevard cinematic is not input-locked and protected.")
	_assert(not runner.request_right(), "Boulevard cinematic accepted gameplay input.")
	cinematic._process(0.8)
	cinematic._process(0.8)
	cinematic._process(0.1)
	_assert(cinematic.stage_history == [BoulevardCurbsideTransition.Stage.CURBSIDE_ENTRY, BoulevardCurbsideTransition.Stage.TRASH_CAN_JUMP, BoulevardCurbsideTransition.Stage.FALL_TO_TARGET], "Boulevard curbside cinematic did not follow entry, jump, fall order.")
	_assert(cinematic.is_running, "Boulevard cinematic ended before its authored completion.")
	_assert(coordinator.development_force_complete_cinematic(), "Boulevard cinematic completion hook failed.")
	_assert(GameFlow.current_state == GameFlow.RUNNING and ScenarioManager.active_scenario_id == FIXTURE_A.id, "Boulevard cinematic did not hand off to the registered fixture target.")
	_assert(not runner.is_invulnerable and not runner.movement_suspended and not generator.suspended, "Boulevard handoff did not restore normal protected services.")

	ScenarioManager.reset_for_tests()
	environment.queue_free()
	runner.queue_free()
	generator.queue_free()
	hud.queue_free()
	coordinator.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr(message)
