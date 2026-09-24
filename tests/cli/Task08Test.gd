extends Node

const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const COORDINATOR_SCENE := preload("res://gameplay/transitions/TransitionCoordinator.tscn")
const HUD_SCENE := preload("res://ui/hud/HUD.tscn")
const FIXTURE_A := preload("res://dev/fixtures/fixture_scenario_a.tres")
const FIXTURE_B := preload("res://dev/fixtures/fixture_scenario_b.tres")

var _failed := false


func _ready() -> void:
	_run()
	if _failed:
		get_tree().quit(1)
		return
	print("Task 08 scenario transition framework test passed.")
	get_tree().quit(0)


func _run() -> void:
	_test_shuffle_bag()
	_test_transition_round_trip()


func _test_shuffle_bag() -> void:
	var entries: Array[StringName] = [&"a", &"b", &"c"]
	var bag_a := ShuffleBag.new()
	var bag_b := ShuffleBag.new()
	bag_a.configure(entries, 808)
	bag_b.configure(entries, 808)
	var sequence_a: Array[StringName] = []
	var sequence_b: Array[StringName] = []
	for _index: int in 7:
		var current_a: StringName = sequence_a.back() if not sequence_a.is_empty() else &""
		var current_b: StringName = sequence_b.back() if not sequence_b.is_empty() else &""
		sequence_a.append(bag_a.draw(current_a))
		sequence_b.append(bag_b.draw(current_b))
	_assert(sequence_a == sequence_b, "Equal shuffle seeds produced different sequences.")
	_assert(sequence_a.slice(0, 3).duplicate().all(func(value: StringName) -> bool: return sequence_a.slice(0, 3).count(value) == 1), "Shuffle bag repeated before exhausting its first cycle.")
	_assert(sequence_a[2] != sequence_a[3] and sequence_a[5] != sequence_a[6], "Shuffle refill immediately repeated the current scenario.")


