extends Node3D

@onready var runner: RunnerController = %Runner
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	runner.development_simulation_enabled = true
	runner.lane_changed.connect(_refresh_status)
	runner.vertical_state_changed.connect(func(_jumping: bool, _sliding: bool) -> void: _refresh_status())
	_refresh_status()


func _process(_delta: float) -> void:
	_refresh_status()


func _refresh_status(_lane: int = 0) -> void:
	status_label.text = "Lane: %d   Distance: %.1f m\nJumping: %s   Sliding: %s" % [runner.target_lane_index + 1, runner.logical_forward_distance, runner.is_jumping, runner.is_sliding]


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
