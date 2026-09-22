class_name TrackGenerator
extends Node3D

signal segment_spawned(segment: TrackSegment)
signal segment_recycled(pattern_id: StringName)
signal candidate_rejected(pattern_id: StringName, reason: String)

@export var segment_definitions: Array[SegmentDefinition] = []
@export var capability_profile: MovementCapabilityProfile
@export var obstacle_library: ObstacleSceneLibrary
@export var fallback_pattern: PatternDefinition
@export_range(30.0, 250.0, 1.0, "suffix:m") var ahead_distance := 90.0
@export_range(0.0, 50.0, 1.0, "suffix:m") var behind_distance := 15.0
@export_range(2.0, 3.0, 0.1, "suffix:s") var validation_window_seconds := 2.5
@export_range(1.25, 3.0, 0.05, "suffix:s") var absolute_minimum_reaction_time := 1.25
@export var deterministic_seed := 24680
@export var randomize_runtime_seed := true
@export var auto_start := true

@onready var segment_root: Node3D = %Segments
@onready var obstacle_root: Node3D = %Obstacles
@onready var inactive_root: Node3D = %Pooled
@onready var pool: TrackPool = %TrackPool

var active_segments: Array[TrackSegment] = []
var generation_history: Array[StringName] = []
var rejected_candidate_count := 0
var fallback_selection_count := 0
var current_logical_distance := 0.0
var current_speed := 10.0
var tail_legal_state_mask := 0

var _runner: RunnerController
var _cursor_distance := 0.0
var _rng := RandomNumberGenerator.new()
var _validator := PatternValidator.new()


func _ready() -> void:
	pool.configure(obstacle_library, segment_root, obstacle_root, inactive_root)
	_validator.absolute_minimum_reaction_time = absolute_minimum_reaction_time
	_validator.validation_window_seconds = validation_window_seconds
	if auto_start and configuration_is_valid():
		reset_generator(randi() if randomize_runtime_seed else deterministic_seed)


func _physics_process(delta: float) -> void:
	if _runner != null and (GameFlow.gameplay_input_enabled or _runner.development_simulation_enabled):
		step_simulation(_runner.logical_forward_distance, _runner.current_speed, delta)


func configuration_is_valid() -> bool:
	if capability_profile == null or not capability_profile.is_valid_profile() or obstacle_library == null or not obstacle_library.is_valid_library():
		return false
	if fallback_pattern == null or not fallback_pattern.safe_fallback:
		return false
	var fallback_result := _validator.validate_pattern(fallback_pattern, capability_profile, maxf(capability_profile.lane_change_duration, 10.0), capability_profile.initial_state_mask())
	if not fallback_result.is_valid or fallback_pattern.minimum_reaction_time < absolute_minimum_reaction_time:
		return false
	for segment_definition: SegmentDefinition in segment_definitions:
		if segment_definition == null or not segment_definition.is_valid_definition():
			return false
	return not segment_definitions.is_empty()


func set_runner(runner: RunnerController) -> void:
	_runner = runner


func reset_generator(seed_value: int = deterministic_seed, start_distance: float = 0.0, speed: float = 10.0, initial_state_mask: int = 0) -> void:
	for segment: TrackSegment in active_segments.duplicate():
		pool.release_segment(segment)
	active_segments.clear()
	generation_history.clear()
	rejected_candidate_count = 0
	fallback_selection_count = 0
	current_logical_distance = start_distance
	current_speed = speed
	_cursor_distance = start_distance
	tail_legal_state_mask = initial_state_mask if initial_state_mask != 0 else capability_profile.initial_state_mask()
	_rng.seed = seed_value
	_fill_ahead()


func step_simulation(logical_distance: float, speed: float, delta: float = 0.0) -> void:
	current_logical_distance = maxf(logical_distance, current_logical_distance)
	current_speed = maxf(speed, 0.01)
	for segment: TrackSegment in active_segments:
		segment.update_visual(current_logical_distance)
		if _runner != null:
			for obstacle: ObstacleBase in segment.active_obstacles:
				obstacle.step_simulation(_runner, delta)
	_recycle_passed()
	_fill_ahead()


func active_track_has_no_holes() -> bool:
	for index: int in range(1, active_segments.size()):
		if not is_equal_approx(active_segments[index - 1].end_distance, active_segments[index].start_distance):
			return false
	return not active_segments.is_empty()


func maximum_expected_active_segments() -> int:
	var minimum_length := INF
	for definition: SegmentDefinition in segment_definitions:
		minimum_length = minf(minimum_length, definition.length)
	return ceili((ahead_distance + behind_distance) / minimum_length) + 2


