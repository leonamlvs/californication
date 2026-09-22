class_name TransitionToken
extends Node3D

signal collected(token: TransitionToken)
signal missed(token: TransitionToken)

@export_range(0.1, 2.0, 0.05, "suffix:m") var pickup_radius := 0.65
@export_range(0.1, 5.0, 0.05, "suffix:m") var miss_distance := 1.0

@onready var visual: MeshInstance3D = %Visual

var forward_distance := 0.0
var lane := 1
var _runner: RunnerController
var _resolved := false


func reset_for_spawn(distance: float, lane_index: int, runner: RunnerController) -> void:
	forward_distance = distance
	lane = lane_index
	_runner = runner
	_resolved = false
	visible = true
	set_process(true)
	_update_visual()


func prepare_for_pool() -> void:
	forward_distance = 0.0
	lane = 1
	_runner = null
	_resolved = false
	position = Vector3.ZERO
	visible = false
	set_process(false)


func step_simulation() -> bool:
	if _runner == null or _resolved:
		return false
	_update_visual()
	if _runner.logical_forward_distance < forward_distance:
		return false
	var lane_x := (float(lane) - float(_runner.movement_profile.lane_count - 1) * 0.5) * _runner.movement_profile.lane_spacing
	if absf(_runner.position.x - lane_x) <= pickup_radius and absf(_runner.position.y) <= pickup_radius:
		_resolved = true
		collected.emit(self)
		return true
	if _runner.logical_forward_distance > forward_distance + miss_distance:
		_resolved = true
		missed.emit(self)
	return false


func is_resolved() -> bool:
	return _resolved


func _update_visual() -> void:
	var logical_distance := _runner.logical_forward_distance if _runner != null else 0.0
	var lane_spacing := _runner.movement_profile.lane_spacing if _runner != null else 1.6
	var lane_count := _runner.movement_profile.lane_count if _runner != null else 3
	position = Vector3((float(lane) - float(lane_count - 1) * 0.5) * lane_spacing, 0.85, -(forward_distance - logical_distance))
	if visual != null:
		visual.rotation.y += 0.06
