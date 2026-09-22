class_name TransitionCoordinator
extends Node

signal transition_ready
signal token_opportunity_spawned(token: TransitionToken, forced_safe: bool)
signal token_opportunity_missed
signal transition_started(definition: TransitionDefinition)
signal handoff_completed(target: ScenarioDefinition)

@export_range(0.1, 10.0, 0.1, "suffix:s") var missed_token_retry_delay := 2.0
@export_range(5.0, 100.0, 1.0, "suffix:m") var safe_runway_distance := 25.0

var runner: RunnerController
var generator: TrackGenerator
var run_stats: RunStats
var hud: RunnerHUD
var active_scenario: ScenarioDefinition
var active_token: TransitionToken
var active_cinematic: ScenarioTransitionController
var scenario_elapsed := 0.0

var _minimum_time := 40.0
var _guaranteed_time := 55.0
var _retry_remaining := 0.0
var _use_development_timing := false
var _collection_committed := false
var _transition_sequence := 0


func _physics_process(delta: float) -> void:
	step_simulation(delta)


func configure_services(runner_service: RunnerController, generator_service: TrackGenerator, stats_service: RunStats, hud_service: RunnerHUD = null) -> void:
	runner = runner_service
	generator = generator_service
	run_stats = stats_service
	hud = hud_service


func begin_scenario(definition: ScenarioDefinition, use_development_timing := false) -> bool:
	if definition == null or not definition.is_valid_definition(use_development_timing):
		return false
	active_scenario = definition
	_use_development_timing = use_development_timing
	_minimum_time = definition.development_minimum_transition_time if use_development_timing else definition.minimum_transition_time
	_guaranteed_time = definition.development_guaranteed_transition_time if use_development_timing else definition.guaranteed_transition_time
	scenario_elapsed = 0.0
	_retry_remaining = 0.0
	_collection_committed = false
	_transition_sequence += 1
	return true


func step_simulation(delta: float) -> void:
	if active_scenario == null or runner == null or generator == null or run_stats == null or delta <= 0.0:
		return
	if GameFlow.current_state != GameFlow.RUNNING and GameFlow.current_state != GameFlow.TRANSITION_READY:
		return
	scenario_elapsed += delta
	if GameFlow.current_state == GameFlow.RUNNING and scenario_elapsed >= _minimum_time:
		if GameFlow.mark_transition_ready():
			transition_ready.emit()
	if GameFlow.current_state != GameFlow.TRANSITION_READY or active_token != null:
		return
	if _retry_remaining > 0.0:
		_retry_remaining = maxf(0.0, _retry_remaining - delta)
		if _retry_remaining > 0.0:
			return
	var force_safe := scenario_elapsed >= _guaranteed_time or _retry_remaining == 0.0 and scenario_elapsed > _minimum_time + missed_token_retry_delay
	_try_spawn_token(force_safe)


func development_force_ready() -> bool:
	if active_scenario == null:
		return false
	scenario_elapsed = maxf(scenario_elapsed, _minimum_time)
	if GameFlow.current_state == GameFlow.RUNNING:
		if not GameFlow.mark_transition_ready():
			return false
		transition_ready.emit()
	return GameFlow.current_state == GameFlow.TRANSITION_READY


func development_force_token_spawn() -> bool:
	return development_force_ready() and (active_token != null or _try_spawn_token(true))


func development_force_token_collection() -> bool:
	if not development_force_token_spawn():
		return false
	runner.position.x = 0.0
	runner.position.y = 0.0
	runner.logical_forward_distance = active_token.forward_distance
	return active_token.step_simulation()


func development_force_token_miss() -> bool:
	if not development_force_token_spawn():
		return false
	runner.position.x = -runner.movement_profile.lane_spacing
	runner.logical_forward_distance = active_token.forward_distance + active_token.miss_distance + 0.1
	active_token.step_simulation()
	return active_token == null and _retry_remaining > 0.0


func development_force_complete_cinematic() -> bool:
	if active_cinematic == null or not active_cinematic.is_running:
		return false
	active_cinematic.force_complete()
	return true


func cancel_active_transition() -> void:
	if active_cinematic != null:
		active_cinematic.cancel()
		remove_child(active_cinematic)
		active_cinematic.queue_free()
		active_cinematic = null
	if generator != null:
		generator.release_transition_token()
	if hud != null:
		hud.show_transition_bonus(false)


func transition_bonus_key() -> StringName:
	if active_scenario == null:
		return &""
	return StringName("%s:%d" % [active_scenario.transition_definition.id, _transition_sequence])


func _try_spawn_token(force_safe: bool) -> bool:
	active_token = generator.spawn_transition_token(force_safe)
	if active_token == null:
		return false
	if not active_token.collected.is_connected(_on_token_collected):
		active_token.collected.connect(_on_token_collected)
	if not active_token.missed.is_connected(_on_token_missed):
		active_token.missed.connect(_on_token_missed)
	token_opportunity_spawned.emit(active_token, force_safe)
	return true


func _on_token_missed(_token: TransitionToken) -> void:
	generator.release_transition_token()
	active_token = null
	_retry_remaining = missed_token_retry_delay
	token_opportunity_missed.emit()


func _on_token_collected(_token: TransitionToken) -> void:
	if _collection_committed or GameFlow.current_state != GameFlow.TRANSITION_READY:
		return
	_collection_committed = true
	runner.set_invulnerable(true)
	runner.set_movement_suspended(true)
	generator.set_suspended(true)
	generator.clear_pending_gameplay_content(runner.logical_forward_distance)
	if not GameFlow.report_transition_token_collected():
		_collection_committed = false
		return
	var transition := active_scenario.transition_definition
	run_stats.award_transition_bonus(transition_bonus_key(), transition.transition_bonus_score)
	if hud != null:
		hud.show_transition_bonus(true)
	generator.release_transition_token()
	active_token = null
	ScenarioManager.begin_transition()
	GameFlow.begin_scenario_transition()
	active_cinematic = transition.transition_scene.instantiate() as ScenarioTransitionController
	if active_cinematic == null:
		push_error("Transition scene must inherit ScenarioTransitionController.")
		return
	add_child(active_cinematic)
	active_cinematic.completed.connect(_on_cinematic_completed, CONNECT_ONE_SHOT)
	active_cinematic.start({
		"runner": runner,
		"source_scenario": active_scenario.id,
		"selected_character_id": GameFlow.selected_character_id,
		"camera_profile": transition.optional_camera_profile,
	})
	transition_started.emit(transition)


func _on_cinematic_completed() -> void:
	if GameFlow.current_state != GameFlow.SCENARIO_TRANSITION:
		return
	if not GameFlow.begin_next_scenario() or not ScenarioManager.complete_transition():
		push_error("Scenario transition could not complete its protected handoff.")
		return
	var target: ScenarioDefinition = ScenarioManager.active_definition
	var completed_cinematic := active_cinematic
	active_cinematic = null
	if is_instance_valid(completed_cinematic):
		remove_child(completed_cinematic)
		completed_cinematic.queue_free()
	if target.movement_profile != null:
		runner.movement_profile = target.movement_profile
		runner.set_movement_mode(target.movement_mode)
		runner.current_speed = target.base_speed
	generator.configure_for_scenario(target)
	generator.prepare_safe_runway(safe_runway_distance)
	if hud != null:
		hud.show_transition_bonus(false)
	if not GameFlow.complete_scenario_handoff():
		return
	generator.set_suspended(false)
	runner.set_movement_suspended(false)
	runner.set_invulnerable(false)
	begin_scenario(target, _use_development_timing)
	handoff_completed.emit(target)
