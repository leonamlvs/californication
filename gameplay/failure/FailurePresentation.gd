class_name FailurePresentation
extends Node

signal completed(family: StringName)

const FLOOR_FALL: StringName = &"floor_fall"
const LAUNCH: StringName = &"launch"

var runner: RunnerController
var family: StringName
var duration := 0.45
var elapsed := 0.0
var is_running := false
var progress := 0.0

var _origin_position := Vector3.ZERO
var _origin_rotation := Vector3.ZERO
var _origin_scale := Vector3.ONE


func play(target: RunnerController, selected_family: StringName, animation_duration: float) -> bool:
	if is_running or target == null or not is_supported_family(selected_family):
		return false
	runner = target
	family = selected_family
	duration = maxf(animation_duration, 0.05)
	elapsed = 0.0
	progress = 0.0
	_origin_position = runner.position
	_origin_rotation = runner.rotation
	_origin_scale = runner.scale
	is_running = true
	set_process(true)
	return true


func _process(delta: float) -> void:
	if not is_running or runner == null:
		return
	elapsed = minf(elapsed + maxf(delta, 0.0), duration)
	progress = clampf(elapsed / duration, 0.0, 1.0)
	_apply_pose(progress)
	if is_equal_approx(progress, 1.0):
		is_running = false
		set_process(false)
		completed.emit(family)


func advance_for_test(delta: float) -> void:
	_process(delta)


func cancel(restore_runner := true) -> void:
	is_running = false
	set_process(false)
	if restore_runner:
		restore()


func restore() -> void:
	if runner == null:
		return
	runner.position = _origin_position
	runner.rotation = _origin_rotation
	runner.scale = _origin_scale
	progress = 0.0


func is_supported_family(value: StringName) -> bool:
	return value == FLOOR_FALL or value == LAUNCH


func _apply_pose(amount: float) -> void:
	match family:
		FLOOR_FALL:
			var eased := amount * amount
			runner.position = _origin_position + Vector3(0.0, -4.8 * eased, 0.8 * amount)
			runner.rotation = _origin_rotation + Vector3(deg_to_rad(115.0) * amount, 0.0, deg_to_rad(24.0) * amount)
			runner.scale = _origin_scale.lerp(_origin_scale * 0.68, amount)
		LAUNCH:
			var lift := sin(amount * PI) * 1.4
			runner.position = _origin_position + Vector3(0.0, lift, 5.6 * amount)
			runner.rotation = _origin_rotation + Vector3(deg_to_rad(-35.0) * amount, deg_to_rad(300.0) * amount, deg_to_rad(90.0) * amount)
			runner.scale = _origin_scale.lerp(_origin_scale * 2.35, amount)
