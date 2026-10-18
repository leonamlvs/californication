class_name IslandHandoffProfile
extends Resource

@export var camera_profile: IslandTransitionProfile = preload("res://dev/island_scene/transition.tres")
@export var blur_profile: CinematicFXProfile = preload("res://dev/island_transition/live_blur.tres")
@export var blur_times := PackedFloat32Array([3.3033, 3.4367667, 3.5035, 3.6036, 3.7370667, 3.90, 4.1370667])
@export var blur_envelopes := PackedFloat32Array([0.65, 0.85, 1.0, 0.65, 0.15, 0.0, 0.0])


func video_opacity(time: float) -> float:
	var weight := clampf((time-camera_profile.blend_start)/(camera_profile.video_end-camera_profile.blend_start),0.0,1.0)
	return 1.0-weight*weight*(3.0-2.0*weight)


func blur_envelope(time: float) -> float:
	if time < blur_times[0] or time >= blur_times[-1]: return 0.0
	for i: int in range(blur_times.size()-1):
		if time <= blur_times[i+1]:
			return lerpf(blur_envelopes[i],blur_envelopes[i+1],inverse_lerp(blur_times[i],blur_times[i+1],time))
	return 0.0
