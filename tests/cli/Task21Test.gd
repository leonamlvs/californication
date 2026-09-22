extends Node

const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
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
	await get_tree().process_frame
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
	var failure := FailureCoordinator.new()
	failure.presentation_duration = 0.01
	add_child(failure)
	failure.configure_services(runner, generator)
	failure.begin_scenario(LAUNCH_SOURCE)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	var event := ObstacleHitEvent.new()
	_assert(runner.request_obstacle_hit(event), "Launch collision did not request a failure.")
	_assert(failure.active_family == &"launch" and runner.movement_suspended and generator.suspended, "Launch failure was not selected and atomically frozen.")
	_assert(not failure.begin_failure(), "Failure presentation was not one-shot.")
	await get_tree().create_timer(0.03).timeout
	_assert(GameFlow.current_state == GameFlow.LAVA_GAME_OVER, "Launch failure did not converge on lava Game Over.")
	_assert(game_over.visible, "Shared lava Game Over overlay did not appear.")
	var retained_character := GameFlow.selected_character_id
	game_over.yes_button.emit_signal("pressed")
	_assert(GameFlow.current_state == GameFlow.RUN_INTRO and GameFlow.prepared_run_target == GameFlow.BOULEVARD_ID, "YES did not enter RUN_INTRO targeting Boulevard.")
	_assert(GameFlow.selected_character_id == retained_character, "YES did not retain the character.")
	_assert(ScenarioManager.active_scenario_id == GameFlow.BOULEVARD_ID and generator.run_stats.score == 0 and not generator.suspended and not runner.movement_suspended, "YES did not reset scenario, metrics, and controls.")

	var floor_source := BOULEVARD.duplicate(true) as ScenarioDefinition
	floor_source.failure_family = &"floor_fall"
	ScenarioManager.load_scenario(floor_source.id)
	runner.movement_profile = floor_source.movement_profile
	runner.set_movement_mode(floor_source.movement_mode)
	failure.begin_scenario(floor_source)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(failure.begin_failure(), "Floor-fall failure did not start.")
	_assert(failure.active_family == &"floor_fall", "Floor-fall family was not data-selected.")
	await get_tree().create_timer(0.03).timeout
	_assert(GameFlow.current_state == GameFlow.LAVA_GAME_OVER, "Floor-fall did not converge on lava Game Over.")
	assert_pause_exclusion()
	game_over.no_button.emit_signal("pressed")
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT, "NO did not return directly to Island Attract.")
	_finish()


func assert_pause_exclusion() -> void:
	_assert(not GameFlow.pause_run() and not GameFlow.gameplay_input_enabled and not GameFlow.run_timer_enabled, "Failure allowed pause or gameplay services.")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("TASK21_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
