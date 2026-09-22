extends Node3D

const BOULEVARD := preload("res://data/scenarios/boulevard.tres")
const GOLDEN_GATE := preload("res://data/scenarios/golden_gate.tres")

@onready var runner: RunnerController = %Runner
@onready var generator: TrackGenerator = %TrackGenerator
@onready var failure: FailureCoordinator = %FailureCoordinator


func _ready() -> void:
	var requested_family: StringName = FailurePresentation.FLOOR_FALL
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--family=launch":
			requested_family = FailurePresentation.LAUNCH
	var source := GOLDEN_GATE if requested_family == FailurePresentation.LAUNCH else BOULEVARD
	runner.movement_profile = source.movement_profile
	runner.set_movement_mode(source.movement_mode)
	runner.reset_for_run()
	generator.set_runner(runner)
	generator.configure_for_scenario(source)
	generator.reset_generator(21, 0.0, runner.current_speed)
	failure.presentation_duration = 0.8
	failure.configure_services(runner, generator)
	failure.begin_scenario(source)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	call_deferred("_start_failure")


func _start_failure() -> void:
	failure.begin_failure()
