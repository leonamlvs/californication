class_name ObstacleSceneLibrary
extends Resource

@export var definitions: Array[ObstacleDefinition] = []
@export var scenes: Array[PackedScene] = []


func is_valid_library() -> bool:
	if definitions.is_empty() or definitions.size() != scenes.size():
		return false
	var ids: Dictionary = {}
	for index: int in definitions.size():
		var definition := definitions[index]
		if definition == null or not definition.is_valid_definition() or scenes[index] == null or ids.has(definition.id):
			return false
		ids[definition.id] = true
	return true


func scene_for(obstacle_id: StringName) -> PackedScene:
	for index: int in definitions.size():
		if definitions[index] != null and definitions[index].id == obstacle_id:
			return scenes[index]
	return null
