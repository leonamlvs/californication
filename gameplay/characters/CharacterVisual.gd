class_name CharacterVisual
extends Node3D

## Identity marker shared by gameplay and frontend primitive instances.
## This script deliberately exposes no gameplay attributes.
@export var character_id: StringName
@export var supported_idle_key: StringName = &"idle"


func matches_definition(definition: CharacterDefinition) -> bool:
	return definition != null and character_id == definition.id


func supports_idle(idle_key: StringName) -> bool:
	return not idle_key.is_empty() and idle_key == supported_idle_key
