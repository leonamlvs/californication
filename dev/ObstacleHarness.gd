extends Node3D

@onready var runner: RunnerController = %Runner
@onready var status_label: Label = %StatusLabel

var _obstacles: Array[ObstacleBase] = []


func _ready() -> void:
	runner.development_simulation_enabled = true
	for child: Node in %ObstacleRoot.get_children():
		var obstacle := child as ObstacleBase
		if obstacle != null:
			obstacle.set_runner(runner)
			obstacle.development_simulation_enabled = true
			obstacle.hit_evaluated.connect(_on_hit_evaluated)
			_obstacles.append(obstacle)
	runner.obstacle_failure_requested.connect(_on_failure_requested)
	_refresh_status("Move, jump, or slide before a primitive reaches you.")


func _process(_delta: float) -> void:
	_refresh_status("")


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
	for index: int in _obstacles.size():
		_obstacles[index].reset_for_spawn(8.0 + float(index) * 5.0)
	_refresh_status("Harness reset.")


func _on_hit_evaluated(event: ObstacleHitEvent) -> void:
	_refresh_status("%s %s." % [event.definition.id, "avoided" if event.was_avoided else "contact"])


func _on_failure_requested(event: ObstacleHitEvent) -> void:
	_refresh_status("Failure requested by %s." % event.definition.id)


func _refresh_status(message: String) -> void:
	var suffix := message if not message.is_empty() else ""
	status_label.text = "Lane: %d  Distance: %.1f m\nJumping: %s  Sliding: %s\n%s" % [runner.target_lane_index + 1, runner.logical_forward_distance, runner.is_jumping, runner.is_sliding, suffix]
