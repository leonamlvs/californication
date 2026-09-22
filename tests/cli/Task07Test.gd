extends Node

const TRACK_GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const COLLECTIBLE_SCENE := preload("res://gameplay/collectibles/CollectibleBase.tscn")
const LAYOUT_LIBRARY := preload("res://data/track/normal_collectible_layouts.tres")

var _failed := false


func _ready() -> void:
	_run()
	if _failed:
		get_tree().quit(1)
		return
	print("Task 07 collectibles, score, and timer test passed.")
	get_tree().quit(0)


func _run() -> void:
	_assert(LAYOUT_LIBRARY.is_valid_library(3), "Normal collectible layout library is invalid.")
	_assert(LAYOUT_LIBRARY.layouts.size() == CollectibleLayout.LayoutType.size(), "Normal collectible library does not contain every required layout type.")
	var covered_lanes: Dictionary = {}
	var has_jump_arc := false
	for layout: CollectibleLayout in LAYOUT_LIBRARY.layouts:
		for point: CollectibleLayoutPoint in layout.points:
			covered_lanes[point.lane] = true
		if layout.layout_type == CollectibleLayout.LayoutType.JUMP_ARC:
			has_jump_arc = layout.points.any(func(point: CollectibleLayoutPoint) -> bool: return point.runner_height > 0.0)
	_assert(covered_lanes.has(0) and covered_lanes.has(1) and covered_lanes.has(2), "Collectible layouts do not cover every lane.")
	_assert(has_jump_arc, "Jump-arc layout contains no airborne pickup path.")

	var stats := RunStats.new()
	add_child(stats)
	stats.reset_for_fresh_run(25.0)
	stats.step_simulation(1.5, 35.0, true)
	_assert(is_equal_approx(stats.active_distance, 10.0) and stats.score == 100 and is_equal_approx(stats.elapsed_seconds, 1.5), "Distance scoring or active timer is incorrect.")
	stats.step_simulation(5.0, 50.0, false)
	_assert(is_equal_approx(stats.active_distance, 10.0) and is_equal_approx(stats.elapsed_seconds, 1.5), "Inactive simulation advanced score distance or timer.")
	stats.step_simulation(1.0, 60.0, true)
	_assert(is_equal_approx(stats.active_distance, 20.0) and stats.score == 200, "Inactive simulation distance leaked into the following active score.")
	stats.elapsed_seconds = 3661.9
	_assert(stats.formatted_time() == "01:01:01", "Timer format is not HH:MM:SS.")
	stats.reset_for_fresh_run(0.0)
	_assert(stats.score == 0 and stats.pickup_score == 0 and is_zero_approx(stats.elapsed_seconds), "Fresh run reset did not clear ordinary metrics.")

	var runner := RUNNER_SCENE.instantiate() as RunnerController
	runner.development_simulation_enabled = false
	add_child(runner)
	runner.reset_for_run()
	var pickup := COLLECTIBLE_SCENE.instantiate() as CollectibleBase
	add_child(pickup)
	pickup.collected.connect(func(_collectible: CollectibleBase) -> void: stats.award_normal_pickup())
	pickup.reset_for_spawn(2.0, 1, 0.0, runner)
	runner.logical_forward_distance = 2.0
	_assert(pickup.step_simulation(runner), "A normal center-lane collectible was not picked up.")
	_assert(not pickup.step_simulation(runner) and stats.score == 100, "Normal collectible pickup was not idempotent or was worth the wrong score.")

	var missed_pickup := COLLECTIBLE_SCENE.instantiate() as CollectibleBase
	add_child(missed_pickup)
	missed_pickup.reset_for_spawn(2.0, 0, 0.0, runner)
	runner.logical_forward_distance = 4.0
	_assert(not missed_pickup.step_simulation(runner) and missed_pickup.is_resolved() and stats.score == 100, "A missed collectible changed score or did not resolve.")

	var lane_pickup := COLLECTIBLE_SCENE.instantiate() as CollectibleBase
	add_child(lane_pickup)
	lane_pickup.reset_for_spawn(4.0, 2, 0.0, runner)
	runner.position.x = runner.movement_profile.lane_spacing
	runner.position.y = 0.0
	runner.logical_forward_distance = 4.0
	_assert(lane_pickup.step_simulation(runner), "Right-lane collectible path did not collect.")
	var jump_pickup := COLLECTIBLE_SCENE.instantiate() as CollectibleBase
	add_child(jump_pickup)
	jump_pickup.reset_for_spawn(6.0, 1, 1.4, runner)
	runner.position.x = 0.0
	runner.position.y = 1.4
	runner.logical_forward_distance = 6.0
	_assert(jump_pickup.step_simulation(runner), "Airborne collectible path did not collect.")

	var generator := TRACK_GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	_assert(generator.configuration_is_valid(), "Task 07 generator configuration is invalid.")
	generator.set_runner(runner)
	generator.reset_generator(707, 0.0, 10.0)
	var spawned_collectibles := 0
	for segment: TrackSegment in generator.active_segments:
		spawned_collectibles += segment.active_collectibles.size()
	_assert(spawned_collectibles > 0, "Generated normal track has no collectible layouts.")
	var pooled_collectible := generator.pool.acquire_collectible()
	generator.pool.release_collectible(pooled_collectible)
	var reused_collectible := generator.pool.acquire_collectible()
	_assert(pooled_collectible == reused_collectible, "Collectible pool did not reuse an available instance.")
	generator.pool.release_collectible(reused_collectible)
	generator.run_stats.award_normal_pickup()
	generator.reset_generator(707, 0.0, 10.0)
	_assert(generator.run_stats.score == 0 and generator.run_stats.pickup_score == 0 and is_zero_approx(generator.run_stats.elapsed_seconds), "Generator fresh reset did not reset score and timer.")

	generator.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr(message)
