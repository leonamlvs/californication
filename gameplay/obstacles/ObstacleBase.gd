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
var _avoidance_posture: RunnerStateSpace.Posture = RunnerStateSpace.Posture.GROUND
var _motion_origin_distance := -INF
var _silhouette_key := ""


func _ready() -> void:
	_apply_definition()


func _physics_process(delta: float) -> void:
	if _runner != null and (development_simulation_enabled or GameFlow.gameplay_input_enabled):
		step_simulation(_runner, delta)


func set_runner(runner: RunnerController) -> void:
	_runner = runner


func reset_for_spawn(distance: float = forward_distance, placement_lane: int = -1, motion_origin_distance: float = -INF, avoidance_posture: RunnerStateSpace.Posture = RunnerStateSpace.Posture.GROUND) -> void:
	forward_distance = distance
	_elapsed = 0.0
	_resolved = false
	_placement_lane = placement_lane
	_avoidance_posture = avoidance_posture
	_motion_origin_distance = motion_origin_distance
	_apply_definition()
	_build_readable_silhouette()
	visible = true
	set_physics_process(true)
	if collision_shape != null:
		collision_shape.disabled = false


func prepare_for_pool() -> void:
	_runner = null
	_elapsed = 0.0
	_resolved = false
	_placement_lane = -1
	_avoidance_posture = RunnerStateSpace.Posture.GROUND
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
	if definition.motion_pattern != ObstacleDefinition.MotionPattern.STATIC:
		return absf(runner.position.x - position.x) > definition.collision_size.x * 0.5 + runner.movement_profile.capsule_radius * 0.6
	if not current_occupied_lanes().has(runner_lane):
		return true
	match definition.obstacle_class:
		ObstacleDefinition.ObstacleClass.HURDLE, ObstacleDefinition.ObstacleClass.GAP:
			return runner.is_jumping
		ObstacleDefinition.ObstacleClass.OVERHEAD:
			return runner.is_sliding
		_:
			return (runner.position.y > 0.28 and _avoidance_posture == RunnerStateSpace.Posture.RISE) or (runner.position.y < -0.28 and _avoidance_posture == RunnerStateSpace.Posture.DIVE)


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


func _build_readable_silhouette() -> void:
	var key := "%s:%d" % [definition.id, _avoidance_posture]
	if key == _silhouette_key:
		return
	_silhouette_key = key
	for child: Node in visual_root.get_children():
		visual_root.remove_child(child)
		child.queue_free()
	var warm := Color(0.93, 0.56, 0.20)
	var dark := Color(0.11, 0.15, 0.19)
	match definition.obstacle_class:
		ObstacleDefinition.ObstacleClass.HURDLE:
			_box(Vector3(1.3, 0.55, 0.5), Vector3(0, 0.275, 0), warm)
			for x: float in [-0.45, 0.0, 0.45]:
				_box(Vector3(0.14, 0.56, 0.52), Vector3(x, 0.28, 0), dark)
		ObstacleDefinition.ObstacleClass.OVERHEAD:
			_box(Vector3(1.55, 0.5, 0.55), Vector3(0, 1.45, 0), warm)
			for x: float in [-0.73, 0.73]:
				_box(Vector3(0.1, 1.7, 0.4), Vector3(x, 0.85, 0), dark)
		ObstacleDefinition.ObstacleClass.GAP:
			_box(Vector3(5.0, 0.045, 1.1), Vector3(0, 0.025, 0), Color(0.015, 0.02, 0.028))
			for z: float in [-0.57, 0.57]:
				_box(Vector3(5.0, 0.06, 0.08), Vector3(0, 0.055, z), warm)
		ObstacleDefinition.ObstacleClass.GATE:
			for lane: int in definition.occupied_lanes:
				_box(Vector3(1.25, 2.7, 0.65), Vector3((lane - 1) * 1.6, 1.35, 0), dark)
			_box(Vector3(4.6, 0.15, 0.7), Vector3(0, 2.75, 0), warm)
		_:
			if _avoidance_posture == RunnerStateSpace.Posture.RISE:
				_box(Vector3(1.35, 1.1, 0.65), Vector3(0, 0.05, 0), warm)
				_box(Vector3(0.18, 0.45, 0.18), Vector3(0, 1.6, 0), Color(0.5, 1.0, 0.85))
			elif _avoidance_posture == RunnerStateSpace.Posture.DIVE:
				_box(Vector3(1.35, 1.5, 0.65), Vector3(0, 1.25, 0), warm)
				_box(Vector3(0.18, 0.4, 0.18), Vector3(0, -0.8, 0), Color(0.5, 1.0, 0.85))
			else:
				_box(Vector3(1.2, 1.8, 0.8), Vector3(0, 0.9, 0), dark)
				_box(Vector3(1.22, 0.12, 0.82), Vector3(0, 1.7, 0), warm)
	if definition.motion_pattern != ObstacleDefinition.MotionPattern.STATIC:
		for x: float in [-1.6, -0.8, 0.0, 0.8, 1.6]:
			_box(Vector3(0.35, 0.035, 0.18), Vector3(x, 0.06, 0.7), warm)


func _box(size: Vector3, center: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = center
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	visual_root.add_child(visual)


func _apply_definition() -> void:
	if definition == null:
		push_error("ObstacleBase requires an ObstacleDefinition resource.")
		return
	var box := collision_shape.shape as BoxShape3D
	if box != null:
		box.size = definition.collision_size
		collision_shape.position.y = definition.collision_size.y * 0.5


func _update_visual_motion(runner: RunnerController) -> void:
	if definition.obstacle_class == ObstacleDefinition.ObstacleClass.GATE:
		visual_root.scale.x = runner.movement_profile.lane_spacing / 1.6
	# Logical distance advances while the runner remains near the origin.
	position.z = -(forward_distance - runner.logical_forward_distance)
	if definition.motion_pattern == ObstacleDefinition.MotionPattern.CROSS_LANE or definition.motion_pattern == ObstacleDefinition.MotionPattern.SWEEP:
		var cycle := fposmod(_elapsed / definition.motion_period, 2.0)
		var amount := 1.0 - absf(cycle - 1.0)
		if definition.motion_pattern == ObstacleDefinition.MotionPattern.SWEEP:
			amount = 1.0 - absf(fposmod(_elapsed / definition.motion_period, 1.0) * 2.0 - 1.0)
		var lane := lerpf(float(definition.motion_start_lane), float(definition.motion_end_lane), amount)
		position.x = (float(lane) - float(runner.movement_profile.lane_count - 1) * 0.5) * runner.movement_profile.lane_spacing
	elif _placement_lane >= 0 and definition.obstacle_class not in [ObstacleDefinition.ObstacleClass.GAP, ObstacleDefinition.ObstacleClass.GATE]:
		position.x = (float(_placement_lane) - float(runner.movement_profile.lane_count - 1) * 0.5) * runner.movement_profile.lane_spacing
	if definition.motion_pattern == ObstacleDefinition.MotionPattern.SWEEP:
		visual_root.rotation.z = sin(_elapsed / definition.motion_period * TAU) * 0.7