func maximum_expected_pooled_obstacles() -> int:
	var maximum_per_id: Dictionary = {}
	for segment_definition: SegmentDefinition in segment_definitions:
		for pattern: PatternDefinition in segment_definition.eligible_patterns:
			var count_per_id: Dictionary = {}
			for placement: PatternObstaclePlacement in pattern.obstacle_placements:
				var obstacle_id: StringName = placement.obstacle.id
				count_per_id[obstacle_id] = int(count_per_id.get(obstacle_id, 0)) + 1
			for obstacle_id: StringName in count_per_id:
				maximum_per_id[obstacle_id] = maxi(int(maximum_per_id.get(obstacle_id, 0)), int(count_per_id[obstacle_id]))
	var per_window_total := 0
	for count: int in maximum_per_id.values():
		per_window_total += count
	return maximum_expected_active_segments() * per_window_total


func validate_active_tail_with(candidate: PatternDefinition) -> PatternValidationResult:
	return _validator.validate_pattern(candidate, capability_profile, current_speed, tail_legal_state_mask)


func _fill_ahead() -> void:
	while _cursor_distance < current_logical_distance + ahead_distance:
		if not _append_next_segment():
			push_error("TrackGenerator could not append a validated segment.")
			return


func _append_next_segment() -> bool:
	var candidates: Array[Dictionary] = []
	for segment_definition: SegmentDefinition in segment_definitions:
		if not segment_definition.compatible_modes.has(capability_profile.movement_mode):
			continue
		for pattern: PatternDefinition in segment_definition.eligible_patterns:
			var result := _validator.validate_pattern(pattern, capability_profile, current_speed, tail_legal_state_mask)
			if result.is_valid:
				candidates.append({"segment": segment_definition, "pattern": pattern, "result": result, "weight": pattern.weight})
			else:
				rejected_candidate_count += 1
				candidate_rejected.emit(pattern.id, result.reason)

	var selected: Dictionary
	if candidates.is_empty():
		var fallback_segment := _segment_for_length(fallback_pattern.length)
		var fallback_result := _validator.validate_pattern(fallback_pattern, capability_profile, current_speed, tail_legal_state_mask)
		if fallback_segment == null or not fallback_result.is_valid:
			return false
		selected = {"segment": fallback_segment, "pattern": fallback_pattern, "result": fallback_result, "weight": 1.0}
		fallback_selection_count += 1
	else:
		selected = _weighted_choice(candidates)

	var segment_definition: SegmentDefinition = selected.segment
	var pattern: PatternDefinition = selected.pattern
	var result: PatternValidationResult = selected.result
	var segment := pool.acquire_segment(segment_definition.scene)
	segment.configure(segment_definition, pattern, _cursor_distance, result.exit_state_mask)
	segment.update_visual(current_logical_distance)
	for placement: PatternObstaclePlacement in pattern.obstacle_placements:
		var obstacle := pool.acquire_obstacle(placement.obstacle)
		if obstacle == null:
			pool.release_segment(segment)
			return false
		obstacle.rotation_degrees = placement.rotation_degrees
		obstacle.reset_for_spawn(_cursor_distance + placement.forward_offset, placement.lane, _cursor_distance)
		segment.active_obstacles.append(obstacle)
	active_segments.append(segment)
	generation_history.append(pattern.id)
	tail_legal_state_mask = result.exit_state_mask
	_cursor_distance = segment.end_distance
	segment_spawned.emit(segment)
	return true


func _weighted_choice(candidates: Array[Dictionary]) -> Dictionary:
	var total_weight := 0.0
	for candidate: Dictionary in candidates:
		total_weight += float(candidate.weight)
	var roll := _rng.randf_range(0.0, total_weight)
	for candidate: Dictionary in candidates:
		roll -= float(candidate.weight)
		if roll <= 0.0:
			return candidate
	return candidates.back()


func _segment_for_length(length: float) -> SegmentDefinition:
	for definition: SegmentDefinition in segment_definitions:
		if definition.compatible_modes.has(capability_profile.movement_mode) and is_equal_approx(definition.length, length):
			return definition
	return null


func _recycle_passed() -> void:
	while not active_segments.is_empty() and active_segments[0].end_distance < current_logical_distance - behind_distance:
		var segment: TrackSegment = active_segments.pop_front()
		var pattern_id: StringName = segment.pattern.id
		pool.release_segment(segment)
		segment_recycled.emit(pattern_id)
