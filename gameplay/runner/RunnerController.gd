class_name RunnerController
extends CharacterBody3D

signal lane_changed(lane_index: int)
signal lane_started(lane_index: int)
signal action_started(action: StringName)
signal action_completed(action: StringName)
signal pickup_response
signal failure_impact
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
var _character_cosmetic_active := false
var run_elapsed := 0.0
var _queued_lane := 0
var _buffered_action: StringName = &""
var _buffer_remaining := 0.0
var _landing := 0.0
var _trail: Array[MeshInstance3D] = []
var _snowboard: MeshInstance3D

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
	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.05
	trail_mesh.height = 0.1
	trail_mesh.radial_segments = 6
	trail_mesh.rings = 3
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.albedo_color = Color(0.45, 0.87, 1.0)
	for index: int in range(5):
		var particle := MeshInstance3D.new()
		particle.mesh = trail_mesh
		particle.material_override = trail_material
		particle.visible = false
		add_child(particle)
		_trail.append(particle)
	_snowboard = _presentation_box(Vector3(0.48, 0.08, 1.85), Vector3(0, -0.79, 0), Color(0.12, 0.55, 0.7), cosmetic_mount)
	_snowboard.visible = current_movement_mode == MODE_SNOWBOARD
	_presentation_box(Vector3(1.02, 0.3, 0.72), Vector3(0, 0.34, -0.15), Color(0.1, 0.24, 0.32), car_cosmetic)
	for side: float in [-0.66, 0.66]:
		for axle: float in [-0.68, 0.68]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.19
			mesh.bottom_radius = 0.19
			mesh.height = 0.16
			wheel.mesh = mesh
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(side, -0.17, axle)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.055, 0.065, 0.08)
			wheel.material_override = material
			car_cosmetic.add_child(wheel)


