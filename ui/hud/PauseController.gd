class_name PauseController
extends Control

## Pause navigation is deliberately local to this overlay; game state remains GameFlow's authority.
const CHARACTER_IDS: Array[StringName] = [&"placeholder_01", &"placeholder_02", &"placeholder_03", &"placeholder_04"]

enum FocusTarget { PORTRAITS, SFX, MUSIC, BACK }

var portrait_index := 0
var focus_target: FocusTarget = FocusTarget.PORTRAITS
var adjusting_audio := false

@onready var portraits: Array[Button] = [%Portrait01, %Portrait02, %Portrait03, %Portrait04]
@onready var sfx_button: Button = %SfxButton
@onready var music_button: Button = %MusicButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	for index in portraits.size():
		portraits[index].pressed.connect(_select_portrait.bind(index))
	sfx_button.pressed.connect(_select_audio.bind(FocusTarget.SFX))
	music_button.pressed.connect(_select_audio.bind(FocusTarget.MUSIC))
	back_button.pressed.connect(back)
	_refresh_visuals()


func _select_portrait(index: int) -> void:
	portrait_index = index
	confirm()
	_refresh_visuals()


func _select_audio(target: FocusTarget) -> void:
	if focus_target == target:
		confirm()
	else:
		focus_target = target
		adjusting_audio = false
	_refresh_visuals()


func move_portrait(delta: int) -> void:
	portrait_index = posmod(portrait_index + delta, CHARACTER_IDS.size())
	_refresh_visuals()


func move_focus(delta: int) -> void:
	if focus_target == FocusTarget.PORTRAITS:
		move_portrait(delta)
	else:
		focus_target = clampi(focus_target + delta, FocusTarget.SFX, FocusTarget.BACK)
	_refresh_visuals()


func confirm() -> bool:
	match focus_target:
		FocusTarget.PORTRAITS:
			if not GameFlow.set_paused_character(CHARACTER_IDS[portrait_index], portrait_index):
				return false
			focus_target = FocusTarget.BACK
			_refresh_visuals()
			return true
		FocusTarget.SFX, FocusTarget.MUSIC:
			adjusting_audio = not adjusting_audio
			_refresh_visuals()
			return true
		FocusTarget.BACK:
			return GameFlow.resume_run()
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
	if intent == InputRouter.INTENT_BACK:
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
		elif adjusting_audio:
			adjust(-1)
		_refresh_visuals()
		return true
	if intent == InputRouter.INTENT_RIGHT and adjusting_audio:
		adjust(1)
		return true
	if intent == InputRouter.INTENT_CONFIRM:
		return confirm()
	return false


func back() -> void:
	GameFlow.resume_run()


func _refresh_visuals() -> void:
	if not is_node_ready():
		return
	for index in portraits.size():
		# Faces intentionally carry no label/card data; the outline is the sole focus cue.
		var focused := focus_target == FocusTarget.PORTRAITS and index == portrait_index
		portraits[index].add_theme_stylebox_override("normal", _portrait_outline(focused))
	sfx_button.text = "SFX LEVEL  %02d" % AudioManager.sfx_step
	music_button.text = "MUSIC LEVEL  %02d" % AudioManager.music_step
	sfx_button.modulate = Color(0.84, 0.95, 0.27) if focus_target == FocusTarget.SFX else Color.WHITE
	music_button.modulate = Color(0.84, 0.95, 0.27) if focus_target == FocusTarget.MUSIC else Color.WHITE
	back_button.modulate = Color(0.84, 0.95, 0.27) if focus_target == FocusTarget.BACK else Color.WHITE


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
