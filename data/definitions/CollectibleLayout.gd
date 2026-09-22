class_name CollectibleLayout
extends Resource

enum LayoutType { STRAIGHT, ARC_UP, ARC_DOWN, LEFT_TO_RIGHT, RIGHT_TO_LEFT, ZIGZAG, JUMP_ARC, LANE_GUIDE }

@export var id: StringName
@export var layout_type: LayoutType = LayoutType.STRAIGHT
@export_range(1.0, 200.0, 0.5, "suffix:m") var length := 30.0
@export_range(0.01, 100.0, 0.01) var weight := 1.0
@export var allowed_movement_modes: Array[StringName] = [&"RUN"]
@export var points: Array[CollectibleLayoutPoint] = []


func is_valid_definition(lane_count: int = 3) -> bool:
	if id.is_empty() or length <= 0.0 or weight <= 0.0 or allowed_movement_modes.is_empty() or points.is_empty():
		return false
	for point: CollectibleLayoutPoint in points:
		if point == null or not point.is_valid(length, lane_count):
			return false
	return true


func is_mode_supported(mode: StringName) -> bool:
	return allowed_movement_modes.has(mode)
