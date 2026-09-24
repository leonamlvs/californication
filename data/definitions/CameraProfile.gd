class_name CameraProfile
extends Resource

@export_range(35.0, 110.0, 1.0, "suffix: deg") var field_of_view := 68.0
@export_range(1.0, 30.0, 0.1, "suffix:m") var follow_distance := 8.0
@export_range(0.1, 10.0, 0.1, "suffix:m") var height := 3.2
@export_range(-45.0, 20.0, 1.0, "suffix: deg") var pitch_degrees := -15.0
@export_range(0.0, 2.0, 0.05) var lateral_look_strength := 0.35
@export var look_ahead := 8.0
@export var position_damping := 10.0
@export var rotation_damping := 12.0
@export var vertical_follow_strength := 0.2
@export var speed_fov_boost := 5.0
@export var roll_limit := 2.5
@export var aspect_distance_adjustment := 0.65


func is_valid_profile() -> bool:
	return field_of_view > 0.0 and follow_distance > 0.0 and height > 0.0
