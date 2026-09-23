class_name PlayerSelectPresenter
extends CanvasLayer

signal rotation_requested(direction: int)
signal confirm_requested()

const CATEGORY_KEY: StringName = &"CATEGORY"
const VALUE_KEYS: Array[StringName] = [
	CATEGORY_KEY, &"STRENGTH", &"STAMINA", &"AGILITY", &"CHARISMA", &"RHYTHM",
]

@export_range(0.1, 2.0, 0.05, "suffix:s") var stat_animation_duration := 0.75

@onready var root_control: Control = %RootControl
@onready var title_label: Label = %TitleLabel
@onready var name_label: Label = %NameLabel
@onready var category_label: Label = %CategoryLabel
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var stats_rows: VBoxContainer = %StatsRows
@onready var left_arrow: Button = %LeftArrow
@onready var right_arrow: Button = %RightArrow
@onready var select_button: Button = %SelectButton

var current_definition: CharacterDefinition
var displayed_values: Dictionary[StringName, float] = {}
var target_values: Dictionary[StringName, float] = {}
var focus_change_count := 0
var stat_replay_count := 0
var stats_animating := false
var _stat_elapsed := 0.0
var _value_labels: Dictionary[StringName, Label] = {}
var _bars: Dictionary[StringName, ProgressBar] = {}
var _available_size := Vector2(960.0, 720.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_stat_rows()
	left_arrow.pressed.connect(func() -> void: rotation_requested.emit(-1))
	right_arrow.pressed.connect(func() -> void: rotation_requested.emit(1))
	select_button.pressed.connect(func() -> void: confirm_requested.emit())
	apply_available_size(get_viewport().get_visible_rect().size)
	visible = false


func _process(delta: float) -> void:
	advance_for_test(delta)


func focus_definition(definition: CharacterDefinition) -> bool:
	if definition == null or not definition.is_valid_definition():
		return false
	current_definition = definition
	focus_change_count += 1
	name_label.text = definition.display_name.to_upper()
	category_label.text = "%s  %s" % [definition.category_label, definition.category_value]
	_reset_stat_animation()
	return true


func replay_stats() -> bool:
	if current_definition == null:
		return false
	stat_replay_count += 1
	_reset_stat_animation()
	return true


func advance_for_test(delta: float) -> void:
	if delta <= 0.0 or not stats_animating:
		return
	_stat_elapsed = minf(_stat_elapsed + delta, stat_animation_duration)
	var normalized := smoothstep(0.0, 1.0, _stat_elapsed / stat_animation_duration)
	for key: StringName in VALUE_KEYS:
		_set_displayed_value(key, target_values.get(key, 0.0) * normalized)
	if is_equal_approx(_stat_elapsed, stat_animation_duration):
		stats_animating = false


func set_navigation_enabled(enabled: bool) -> void:
	left_arrow.disabled = not enabled
	right_arrow.disabled = not enabled
	select_button.disabled = not enabled


func set_rotation_pending() -> void:
	# Arrows stay live so every device may use the same one-step bounded queue;
	# confirmation remains unavailable until an exact detent is reached.
	left_arrow.disabled = false
	right_arrow.disabled = false
	select_button.disabled = true


func displayed_value(key: StringName) -> float:
	return displayed_values.get(key, 0.0)


func target_value(key: StringName) -> float:
	return target_values.get(key, 0.0)


func values_are_at_zero() -> bool:
	for key: StringName in VALUE_KEYS:
		if not is_zero_approx(displayed_value(key)):
			return false
	return true


func values_reached_targets() -> bool:
	for key: StringName in VALUE_KEYS:
		if not is_equal_approx(displayed_value(key), target_value(key)):
			return false
	return true


func apply_available_size(available_size: Vector2) -> void:
	_available_size = available_size.max(Vector2.ONE)
	var aspect := _available_size.x / _available_size.y
	var narrow := aspect < 0.82
	_set_anchored_rect(title_label, Rect2(0.20, 0.06, 0.60, 0.07))
	if narrow:
		_set_anchored_rect(stats_panel, Rect2(0.08, 0.55, 0.84, 0.30))
		_set_anchored_rect(%IdentityPanel, Rect2(0.12, 0.14, 0.76, 0.14))
		_set_arrow_layout(0.05, 0.34, 0.95, 0.34)
		_set_anchored_rect(select_button, Rect2(0.34, 0.865, 0.32, 0.07))
	else:
		_set_anchored_rect(stats_panel, Rect2(0.67, 0.40, 0.29, 0.38))
		_set_anchored_rect(%IdentityPanel, Rect2(0.23, 0.14, 0.54, 0.13))
		_set_arrow_layout(0.04, 0.30, 0.96, 0.30)
		_set_anchored_rect(select_button, Rect2(0.41, 0.855, 0.18, 0.08))


func layout_snapshot(available_size: Vector2) -> Dictionary:
	var safe_rect := Rect2(available_size * Vector2(0.04, 0.06), available_size * Vector2(0.92, 0.88))
	var narrow := available_size.x / maxf(available_size.y, 1.0) < 0.82
	var stats_rect := Rect2(
		available_size * (Vector2(0.08, 0.55) if narrow else Vector2(0.67, 0.40)),
		available_size * (Vector2(0.84, 0.30) if narrow else Vector2(0.29, 0.38))
	)
	var title_rect := Rect2(available_size * Vector2(0.20, 0.06), available_size * Vector2(0.60, 0.07))
	var identity_rect := Rect2(
		available_size * (Vector2(0.12, 0.14) if narrow else Vector2(0.23, 0.14)),
		available_size * (Vector2(0.76, 0.14) if narrow else Vector2(0.54, 0.13))
	)
	var select_rect := Rect2(
		available_size * (Vector2(0.34, 0.865) if narrow else Vector2(0.41, 0.855)),
		available_size * (Vector2(0.32, 0.07) if narrow else Vector2(0.18, 0.08))
	)
	var arrow_size := Vector2(72.0, 72.0).min(available_size * Vector2(0.2, 0.2))
	return {
		"narrow": narrow,
		"safe_rect": safe_rect,
		"stats_rect": stats_rect,
		"arrow_size": arrow_size,
		"mandatory_inside": safe_rect.encloses(stats_rect) and safe_rect.encloses(title_rect) \
			and safe_rect.encloses(identity_rect) and safe_rect.encloses(select_rect) \
			and arrow_size.x >= 56.0 and arrow_size.y >= 56.0,
	}


func _reset_stat_animation() -> void:
	target_values.clear()
	target_values[CATEGORY_KEY] = current_definition.decorative_category_value
	for key: StringName in CharacterDefinition.DECORATIVE_STAT_KEYS:
		target_values[key] = current_definition.decorative_value(key)
	_stat_elapsed = 0.0
	stats_animating = true
	for key: StringName in VALUE_KEYS:
		_set_displayed_value(key, 0.0)


func _set_displayed_value(key: StringName, value: float) -> void:
	displayed_values[key] = value
	if _bars.has(key):
		_bars[key].value = value
	if _value_labels.has(key):
		_value_labels[key].text = "%.1f" % value


func _build_stat_rows() -> void:
	if stats_rows.get_child_count() > 1:
		return
	for key: StringName in VALUE_KEYS:
		var row := HBoxContainer.new()
		row.name = "%sRow" % String(key).to_pascal_case()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.custom_minimum_size = Vector2(92.0, 22.0)
		label.text = "INSTRUMENT" if key == CATEGORY_KEY else String(key)
		label.add_theme_font_size_override("font_size", 13)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(105.0, 18.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = 100.0
		bar.show_percentage = false
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(42.0, 22.0)
		value_label.text = "0.0"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(label)
		row.add_child(bar)
		row.add_child(value_label)
		stats_rows.add_child(row)
		_bars[key] = bar
		_value_labels[key] = value_label
		displayed_values[key] = 0.0


func _set_arrow_layout(left_x: float, y: float, right_x: float, right_y: float) -> void:
	left_arrow.anchor_left = left_x
	left_arrow.anchor_right = left_x
	left_arrow.anchor_top = y
	left_arrow.anchor_bottom = y
	left_arrow.offset_left = 0.0
	left_arrow.offset_top = 0.0
	left_arrow.offset_right = 72.0
	left_arrow.offset_bottom = 72.0
	right_arrow.anchor_left = right_x
	right_arrow.anchor_right = right_x
	right_arrow.anchor_top = right_y
	right_arrow.anchor_bottom = right_y
	right_arrow.offset_left = -72.0
	right_arrow.offset_top = 0.0
	right_arrow.offset_right = 0.0
	right_arrow.offset_bottom = 72.0


func _set_anchored_rect(control: Control, normalized: Rect2) -> void:
	control.anchor_left = normalized.position.x
	control.anchor_top = normalized.position.y
	control.anchor_right = normalized.end.x
	control.anchor_bottom = normalized.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
