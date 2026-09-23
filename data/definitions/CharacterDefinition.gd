class_name CharacterDefinition
extends Resource

## Presentation-only identity data. Gameplay systems must never read decorative values.
const DECORATIVE_STAT_KEYS: Array[StringName] = [
	&"STRENGTH",
	&"STAMINA",
	&"AGILITY",
	&"CHARISMA",
	&"RHYTHM",
]

@export var id: StringName
@export var display_name := ""
@export var category_label := ""
@export var category_value := ""
@export_range(0.0, 100.0, 1.0) var decorative_category_value := 0.0
@export var decorative_stats: Dictionary[StringName, float] = {}
@export var gameplay_cosmetic_scene: PackedScene
@export var frontend_presentation_scene: PackedScene
@export var frontend_idle_key: StringName = &"idle"
@export var pause_portrait: Texture2D


func is_valid_definition() -> bool:
	if id.is_empty() or display_name.is_empty() or category_label.is_empty() or category_value.is_empty():
		return false
	if gameplay_cosmetic_scene == null or frontend_presentation_scene == null or frontend_idle_key.is_empty() or pause_portrait == null:
		return false
	if decorative_stats.size() != DECORATIVE_STAT_KEYS.size():
		return false
	if decorative_category_value < 0.0 or decorative_category_value > 100.0:
		return false
	for stat_key: StringName in DECORATIVE_STAT_KEYS:
		if not decorative_stats.has(stat_key):
			return false
		var value: float = decorative_stats[stat_key]
		if value < 0.0 or value > 100.0:
			return false
	return true


func decorative_value(stat_key: StringName) -> float:
	return decorative_stats.get(stat_key, 0.0)
