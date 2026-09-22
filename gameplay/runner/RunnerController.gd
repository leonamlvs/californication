class_name RunnerController
extends CharacterBody3D

signal lane_changed(lane_index: int)
signal vertical_state_changed(is_jumping: bool, is_sliding: bool)
signal movement_mode_changed(mode: StringName)
signal obstacle_hit_received(event: ObstacleHitEvent)
signal obstacle_failure_requested(event: ObstacleHitEvent)

const MODE_RUN: StringName = &"RUN"

@export var movement_profile: MovementProfile
@export var development_simulation_enabled := false

@onready var collision_shape: CollisionShape3D = %CollisionShape
@onready var cosmetic_mount: Node3D = %CosmeticMount

var logical_forward_distance := 0.0
var current_speed := 0.0
var current_lane_index := 1
var target_lane_index := 1
var is_jumping := false
var is_sliding := false
var is_invulnerable := false
var current_movement_mode: StringName = &""

var _active_mode: MovementMode
var _lane_from_x := 0.0
var _lane_elapsed := 0.0
var _jump_elapsed := 0.0
var _slide_remaining := 0.0


func _ready() -> void:
	if movement_profile == null:
		push_error("RunnerController requires a MovementProfile resource.")
		return
	set_movement_mode(MODE_RUN)
	reset_for_run()
	InputRouter.intent_requested.connect(_on_intent_requested)


func _exit_tree() -> void:
	if InputRouter.intent_requested.is_connected(_on_intent_requested):
		InputRouter.intent_requested.disconnect(_on_intent_requested)


func _physics_process(delta: float) -> void:
	if development_simulation_enabled or GameFlow.gameplay_input_enabled:
		step_simulation(delta)


func request_left() -> bool:
	return _handle_intent(InputRouter.INTENT_LEFT)


func request_right() -> bool:
	return _handle_intent(InputRouter.INTENT_RIGHT)


func request_up() -> bool:
	return _handle_intent(InputRouter.INTENT_UP)


func request_down() -> bool:
	return _handle_intent(InputRouter.INTENT_DOWN)


func set_movement_mode(mode: StringName) -> bool:
	if movement_profile == null or mode != MODE_RUN or movement_profile.movement_mode != mode:
		return false
	if _active_mode != null:
		_active_mode.exit(self)
	_active_mode = RunMovementMode.new()
	_active_mode.enter(self, movement_profile)
	current_movement_mode = mode
	movement_mode_changed.emit(mode)
	return true


func reset_for_run() -> void:
	if movement_profile == null:
		return
	logical_forward_distance = 0.0
	current_speed = movement_profile.base_speed
	current_lane_index = movement_profile.lane_count / 2
	target_lane_index = current_lane_index
	_lane_from_x = _lane_x(current_lane_index)
	_lane_elapsed = movement_profile.lane_change_duration
	_jump_elapsed = 0.0
	_slide_remaining = 0.0
	is_jumping = false
	is_sliding = false
	position = Vector3(_lane_from_x, 0.0, 0.0)
	_set_collider_height(movement_profile.standing_height)
	cosmetic_mount.position.y = movement_profile.standing_height * 0.5
	cosmetic_mount.scale = Vector3.ONE


func set_invulnerable(enabled: bool) -> void:
	is_invulnerable = enabled


## Obstacles report typed data events here; GameFlow remains the only global
## state authority. A non-invulnerable hit always emits a failure request,
## even when a standalone harness has no active RUNNING state.
func request_obstacle_hit(event: ObstacleHitEvent) -> bool:
	if event == null:
		return false
	obstacle_hit_received.emit(event)
	if is_invulnerable:
		event.was_suppressed = true
		return false
	obstacle_failure_requested.emit(event)
	return GameFlow.fail_run()


## Deterministic stepping path for CLI tests and the development runner harness.
func step_simulation(delta: float) -> void:
	if movement_profile == null or _active_mode == null or delta <= 0.0:
		return
	_active_mode.physics_step(self, delta)


func _on_intent_requested(intent: StringName) -> void:
	if GameFlow.gameplay_input_enabled:
		_handle_intent(intent)


func _handle_intent(intent: StringName) -> bool:
	return _active_mode != null and _active_mode.handle_intent(self, intent)


func _request_lane_delta(delta: int) -> bool:
	var next_target := clampi(target_lane_index + delta, 0, movement_profile.lane_count - 1)
	if next_target == target_lane_index:
		return false
	_lane_from_x = position.x
	target_lane_index = next_target
	_lane_elapsed = 0.0
	return true


func _begin_jump() -> bool:
	if is_jumping or is_sliding:
		return false
	is_jumping = true
	_jump_elapsed = 0.0
	vertical_state_changed.emit(true, false)
	return true


func _begin_slide() -> bool:
	if is_jumping or is_sliding:
		return false
	is_sliding = true
	_slide_remaining = movement_profile.slide_duration
	_set_collider_height(movement_profile.sliding_height)
	cosmetic_mount.position.y = movement_profile.sliding_height * 0.5
	cosmetic_mount.scale.y = movement_profile.sliding_height / movement_profile.standing_height
	vertical_state_changed.emit(false, true)
	return true


func _advance_run_state(delta: float) -> void:
	logical_forward_distance += current_speed * delta
	_advance_lane(delta)
	_advance_jump(delta)
	_advance_slide(delta)


func _advance_lane(delta: float) -> void:
	if _lane_elapsed >= movement_profile.lane_change_duration:
		return
	_lane_elapsed = minf(_lane_elapsed + delta, movement_profile.lane_change_duration)
	var progress := _lane_elapsed / movement_profile.lane_change_duration
	position.x = lerpf(_lane_from_x, _lane_x(target_lane_index), progress)
	if is_equal_approx(progress, 1.0):
		current_lane_index = target_lane_index
		lane_changed.emit(current_lane_index)


func _advance_jump(delta: float) -> void:
	if not is_jumping:
		return
	_jump_elapsed = minf(_jump_elapsed + delta, movement_profile.jump_duration)
	var progress := _jump_elapsed / movement_profile.jump_duration
	position.y = 4.0 * movement_profile.jump_height * progress * (1.0 - progress)
	if is_equal_approx(progress, 1.0):
		position.y = 0.0
		is_jumping = false
		vertical_state_changed.emit(false, false)


func _advance_slide(delta: float) -> void:
	if not is_sliding:
		return
	_slide_remaining = maxf(0.0, _slide_remaining - delta)
	if _slide_remaining <= 0.0:
		is_sliding = false
		_set_collider_height(movement_profile.standing_height)
		cosmetic_mount.position.y = movement_profile.standing_height * 0.5
		cosmetic_mount.scale = Vector3.ONE
		vertical_state_changed.emit(false, false)


func _lane_x(lane_index: int) -> float:
	return (float(lane_index) - float(movement_profile.lane_count - 1) * 0.5) * movement_profile.lane_spacing


func _set_collider_height(height: float) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.radius = movement_profile.capsule_radius
	capsule.height = maxf(height, movement_profile.capsule_radius * 2.0)
	collision_shape.position.y = capsule.height * 0.5