func _test_transition_round_trip() -> void:
	var scenario_root := Node3D.new()
	add_child(scenario_root)
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	var scenario_a := FIXTURE_A.duplicate(true) as ScenarioDefinition
	scenario_a.minimum_transition_time = 0.5
	scenario_a.guaranteed_transition_time = 1.0
	_assert(ScenarioManager.register_scenario(scenario_a, true), "Fixture A did not register.")
	_assert(ScenarioManager.register_scenario(FIXTURE_B, true), "Fixture B did not register.")
	_assert(ScenarioManager.production_scenario_ids().is_empty() and ScenarioManager.development_scenario_ids().size() == 2, "Development fixtures leaked into the production registry.")
	_assert(ScenarioManager.load_scenario(scenario_a.id), "Fixture A did not load.")
	_assert(not ScenarioManager.active_environment_has_gameplay_entities(), "Fixture environment contains a gameplay entity.")

	var runner := RUNNER_SCENE.instantiate() as RunnerController
	add_child(runner)
	runner.development_simulation_enabled = false
	var generator := GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	generator.set_runner(runner)
	generator.reset_generator(808, 0.0, runner.current_speed)
	for segment: TrackSegment in generator.active_segments:
		segment.pattern = segment.pattern.duplicate(true) as PatternDefinition
		segment.pattern.safe_fallback = false
	var hud := HUD_SCENE.instantiate() as RunnerHUD
	add_child(hud)
	hud.bind_run_stats(generator.run_stats)
	var coordinator := COORDINATOR_SCENE.instantiate() as TransitionCoordinator
	add_child(coordinator)
	coordinator.missed_token_retry_delay = 0.5
	coordinator.configure_services(runner, generator, generator.run_stats, hud)
	var atomic_snapshot: Dictionary = {}
	coordinator.transition_started.connect(func(_definition: TransitionDefinition) -> void:
		atomic_snapshot["invulnerable"] = runner.is_invulnerable
		atomic_snapshot["movement_suspended"] = runner.movement_suspended
		atomic_snapshot["generator_suspended"] = generator.suspended
		atomic_snapshot["input_locked"] = not GameFlow.gameplay_input_enabled
	)
	_assert(coordinator.begin_scenario(scenario_a), "Coordinator rejected valid fixture scenario.")
	_assert(GameFlow.development_jump_to_state(GameFlow.RUNNING), "Development state jump could not enter RUNNING.")
	_assert(not GameFlow.development_jump_to_state(&"UNKNOWN_STATE"), "Development state jump accepted an unknown state.")

	coordinator.step_simulation(0.49)
	_assert(GameFlow.current_state == GameFlow.RUNNING and coordinator.active_token == null, "Transition became ready before its minimum time.")
	coordinator.step_simulation(0.01)
	_assert(GameFlow.current_state == GameFlow.TRANSITION_READY and coordinator.active_token == null, "Minimum time did not enter TRANSITION_READY or accepted an unsafe ordinary opportunity.")
	coordinator.step_simulation(0.5)
	_assert(coordinator.active_token != null, "Guaranteed time did not force a safe token opportunity.")
	_assert(coordinator.active_token.forward_distance - runner.logical_forward_distance >= generator.current_speed * generator.absolute_minimum_reaction_time, "Guaranteed token was inside the minimum reaction distance.")

	_assert(coordinator.development_force_token_miss(), "Forced token miss did not schedule a retry.")
	runner.logical_forward_distance = 0.0
	runner.position.x = 0.0
	coordinator.step_simulation(0.49)
	_assert(coordinator.active_token == null, "Missed token retried before the configured delay.")
	coordinator.step_simulation(0.02)
	_assert(coordinator.active_token != null, "Missed token did not retry with a safe opportunity.")

	var score_before := generator.run_stats.score
	var mode_before := runner.current_movement_mode
	_assert(coordinator.development_force_token_collection(), "Forced transition token collection failed.")
	_assert(GameFlow.current_state == GameFlow.SCENARIO_TRANSITION, "Token collection did not enter SCENARIO_TRANSITION.")
	_assert(runner.is_invulnerable and runner.movement_suspended and generator.suspended, "Token collection did not atomically protect and suspend gameplay.")
	_assert(atomic_snapshot.values().all(func(value: bool) -> bool: return value) and atomic_snapshot.size() == 4, "Transition began before the atomic gameplay lock was complete.")
	_assert(not GameFlow.gameplay_input_enabled and not GameFlow.run_timer_enabled, "Cinematic retained gameplay input or timer authority.")
	_assert(generator.run_stats.score == score_before + 1000 and generator.run_stats.transition_bonus_score == 1000, "Transition bonus was not added to ordinary score exactly once.")
	_assert(hud.bonus_overlay.visible and hud.score_label.text.contains("001000"), "HUD did not show centered BONUS with the updated ordinary score.")
	_assert(runner.current_movement_mode == mode_before, "Scenario transition was installed as a movement mode.")
	_assert(coordinator.active_cinematic != null and coordinator.active_cinematic.is_running, "Scripted cinematic did not start.")
	_assert(coordinator.active_cinematic.find_children("*", "RunnerController", true, false).is_empty(), "Cinematic contains a runner controller.")
	_assert(coordinator.active_cinematic.find_children("*", "ObstacleBase", true, false).is_empty(), "Cinematic contains gameplay obstacles.")
	_assert(coordinator.active_cinematic.find_children("*", "CollectibleBase", true, false).is_empty(), "Cinematic contains normal collectibles.")
	_assert(not runner.request_left(), "Suspended runner accepted gameplay movement during the cinematic.")
	var stopped_distance := runner.logical_forward_distance
	runner.step_simulation(1.0)
	_assert(is_equal_approx(runner.logical_forward_distance, stopped_distance), "Runner advanced during the cinematic.")
	for segment: TrackSegment in generator.active_segments:
		for obstacle: ObstacleBase in segment.active_obstacles:
			_assert(obstacle.forward_distance < runner.logical_forward_distance, "Unsafe obstacle remained queued during the cinematic.")
		for collectible: CollectibleBase in segment.active_collectibles:
			_assert(collectible.forward_distance < runner.logical_forward_distance, "Normal collectible remained queued during the cinematic.")
	var suppressed_event := ObstacleHitEvent.new()
	_assert(not runner.request_obstacle_hit(suppressed_event) and suppressed_event.was_suppressed, "Cinematic invulnerability did not suppress failure.")
	var timer_before := generator.run_stats.elapsed_seconds
	generator.step_simulation(runner.logical_forward_distance + 10.0, runner.current_speed, 1.0)
	_assert(is_equal_approx(generator.run_stats.elapsed_seconds, timer_before), "Cinematic advanced the run timer.")
	_assert(not generator.run_stats.award_transition_bonus(coordinator.transition_bonus_key(), 1000) and generator.run_stats.score == score_before + 1000, "Transition bonus idempotence failed.")

	_assert(coordinator.development_force_complete_cinematic(), "Fixture cinematic could not be completed through its development hook.")
	_assert(GameFlow.current_state == GameFlow.RUNNING and ScenarioManager.active_scenario_id == FIXTURE_B.id, "Fixture cinematic did not hand off to the next scenario.")
	_assert(not runner.is_invulnerable and not runner.movement_suspended and not generator.suspended, "Control or vulnerability returned in the wrong protected state.")
	_assert(not hud.bonus_overlay.visible, "BONUS overlay remained after handoff.")
	_assert(generator.pool.created_token_count == 1 and generator.pool.available_token_count() == 1, "Transition token was not returned to its bounded pool.")
	_assert(not ScenarioManager.active_environment_has_gameplay_entities(), "Next fixture environment contains gameplay entities.")
	var runway_end := generator.current_logical_distance + coordinator.safe_runway_distance
	for segment: TrackSegment in generator.active_segments:
		if segment.start_distance < runway_end:
			for obstacle: ObstacleBase in segment.active_obstacles:
				_assert(obstacle.forward_distance >= runway_end, "Next scenario placed a hazard inside the safe runway.")
	_assert(generator.active_segments.back().end_distance >= generator.current_logical_distance + generator.ahead_distance, "Normal generation did not resume beyond the safe runway.")

	ScenarioManager.reset_for_tests()
	runner.queue_free()
	generator.queue_free()
	hud.queue_free()
	coordinator.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr(message)
