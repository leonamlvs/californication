class_name PatternValidationResult
extends RefCounted

var is_valid := false
var reason := ""
var exit_state_mask := 0
var surviving_state_counts: PackedInt32Array = PackedInt32Array()


static func accepted(mask: int, counts: PackedInt32Array = PackedInt32Array()) -> PatternValidationResult:
	var result := PatternValidationResult.new()
	result.is_valid = true
	result.exit_state_mask = mask
	result.surviving_state_counts = counts
	return result


static func rejected(message: String) -> PatternValidationResult:
	var result := PatternValidationResult.new()
	result.reason = message
	return result
