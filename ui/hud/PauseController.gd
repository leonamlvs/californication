class_name PauseController
extends Control

## Pause navigation is local to this overlay; GameFlow remains state authority.
const CHARACTERS: Array[CharacterDefinition] = [
	preload("res://data/characters/character_01.tres"),
	preload("res://data/characters/character_02.tres"),
	preload("res://data/characters/character_03.tres"),
	preload("res://data/characters/character_04.tres"),
]
const TOUCH_TARGET := 56.0
const NARROW_LAYOUT_WIDTH := 560.0

enum FocusTarget { PORTRAITS, SFX, MUSIC, BACK, EXIT }

var portrait_index := 0
var focus_target: FocusTarget = FocusTarget.PORTRAITS
var adjusting_audio := false
var _run_stats: RunStats
var _accept_routed_intents := false

@onready var summary: Control = %Summary
@onready var pause_score_label: Label = %PauseScoreLabel
@onready var pause_time_label: Label = %PauseTimeLabel
@onready var portraits_grid: GridContainer = %Portraits
@onready var portraits: Array[Button] = [%Portrait01, %Portrait02, %Portrait03, %Portrait04]
@onready var actions: VBoxContainer = %Actions
@onready var sfx_button: Button = %SfxButton
@onready var music_button: Button = %MusicButton
@onready var back_button: Button = %BackButton
@onready var exit_button: Button = %ExitButton
@onready var sfx_minus_button: Button = %SfxMinus
@onready var sfx_plus_button: Button = %SfxPlus
@onready var music_minus_button: Button = %MusicMinus
@onready var music_plus_button: Button = %MusicPlus


func _ready() -> void:
	for index: int in portraits.size():
		portraits[index].icon = CHARACTERS[index].pause_portrait
		portraits[index].pressed.connect(_select_portrait.bind(index))
	sfx_button.pressed.connect(_select_audio.bind(FocusTarget.SFX))
	music_button.pressed.connect(_select_audio.bind(FocusTarget.MUSIC))
	sfx_minus_button.pressed.connect(_touch_adjust.bind(FocusTarget.SFX, -1))
	sfx_plus_button.pressed.connect(_touch_adjust.bind(FocusTarget.SFX, 1))
	music_minus_button.pressed.connect(_touch_adjust.bind(FocusTarget.MUSIC, -1))
	music_plus_button.pressed.connect(_touch_adjust.bind(FocusTarget.MUSIC, 1))
	back_button.pressed.connect(back)
	exit_button.pressed.connect(exit_run)
	InputRouter.intent_requested.connect(_on_intent_requested)
	GameFlow.state_changed.connect(_on_game_flow_state_changed)
	AudioManager.levels_changed.connect(_on_audio_levels_changed)
	set_pause_active(GameFlow.current_state == GameFlow.PAUSED)
	call_deferred("apply_available_size", size)


func _exit_tree() -> void:
	if InputRouter.intent_requested.is_connected(_on_intent_requested):
		InputRouter.intent_requested.disconnect(_on_intent_requested)
	if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.disconnect(_on_game_flow_state_changed)
	if AudioManager.levels_changed.is_connected(_on_audio_levels_changed):
		AudioManager.levels_changed.disconnect(_on_audio_levels_changed)


func bind_run_stats(run_stats: RunStats) -> void:
	if _run_stats != null and _run_stats.metrics_changed.is_connected(_on_metrics_changed):
		_run_stats.metrics_changed.disconnect(_on_metrics_changed)
	_run_stats = run_stats
	if _run_stats != null:
		_run_stats.metrics_changed.connect(_on_metrics_changed)
		_on_metrics_changed(_run_stats.score, _run_stats.elapsed_seconds, _run_stats.active_distance)


