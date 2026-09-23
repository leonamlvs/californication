class_name LogoCarouselController
extends Node

signal rotation_started(from_index: int, to_index: int)
signal detent_settled(index: int, character_id: StringName)
signal selection_confirmed(index: int, character_id: StringName)

const CHARACTER_DEFINITIONS: Array[CharacterDefinition] = [
	preload("res://data/characters/character_01.tres"),
	preload("res://data/characters/character_02.tres"),
	preload("res://data/characters/character_03.tres"),
	preload("res://data/characters/character_04.tres"),
]

@export_range(0.1, 1.5, 0.05, "suffix:s") var rotation_duration := 0.42

var logo_assembly: Node3D
var panel_anchors: Array[Node3D] = []
var presenter: PlayerSelectPresenter
var character_visuals: Array[CharacterVisual] = []
var current_index := 0
var target_index := 0
var queued_direction := 0
var is_rotating := false
var selection_locked := true
var confirmation_accepted := false
var rotation_settle_count := 0
var rejected_panel_click_count := 0
var _rotation_elapsed := 0.0
var _rotation_start := 0.0
var _rotation_target := 0.0
var _configured := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputRouter.intent_requested.connect(_on_intent_requested)
	GameFlow.state_changed.connect(_on_game_flow_state_changed)


func _exit_tree() -> void:
	GameFlow.set_frontend_selection_controller_active(false)
	if InputRouter.intent_requested.is_connected(_on_intent_requested):
		InputRouter.intent_requested.disconnect(_on_intent_requested)
	if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.disconnect(_on_game_flow_state_changed)


func _process(delta: float) -> void:
	advance_for_test(delta)


func configure(target_logo: Node3D, anchors: Array[Node3D], target_presenter: PlayerSelectPresenter) -> bool:
	if target_logo == null or anchors.size() != CHARACTER_DEFINITIONS.size() or target_presenter == null:
		return false
	logo_assembly = target_logo
	panel_anchors = anchors
	presenter = target_presenter
	if not presenter.rotation_requested.is_connected(request_rotation):
		presenter.rotation_requested.connect(request_rotation)
	if not presenter.confirm_requested.is_connected(confirm_selection):
		presenter.confirm_requested.connect(confirm_selection)
	_attach_character_presentations()
	_configured = character_visuals.size() == CHARACTER_DEFINITIONS.size()
	_apply_state(GameFlow.current_state)
	return _configured


func request_rotation(direction: int) -> bool:
	if not _configured or confirmation_accepted or GameFlow.current_state != GameFlow.CHARACTER_SELECT_ACTIVE:
		return false
	var step := signi(direction)
	if step == 0:
		return false
	if is_rotating:
		if queued_direction != 0:
			return false
		queued_direction = step
		return true
	if selection_locked:
		return false
	_begin_rotation(step)
	return true


func request_panel_selection(_panel_index: int) -> bool:
	# Side panels are 3D presentation surfaces, never input targets.
	rejected_panel_click_count += 1
	return false


func confirm_selection() -> bool:
	if not _configured or selection_locked or is_rotating or queued_direction != 0 or confirmation_accepted:
		return false
	if GameFlow.current_state != GameFlow.CHARACTER_SELECT_ACTIVE:
		return false
	var definition := CHARACTER_DEFINITIONS[current_index]
	if not GameFlow.set_selected_character(definition.id):
		return false
	confirmation_accepted = true
	selection_locked = true
	presenter.set_navigation_enabled(false)
	if not GameFlow.request_transition(GameFlow.CHARACTER_CONFIRMED):
		confirmation_accepted = false
		selection_locked = false
		presenter.set_navigation_enabled(true)
		return false
	selection_confirmed.emit(current_index, definition.id)
	return true


func advance_for_test(delta: float) -> void:
	if delta <= 0.0 or not is_rotating:
		return
	_rotation_elapsed = minf(_rotation_elapsed + delta, rotation_duration)
	var normalized := smoothstep(0.0, 1.0, _rotation_elapsed / rotation_duration)
	logo_assembly.rotation.y = lerpf(_rotation_start, _rotation_target, normalized)
	if is_equal_approx(_rotation_elapsed, rotation_duration):
		_finish_rotation()


func normalized_detent_angle() -> float:
	return fposmod(logo_assembly.rotation.y, TAU) if logo_assembly != null else 0.0


func queued_step_count() -> int:
	return 0 if queued_direction == 0 else 1


func development_enter_active() -> void:
	if GameFlow.current_state != GameFlow.CHARACTER_SELECT_ENTER:
		GameFlow.development_jump_to_state(GameFlow.CHARACTER_SELECT_ENTER)
	_complete_entry()


func development_next_detent() -> void:
	if GameFlow.current_state != GameFlow.CHARACTER_SELECT_ACTIVE:
		development_enter_active()
	if request_rotation(1):
		advance_for_test(rotation_duration)


