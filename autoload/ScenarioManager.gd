extends Node

## Reserved scenario lifecycle boundary. Scenario registration begins in Task 08.
var active_scenario_id: StringName = &""


func load_scenario(_scenario_id: StringName) -> bool:
	return false


func unload_active_scenario() -> void:
	pass


func begin_transition() -> void:
	pass


func complete_transition() -> void:
	pass
