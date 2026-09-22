class_name FailureCoordinator
extends Node

## Shared failure authority. Scenario data selects presentation only; it never changes collision rules.
signal failure_started(family: StringName)
signal game_over_ready

const FAILURE_PRESENTATION_SCENE := preload("res://gameplay/failure/FailurePresentation.tscn")

@export_range(0.05, 3.0, 0.05, "suffix:s") var presentation_duration := 0.45

var runner: RunnerController
var generator: TrackGenerator
var transition_coordinator: TransitionCoordinator
var active_scenario: ScenarioDefinition
var active_family: StringName = &""
var active_presentation: FailurePresentation
var is_presenting := false


func configure_services(runner_service: RunnerController, generator_service: TrackGenerator, transition_service: TransitionCoordinator = null) -> void:
	if runner != null and runner.obstacle_failure_requested.is_connected(_on_obstacle_failure_requested):
		runner.obstacle_failure_requested.disconnect(_on_obstacle_failure_requested)
	runner = runner_service
	generator = generator_service
	transition_coordinator = transition_service
	if runner != null and not runner.obstacle_failure_requested.is_connected(_on_obstacle_failure_requested):
		runner.obstacle_failure_requested.connect(_on_obstacle_failure_requested)
	if not GameFlow.run_reset_requested.is_connected(_on_run_reset_requested):
		GameFlow.run_reset_requested.connect(_on_run_reset_requested)
	if not GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.connect(_on_game_flow_state_changed)


func begin_scenario(definition: ScenarioDefinition) -> void:
	active_scenario = definition


func _on_obstacle_failure_requested(_event: ObstacleHitEvent) -> void:
	begin_failure()


func begin_failure() -> bool:
	if is_presenting or GameFlow.current_state != GameFlow.RUNNING and GameFlow.current_state != GameFlow.TRANSITION_READY:
		return false
	if active_scenario == null or runner == null or generator == null:
		return false
	if active_scenario.failure_family != FailurePresentation.FLOOR_FALL and active_scenario.failure_family != FailurePresentation.LAUNCH:
		return false

	# Commit every gameplay lock before the visible presentation begins.
	runner.set_invulnerable(true)
	runner.set_movement_suspended(true)
	generator.set_suspended(true)
	generator.release_transition_token()
	generator.clear_pending_gameplay_content(runner.logical_forward_distance)
	if transition_coordinator != null:
		transition_coordinator.cancel_active_transition()
	if not GameFlow.fail_run():
		_restore_gameplay_locks()
		return false

	active_family = active_scenario.failure_family
	active_presentation = FAILURE_PRESENTATION_SCENE.instantiate() as FailurePresentation
	if active_presentation == null:
		push_error("Failure presentation scene must inherit FailurePresentation.")
		GameFlow.request_transition(GameFlow.LAVA_GAME_OVER)
		return true
	add_child(active_presentation)
	active_presentation.completed.connect(_on_presentation_completed, CONNECT_ONE_SHOT)
	if not active_presentation.play(runner, active_family, presentation_duration):
		active_presentation.queue_free()
		active_presentation = null
		GameFlow.request_transition(GameFlow.LAVA_GAME_OVER)
		return true
	is_presenting = true
	failure_started.emit(active_family)
	return true


func _on_presentation_completed(_family: StringName) -> void:
	if not is_presenting:
		return
	is_presenting = false
	if GameFlow.current_state == GameFlow.FAILURE_TRANSITION and GameFlow.request_transition(GameFlow.LAVA_GAME_OVER):
		game_over_ready.emit()


func _on_run_reset_requested(target_scenario: StringName) -> void:
	if target_scenario != GameFlow.BOULEVARD_ID or runner == null or generator == null:
		return
	_clear_presentation(true)
	if not ScenarioManager.begin_production_run(generator.deterministic_seed):
		push_error("Failure retry could not prepare Boulevard.")
		return
	var target := ScenarioManager.active_definition
	if target == null or not generator.configure_for_scenario(target):
		push_error("Failure retry could not configure Boulevard gameplay.")
		return
	runner.movement_profile = target.movement_profile
	runner.set_movement_mode(target.movement_mode)
	runner.reset_for_run()
	generator.reset_generator(generator.deterministic_seed, 0.0, runner.current_speed)
	begin_scenario(target)
	if transition_coordinator != null:
		transition_coordinator.begin_scenario(target)
	# RUN_INTRO owns the eventual unlock. Until it reports ready, failure input,
	# generation, collision, and timer state remain protected.
	runner.set_invulnerable(true)
	runner.set_movement_suspended(true)
	generator.set_suspended(true)


func _on_game_flow_state_changed(previous: StringName, next_state: StringName) -> void:
	if next_state == GameFlow.ISLAND_ATTRACT:
		_clear_presentation(true)
		if transition_coordinator != null:
			transition_coordinator.cancel_active_transition()
		if generator != null:
			generator.release_transition_token()
			generator.clear_pending_gameplay_content(-INF)
			generator.set_suspended(true)
		if runner != null:
			runner.set_invulnerable(true)
			runner.set_movement_suspended(true)
		ScenarioManager.unload_active_scenario()
		active_scenario = null
	elif previous == GameFlow.RUN_INTRO and next_state == GameFlow.RUNNING:
		_restore_gameplay_locks()


func _restore_gameplay_locks() -> void:
	if runner != null:
		runner.set_invulnerable(false)
		runner.set_movement_suspended(false)
	if generator != null:
		generator.set_suspended(false)


func _clear_presentation(restore_runner: bool) -> void:
	is_presenting = false
	if active_presentation == null:
		return
	active_presentation.cancel(restore_runner)
	active_presentation.queue_free()
	active_presentation = null


func _exit_tree() -> void:
	_clear_presentation(true)
	if runner != null and runner.obstacle_failure_requested.is_connected(_on_obstacle_failure_requested):
		runner.obstacle_failure_requested.disconnect(_on_obstacle_failure_requested)
	if GameFlow.run_reset_requested.is_connected(_on_run_reset_requested):
		GameFlow.run_reset_requested.disconnect(_on_run_reset_requested)
	if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.disconnect(_on_game_flow_state_changed)