func set_pause_active(active: bool) -> void:
	visible = active
	_accept_routed_intents = false
	if not active:
		adjusting_audio = false
		return
	portrait_index = clampi(GameFlow.selected_character_index, 0, CHARACTERS.size() - 1)
	focus_target = FocusTarget.PORTRAITS
	adjusting_audio = false
	_refresh_visuals()
	if _run_stats != null:
		_on_metrics_changed(_run_stats.score, _run_stats.elapsed_seconds, _run_stats.active_distance)
	call_deferred("_enable_routed_intents")


func apply_available_size(available_size: Vector2) -> void:
	if not is_node_ready() or available_size.x <= 0.0 or available_size.y <= 0.0:
		return
	var inset := 12.0
	var summary_size := Vector2(minf(220.0, available_size.x - inset * 2.0), 104.0)
	summary.position = Vector2(available_size.x - summary_size.x - inset, inset)
	summary.size = summary_size
	if available_size.x < NARROW_LAYOUT_WIDTH:
		portraits_grid.columns = 4
		var portraits_size := Vector2(TOUCH_TARGET * 4.0 + 18.0, TOUCH_TARGET)
		portraits_grid.position = Vector2((available_size.x - portraits_size.x) * 0.5, summary.position.y + summary.size.y + 8.0)
		portraits_grid.size = portraits_size
		var actions_width := minf(332.0, available_size.x - inset * 2.0)
		actions.position = Vector2((available_size.x - actions_width) * 0.5, portraits_grid.position.y + TOUCH_TARGET + 12.0)
		actions.size = Vector2(actions_width, maxf(TOUCH_TARGET * 4.0 + 18.0, available_size.y - actions.position.y - inset))
	else:
		portraits_grid.columns = 1
		portraits_grid.position = Vector2(available_size.x - TOUCH_TARGET - inset, summary.position.y + summary.size.y + 8.0)
		portraits_grid.size = Vector2(TOUCH_TARGET, TOUCH_TARGET * 4.0 + 18.0)
		var actions_width := minf(332.0, available_size.x - 112.0)
		actions.position = Vector2(inset, maxf(inset, (available_size.y - (TOUCH_TARGET * 4.0 + 18.0)) * 0.5))
		actions.size = Vector2(actions_width, TOUCH_TARGET * 4.0 + 18.0)


func _select_portrait(index: int) -> void:
	portrait_index = index
	focus_target = FocusTarget.PORTRAITS
	confirm()


func _select_audio(target: FocusTarget) -> void:
	focus_target = target
	adjusting_audio = not adjusting_audio
	_refresh_visuals()


func _touch_adjust(target: FocusTarget, delta: int) -> void:
	focus_target = target
	adjusting_audio = true
	adjust(delta)


func move_portrait(delta: int) -> void:
	portrait_index = posmod(portrait_index + delta, CHARACTERS.size())
	_refresh_visuals()


func move_focus(delta: int) -> void:
	if focus_target == FocusTarget.PORTRAITS:
		move_portrait(delta)
	else:
		focus_target = clampi(focus_target + delta, FocusTarget.SFX, FocusTarget.EXIT)
		adjusting_audio = false
		_refresh_visuals()


func confirm() -> bool:
	match focus_target:
		FocusTarget.PORTRAITS:
			var definition := CHARACTERS[portrait_index]
			if not GameFlow.set_paused_character(definition.id, portrait_index):
				return false
			focus_target = FocusTarget.BACK
			adjusting_audio = false
			_refresh_visuals()
			return true
		FocusTarget.SFX, FocusTarget.MUSIC:
			adjusting_audio = not adjusting_audio
			_refresh_visuals()
			return true
		FocusTarget.BACK:
			return GameFlow.resume_run()
		FocusTarget.EXIT:
			return GameFlow.exit_run()
	return false


func adjust(delta: int) -> void:
	if not adjusting_audio:
		return
	if focus_target == FocusTarget.SFX:
		AudioManager.adjust_sfx(delta)
	elif focus_target == FocusTarget.MUSIC:
		AudioManager.adjust_music(delta)
	_refresh_visuals()


