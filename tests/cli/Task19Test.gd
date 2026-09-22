extends Node

const RUNNER_SCENE := preload("res://gameplay/runner/Runner.tscn")
const CHARACTERS: Array[CharacterDefinition] = [
	preload("res://data/characters/character_01.tres"),
	preload("res://data/characters/character_02.tres"),
	preload("res://data/characters/character_03.tres"),
	preload("res://data/characters/character_04.tres"),
]
const GAMEPLAY_DEPENDENCY_ROOTS: Array[String] = [
	"res://gameplay/runner",
	"res://gameplay/obstacles",
	"res://gameplay/track",
	"res://gameplay/scoring",
	"res://gameplay/transitions",
]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_definitions()
	_validate_presentation_binding_and_safe_swap()
	_validate_retry_identity()
	_validate_stats_are_not_gameplay_dependencies()
	if failures.is_empty():
		print("TASK19_PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		get_tree().quit(1)


func _validate_definitions() -> void:
	var ids: Dictionary[StringName, bool] = {}
	var scenes: Dictionary[String, bool] = {}
	for definition: CharacterDefinition in CHARACTERS:
		_assert(definition.is_valid_definition(), "%s is not a complete character definition." % definition.resource_path)
		_assert(not ids.has(definition.id), "Character IDs are not unique.")
		ids[definition.id] = true
		var scene_path := definition.gameplay_cosmetic_scene.resource_path
		_assert(not scenes.has(scene_path), "%s does not have a distinct primitive scene." % definition.id)
		scenes[scene_path] = true
		_assert(definition.pause_portrait != null, "%s has no pause portrait." % definition.id)
		_assert(definition.frontend_idle_key == &"idle", "%s has no supported frontend idle key." % definition.id)
		_assert(definition.decorative_stats.size() == CharacterDefinition.DECORATIVE_STAT_KEYS.size(), "%s has incomplete decorative stats." % definition.id)
		for stat_key: StringName in CharacterDefinition.DECORATIVE_STAT_KEYS:
			_assert(definition.decorative_stats.has(stat_key), "%s is missing %s." % [definition.id, stat_key])


func _validate_presentation_binding_and_safe_swap() -> void:
	var runner := RUNNER_SCENE.instantiate() as RunnerController
	add_child(runner)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	runner.step_simulation(0.25)
	var presenter := CharacterPresenter.new()
	add_child(presenter)
	presenter.bind_runner(runner)
	var stats := RunStats.new()
	add_child(stats)
	stats.reset_for_fresh_run(runner.logical_forward_distance)
	stats.award_normal_pickup()

	var profile_before := runner.movement_profile
	var collision_before := (runner.collision_shape.shape as CapsuleShape3D).duplicate()
	var distance_before := runner.logical_forward_distance
	var speed_before := runner.current_speed
	var lane_before := runner.current_lane_index
	var position_before := runner.position
	var score_before := stats.score
	_assert(presenter.apply_definition(CHARACTERS[0]), "Initial gameplay presentation could not bind.")
	_assert(not runner.placeholder_body.visible, "Bound presentation did not replace the anonymous runner placeholder.")

	var frontend_root := Node3D.new()
	add_child(frontend_root)
	var frontend := presenter.create_frontend_presentation(frontend_root)
	_assert(frontend != null and frontend.matches_definition(CHARACTERS[0]), "Frontend presentation did not bind the gameplay definition.")
	_assert(frontend.character_id == presenter.cosmetic.character_id, "Frontend and gameplay identities do not match.")

	_assert(GameFlow.pause_run(), "Could not enter PAUSED for cosmetic replacement.")
	_assert(presenter.replace_paused_cosmetic(CHARACTERS[1]), "Pause-safe cosmetic replacement failed.")
	var collision_after := runner.collision_shape.shape as CapsuleShape3D
	_assert(runner.movement_profile == profile_before, "Cosmetic replacement changed the movement profile.")
	_assert(is_equal_approx(collision_after.radius, collision_before.radius) and is_equal_approx(collision_after.height, collision_before.height), "Cosmetic replacement changed collision geometry.")
	_assert(is_equal_approx(runner.logical_forward_distance, distance_before) and is_equal_approx(runner.current_speed, speed_before), "Cosmetic replacement reset run movement state.")
	_assert(runner.current_lane_index == lane_before and runner.position.is_equal_approx(position_before), "Cosmetic replacement moved the runner.")
	_assert(stats.score == score_before, "Cosmetic replacement changed score.")
	_assert(presenter.cosmetic.matches_definition(CHARACTERS[1]), "Pause swap installed the wrong identity.")


func _validate_retry_identity() -> void:
	GameFlow.development_jump_to_state(GameFlow.CHARACTER_SELECT_ACTIVE)
	_assert(GameFlow.set_selected_character(CHARACTERS[2].id), "Could not select a character identity.")
	var selected_before := GameFlow.selected_character_id
	GameFlow.development_jump_to_state(GameFlow.LAVA_GAME_OVER)
	_assert(GameFlow.choose_game_over(true), "Retry YES path was rejected.")
	_assert(GameFlow.current_state == GameFlow.RUN_INTRO, "Retry did not enter RUN_INTRO.")
	_assert(GameFlow.selected_character_id == selected_before, "Retry did not retain selected identity.")


func _validate_stats_are_not_gameplay_dependencies() -> void:
	for root_path: String in GAMEPLAY_DEPENDENCY_ROOTS:
		_scan_for_decorative_dependency(root_path)


func _scan_for_decorative_dependency(root_path: String) -> void:
	var directory := DirAccess.open(root_path)
	_assert(directory != null, "Could not inspect gameplay dependency root %s." % root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root_path.path_join(entry)
		if directory.current_is_dir():
			if not entry.begins_with("."):
				_scan_for_decorative_dependency(path)
		elif entry.get_extension() == "gd":
			var source := FileAccess.get_file_as_string(path)
			_assert(source.find("decorative_stats") == -1 and source.find("decorative_value(") == -1, "Gameplay code consumes decorative character data: %s" % path)
		entry = directory.get_next()
	directory.list_dir_end()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
