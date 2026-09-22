class_name SegmentDefinition
extends Resource

@export var id: StringName
@export_range(1.0, 200.0, 0.5, "suffix:m") var length := 30.0
@export var connection_start := Vector3.ZERO
@export var connection_end := Vector3(0.0, 0.0, -30.0)
@export var compatible_modes: Array[StringName] = [&"RUN"]
@export var environment_tags: Array[StringName] = [&"graybox"]
@export var scene: PackedScene
@export var eligible_patterns: Array[PatternDefinition] = []


func is_valid_definition() -> bool:
	if id.is_empty() or length <= 0.0 or compatible_modes.is_empty() or scene == null or eligible_patterns.is_empty():
		return false
	if not is_equal_approx(connection_end.z - connection_start.z, -length):
		return false
	for pattern: PatternDefinition in eligible_patterns:
		if pattern == null or not pattern.is_valid_definition() or not is_equal_approx(pattern.length, length):
			return false
	return true
