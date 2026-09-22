class_name TransitionDefinition
extends Resource

enum NextScenarioPolicy {
	SHUFFLE,
	EXPLICIT,
}

@export var id: StringName
@export var source_scenario: StringName
@export var transition_scene: PackedScene
@export var next_scenario_policy: NextScenarioPolicy = NextScenarioPolicy.SHUFFLE
@export var next_scenario_ids: Array[StringName] = []
@export var optional_camera_profile: Resource
@export_range(0, 10000, 10, "suffix: pts") var transition_bonus_score := 1000


func is_valid_definition() -> bool:
	if id.is_empty() or source_scenario.is_empty() or transition_scene == null or transition_bonus_score < 0:
		return false
	if next_scenario_policy == NextScenarioPolicy.EXPLICIT and next_scenario_ids.is_empty():
		return false
	return true
