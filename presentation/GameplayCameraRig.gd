class_name GameplayCameraRig
extends Node

## Writes only the gameplay camera. Frontend and cinematic cameras explicitly
## take ownership while this rig continues preparing the eventual landing frame.
var camera: Camera3D
var runner: RunnerController
var profile: CameraProfile
var impulse := 0.0

func bind(camera_node: Camera3D, runner_node: RunnerController) -> void:
	camera = camera_node
	runner = runner_node
	runner.lane_started.connect(func(_lane: int): kick(0.12))
	runner.action_started.connect(func(_action: StringName): kick(0.16))
	runner.pickup_response.connect(func(): kick(0.08))
	runner.failure_impact.connect(func(): kick(0.65))

func apply_profile(value: CameraProfile, snap := false) -> void:
	profile = value
	if snap:
		settle()

func desired_position() -> Vector3:
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	var extra := clampf((4.0 / 3.0) / maxf(aspect, 0.4) - 1.0, 0.0, 1.5) * profile.aspect_distance_adjustment
	var lane_x := runner._lane_x(runner.target_lane_index)
	return Vector3(lane_x * profile.lateral_look_strength * 0.45, profile.height + runner.position.y * profile.vertical_follow_strength + extra, profile.follow_distance * (1.0 + extra))

func settle() -> void:
	if profile == null or camera == null:
		return
	impulse = 0.0
	camera.position = desired_position()
	camera.rotation_degrees = Vector3(profile.pitch_degrees, 0.0, 0.0)
	camera.fov = profile.field_of_view + profile.speed_fov_boost * clampf(runner.run_elapsed / runner.movement_profile.speed_ramp_duration, 0.0, 1.0)

func kick(strength: float) -> void:
	impulse = clampf(impulse + strength, 0.0, 0.75)

func _process(delta: float) -> void:
	if profile == null or camera == null or runner == null or GameFlow.current_state == GameFlow.PAUSED:
		return
	var target := desired_position()
	impulse = move_toward(impulse, 0.0, delta * 2.5)
	target.y += impulse * 0.18
	camera.position = camera.position.lerp(target, 1.0 - exp(-profile.position_damping * delta))
	var lane_error := runner._lane_x(runner.target_lane_index) - runner.position.x
	var roll := clampf(-lane_error * 1.5, -profile.roll_limit, profile.roll_limit)
	var yaw := -rad_to_deg(atan2(runner.position.x * profile.lateral_look_strength - camera.position.x, profile.follow_distance + profile.look_ahead))
	var angles := Vector3(profile.pitch_degrees + impulse, yaw, roll)
	camera.rotation_degrees = camera.rotation_degrees.lerp(angles, 1.0 - exp(-profile.rotation_damping * delta))
	var speed_fraction := clampf(runner.run_elapsed / runner.movement_profile.speed_ramp_duration, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, profile.field_of_view + speed_fraction * profile.speed_fov_boost, 1.0 - exp(-5.0 * delta))
