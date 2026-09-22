class_name PatternObstaclePlacement
extends Resource

@export var obstacle: ObstacleDefinition
@export_range(0.0, 1000.0, 0.05, "suffix:m") var forward_offset := 0.0
## -1 preserves the definition's lane set; 0..2 places a lane-sized obstacle.
@export_range(-1, 2, 1) var lane := -1
@export var vertical_state: RunnerStateSpace.Posture = RunnerStateSpace.Posture.GROUND
@export var rotation_degrees := Vector3.ZERO


func is_valid_placement(pattern_length: float, lane_count: int = 3) -> bool:
	return obstacle != null and obstacle.is_valid_definition(lane_count) and forward_offset >= 0.0 and forward_offset <= pattern_length and lane >= -1 and lane < lane_count and _declared_posture_matches_class()


func occupied_lanes_at(elapsed: float) -> PackedInt32Array:
	if obstacle == null:
		return PackedInt32Array()
	if obstacle.motion_pattern != ObstacleDefinition.MotionPattern.STATIC:
		return obstacle.occupied_lanes_at(elapsed)
	if lane >= 0 and obstacle.obstacle_class != ObstacleDefinition.ObstacleClass.GAP and obstacle.obstacle_class != ObstacleDefinition.ObstacleClass.GATE:
		return PackedInt32Array([lane])
	return obstacle.occupied_lanes


func _declared_posture_matches_class() -> bool:
	match obstacle.obstacle_class:
		ObstacleDefinition.ObstacleClass.HURDLE, ObstacleDefinition.ObstacleClass.GAP:
			return vertical_state == RunnerStateSpace.Posture.JUMP
		ObstacleDefinition.ObstacleClass.OVERHEAD:
			return vertical_state == RunnerStateSpace.Posture.LOW
		_:
			return vertical_state == RunnerStateSpace.Posture.GROUND
