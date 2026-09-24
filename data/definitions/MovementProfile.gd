class_name MovementProfile
extends Resource

## Editable movement tuning shared by one movement strategy at a time.
@export var movement_mode: StringName = &"RUN"
@export var speed_ramp_duration := 150.0
@export var action_buffer_duration := 0.12
@export var presentation_lean := 5.0
@export var presentation_bob := 0.045
@export_range(3, 3, 1) var lane_count := 3
@export_range(0.5, 4.0, 0.05) var lane_spacing := 1.6
@export_range(0.0, 40.0, 0.1) var base_speed := 10.0
@export_range(0.0, 40.0, 0.1) var max_speed := 16.0
@export_range(0.05, 1.0, 0.01) var lane_change_duration := 0.18
@export_range(0.1, 4.0, 0.05) var jump_height := 1.4
@export_range(0.1, 2.0, 0.01) var jump_duration := 0.72
@export_range(0.1, 2.0, 0.01) var slide_duration := 0.65
@export_range(0.0, 4.0, 0.05, "suffix:m") var vertical_rise_offset := 1.2
@export_range(0.0, 4.0, 0.05, "suffix:m") var vertical_dive_offset := 0.9
@export_range(0.05, 2.0, 0.01, "suffix:s") var vertical_action_duration := 0.2
@export_range(0.0, 2.0, 0.01, "suffix:s") var vertical_hold_duration := 0.2
@export_range(0.05, 3.0, 0.01, "suffix:s") var vertical_neutral_return_duration := 0.75
@export_range(0.2, 1.0, 0.01) var capsule_radius := 0.38
@export_range(0.5, 3.0, 0.01) var standing_height := 1.7
@export_range(0.3, 2.0, 0.01) var sliding_height := 0.9


func is_valid_profile() -> bool:
	return lane_count == 3 and lane_spacing > 0.0 and base_speed >= 0.0 and max_speed >= base_speed and lane_change_duration > 0.0 and jump_duration > 0.0 and slide_duration > 0.0 and vertical_rise_offset >= 0.0 and vertical_dive_offset >= 0.0 and vertical_action_duration > 0.0 and vertical_neutral_return_duration > 0.0 and sliding_height <= standing_height
