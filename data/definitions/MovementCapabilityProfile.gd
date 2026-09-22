class_name MovementCapabilityProfile
extends Resource

@export var movement_mode: StringName = &"RUN"
@export_range(1, 5, 1) var lane_count := 3
@export_flags("GROUND", "JUMP", "LOW") var supported_postures := 0b111
@export var supports_lane_change := true
@export var supports_jump := true
@export var supports_low := true
@export_range(0.01, 1.0, 0.01, "suffix:s") var action_response_time := 0.05
@export_range(0.01, 2.0, 0.01, "suffix:s") var lane_change_duration := 0.18
@export_range(0.01, 3.0, 0.01, "suffix:s") var jump_duration := 0.72
@export_range(0.01, 3.0, 0.01, "suffix:s") var low_duration := 0.65


func is_valid_profile() -> bool:
	return not movement_mode.is_empty() and lane_count > 0 and supported_postures != 0 and action_response_time > 0.0 and lane_change_duration > 0.0 and jump_duration > 0.0 and low_duration > 0.0


func supports_posture(posture: RunnerStateSpace.Posture) -> bool:
	if posture == RunnerStateSpace.Posture.JUMP and not supports_jump:
		return false
	if posture == RunnerStateSpace.Posture.LOW and not supports_low:
		return false
	return (supported_postures & (1 << int(posture))) != 0


func all_state_mask() -> int:
	var mask := 0
	for posture_value: int in RunnerStateSpace.Posture.size():
		var posture := posture_value as RunnerStateSpace.Posture
		if supports_posture(posture):
			mask |= RunnerStateSpace.all_lanes_for_posture(posture, lane_count)
	return mask


func initial_state_mask() -> int:
	return RunnerStateSpace.state_bit(lane_count / 2, RunnerStateSpace.Posture.GROUND, lane_count) & all_state_mask()


func expand_reachable(source_mask: int, elapsed: float) -> int:
	if source_mask == 0:
		return 0
	var result := 0
	var maximum_lane_steps := lane_count - 1 if supports_lane_change else 0
	if supports_lane_change:
		maximum_lane_steps = mini(maximum_lane_steps, floori(maxf(elapsed, 0.0) / lane_change_duration))
	for source_index: int in lane_count * RunnerStateSpace.Posture.size():
		if (source_mask & (1 << source_index)) == 0:
			continue
		var source_lane := RunnerStateSpace.lane_from_index(source_index, lane_count)
		var source_posture := RunnerStateSpace.posture_from_index(source_index, lane_count)
		for target_posture_value: int in RunnerStateSpace.Posture.size():
			var target_posture := target_posture_value as RunnerStateSpace.Posture
			if not supports_posture(target_posture) or not _posture_reachable(source_posture, target_posture, elapsed):
				continue
			for target_lane: int in lane_count:
				if abs(target_lane - source_lane) <= maximum_lane_steps:
					result |= RunnerStateSpace.state_bit(target_lane, target_posture, lane_count)
	return result


func _posture_reachable(source: RunnerStateSpace.Posture, target: RunnerStateSpace.Posture, elapsed: float) -> bool:
	if source == target:
		return true
	if target == RunnerStateSpace.Posture.GROUND:
		return true
	if source == RunnerStateSpace.Posture.GROUND:
		return elapsed >= action_response_time
	if source == RunnerStateSpace.Posture.JUMP and target == RunnerStateSpace.Posture.LOW:
		return elapsed >= jump_duration
	if source == RunnerStateSpace.Posture.LOW and target == RunnerStateSpace.Posture.JUMP:
		return elapsed >= low_duration
	return false
