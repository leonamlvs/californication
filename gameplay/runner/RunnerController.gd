class_name RunnerController
extends CharacterBody3D

signal lane_changed(lane_index: int)
signal vertical_state_changed(is_jumping: bool, is_sliding: bool)
signal movement_mode_changed(mode: StringName)
signal obstacle_hit_received(event: ObstacleHitEvent)
signal obstacle_failure_requested(event: ObstacleHitEvent)

const MODE_RUN: StringName = &"RUN"
const MODE_SNOWBOARD: StringName = &"SNOWBOARD"
const MODE_SWIM: StringName = &"SWIM"
const MODE_CAR: StringName = &"CAR"
const MODE_FLY: StringName = &"FLY"
const CAR_MOVEMENT_MODE := preload("res://gameplay/runner/CarMovementMode.gd")
const FLY_MOVEMENT_MODE := preload("res://gameplay/runner/FlyMovementMode.gd")

enum SwimDepthPhase { NEUTRAL, OUTBOUND, HOLD, RETURN }

@export var movement_profile: MovementProfile
@export var development_simulation_enabled := false

@onready var collision_shape: CollisionShape3D = %CollisionShape
@onready var cosmetic_mount: Node3D = %CosmeticMount
@onready var placeholder_body: MeshInstance3D = %PlaceholderBody
@onready var car_cosmetic: Node3D = %CarCosmetic

var logical_forward_distance := 0.0
var current_speed := 0.0
var current_lane_index := 1
var target_lane_index := 1
var is_jumping := false
var is_sliding := false
var is_invulnerable := false
var movement_suspended := false
var current_movement_mode: StringName = &""
var swim_depth_state: RunnerStateSpace.Posture = RunnerStateSpace.Posture.GROUND

var _active_mode: MovementMode
var _lane_from_x := 0.0
var _lane_elapsed := 0.0
var _jump_elapsed := 0.0
var _slide_remaining := 0.0
var _swim_depth_phase: SwimDepthPhase = SwimDepthPhase.NEUTRAL
var _swim_depth_elapsed := 0.0
var _swim_depth_hold_remaining := 0.0
var _swim_depth_from_y := 0.0
var _swim_depth_target_y := 0.0


func _ready() -> void:
	if movement_profile == null:
		push_error("RunnerController requires a MovementProfile resource.")
		return
	set_movement_mode(movement_profile.movement_mode)
	reset_for_run()
	InputRouter.intent_requested.connect(_on_intent_requested)


func _exit_tree() -> void:
	if InputRouter.intent_requested.is_connected(_on_intent_requested):
		InputRouter.intent_requested.disconnect(_on_intent_requested)


func _physics_process(delta: float) -> void:
	if not movement_suspended and (development_simulation_enabled or GameFlow.gameplay_input_enabled):
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
	if movement_profile == null or movement_profile.movement_mode != mode:
		return false
	if _active_mode != null:
		_active_mode.exit(self)
	match mode:
		MODE_RUN:
			_active_mode = RunMovementMode.new()
		MODE_SNOWBOARD:
			_active_mode = SnowboardMovementMode.new()
		MODE_SWIM:
			_active_mode = SwimMovementMode.new()
		MODE_CAR:
			_active_mode = CAR_MOVEMENT_MODE.new()
		MODE_FLY:
			_active_mode = FLY_MOVEMENT_MODE.new()
		_:
			return false
	_active_mode.enter(self, movement_profile)
	current_movement_mode = mode
	placeholder_body.visible = mode != MODE_CAR
	car_cosmetic.visible = mode == MODE_CAR
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
	_swim_depth_phase = SwimDepthPhase.NEUTRAL
	_swim_depth_elapsed = 0.0
	_swim_depth_hold_remaining = 0.0
	_swim_depth_from_y = 0.0
	_swim_depth_target_y = 0.0
	swim_depth_state = RunnerStateSpace.Posture.GROUND
	is_jumping = false
	is_sliding = false
	movement_suspended = false
	position = Vector3(_lane_from_x, 0.0, 0.0)
	_set_collider_height(movement_profile.standing_height)
	cosmetic_mount.position.y = movement_profile.standing_height * 0.5
	cosmetic_mount.scale = Vector3.ONE


func set_invulnerable(enabled: bool) -> void:
	is_invulnerable = enabled


func set_movement_suspended(suspended: bool) -> void:
	movement_suspended = suspended
	velocity = Vector3.ZERO


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
	if movement_profile == null or _active_mode == null or movement_suspended or delta <= 0.0:
		return
	_active_mode.physics_step(self, delta)


func _on_intent_requested(intent: StringName) -> void:
	if GameFlow.gameplay_input_enabled:
		_handle_intent(intent)


func _handle_intent(intent: StringName) -> bool:
	return not movement_suspended and _active_mode != null and _active_mode.handle_intent(self, intent)


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


func _begin_swim_depth(next_state: RunnerStateSpace.Posture) -> bool:
	if next_state != RunnerStateSpace.Posture.RISE and next_state != RunnerStateSpace.Posture.DIVE:
		return false
	if swim_depth_state == next_state and _swim_depth_phase != SwimDepthPhase.RETURN:
		return false
	swim_depth_state = next_state
	_swim_depth_phase = SwimDepthPhase.OUTBOUND
	_swim_depth_elapsed = 0.0
	_swim_depth_hold_remaining = movement_profile.vertical_hold_duration
	_swim_depth_from_y = position.y
	_swim_depth_target_y = movement_profile.vertical_rise_offset if next_state == RunnerStateSpace.Posture.RISE else -movement_profile.vertical_dive_offset
	return true


func _advance_swim_state(delta: float) -> void:
	logical_forward_distance += current_speed * delta
	_advance_lane(delta)
	_advance_swim_depth(delta)


func _advance_swim_depth(delta: float) -> void:
	var remaining := delta
	while remaining > 0.0 and _swim_depth_phase != SwimDepthPhase.NEUTRAL:
		match _swim_depth_phase:
			SwimDepthPhase.OUTBOUND:
				var outbound_remaining := movement_profile.vertical_action_duration - _swim_depth_elapsed
				var outbound_step := minf(remaining, outbound_remaining)
				_swim_depth_elapsed += outbound_step
				remaining -= outbound_step
				position.y = lerpf(_swim_depth_from_y, _swim_depth_target_y, _swim_depth_elapsed / movement_profile.vertical_action_duration)
				if is_equal_approx(_swim_depth_elapsed, movement_profile.vertical_action_duration):
					_swim_depth_phase = SwimDepthPhase.HOLD
			SwimDepthPhase.HOLD:
				var hold_step := minf(remaining, _swim_depth_hold_remaining)
				_swim_depth_hold_remaining -= hold_step
				remaining -= hold_step
				if _swim_depth_hold_remaining <= 0.0:
					_swim_depth_phase = SwimDepthPhase.RETURN
					_swim_depth_elapsed = 0.0
					_swim_depth_from_y = position.y
			SwimDepthPhase.RETURN:
				var return_remaining := movement_profile.vertical_neutral_return_duration - _swim_depth_elapsed
				var return_step := minf(remaining, return_remaining)
				_swim_depth_elapsed += return_step
				remaining -= return_step
				position.y = lerpf(_swim_depth_from_y, 0.0, _swim_depth_elapsed / movement_profile.vertical_neutral_return_duration)
				if is_equal_approx(_swim_depth_elapsed, movement_profile.vertical_neutral_return_duration):
					position.y = 0.0
					swim_depth_state = RunnerStateSpace.Posture.GROUND
					_swim_depth_phase = SwimDepthPhase.NEUTRAL


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
