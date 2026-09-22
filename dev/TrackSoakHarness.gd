extends Node3D

@onready var runner: RunnerController = %Runner
@onready var generator: TrackGenerator = %TrackGenerator
@onready var status_label: Label = %StatusLabel

var _message := "Seeded graybox stream ready."
var _layout_index := 0


func _ready() -> void:
	runner.development_simulation_enabled = true
	generator.set_runner(runner)
	generator.reset_generator(generator.deterministic_seed, 0.0, runner.current_speed)


func _process(_delta: float) -> void:
	status_label.text = "Score: %d  Time: %s  Distance: %.1f m\nActive segments: %d  Segment pool: %d  Collectible pool: %d\nLegal states: %d  Fallbacks: %d\n%s" % [
		generator.run_stats.score,
		generator.run_stats.formatted_time(),
		runner.logical_forward_distance,
		generator.active_segments.size(),
		generator.pool.available_segment_count(),
		generator.pool.available_collectible_count(),
		RunnerStateSpace.count_states(generator.tail_legal_state_mask),
		generator.fallback_selection_count,
		_message,
	]


func _on_left_pressed() -> void:
	runner.request_left()


func _on_right_pressed() -> void:
	runner.request_right()


func _on_jump_pressed() -> void:
	runner.request_up()


func _on_slide_pressed() -> void:
	runner.request_down()


func _on_reset_pressed() -> void:
	runner.reset_for_run()
	generator.reset_generator(generator.deterministic_seed, 0.0, runner.current_speed)
	_message = "Reset with deterministic seed %d." % generator.deterministic_seed


func _on_soak_pressed() -> void:
	var distance := runner.logical_forward_distance
	for _second: int in 600:
		distance += 16.0
		generator.step_simulation(distance, 16.0)
	_message = "10-minute / 9.6 km soak: %s, %d segments created." % ["no holes" if generator.active_track_has_no_holes() else "HOLE DETECTED", generator.pool.created_segment_count]


func _on_layout_pressed() -> void:
	var layouts := generator.collectible_layout_library.layouts
	if layouts.is_empty():
		return
	var layout: CollectibleLayout = layouts[_layout_index % layouts.size()]
	_layout_index += 1
	_message = "%s %s." % [layout.id, "spawned" if generator.spawn_collectible_layout(layout) else "could not spawn"]
