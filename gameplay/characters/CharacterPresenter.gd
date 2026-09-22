class_name CharacterPresenter
extends Node

signal definition_changed(definition: CharacterDefinition)

var current_definition: CharacterDefinition
var runner: RunnerController
var cosmetic: CharacterVisual
var frontend_presentation: CharacterVisual


func bind_runner(target: RunnerController) -> void:
	if runner == target:
		return
	if runner != null:
		runner.set_character_cosmetic_active(false)
	runner = target
	if runner != null:
		runner.set_character_cosmetic_active(is_instance_valid(cosmetic))


## Replaces presentation only. Runner state, collision, movement profile, score,
## scenario state, and generator state are intentionally outside this API.
func apply_definition(definition: CharacterDefinition) -> bool:
	if runner == null or definition == null or not definition.is_valid_definition():
		return false
	var replacement := _instantiate_visual(definition.gameplay_cosmetic_scene, definition)
	if replacement == null:
		return false
	var previous := cosmetic
	cosmetic = replacement
	runner.cosmetic_mount.add_child(cosmetic)
	runner.set_character_cosmetic_active(true)
	if is_instance_valid(previous):
		previous.queue_free()
	current_definition = definition
	definition_changed.emit(current_definition)
	return true


func replace_paused_cosmetic(definition: CharacterDefinition) -> bool:
	if GameFlow.current_state != GameFlow.PAUSED:
		return false
	return apply_definition(definition)


func create_frontend_presentation(parent: Node, definition: CharacterDefinition = null) -> CharacterVisual:
	var selected_definition := definition if definition != null else current_definition
	if parent == null or selected_definition == null or not selected_definition.is_valid_definition():
		return null
	var replacement := _instantiate_visual(selected_definition.frontend_presentation_scene, selected_definition)
	if replacement == null or not replacement.supports_idle(selected_definition.frontend_idle_key):
		if replacement != null:
			replacement.free()
		return null
	if is_instance_valid(frontend_presentation):
		frontend_presentation.queue_free()
	frontend_presentation = replacement
	parent.add_child(frontend_presentation)
	return frontend_presentation


func clear_presentations() -> void:
	if is_instance_valid(cosmetic):
		cosmetic.queue_free()
	if is_instance_valid(frontend_presentation):
		frontend_presentation.queue_free()
	cosmetic = null
	frontend_presentation = null
	current_definition = null
	if runner != null:
		runner.set_character_cosmetic_active(false)


func _instantiate_visual(scene: PackedScene, definition: CharacterDefinition) -> CharacterVisual:
	var instance := scene.instantiate() as CharacterVisual
	if instance == null or not instance.matches_definition(definition):
		if instance != null:
			instance.free()
		return null
	return instance
