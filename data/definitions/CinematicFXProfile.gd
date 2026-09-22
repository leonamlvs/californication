class_name CinematicFXProfile
extends Resource

enum FallbackPolicy {
	AUTO,
	PREFER_SCREEN_BLUR,
	FORCE_CAMERA_OVERLAY,
}

@export var id: StringName
@export_range(0.0, 0.25, 0.001) var radial_blur_strength := 0.055
@export var radial_blur_center := Vector2(0.5, 0.5)
@export_range(2, 12, 1) var desktop_sample_count := 8
@export_range(2, 8, 1) var mobile_sample_count := 4
@export_range(-30.0, 30.0, 0.5, "suffix:deg") var fov_kick := 8.0
@export var overlay_color := Color(0.04, 0.12, 0.24, 1.0)
@export_range(0.0, 1.0, 0.01) var fade_amount := 0.28
@export_range(0.05, 5.0, 0.05, "suffix:s") var duration := 0.65
@export var fallback_policy: FallbackPolicy = FallbackPolicy.AUTO
@export var blur_enabled := true


func is_valid_profile() -> bool:
	return not id.is_empty() \
		and radial_blur_strength >= 0.0 \
		and radial_blur_center.x >= 0.0 and radial_blur_center.x <= 1.0 \
		and radial_blur_center.y >= 0.0 and radial_blur_center.y <= 1.0 \
		and desktop_sample_count >= 2 and desktop_sample_count <= 12 \
		and mobile_sample_count >= 2 and mobile_sample_count <= desktop_sample_count \
		and fade_amount >= 0.0 and fade_amount <= 1.0 \
		and duration > 0.0
