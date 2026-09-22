class_name PatternValidator
extends RefCounted

var absolute_minimum_reaction_time := 1.25
var validation_window_seconds := 2.5


func validate_pattern(pattern: PatternDefinition, capability: MovementCapabilityProfile, speed: float, incoming_state_mask: int) -> PatternValidationResult:
	if pattern == null or capability == null:
		return PatternValidationResult.rejected("Pattern and movement capability are required.")
	if not capability.is_valid_profile() or not pattern.is_valid_definition(capability.lane_count):
		return PatternValidationResult.rejected("Pattern or capability metadata is invalid.")
	if not pattern.allowed_movement_modes.has(capability.movement_mode):
		return PatternValidationResult.rejected("Pattern does not support movement mode %s." % capability.movement_mode)
	if speed < pattern.minimum_speed or speed > pattern.maximum_speed:
		return PatternValidationResult.rejected("Speed %.2f is outside the pattern range." % speed)
	if pattern.minimum_reaction_time < absolute_minimum_reaction_time:
		return PatternValidationResult.rejected("Pattern reaction time is below the absolute minimum.")
	if pattern.safe_fallback and not pattern.obstacle_placements.is_empty():
		return PatternValidationResult.rejected("Safe fallback patterns cannot contain hazards.")

	var states := incoming_state_mask & pattern.entrance_state_mask & capability.all_state_mask()
	if states == 0:
		return PatternValidationResult.rejected("No incoming state satisfies the entrance state set.")

	var placements := pattern.sorted_placements()
	var validation_speed := maxf(speed, pattern.maximum_speed)
	if not placements.is_empty():
		var first := placements[0]
		var required_reaction := maxf(absolute_minimum_reaction_time, maxf(pattern.minimum_reaction_time, first.obstacle.minimum_reaction_time))
		if first.forward_offset / validation_speed + 0.00001 < required_reaction:
			return PatternValidationResult.rejected("First response violates the declared reaction time.")

	var previous_offset := 0.0
	var surviving_counts := PackedInt32Array()
	var placement_index := 0
	while placement_index < placements.size():
		var event_offset := placements[placement_index].forward_offset
		states = capability.expand_reachable(states, (event_offset - previous_offset) / validation_speed)
		var event_safe_mask := capability.all_state_mask()
		while placement_index < placements.size() and is_equal_approx(placements[placement_index].forward_offset, event_offset):
			var placement := placements[placement_index]
			if not placement.obstacle.is_mode_supported(capability.movement_mode):
				return PatternValidationResult.rejected("Obstacle %s does not support movement mode %s." % [placement.obstacle.id, capability.movement_mode])
			event_safe_mask &= _safe_state_mask(placement, capability, event_offset / validation_speed)
			placement_index += 1
		states &= event_safe_mask
		surviving_counts.append(RunnerStateSpace.count_states(states))
		if states == 0:
			return PatternValidationResult.rejected("Obstacle event at %.2f m has no legal survival state." % event_offset)
		previous_offset = event_offset

	states = capability.expand_reachable(states, (pattern.length - previous_offset) / validation_speed)
	states &= pattern.exit_state_mask & capability.all_state_mask()
	if states == 0:
		return PatternValidationResult.rejected("No surviving state satisfies the exit state set.")
	return PatternValidationResult.accepted(states, surviving_counts)


func validate_sequence(patterns: Array[PatternDefinition], capability: MovementCapabilityProfile, speed: float, incoming_state_mask: int) -> PatternValidationResult:
	var states := incoming_state_mask
	var counts := PackedInt32Array()
	for pattern: PatternDefinition in patterns:
		var result := validate_pattern(pattern, capability, speed, states)
		if not result.is_valid:
			return result
		states = result.exit_state_mask
		counts.append_array(result.surviving_state_counts)
	return PatternValidationResult.accepted(states, counts)


func _safe_state_mask(placement: PatternObstaclePlacement, capability: MovementCapabilityProfile, elapsed: float) -> int:
	var occupied := placement.occupied_lanes_at(elapsed)
	var mask := 0
	for posture_value: int in RunnerStateSpace.Posture.size():
		var posture := posture_value as RunnerStateSpace.Posture
		if not capability.supports_posture(posture):
			continue
		for lane: int in capability.lane_count:
			var survives := not occupied.has(lane)
			if not survives:
				match placement.obstacle.obstacle_class:
					ObstacleDefinition.ObstacleClass.HURDLE, ObstacleDefinition.ObstacleClass.GAP:
						survives = posture == placement.vertical_state
					ObstacleDefinition.ObstacleClass.OVERHEAD:
						survives = posture == placement.vertical_state
					_:
						survives = false
			if survives:
				mask |= RunnerStateSpace.state_bit(lane, posture, capability.lane_count)
	return mask
