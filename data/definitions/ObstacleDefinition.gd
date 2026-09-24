class_name ObstacleDefinition
extends Resource

## Data contract for one reusable gameplay obstacle. Placeholder meshes are
## intentionally excluded from the collision and response decisions.
enum ObstacleClass { BLOCK, HURDLE, OVERHEAD, CROSSER, SWEEPER, GAP, GATE }
enum MotionPattern { STATIC, CROSS_LANE, SWEEP }

@export var id: StringName
@export var obstacle_class: ObstacleClass = ObstacleClass.BLOCK
@export var allowed_movement_modes: Array[StringName] = [&"RUN"]
@export var occupied_lanes: PackedInt32Array = PackedInt32Array([1])
@export var motion_pattern: MotionPattern = MotionPattern.STATIC
@export_range(0.05, 10.0, 0.05, "suffix:s") var motion_period := 1.0
@export_range(0, 2, 1) var motion_start_lane := 0
@export_range(0, 2, 1) var motion_end_lane := 2
@export_range(0.0, 5.0, 0.05, "suffix:s") var minimum_reaction_time := 0.5
@export var collision_size := Vector3(1.2, 1.7, 0.7)
@export var visual_scene: PackedScene


func is_valid_definition(lane_count: int = 3) -> bool:
	if id.is_empty() or lane_count <= 0 or allowed_movement_modes.is_empty():
		return false
	if collision_size.x <= 0.0 or collision_size.y <= 0.0 or collision_size.z <= 0.0:
		return false
	if motion_period <= 0.0 or minimum_reaction_time < 0.0:
		return false
	if obstacle_class == ObstacleClass.HURDLE or obstacle_class == ObstacleClass.OVERHEAD or obstacle_class == ObstacleClass.GAP:
		return not occupied_lanes.is_empty()
	for lane: int in occupied_lanes:
		if lane < 0 or lane >= lane_count:
			return false
	return motion_start_lane >= 0 and motion_start_lane < lane_count and motion_end_lane >= 0 and motion_end_lane < lane_count


func is_mode_supported(movement_mode: StringName) -> bool:
	return allowed_movement_modes.has(movement_mode)


func occupied_lanes_at(elapsed: float) -> PackedInt32Array:
	if motion_pattern == MotionPattern.STATIC:
		return occupied_lanes
	var cycle_progress := fposmod(maxf(elapsed, 0.0), motion_period) / motion_period
	if motion_pattern == MotionPattern.SWEEP:
		cycle_progress = 1.0 - absf(cycle_progress * 2.0 - 1.0)
	else:
		cycle_progress = 1.0 - absf(fposmod(maxf(elapsed, 0.0) / motion_period, 2.0) - 1.0)
	return PackedInt32Array([roundi(lerpf(float(motion_start_lane), float(motion_end_lane), cycle_progress))])