func development_replay_stats() -> bool:
	return presenter != null and presenter.replay_stats()


func _begin_rotation(direction: int) -> void:
	is_rotating = true
	selection_locked = true
	_rotation_elapsed = 0.0
	_rotation_start = logo_assembly.rotation.y
	_rotation_target = _rotation_start + float(direction) * LogoRevealController.DETENT_STEP_RADIANS
	target_index = posmod(current_index + direction, CHARACTER_DEFINITIONS.size())
	presenter.set_rotation_pending()
	rotation_started.emit(current_index, target_index)


func _finish_rotation() -> void:
	if not is_rotating:
		return
	current_index = target_index
	# Equivalent full turns are collapsed so long sessions cannot accumulate drift.
	logo_assembly.rotation.y = LogoRevealController.ENTRY_DETENT_RADIANS \
		+ float(current_index) * LogoRevealController.DETENT_STEP_RADIANS
	is_rotating = false
	rotation_settle_count += 1
	_focus_current_detent()
	detent_settled.emit(current_index, CHARACTER_DEFINITIONS[current_index].id)
	var next_direction := queued_direction
	queued_direction = 0
	if next_direction != 0 and GameFlow.current_state == GameFlow.CHARACTER_SELECT_ACTIVE:
		_begin_rotation(next_direction)
	else:
		selection_locked = confirmation_accepted
		presenter.set_navigation_enabled(not selection_locked)


func _focus_current_detent() -> void:
	var definition := CHARACTER_DEFINITIONS[current_index]
	for index: int in character_visuals.size():
		character_visuals[index].visible = index == current_index
	presenter.focus_definition(definition)
	if GameFlow.current_state == GameFlow.CHARACTER_SELECT_ACTIVE:
		GameFlow.set_selected_character(definition.id)


func _attach_character_presentations() -> void:
	character_visuals.clear()
	for index: int in CHARACTER_DEFINITIONS.size():
		var definition := CHARACTER_DEFINITIONS[index]
		var visual := definition.frontend_presentation_scene.instantiate() as CharacterVisual
		if visual == null or not visual.matches_definition(definition):
			if visual != null:
				visual.free()
			continue
		panel_anchors[index].add_child(visual)
		visual.name = "CharacterPresentation%d" % index
		# Anchors face outward; local -Z places the full body in front of the
		# extrusion instead of allowing the persistent logo to occlude it.
		visual.position = Vector3(0.0, -0.12, -1.05)
		visual.rotation.y = PI
		visual.scale = Vector3.ONE * 0.92
		visual.visible = false
		character_visuals.append(visual)


func _on_intent_requested(intent: StringName) -> void:
	if GameFlow.current_state != GameFlow.CHARACTER_SELECT_ACTIVE:
		return
	match intent:
		InputRouter.INTENT_LEFT:
			request_rotation(-1)
		InputRouter.INTENT_RIGHT:
			request_rotation(1)
		InputRouter.INTENT_CONFIRM:
			confirm_selection()


func _on_game_flow_state_changed(_previous: StringName, next: StringName) -> void:
	_apply_state(next)


func _apply_state(state: StringName) -> void:
	if not _configured:
		return
	match state:
		GameFlow.CHARACTER_SELECT_ENTER:
			GameFlow.set_frontend_selection_controller_active(false)
			selection_locked = true
			confirmation_accepted = false
			presenter.visible = false
			presenter.set_navigation_enabled(false)
			call_deferred("_complete_entry")
		GameFlow.CHARACTER_SELECT_ACTIVE:
			_activate_selection()
		GameFlow.CHARACTER_CONFIRMED:
			GameFlow.set_frontend_selection_controller_active(false)
			selection_locked = true
			confirmation_accepted = true
			presenter.visible = true
			presenter.set_navigation_enabled(false)
		_:
			GameFlow.set_frontend_selection_controller_active(false)
			selection_locked = true
			presenter.visible = false


func _complete_entry() -> void:
	if _configured and GameFlow.current_state == GameFlow.CHARACTER_SELECT_ENTER:
		GameFlow.request_transition(GameFlow.CHARACTER_SELECT_ACTIVE)


func _activate_selection() -> void:
	GameFlow.set_frontend_selection_controller_active(true)
	confirmation_accepted = false
	queued_direction = 0
	is_rotating = false
	current_index = clampi(GameFlow.selected_character_index, 0, CHARACTER_DEFINITIONS.size() - 1)
	target_index = current_index
	logo_assembly.rotation.y = LogoRevealController.ENTRY_DETENT_RADIANS \
		+ float(current_index) * LogoRevealController.DETENT_STEP_RADIANS
	presenter.visible = true
	selection_locked = false
	presenter.set_navigation_enabled(true)
	_focus_current_detent()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		queued_direction = 0
		if is_rotating:
			_finish_rotation()
