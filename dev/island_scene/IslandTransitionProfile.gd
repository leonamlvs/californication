class_name IslandTransitionProfile
extends Resource

## Measured image-space continuation; elevation and metric scale are authored.
@export var times := PackedFloat32Array()
@export var ortho_sizes := PackedFloat32Array()
@export var targets := PackedVector2Array()
@export var rolls_degrees := PackedFloat32Array()
@export var pixels_per_unit := 30.0
@export var elevation_degrees := 78.0
@export var camera_distance := 45.0
@export var blend_start := 3.3033
@export var video_end := 3.470133333333333
@export var reveal_time := 3.737066666666667
@export var settle_end := 4.137066666666667
@export var rotation_degrees_per_second := 5.0
@export var final_size := 25.2
@export var final_target := Vector2(479.0, 354.0)
@export var final_roll_degrees := -1.0
@export var blur_peak := 0.0 # V4 supplies the live blur; V2 camera preview is sharp.
@export var water_phase := 0.0


func sample(time: float) -> Dictionary:
	var t := clampf(time, times[0], settle_end)
	var index := 0
	while index < times.size() - 2 and t > times[index + 1]:
		index += 1
	var weight := clampf((t - times[index]) / (times[index + 1] - times[index]), 0.0, 1.0)
	# Piecewise linear size preserves measured frame poses and avoids spline overshoot.
	var size := lerpf(ortho_sizes[index], ortho_sizes[index + 1], weight)
	var target := targets[index].lerp(targets[index + 1], weight)
	var roll := lerpf(rolls_degrees[index], rolls_degrees[index + 1], weight)
	if t > reveal_time:
		var interval := times[-1] - times[-2]
		var since_reveal := t - reveal_time
		size = _settle(ortho_sizes[-1], final_size, (ortho_sizes[-1] - ortho_sizes[-2]) / interval, since_reveal)
		target.x = _settle(targets[-1].x, final_target.x, (targets[-1].x - targets[-2].x) / interval, since_reveal)
		target.y = _settle(targets[-1].y, final_target.y, (targets[-1].y - targets[-2].y) / interval, since_reveal)
		roll = _settle(rolls_degrees[-1], final_roll_degrees, (rolls_degrees[-1] - rolls_degrees[-2]) / interval, since_reveal)
	var elevation := deg_to_rad(elevation_degrees)
	var focus := Vector3((target.x - 480.0) / pixels_per_unit, 0.0, (target.y - 360.0) / pixels_per_unit / sin(elevation))
	return {"size": size, "target": focus, "roll": deg_to_rad(roll), "elevation": elevation}


func _settle(start: float, finish: float, speed: float, elapsed: float) -> float:
	# Preserve endpoint velocity, decelerate monotonically, then hold. The camera
	# may settle before rotation finishes easing; no attract pose assignment occurs.
	if is_zero_approx(finish - start): return finish
	var duration := settle_end - reveal_time
	if speed * (finish - start) > 0.0:
		duration = minf(duration, 3.0 * absf((finish - start) / speed))
	var u := clampf(elapsed / maxf(duration, 0.0001), 0.0, 1.0)
	return lerpf(start, finish, 1.0 - pow(1.0 - u, 3.0))


func rotation_at(time: float) -> float:
	var duration := settle_end - reveal_time
	var u := clampf((time - reveal_time) / duration, 0.0, 1.0)
	# Integral of smoothstep velocity, joined to indefinite constant rotation.
	var eased_seconds := duration * (u * u * u - 0.5 * u * u * u * u)
	return deg_to_rad(rotation_degrees_per_second * (eased_seconds + maxf(0.0, time - settle_end)))
