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
const GAMEPLAY_STATES: Array[StringName] = [
	GameFlow.RUNNING, GameFlow.TRANSITION_READY, GameFlow.TOKEN_COLLECTED,
	GameFlow.SCENARIO_TRANSITION, GameFlow.NEXT_SCENARIO, GameFlow.PAUSED,
	GameFlow.FAILURE_TRANSITION, GameFlow.LAVA_GAME_OVER,
]

var active_profile: Profile = Profile.FULL

@onready var band_panel: Control = %BandPanel
@onready var coordinate_panel: Control = %CoordinatePanel
@onready var scenario_panel: Control = %ScenarioPanel
@onready var top_left: Control = %TopLeft
@onready var top_right: Control = %TopRight
@onready var pause_button: Button = %PauseButton
@onready var pause_overlay: PauseController = $PauseOverlay
@onready var score_label: Label = %ScoreLabel
@onready var timer_label: Label = %TimerLabel
@onready var bonus_overlay: Control = %BonusOverlay
@onready var band_label: Label = %BandLabel
@onready var coordinate_label: Label = %CoordinateLabel
@onready var scenario_label: Label = %ScenarioLabel

var _run_stats: RunStats
var _coordinate_profile: HUDCoordinateProfile
var _coordinate_seed := 0
var _coordinate_elapsed := 0.0
var _loop_elapsed := 0.0
var _entry_banner: Label
var _entry_remaining := 0.0
var _portrait: TextureRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	band_label.text = ""
	scenario_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scenario_label.add_theme_font_size_override("font_size", 14)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_panel.add_child(_portrait)
	_entry_banner = Label.new()
	_entry_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_entry_banner.offset_top = -122.0
	_entry_banner.offset_bottom = -64.0
	_entry_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_banner.add_theme_font_size_override("font_size", 18)
	_entry_banner.add_theme_color_override("font_shadow_color", Color.BLACK)
	_entry_banner.add_theme_constant_override("shadow_offset_x", 2)
	_entry_banner.add_theme_constant_override("shadow_offset_y", 2)
	_entry_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_entry_banner)
	pause_button.pressed.connect(GameFlow.pause_run)
	GameFlow.state_changed.connect(_on_game_flow_state_changed)
	ScenarioManager.scenario_loaded.connect(_on_scenario_loaded)
	ScenarioManager.scenario_unloaded.connect(_on_scenario_unloaded)
	if ScenarioManager.active_definition != null:
		_on_scenario_loaded(ScenarioManager.active_definition)
	_set_pause_presentation(GameFlow.current_state == GameFlow.PAUSED)
	visible = GameFlow.current_state in GAMEPLAY_STATES


func _exit_tree() -> void:
	if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.disconnect(_on_game_flow_state_changed)
	if ScenarioManager.scenario_loaded.is_connected(_on_scenario_loaded):
		ScenarioManager.scenario_loaded.disconnect(_on_scenario_loaded)
	if ScenarioManager.scenario_unloaded.is_connected(_on_scenario_unloaded):
		ScenarioManager.scenario_unloaded.disconnect(_on_scenario_unloaded)


func _process(delta: float) -> void:
	if not visible or delta <= 0.0 or GameFlow.current_state == GameFlow.PAUSED:
		return
	_loop_elapsed += delta
	band_label.modulate.a = lerpf(0.72, 1.0, (sin(_loop_elapsed * 3.0) + 1.0) * 0.5)
	_portrait.texture = RunIntroController.CHARACTERS[int(_loop_elapsed * 0.7) % 4].pause_portrait
	_portrait.modulate = Color(0.7, 0.9, 1.0, 0.85 + sin(_loop_elapsed * 3.0) * 0.15)
	if GameFlow.gameplay_input_enabled:
		_entry_remaining = maxf(0.0, _entry_remaining - delta)
	_entry_banner.modulate.a = clampf(_entry_remaining, 0.0, 1.0)
	if _coordinate_profile != null:
		_coordinate_elapsed += delta
		if _coordinate_elapsed >= _coordinate_profile.update_interval:
			_coordinate_elapsed = 0.0
			_refresh_coordinates()


func _on_game_flow_state_changed(_previous_state: StringName, next_state: StringName) -> void:
	# RUN_INTRO binds its data before this point, but gameplay HUD visibility is
	# atomically reserved for the settled RUNNING edge.
	visible = next_state in GAMEPLAY_STATES
	_entry_banner.visible = next_state in [GameFlow.RUNNING, GameFlow.TRANSITION_READY]
	_set_pause_presentation(next_state == GameFlow.PAUSED)


func _set_pause_presentation(paused: bool) -> void:
	pause_overlay.set_pause_active(paused)
	# The pause overlay owns its own score/time so the frozen HUD does not double-render.
	top_left.visible = not paused
	top_right.visible = not paused
	pause_button.visible = not paused


