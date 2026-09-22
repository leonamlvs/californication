class_name CharacterPresenter
extends Node
var current_definition:CharacterDefinition
var runner:RunnerController
var cosmetic:Node
func bind_runner(target:RunnerController)->void: runner=target
func apply_definition(definition:CharacterDefinition)->bool:
	if runner==null or definition==null or not definition.is_valid_definition(): return false
	if is_instance_valid(cosmetic): cosmetic.queue_free()
	cosmetic=definition.gameplay_cosmetic_scene.instantiate(); runner.cosmetic_mount.add_child(cosmetic); current_definition=definition; return true
