extends Node3D

const FIXTURE_A := preload("res://dev/fixtures/fixture_scenario_a.tres")
const FIXTURE_B := preload("res://dev/fixtures/fixture_scenario_b.tres")
const BLOCK_DEFINITION := preload("res://data/obstacles/block.tres")

@onready var runner: RunnerController = %Runner
@onready var generator: TrackGenerator = %TrackGenerator
@onready var coordinator: TransitionCoordinator = %TransitionCoordinator
@onready var hud: RunnerHUD = %HUD
@onready var scenario_root: Node3D = %ScenarioRoot
@onready var status_label: Label = %StatusLabel

var _layout_index := 0
var _speed_index := 0
var _message := "Task 08 fixture services ready."
var _speeds: Array[float] = [10.0, 13.0, 16.0]


func _ready() -> void:
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	ScenarioManager.register_scenario(FIXTURE_A, true)
	ScenarioManager.register_scenario(FIXTURE_B, true)
	ScenarioManager.load_scenario(FIXTURE_A.id)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	runner.development_simulation_enabled = true
	generator.set_runner(runner)
	generator.reset_generator(generator.deterministic_seed, 0.0, runner.current_speed)
	hud.bind_run_stats(generator.run_stats)
	coordinator.configure_services(runner, generator, generator.run_stats, hud)
	coordinator.begin_scenario(FIXTURE_A, true)


func _process(_delta: float) -> void:
	status_label.text = "State: %s  Scenario: %s  Mode: %s\nSpeed: %.1f  Invulnerable: %s  Input: %s  Suspended: %s\nScore: %d  Time: %s  Pools S/O/C/T: %d/%d/%d/%d\n%s" % [
		GameFlow.current_state,
		ScenarioManager.active_scenario_id,
		runner.current_movement_mode,
		runner.current_speed,
		runner.is_invulnerable,
		GameFlow.gameplay_input_enabled,
		generator.suspended,
		generator.run_stats.score,
		generator.run_stats.formatted_time(),
		generator.pool.available_segment_count(),
		generator.pool.available_obstacle_count(),
		generator.pool.available_collectible_count(),
		generator.pool.available_token_count(),
		_message,
	]


func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % _speeds.size()
	runner.current_speed = _speeds[_speed_index]
	_message = "Speed set to %.1f m/s." % runner.current_speed


func _on_obstacle_pressed() -> void:
	if generator.active_segments.is_empty():
		return
	var obstacle := generator.pool.acquire_obstacle(BLOCK_DEFINITION)
	obstacle.reset_for_spawn(runner.logical_forward_distance + 15.0, 1, runner.logical_forward_distance)
	generator.active_segments.front().active_obstacles.append(obstacle)
	_message = "Spawned BLOCK through the production pool."


func _on_layout_pressed() -> void:
	var layouts := generator.collectible_layout_library.layouts
	if layouts.is_empty():
		return
	var layout: CollectibleLayout = layouts[_layout_index % layouts.size()]
	_layout_index += 1
	_message = "%s %s." % [layout.id, "spawned" if generator.spawn_collectible_layout(layout) else "could not spawn"]


func _on_ready_pressed() -> void:
	_message = "Transition ready: %s." % coordinator.development_force_ready()


func _on_token_pressed() -> void:
	_message = "Token collected: %s." % coordinator.development_force_token_collection()


func _on_miss_pressed() -> void:
	_message = "Token missed/retry scheduled: %s." % coordinator.development_force_token_miss()


func _on_death_pressed() -> void:
	_message = "Failure request accepted: %s." % GameFlow.fail_run()


func _on_invulnerability_pressed() -> void:
	runner.set_invulnerable(not runner.is_invulnerable)
	_message = "Invulnerability toggled."


func _on_bonus_pressed() -> void:
	var awarded := generator.run_stats.award_transition_bonus(coordinator.transition_bonus_key(), 1000)
	_message = "Duplicate bonus accepted: %s (expected false after collection)." % awarded


func _on_complete_pressed() -> void:
	_message = "Fixture cinematic completed: %s." % coordinator.development_force_complete_cinematic()


func _on_skip_pressed() -> void:
	_on_complete_pressed()


func _on_cycle_pressed() -> void:
	var target := FIXTURE_B if ScenarioManager.active_scenario_id == FIXTURE_A.id else FIXTURE_A
	ScenarioManager.load_scenario(target.id)
	coordinator.begin_scenario(target, true)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_message = "Jumped directly to %s." % target.display_name


func _on_state_pressed() -> void:
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_message = "Generic GameFlow development jump used for RUNNING."


func _on_collisions_pressed() -> void:
	get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
	_message = "Collision visibility: %s." % get_tree().debug_collisions_hint
