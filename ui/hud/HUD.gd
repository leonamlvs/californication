class_name RunnerHUD
extends Control

## One HUD tree whose optional panels reflow by fit, never device identity.
enum Profile {
	FULL,
	MEDIUM,
	COMPACT,
}

const FULL_MIN_SIZE := Vector2(760.0, 480.0)
const MEDIUM_MIN_SIZE := Vector2(540.0, 340.0)
const MEDIUM_COORDINATE_MIN_SIZE := Vector2(680.0, 380.0)

var active_profile: Profile = Profile.FULL

@onready var band_panel: Control = %BandPanel
@onready var coordinate_panel: Control = %CoordinatePanel
@onready var scenario_panel: Control = %ScenarioPanel
@onready var pause_button: Control = %PauseButton


func apply_available_size(available_size: Vector2) -> void:
	active_profile = _select_profile(available_size)
	var show_coordinates := active_profile == Profile.FULL or (active_profile == Profile.MEDIUM and available_size.x >= MEDIUM_COORDINATE_MIN_SIZE.x and available_size.y >= MEDIUM_COORDINATE_MIN_SIZE.y)
	band_panel.visible = true
	coordinate_panel.visible = show_coordinates
	scenario_panel.visible = active_profile == Profile.FULL
	pause_button.custom_minimum_size = Vector2(56.0, 56.0)
	_match_panel_density()


func _select_profile(available_size: Vector2) -> Profile:
	if available_size.x >= FULL_MIN_SIZE.x and available_size.y >= FULL_MIN_SIZE.y:
		return Profile.FULL
	if available_size.x >= MEDIUM_MIN_SIZE.x and available_size.y >= MEDIUM_MIN_SIZE.y:
		return Profile.MEDIUM
	return Profile.COMPACT


func _match_panel_density() -> void:
	var compact := active_profile == Profile.COMPACT
	band_panel.custom_minimum_size = Vector2(72.0, 72.0) if compact else Vector2(112.0, 112.0)
