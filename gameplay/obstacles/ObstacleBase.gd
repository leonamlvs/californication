class_name ObstacleBase
extends Node3D

## Shared deterministic obstacle runtime. It evaluates path distance rather
## than a rendered mesh, so scenarios may replace the visual child freely.
signal hit_evaluated(event: ObstacleHitEvent)
signal avoidance_succeeded(event: ObstacleHitEvent)

@export var definition: ObstacleDefinition
@export_range(0.0, 10000.0, 0.1, "suffix:m") var forward_distance := 10.0
@export var development_simulation_enabled := false

@onready var collision_shape: CollisionShape3D = %CollisionShape
@onready var visual_root: Node3D = %VisualRoot

var _runner: RunnerController
var _elapsed := 0.0
var _resolved := false
var _placement_lane := -1
var _motion_origin_distance := -INF


func _ready() -> void:
	_apply_definition()


func _physics_process(delta: float) -> void:
	if _runner != null and (development_simulation_enabled or GameFlow.gameplay_input_enabled):
		step_simulation(_runner, delta)


func set_runner(runner: RunnerController) -> void:
	_runner = runner


func reset_for_spawn(distance: float = forward_distance, placement_lane: int = -1, motion_origin_distance: float = -INF) -> void:
	forward_distance = distance
	_elapsed = 0.0
	_resolved = false
	_placement_lane = placement_lane
	_motion_origin_distance = motion_origin_distance
	visible = true
	set_physics_process(true)
	if collision_shape != null:
		collision_shape.disabled = false


func prepare_for_pool() -> void:
	_runner = null
	_elapsed = 0.0
	_resolved = false
	_placement_lane = -1
	_motion_origin_distance = -INF
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	visual_root.rotation = Vector3.ZERO
	visible = false
	set_physics_process(false)
	if collision_shape != null:
		collision_shape.disabled = true


## Deterministic stepping path for tests, the harness, and future pools.
func step_simulation(runner: RunnerController, delta: float) -> ObstacleHitEvent:
	if definition == null or runner == null:
		return null
	if is_finite(_motion_origin_distance) and runner.current_speed > 0.0:
		_elapsed = maxf(0.0, (runner.logical_forward_distance - _motion_origin_distance) / runner.current_speed)
	else:
		_elapsed += maxf(delta, 0.0)
	_update_visual_motion(runner)
	if _resolved or runner.logical_forward_distance < forward_distance:
		return null
	_resolved = true
	var event := ObstacleHitEvent.new(definition, self)
	event.contact_distance = forward_distance
	event.runner_lane = _nearest_lane_index(runner)
	event.was_avoided = _runner_avoids(runner, event.runner_lane)
	hit_evaluated.emit(event)
	if event.was_avoided:
		avoidance_succeeded.emit(event)
	else:
		runner.request_obstacle_hit(event)
	return event


func current_occupied_lanes() -> PackedInt32Array:
	if definition == null:
		return PackedInt32Array()
	match definition.motion_pattern:
		ObstacleDefinition.MotionPattern.STATIC:
			if _placement_lane >= 0 and definition.obstacle_class != ObstacleDefinition.ObstacleClass.GAP and definition.obstacle_class != ObstacleDefinition.ObstacleClass.GATE:
				return PackedInt32Array([_placement_lane])
			return definition.occupied_lanes
		ObstacleDefinition.MotionPattern.CROSS_LANE, ObstacleDefinition.MotionPattern.SWEEP:
			return definition.occupied_lanes_at(_elapsed)
	return definition.occupied_lanes


func _runner_avoids(runner: RunnerController, runner_lane: int) -> bool:
	if not definition.is_mode_supported(runner.current_movement_mode):
		return true
	if not current_occupied_lanes().has(runner_lane):
		return true
	match definition.obstacle_class:
		ObstacleDefinition.ObstacleClass.HURDLE, ObstacleDefinition.ObstacleClass.GAP:
			return runner.is_jumping
		ObstacleDefinition.ObstacleClass.OVERHEAD:
			return runner.is_sliding
		_:
			return false


func _nearest_lane_index(runner: RunnerController) -> int:
	var nearest := 0
	var nearest_distance := INF
	for lane: int in runner.movement_profile.lane_count:
		var lane_x := (float(lane) - float(runner.movement_profile.lane_count - 1) * 0.5) * runner.movement_profile.lane_spacing
		var distance := absf(runner.position.x - lane_x)
		if distance < nearest_distance:
			nearest = lane
			nearest_distance = distance
	return nearest


func _moving_lane() -> int:
	return definition.occupied_lanes_at(_elapsed)[0]


func _apply_definition() -> void:
	if definition == null:
		push_error("ObstacleBase requires an ObstacleDefinition resource.")
		return
	var box := collision_shape.shape as BoxShape3D
	if box != null:
		box.size = definition.collision_size
		collision_shape.position.y = definition.collision_size.y * 0.5


func _update_visual_motion(runner: RunnerController) -> void:
	# Logical distance advances while the runner remains near the origin.
	position.z = -(forward_distance - runner.logical_forward_distance)
	if definition.motion_pattern == ObstacleDefinition.MotionPattern.CROSS_LANE or definition.motion_pattern == ObstacleDefinition.MotionPattern.SWEEP:
		var lane := _moving_lane()
		position.x = (float(lane) - float(runner.movement_profile.lane_count - 1) * 0.5) * runner.movement_profile.lane_spacing
	elif _placement_lane >= 0:
		position.x = (float(_placement_lane) - float(runner.movement_profile.lane_count - 1) * 0.5) * runner.movement_profile.lane_spacing
	if definition.motion_pattern == ObstacleDefinition.MotionPattern.SWEEP:
		visual_root.rotation.z = sin(_elapsed / definition.motion_period * TAU) * 0.7
