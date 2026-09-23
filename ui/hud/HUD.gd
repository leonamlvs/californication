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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if not visible or delta <= 0.0:
		return
	_loop_elapsed += delta
	band_label.modulate.a = lerpf(0.72, 1.0, (sin(_loop_elapsed * 3.0) + 1.0) * 0.5)
	scenario_label.modulate = Color.from_hsv(fposmod(float(_coordinate_seed) * 0.013 + _loop_elapsed * 0.035, 1.0), 0.35, 1.0)
	if _coordinate_profile != null:
		_coordinate_elapsed += delta
		if _coordinate_elapsed >= _coordinate_profile.update_interval:
			_coordinate_elapsed = 0.0
			_refresh_coordinates()


func _on_game_flow_state_changed(_previous_state: StringName, next_state: StringName) -> void:
	# RUN_INTRO binds its data before this point, but gameplay HUD visibility is
	# atomically reserved for the settled RUNNING edge.
	visible = next_state in GAMEPLAY_STATES
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
	scenario_label.text = "SCENARIO\n%s" % definition.display_name.to_upper()
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