func apply_available_size(available_size: Vector2) -> void:
	active_profile = _select_profile(available_size)
	var show_coordinates := active_profile == Profile.FULL or (active_profile == Profile.MEDIUM and available_size.x >= MEDIUM_COORDINATE_MIN_SIZE.x and available_size.y >= MEDIUM_COORDINATE_MIN_SIZE.y)
	band_panel.visible = true
	coordinate_panel.visible = show_coordinates
	scenario_panel.visible = active_profile == Profile.FULL
	pause_button.custom_minimum_size = Vector2(56.0, 56.0)
	pause_overlay.apply_available_size(available_size)
	_match_panel_density()
	top_left.offset_right = 88.0 if active_profile == Profile.COMPACT else 206.0
	for panel: Control in top_right.get_node("Panels").get_children():
		panel.custom_minimum_size.x = 174.0 if active_profile == Profile.COMPACT else 220.0
	top_right.offset_left = -190.0 if active_profile == Profile.COMPACT else -236.0
	score_label.add_theme_font_size_override("font_size", 18 if active_profile == Profile.COMPACT else 24)
	timer_label.add_theme_font_size_override("font_size", 16 if active_profile == Profile.COMPACT else 20)


func _select_profile(available_size: Vector2) -> Profile:
	if available_size.x >= FULL_MIN_SIZE.x and available_size.y >= FULL_MIN_SIZE.y:
		return Profile.FULL
	if available_size.x >= MEDIUM_MIN_SIZE.x and available_size.y >= MEDIUM_MIN_SIZE.y:
		return Profile.MEDIUM
	return Profile.COMPACT


func _match_panel_density() -> void:
	var compact := active_profile == Profile.COMPACT
	band_panel.custom_minimum_size = Vector2(72.0, 72.0) if compact else Vector2(112.0, 112.0)


func _on_scenario_loaded(definition: ScenarioDefinition) -> void:
	_coordinate_profile = definition.hud_coordinate_profile as HUDCoordinateProfile
	if _coordinate_profile == null:
		_coordinate_profile = HUDCoordinateProfile.fallback_for_scenario(definition.id)
	_coordinate_seed = abs(String(definition.id).hash())
	_coordinate_elapsed = 0.0
	scenario_label.text = "%s\n%s" % [definition.display_name.to_upper(), String(definition.movement_mode)]
	_entry_banner.text = "%s · %s\n%s" % [definition.display_name.to_upper(), String(definition.movement_mode), definition.control_hint]
	_entry_remaining = 2.8
	_refresh_coordinates()


func _on_scenario_unloaded(_scenario_id: StringName) -> void:
	_coordinate_profile = null
	coordinate_label.text = "X  ---.---\nY  ---.---\nZ  ---.---"
	scenario_label.text = "SCENARIO\n--"


func _refresh_coordinates() -> void:
	if _coordinate_profile == null:
		return
	# A deterministic scenario-local sequence gives a readable looping display
	# without implying it is the runner's location.
	_coordinate_seed = int((_coordinate_seed * 1103515245 + 12345) & 0x7fffffff)
	var x := lerpf(_coordinate_profile.minimum.x, _coordinate_profile.maximum.x, _unit_sample(0))
	var y := lerpf(_coordinate_profile.minimum.y, _coordinate_profile.maximum.y, _unit_sample(9))
	var z := lerpf(_coordinate_profile.minimum.z, _coordinate_profile.maximum.z, _unit_sample(17))
	coordinate_label.text = "X  %8.3f\nY  %8.3f\nZ  %8.3f" % [x, y, z]


func _unit_sample(offset: int) -> float:
	return float((_coordinate_seed >> offset) & 0x3ff) / 1023.0


## Read-only binding stub; final HUD behavior and pause reflow remain later tasks.
func bind_run_stats(run_stats: RunStats) -> void:
	if _run_stats != null and _run_stats.metrics_changed.is_connected(_on_metrics_changed):
		_run_stats.metrics_changed.disconnect(_on_metrics_changed)
	_run_stats = run_stats
	pause_overlay.bind_run_stats(_run_stats)
	if _run_stats == null:
		return
	_run_stats.metrics_changed.connect(_on_metrics_changed)
	_on_metrics_changed(_run_stats.score, _run_stats.elapsed_seconds, _run_stats.active_distance)


func show_transition_bonus(visible: bool) -> void:
	bonus_overlay.visible = visible


func _on_metrics_changed(score: int, elapsed_seconds: float, _distance: float) -> void:
	score_label.text = "SCORE %06d" % score
	var total_seconds: int = maxi(0, floori(elapsed_seconds))
	timer_label.text = "TIME %02d:%02d:%02d" % [total_seconds / 3600, (total_seconds % 3600) / 60, total_seconds % 60]
