extends Node

const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const TRANSITION_COORDINATOR_SCENE := preload("res://gameplay/transitions/TransitionCoordinator.tscn")
const GAME_OVER_OVERLAY := preload("res://ui/hud/GameOverOverlay.tscn")
const BOULEVARD := preload("res://data/scenarios/boulevard.tres")
const LAUNCH_SOURCE := preload("res://data/scenarios/golden_gate.tres")
const SIERRA := preload("res://data/scenarios/sierra_nevada.tres")
const BAY := preload("res://data/scenarios/san_francisco_bay.tres")
const SEQUOIA := preload("res://data/scenarios/sequoia.tres")
const FILMING := preload("res://data/scenarios/filming_sets.tres")
const HOLLYWOOD := preload("res://data/scenarios/hollywood.tres")
const GRASS := preload("res://data/scenarios/grass.tres")
const EARTHQUAKE := preload("res://data/scenarios/earthquake.tres")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_over := GAME_OVER_OVERLAY.instantiate() as GameOverController
	add_child(game_over)
	var scenario_root := Node3D.new()
	add_child(scenario_root)
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	for definition: ScenarioDefinition in [BOULEVARD, SIERRA, BAY, SEQUOIA, FILMING, LAUNCH_SOURCE, HOLLYWOOD, GRASS, EARTHQUAKE]:
		_assert(ScenarioManager.register_scenario(definition), "%s did not register for retry." % definition.id)
	_assert(ScenarioManager.load_scenario(LAUNCH_SOURCE.id), "Launch source did not load.")

	var runner := RUNNER_SCENE.instantiate() as RunnerController
	add_child(runner)
	runner.movement_profile = LAUNCH_SOURCE.movement_profile
	runner.set_movement_mode(LAUNCH_SOURCE.movement_mode)
	runner.reset_for_run()
	var generator := GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	generator.set_runner(runner)
	_assert(generator.configure_for_scenario(LAUNCH_SOURCE), "Generator did not configure for launch source.")
	generator.reset_generator(21, 0.0, runner.current_speed)
	generator.run_stats.award_normal_pickup()
	generator.run_stats.step_simulation(2.0, 5.0, true)

	var transition_coordinator := TRANSITION_COORDINATOR_SCENE.instantiate() as TransitionCoordinator
	add_child(transition_coordinator)
	transition_coordinator.configure_services(runner, generator, generator.run_stats)
	_assert(transition_coordinator.begin_scenario(LAUNCH_SOURCE, true), "Transition coordinator rejected launch source.")
	var failure := FailureCoordinator.new()
	failure.presentation_duration = 1.0
	add_child(failure)
	failure.configure_services(runner, generator, transition_coordinator)
	failure.begin_scenario(LAUNCH_SOURCE)
	await get_tree().process_frame

	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(transition_coordinator.development_force_token_spawn(), "Could not prepare a transition token for failure cleanup.")
	var launch_origin := runner.position
	var event := ObstacleHitEvent.new()
	_assert(runner.request_obstacle_hit(event), "Launch collision did not request a failure.")
	_assert(failure.active_family == FailurePresentation.LAUNCH and failure.active_presentation != null, "Launch family did not create its presentation.")
	_assert(runner.movement_suspended and runner.is_invulnerable and generator.suspended, "Failure did not atomically lock control, damage, and generation.")
	_assert(transition_coordinator.active_token == null and generator.active_transition_token == null, "Failure did not clear the transition-token opportunity.")
	_assert(not failure.begin_failure(), "Failure presentation was not one-shot.")
	_assert(not GameFlow.pause_run() and not GameFlow.gameplay_input_enabled and not GameFlow.run_timer_enabled, "Failure transition allowed pause or gameplay services.")
	failure.active_presentation.advance_for_test(0.5)
	_assert(runner.position.z > launch_origin.z and runner.scale.x > 1.0, "Launch family did not move the runner toward the camera.")
	failure.active_presentation.advance_for_test(0.5)
	_assert(GameFlow.current_state == GameFlow.LAVA_GAME_OVER and game_over.visible, "Launch did not converge on the shared lava Game Over.")
	_assert(failure.active_presentation != null and not failure.active_presentation.is_running, "Completed failure presentation was not retained behind Game Over.")
	_assert(not GameFlow.pause_run(), "Game Over allowed pause.")

	var retained_character := GameFlow.selected_character_id
	game_over.yes_button.emit_signal("pressed")
	_assert(GameFlow.current_state == GameFlow.RUN_INTRO and GameFlow.prepared_run_target == GameFlow.BOULEVARD_ID, "YES did not enter RUN_INTRO targeting Boulevard.")
	_assert(GameFlow.selected_character_id == retained_character, "YES did not retain the character.")
	_assert(ScenarioManager.active_scenario_id == LAUNCH_SOURCE.id, "FailureCoordinator duplicated Run Intro's scenario preparation.")
	_assert(generator.run_stats.score > 0, "FailureCoordinator duplicated Run Intro's metric reset.")
	_assert(generator.suspended and runner.movement_suspended and runner.is_invulnerable, "YES unlocked gameplay before RUN_INTRO readiness.")
	_assert(failure.active_presentation == null, "YES did not clean up the failure presentation.")
	# This isolated fixture has no Run Intro. Production retry preparation and
	# metric reset are covered through Main by RehabilitationTest.
	runner.reset_for_run()
	runner.set_movement_suspended(true)
	_assert(GameFlow.report_run_intro_ready(true, true), "RUN_INTRO readiness was rejected.")
	_assert(not generator.suspended and not runner.movement_suspended and not runner.is_invulnerable, "RUN_INTRO completion did not restore gameplay locks.")

	var floor_source := BOULEVARD.duplicate(true) as ScenarioDefinition
	floor_source.failure_family = FailurePresentation.FLOOR_FALL
	failure.begin_scenario(floor_source)
	var floor_origin := runner.position
	_assert(failure.begin_failure(), "Floor-fall failure did not start.")
	_assert(failure.active_family == FailurePresentation.FLOOR_FALL, "Floor-fall family was not data-selected.")
	failure.active_presentation.advance_for_test(0.5)
	_assert(runner.position.y < floor_origin.y and runner.scale.x < 1.0, "Floor-fall family did not drop the runner away from play.")
	failure.active_presentation.advance_for_test(0.5)
	_assert(GameFlow.current_state == GameFlow.LAVA_GAME_OVER and game_over.visible, "Floor-fall did not converge on the same lava Game Over.")

	var intro_seen_before := GameFlow.intro_seen
	_assert(game_over.handle_intent(InputRouter.INTENT_DOWN) and not game_over.selected_yes, "Game Over navigation did not select NO.")
	_assert(game_over.handle_intent(InputRouter.INTENT_CONFIRM), "Game Over confirm did not activate NO.")
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT, "NO did not return directly to Island Attract.")
	_assert(GameFlow.intro_seen == intro_seen_before, "NO changed Island Intro session history.")
	_assert(ScenarioManager.active_definition == null, "NO did not unload the active gameplay scenario.")
	_assert(generator.suspended and runner.movement_suspended and runner.is_invulnerable, "Island return did not keep gameplay services excluded.")
	_assert(failure.active_presentation == null, "Island return leaked the failure presentation.")
	_assert(_active_content_is_clear(generator), "Island return retained active obstacles or collectibles.")

	if failures.is_empty():
		print("TASK21_PASS")
		get_tree().quit(0)
	else:
		for failure_message: String in failures:
			push_error(failure_message)
		get_tree().quit(1)


func _active_content_is_clear(generator: TrackGenerator) -> bool:
	if generator.active_transition_token != null:
		return false
	for segment: TrackSegment in generator.active_segments:
		if not segment.active_obstacles.is_empty() or not segment.active_collectibles.is_empty():
			return false
	return true


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