func _presentation_box(size: Vector3, center: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = center
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	parent.add_child(visual)
	return visual


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
	placeholder_body.visible = mode != MODE_CAR and not _character_cosmetic_active
	car_cosmetic.visible = mode == MODE_CAR
	if _snowboard != null:
		_snowboard.visible = mode == MODE_SNOWBOARD
	movement_mode_changed.emit(mode)
	return true


func reset_for_run() -> void:
	if movement_profile == null:
		return
	logical_forward_distance = 0.0
	run_elapsed = 0.0
	_queued_lane = 0
	_buffered_action = &""
	_buffer_remaining = 0.0
	_landing = 0.0
	rotation = Vector3.ZERO
	scale = Vector3.ONE
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
	cosmetic_mount.rotation = Vector3.ZERO


func set_invulnerable(enabled: bool) -> void:
	is_invulnerable = enabled


func set_movement_suspended(suspended: bool) -> void:
	movement_suspended = suspended
	velocity = Vector3.ZERO


func set_character_cosmetic_active(active: bool) -> void:
	_character_cosmetic_active = active
	placeholder_body.visible = not active and current_movement_mode != MODE_CAR


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
	failure_impact.emit()
	if GameFlow.current_state == GameFlow.FAILURE_TRANSITION:
		return true
	return GameFlow.fail_run()


## Deterministic stepping path for CLI tests and the development runner harness.
func step_simulation(delta: float) -> void:
	if movement_profile == null or _active_mode == null or movement_suspended or delta <= 0.0:
		return
	# Midpoint speed integrates the linear ramp consistently at 30/60/120 Hz.
	current_speed = speed_at(run_elapsed + delta * 0.5)
	_buffer_remaining = maxf(0.0, _buffer_remaining - delta)
	_active_mode.physics_step(self, delta)
	run_elapsed += delta
	current_speed = speed_at(run_elapsed)
	if _buffer_remaining > 0.0:
		if _active_mode.handle_intent(self, _buffered_action):
			_buffer_remaining = 0.0
	_update_presentation(delta)


func speed_at(seconds: float) -> float:
	return lerpf(movement_profile.base_speed, movement_profile.max_speed, clampf(seconds / movement_profile.speed_ramp_duration, 0.0, 1.0))


func adopt_profile(profile: MovementProfile) -> void:
	var elapsed := run_elapsed
	var distance := logical_forward_distance
	movement_profile = profile
	set_movement_mode(profile.movement_mode)
	reset_for_run()
	run_elapsed = elapsed
	logical_forward_distance = distance
	current_speed = speed_at(elapsed)


func _update_presentation(delta: float) -> void:
	_landing = maxf(0.0, _landing - delta * 5.0)
	var bank := clampf((_lane_x(target_lane_index) - position.x) / movement_profile.lane_spacing, -1.0, 1.0)
	var airborne := current_movement_mode in [MODE_SWIM, MODE_FLY]
	var bob := sin(logical_forward_distance * 3.3) * movement_profile.presentation_bob if not is_jumping and not is_sliding and not airborne else 0.0
	var height := movement_profile.sliding_height if is_sliding else movement_profile.standing_height
	cosmetic_mount.position.y = height * 0.5 + bob - _landing * 0.08
	var pitch := -movement_profile.presentation_lean - (position.y * 9.0 if airborne else 0.0)
	cosmetic_mount.rotation_degrees = cosmetic_mount.rotation_degrees.lerp(Vector3(pitch, -bank * 8.0, -bank * 12.0), 1.0 - exp(-16.0 * delta))
	var stretch := 1.06 if is_jumping else 1.0 - _landing * 0.16
	cosmetic_mount.scale = Vector3(1.0 + _landing * 0.1, height / movement_profile.standing_height * stretch, 1.0)
	for index: int in range(_trail.size()):
		_trail[index].visible = airborne and absf(position.y) > 0.05
		_trail[index].position = Vector3(sin(run_elapsed * 8.0 + index) * 0.12, 0.65 - position.y * float(index) * 0.1, 0.5 + float(index) * 0.28)
	for child: Node3D in cosmetic_mount.get_children():
		if child is CharacterVisual:
			child.scale = Vector3.ONE * (0.55 if current_movement_mode == MODE_CAR else 1.0)
			child.position.y = -0.2 if current_movement_mode == MODE_CAR else 0.0


func _on_intent_requested(intent: StringName) -> void:
	if GameFlow.gameplay_input_enabled:
		_handle_intent(intent)


func _handle_intent(intent: StringName) -> bool:
	if movement_suspended or _active_mode == null:
		return false
	if _active_mode.handle_intent(self, intent):
		if intent in [InputRouter.INTENT_UP, InputRouter.INTENT_DOWN]:
			_buffer_remaining = 0.0
		return true
	if intent in [InputRouter.INTENT_UP, InputRouter.INTENT_DOWN]:
		_buffered_action = intent
		_buffer_remaining = movement_profile.action_buffer_duration
	return false


func _request_lane_delta(delta: int) -> bool:
	if _lane_elapsed < movement_profile.lane_change_duration:
		var direction := signi(target_lane_index - current_lane_index)
		if direction == delta:
			_queued_lane = delta if target_lane_index + delta in range(movement_profile.lane_count) else 0
			return _queued_lane != 0
		# Reverse toward the lane we departed, never an intermediate position.
		_queued_lane = 0
		var old_target := target_lane_index
		target_lane_index = current_lane_index
		current_lane_index = old_target
		_lane_from_x = position.x
		_lane_elapsed = 0.0
		lane_started.emit(target_lane_index)
		return true
	var next_target := clampi(target_lane_index + delta, 0, movement_profile.lane_count - 1)
	if next_target == target_lane_index:
		return false
	_lane_from_x = position.x
	target_lane_index = next_target
	_lane_elapsed = 0.0
	lane_started.emit(target_lane_index)
	return true


func _begin_jump() -> bool:
	if is_jumping or is_sliding:
		return false
	is_jumping = true
	_jump_elapsed = 0.0
	vertical_state_changed.emit(true, false)
	action_started.emit(&"jump")
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
	action_started.emit(&"slide")
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
	action_started.emit(&"rise" if next_state == RunnerStateSpace.Posture.RISE else &"dive")
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
					action_completed.emit(&"depth")


func _advance_lane(delta: float) -> void:
	var remaining := delta
	while remaining > 0.000001 and _lane_elapsed < movement_profile.lane_change_duration:
		var step := minf(remaining, movement_profile.lane_change_duration - _lane_elapsed)
		_lane_elapsed += step
		remaining -= step
		var progress := _lane_elapsed / movement_profile.lane_change_duration
		position.x = lerpf(_lane_from_x, _lane_x(target_lane_index), smoothstep(0.0, 1.0, progress))
		if progress >= 0.99999:
			_lane_elapsed = movement_profile.lane_change_duration
			current_lane_index = target_lane_index
			lane_changed.emit(current_lane_index)
			if _queued_lane != 0:
				var queued := _queued_lane
				_queued_lane = 0
				_request_lane_delta(queued)


func _advance_jump(delta: float) -> void:
	if not is_jumping:
		return
	_jump_elapsed = minf(_jump_elapsed + delta, movement_profile.jump_duration)
	var progress := _jump_elapsed / movement_profile.jump_duration
	position.y = 4.0 * movement_profile.jump_height * progress * (1.0 - progress)
	if is_equal_approx(progress, 1.0):
		position.y = 0.0
		is_jumping = false
		_landing = 1.0
		action_completed.emit(&"jump")
		vertical_state_changed.emit(false, false)


func _advance_slide(delta: float) -> void:
	if not is_sliding:
		return
	_slide_remaining = maxf(0.0, _slide_remaining - delta)
	if _slide_remaining <= 0.0:
		is_sliding = false
		action_completed.emit(&"slide")
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
