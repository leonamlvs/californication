class_name CameraProfile
extends Resource

@export_range(35.0, 110.0, 1.0, "suffix: deg") var field_of_view := 68.0
@export_range(1.0, 30.0, 0.1, "suffix:m") var follow_distance := 8.0
@export_range(0.1, 10.0, 0.1, "suffix:m") var height := 3.2
@export_range(-45.0, 20.0, 1.0, "suffix: deg") var pitch_degrees := -15.0
@export_range(0.0, 2.0, 0.05) var lateral_look_strength := 0.35


func is_valid_profile() -> bool:
	return field_of_view > 0.0 and follow_distance > 0.0 and height > 0.0
