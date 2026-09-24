class_name CollectibleBase
extends Node3D

signal collected(collectible: CollectibleBase)
signal missed(collectible: CollectibleBase)

@export_range(0.1, 2.0, 0.05, "suffix:m") var pickup_radius := 0.55
@export_range(0.1, 5.0, 0.05, "suffix:m") var miss_distance := 1.0

@onready var visual: MeshInstance3D = %Visual

var forward_distance := 0.0
var lane := 1
var required_runner_height := 0.0
var _collected := false
var _missed := false


func reset_for_spawn(distance: float, lane_index: int, runner_height: float, runner: RunnerController) -> void:
	forward_distance = distance
	lane = lane_index
	required_runner_height = runner_height
	_collected = false
	_missed = false
	visible = true
	set_process(true)
	_update_visual(runner)


func prepare_for_pool() -> void:
	forward_distance = 0.0
	lane = 1
	required_runner_height = 0.0
	_collected = false
	_missed = false
	position = Vector3.ZERO
	visible = false
	set_process(false)


## Returns true exactly once if this runner meets the lane/height pickup path.
func step_simulation(runner: RunnerController) -> bool:
	if runner == null or _collected or _missed:
		return false
	_update_visual(runner)
	if runner.logical_forward_distance < forward_distance:
		return false
	if _runner_matches_path(runner):
		_collected = true
		collected.emit(self)
		return true
	if runner.logical_forward_distance > forward_distance + miss_distance:
		_missed = true
		missed.emit(self)
	return false


func is_resolved() -> bool:
	return _collected or _missed


func _runner_matches_path(runner: RunnerController) -> bool:
	var lane_x := (float(lane) - float(runner.movement_profile.lane_count - 1) * 0.5) * runner.movement_profile.lane_spacing
	return absf(runner.position.x - lane_x) <= pickup_radius and absf(runner.position.y - required_runner_height) <= pickup_radius


func _update_visual(runner: RunnerController) -> void:
	var lane_count := runner.movement_profile.lane_count if runner != null else 3
	var lane_spacing := runner.movement_profile.lane_spacing if runner != null else 1.6
	var logical_distance := runner.logical_forward_distance if runner != null else 0.0
	var lane_x := (float(lane) - float(lane_count - 1) * 0.5) * lane_spacing
	position = Vector3(lane_x, required_runner_height + 0.5, -(forward_distance - logical_distance))
	visual.rotation.y += 0.04
	visual.position.y = sin(logical_distance * 0.7 + forward_distance) * 0.08
