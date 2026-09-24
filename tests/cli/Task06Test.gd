extends Node

const TRACK_GENERATOR_SCENE := preload("res://gameplay/track/TrackGenerator.tscn")
const RUN_CAPABILITIES := preload("res://data/track/run_capabilities.tres")
const GRAYBOX_SEGMENT := preload("res://data/segments/graybox_straight.tres")
const SAFE_RECOVERY_PATTERN := preload("res://data/patterns/safe_recovery.tres")
const HURDLE_PATTERN := preload("res://data/patterns/hurdle_center.tres")
const OVERHEAD_PATTERN := preload("res://data/patterns/overhead_center.tres")
const GAP_DEFINITION := preload("res://data/obstacles/gap.tres")
const OVERHEAD_DEFINITION := preload("res://data/obstacles/overhead.tres")

var _failed := false


func _ready() -> void:
	_run()
	if _failed:
		get_tree().quit(1)
		return
	print("Task 06 segment and pattern generator test passed.")
	get_tree().quit(0)


func _run() -> void:
	var validator := PatternValidator.new()
	_assert(RUN_CAPABILITIES.is_valid_profile(), "RUN capability profile is invalid.")
	_assert(GRAYBOX_SEGMENT.is_valid_definition(), "Graybox segment library is invalid.")
	_assert(validator.validation_window_seconds >= 2.0 and validator.validation_window_seconds <= 3.0, "Validator future window is outside 2-3 seconds.")

	var unsupported := _new_test_pattern(&"unsupported_mode")
	unsupported.allowed_movement_modes = [&"FLY"]
	_assert(not validator.validate_pattern(unsupported, RUN_CAPABILITIES, 10.0, RUN_CAPABILITIES.initial_state_mask()).is_valid, "Unsupported movement-mode pattern was accepted.")

	var speed_limited := _new_test_pattern(&"speed_limited")
	speed_limited.maximum_speed = 9.0
	_assert(not validator.validate_pattern(speed_limited, RUN_CAPABILITIES, 10.0, RUN_CAPABILITIES.initial_state_mask()).is_valid, "Out-of-range speed pattern was accepted.")

	var impossible := _new_test_pattern(&"impossible_jump_and_slide")
	var gap_placement := PatternObstaclePlacement.new()
	gap_placement.obstacle = GAP_DEFINITION
	gap_placement.forward_offset = 24.0
	gap_placement.vertical_state = RunnerStateSpace.Posture.JUMP
	var overhead_placement := PatternObstaclePlacement.new()
	var all_lane_overhead := OVERHEAD_DEFINITION.duplicate(true) as ObstacleDefinition
	all_lane_overhead.occupied_lanes = PackedInt32Array([0, 1, 2])
	overhead_placement.obstacle = all_lane_overhead
	overhead_placement.forward_offset = 24.0
	overhead_placement.lane = -1
	overhead_placement.vertical_state = RunnerStateSpace.Posture.LOW
	impossible.obstacle_placements = [gap_placement, overhead_placement]
	var impossible_result := validator.validate_pattern(impossible, RUN_CAPABILITIES, 16.0, RUN_CAPABILITIES.initial_state_mask())
	_assert(not impossible_result.is_valid and impossible_result.exit_state_mask == 0, "Impossible simultaneous posture requirements retained a legal path.")
	var no_jump_capability := RUN_CAPABILITIES.duplicate(true) as MovementCapabilityProfile
	no_jump_capability.supports_jump = false
	no_jump_capability.supported_postures = 0b101
	var gap_only := _new_test_pattern(&"unsupported_gap_action")
	gap_only.obstacle_placements = [gap_placement]
	_assert(not validator.validate_pattern(gap_only, no_jump_capability, 16.0, no_jump_capability.initial_state_mask()).is_valid, "A full-width gap was accepted without jump capability.")

	var sequence: Array[PatternDefinition] = [HURDLE_PATTERN, OVERHEAD_PATTERN]
	var sequence_result := validator.validate_sequence(sequence, RUN_CAPABILITIES, 16.0, RUN_CAPABILITIES.initial_state_mask())
	_assert(sequence_result.is_valid and sequence_result.exit_state_mask != 0, "Active tail plus compatible candidate lost every survival path.")

	var relaxed_fallback := _new_test_pattern(&"relaxed_fallback")
	relaxed_fallback.safe_fallback = true
	relaxed_fallback.minimum_reaction_time = 1.0
	_assert(not validator.validate_pattern(relaxed_fallback, RUN_CAPABILITIES, 10.0, RUN_CAPABILITIES.initial_state_mask()).is_valid, "Fallback validation relaxed the reaction floor.")
	_assert(SAFE_RECOVERY_PATTERN.minimum_reaction_time >= validator.absolute_minimum_reaction_time, "Authored recovery pattern violates the reaction floor.")

	var generator_a := _new_generator()
	_assert(generator_a.configuration_is_valid(), "Track generator configuration is invalid.")
	generator_a.reset_generator(90210, 0.0, 16.0)
	var peak_active := generator_a.active_segments.size()
	for second: int in 600:
		generator_a.step_simulation(float(second + 1) * 16.0, 16.0)
		_assert(generator_a.active_track_has_no_holes(), "Track developed a hole during the 10-minute soak.")
		for segment: TrackSegment in generator_a.active_segments:
			_assert(segment.legal_exit_state_mask != 0, "Generated segment has no legal exit state.")
		peak_active = maxi(peak_active, generator_a.active_segments.size())
	_assert(peak_active <= generator_a.maximum_expected_active_segments(), "Active segment count exceeded its bounded window.")
	_assert(generator_a.pool.created_segment_count <= generator_a.maximum_expected_active_segments(), "Segment pool grew without a bound.")
	_assert(generator_a.pool.created_obstacle_count <= generator_a.maximum_expected_pooled_obstacles(), "Obstacle pool grew without a per-class window bound.")
	_assert(generator_a.generation_history.size() == 256 and generator_a.current_logical_distance >= 9600.0, "10-minute soak did not retain bounded history for a long-running stream.")
	for expected_pattern: StringName in [&"block_center", &"hurdle_center", &"overhead_center", &"gate_center", &"crosser_timing", &"sweeper_timing", &"gap_jump"]:
		_assert(generator_a.generation_history.has(expected_pattern), "10-minute soak never selected authored pattern %s." % expected_pattern)

	var generator_b := _new_generator()
	generator_b.reset_generator(90210, 0.0, 16.0)
	for second: int in 600:
		generator_b.step_simulation(float(second + 1) * 16.0, 16.0)
	_assert(generator_a.generation_history == generator_b.generation_history, "Equal seeds produced different pattern histories.")

	var fallback_generator := TRACK_GENERATOR_SCENE.instantiate() as TrackGenerator
	fallback_generator.auto_start = false
	var fallback_only_segment := GRAYBOX_SEGMENT.duplicate(true) as SegmentDefinition
	fallback_only_segment.eligible_patterns = [unsupported]
	fallback_generator.segment_definitions = [fallback_only_segment]
	add_child(fallback_generator)
	fallback_generator.reset_generator(7, 0.0, 10.0)
	_assert(fallback_generator.fallback_selection_count > 0 and fallback_generator.active_track_has_no_holes(), "Safe fallback was not used after candidate rejection.")
	_assert(fallback_generator.fallback_pattern.minimum_reaction_time >= fallback_generator.absolute_minimum_reaction_time, "Runtime fallback weakened reaction time.")

	generator_a.queue_free()
	generator_b.queue_free()
	fallback_generator.queue_free()


func _new_generator() -> TrackGenerator:
	var generator := TRACK_GENERATOR_SCENE.instantiate() as TrackGenerator
	generator.auto_start = false
	add_child(generator)
	return generator


func _new_test_pattern(pattern_id: StringName) -> PatternDefinition:
	var pattern := PatternDefinition.new()
	pattern.id = pattern_id
	pattern.length = 30.0
	pattern.maximum_speed = 16.0
	pattern.allowed_movement_modes = [&"RUN"]
	pattern.minimum_reaction_time = 1.5
	pattern.entrance_state_mask = RUN_CAPABILITIES.all_state_mask()
	pattern.exit_state_mask = RUN_CAPABILITIES.all_state_mask()
	return pattern


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr(message)