func handle_intent(intent: StringName) -> bool:
	if GameFlow.current_state != GameFlow.PAUSED:
		return false
	if intent == InputRouter.INTENT_PAUSE or intent == InputRouter.INTENT_BACK:
		return GameFlow.resume_run()
	if intent == InputRouter.INTENT_UP:
		move_focus(-1)
		return true
	if intent == InputRouter.INTENT_DOWN:
		move_focus(1)
		return true
	if intent == InputRouter.INTENT_LEFT:
		if focus_target == FocusTarget.PORTRAITS:
			focus_target = FocusTarget.SFX
			adjusting_audio = false
		elif adjusting_audio:
			adjust(-1)
		_refresh_visuals()
		return true
	if intent == InputRouter.INTENT_RIGHT:
		if adjusting_audio and (focus_target == FocusTarget.SFX or focus_target == FocusTarget.MUSIC):
			adjust(1)
		elif focus_target != FocusTarget.PORTRAITS:
			focus_target = FocusTarget.PORTRAITS
			adjusting_audio = false
			_refresh_visuals()
		return true
	if intent == InputRouter.INTENT_CONFIRM:
		return confirm()
	return false


func back() -> void:
	GameFlow.resume_run()


func exit_run() -> void:
	GameFlow.exit_run()


func _on_intent_requested(intent: StringName) -> void:
	# GameFlow receives the same signal first. Deferring activation prevents the
	# pause intent that opened this overlay from immediately closing it again.
	if _accept_routed_intents:
		handle_intent(intent)


func _enable_routed_intents() -> void:
	_accept_routed_intents = visible and GameFlow.current_state == GameFlow.PAUSED


func _on_game_flow_state_changed(_previous: StringName, next_state: StringName) -> void:
	set_pause_active(next_state == GameFlow.PAUSED)


func _on_audio_levels_changed(_sfx_step: int, _music_step: int) -> void:
	_refresh_visuals()


func _on_metrics_changed(score: int, elapsed_seconds: float, _distance: float) -> void:
	pause_score_label.text = "SCORE %06d" % score
	var total_seconds := maxi(0, floori(elapsed_seconds))
	pause_time_label.text = "TIME %02d:%02d:%02d" % [total_seconds / 3600, (total_seconds % 3600) / 60, total_seconds % 60]


func _refresh_visuals() -> void:
	if not is_node_ready():
		return
	for index: int in portraits.size():
		var focused := focus_target == FocusTarget.PORTRAITS and index == portrait_index
		var outline := _portrait_outline(focused)
		portraits[index].add_theme_stylebox_override("normal", outline)
		portraits[index].add_theme_stylebox_override("hover", outline)
		portraits[index].add_theme_stylebox_override("pressed", outline)
		portraits[index].add_theme_stylebox_override("focus", outline)
	sfx_button.text = "SFX LEVEL  %02d" % AudioManager.sfx_step
	music_button.text = "MUSIC LEVEL  %02d" % AudioManager.music_step
	sfx_button.modulate = Color(0.84, 0.95, 0.27) if focus_target == FocusTarget.SFX else Color.WHITE
	music_button.modulate = Color(0.84, 0.95, 0.27) if focus_target == FocusTarget.MUSIC else Color.WHITE
	back_button.modulate = Color(0.84, 0.95, 0.27) if focus_target == FocusTarget.BACK else Color.WHITE
	exit_button.modulate = Color(0.84, 0.95, 0.27) if focus_target == FocusTarget.EXIT else Color.WHITE


func _portrait_outline(focused: bool) -> StyleBoxFlat:
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color(0.08, 0.11, 0.14, 0.95)
	outline.corner_radius_top_left = 18
	outline.corner_radius_top_right = 18
	outline.corner_radius_bottom_left = 18
	outline.corner_radius_bottom_right = 18
	if focused:
		outline.border_width_left = 3
		outline.border_width_top = 3
		outline.border_width_right = 3
		outline.border_width_bottom = 3
		outline.border_color = Color(0.58, 0.94, 0.20)
	return outline
