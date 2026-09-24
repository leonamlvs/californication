extends Node

signal scenario_loaded(definition: ScenarioDefinition)
signal scenario_unloaded(scenario_id: StringName)
signal transition_began(source_scenario_id: StringName)
signal transition_completed(source_scenario_id: StringName, target_scenario_id: StringName)

var active_scenario_id: StringName = &""
var active_definition: ScenarioDefinition
var transition_in_progress := false

var _registry: Dictionary = {}
var _production_ids: Array[StringName] = []
var _development_ids: Array[StringName] = []
var _production_shuffle := ShuffleBag.new()
var _scenario_root: Node
var _active_environment: Node


func set_scenario_root(root: Node) -> void:
	_scenario_root = root


func register_scenario(definition: ScenarioDefinition, development_fixture := false) -> bool:
	if definition == null or not definition.is_valid_definition(development_fixture):
		return false
	_registry[definition.id] = definition
	var target := _development_ids if development_fixture else _production_ids
	if not target.has(definition.id):
		target.append(definition.id)
	return true


func unregister_development_fixtures() -> void:
	for scenario_id: StringName in _development_ids:
		_registry.erase(scenario_id)
	_development_ids.clear()


func production_scenario_ids() -> Array[StringName]:
	return _production_ids.duplicate()


func development_scenario_ids() -> Array[StringName]:
	return _development_ids.duplicate()


func configure_production_shuffle(scenario_ids: Array[StringName], seed_value: int) -> bool:
	for scenario_id: StringName in scenario_ids:
		if not _production_ids.has(scenario_id):
			return false
	_production_shuffle.configure(scenario_ids, seed_value)
	return true


func begin_production_run(seed_value: int = 0) -> bool:
	var boulevard_id: StringName = &"boulevard"
	if not _production_ids.has(boulevard_id):
		return false
	var post_opening: Array[StringName] = []
	for scenario_id: StringName in _production_ids:
		if scenario_id != boulevard_id:
			post_opening.append(scenario_id)
	if post_opening.size() != 8 or not configure_production_shuffle(post_opening, seed_value):
		return false
	return load_scenario(boulevard_id)


func load_scenario(scenario_id: StringName) -> bool:
	var definition: ScenarioDefinition = _registry.get(scenario_id)
	if definition == null:
		return false
	if not active_scenario_id.is_empty():
		unload_active_scenario()
	active_definition = definition
	active_scenario_id = definition.id
	if _scenario_root != null and definition.environment_scene != null:
		_active_environment = definition.environment_scene.instantiate()
		_scenario_root.add_child(_active_environment)
	scenario_loaded.emit(definition)
	return true


func unload_active_scenario() -> void:
	transition_in_progress = false
	if active_scenario_id.is_empty():
		return
	var previous_id := active_scenario_id
	if is_instance_valid(_active_environment):
		_active_environment.queue_free()
	_active_environment = null
	active_definition = null
	active_scenario_id = &""
	scenario_unloaded.emit(previous_id)


func begin_transition() -> bool:
	if active_definition == null or transition_in_progress:
		return false
	transition_in_progress = true
	transition_began.emit(active_scenario_id)
	return true


func complete_transition() -> bool:
	if not transition_in_progress or active_definition == null:
		return false
	var source_id := active_scenario_id
	var target_id := _select_next_scenario(active_definition.transition_definition)
	if target_id.is_empty() or not load_scenario(target_id):
		return false
	transition_in_progress = false
	transition_completed.emit(source_id, target_id)
	return true


func active_environment_has_gameplay_entities() -> bool:
	if not is_instance_valid(_active_environment):
		return false
	return not _active_environment.find_children("*", "RunnerController", true, false).is_empty() \
		or not _active_environment.find_children("*", "ObstacleBase", true, false).is_empty() \
		or not _active_environment.find_children("*", "CollectibleBase", true, false).is_empty() \
		or not _active_environment.find_children("*", "TransitionToken", true, false).is_empty()


func reset_for_tests() -> void:
	unload_active_scenario()
	transition_in_progress = false
	_registry.clear()
	_production_ids.clear()
	_development_ids.clear()
	_production_shuffle.configure([], 0)


func _select_next_scenario(definition: TransitionDefinition) -> StringName:
	if definition == null:
		return &""
	if definition.next_scenario_policy == TransitionDefinition.NextScenarioPolicy.EXPLICIT:
		for scenario_id: StringName in definition.next_scenario_ids:
			if _registry.has(scenario_id):
				return scenario_id
		return &""
	return _production_shuffle.draw(active_scenario_id)
