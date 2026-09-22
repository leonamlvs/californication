class_name PatternDefinition
extends Resource

@export var id: StringName
@export_range(1.0, 200.0, 0.5, "suffix:m") var length := 30.0
@export_range(0, 10, 1) var difficulty := 0
@export_range(0.01, 100.0, 0.01) var weight := 1.0
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var minimum_speed := 0.0
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var maximum_speed := 16.0
@export var allowed_movement_modes: Array[StringName] = [&"RUN"]
@export_range(0.0, 5.0, 0.05, "suffix:s") var minimum_reaction_time := 1.5
@export var entrance_state_mask := 0
@export var exit_state_mask := 0
@export var safe_fallback := false
@export var obstacle_placements: Array[PatternObstaclePlacement] = []


func is_valid_definition(lane_count: int = 3) -> bool:
	if id.is_empty() or length <= 0.0 or weight <= 0.0 or maximum_speed < minimum_speed or allowed_movement_modes.is_empty():
		return false
	if entrance_state_mask == 0 or exit_state_mask == 0:
		return false
	for placement: PatternObstaclePlacement in obstacle_placements:
		if placement == null or not placement.is_valid_placement(length, lane_count):
			return false
	return true


func sorted_placements() -> Array[PatternObstaclePlacement]:
	var sorted := obstacle_placements.duplicate()
	sorted.sort_custom(func(a: PatternObstaclePlacement, b: PatternObstaclePlacement) -> bool: return a.forward_offset < b.forward_offset)
	return sorted
