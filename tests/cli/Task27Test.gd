extends Node

const MAIN_SCENE := preload("res://main/Main.tscn")
const BOULEVARD := preload("res://data/scenarios/boulevard.tres")
const SIERRA := preload("res://data/scenarios/sierra_nevada.tres")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameFlow.development_jump_to_state(GameFlow.BOOT)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var root: PresentationRoot = main.presentation_root
	var hud: RunnerHUD = main.hud
	var runner_id: int = main.runner.get_instance_id()
	var logo_id: int = main.logo_frontend.get_instance_id()

	ScenarioManager.load_scenario(BOULEVARD.id)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	await get_tree().process_frame
	_assert(hud.visible, "HUD did not reveal on the settled RUNNING edge.")
	_assert(hud.scenario_label.text.contains("BOULEVARD"), "Scenario loop did not bind the active scenario.")
	_assert(hud.coordinate_label.text.begins_with("X") and hud.coordinate_label.text.contains("Y") and hud.coordinate_label.text.contains("Z"), "Decorative coordinate loop has an invalid format.")
	_assert(_coordinates_within(hud.coordinate_label.text, HUDCoordinateProfile.fallback_for_scenario(BOULEVARD.id)), "Boulevard coordinates left the authored scenario range.")
	var coordinates_before := hud.coordinate_label.text
	hud._process(1.0)
	_assert(hud.coordinate_label.text != coordinates_before, "Decorative coordinate loop did not update.")

	for fixture: Dictionary in [
		{"size": Vector2(960, 720), "profile": RunnerHUD.Profile.FULL, "coordinates": true, "scenario": true},
		{"size": Vector2(620, 360), "profile": RunnerHUD.Profile.MEDIUM, "coordinates": false, "scenario": false},
		{"size": Vector2(360, 640), "profile": RunnerHUD.Profile.COMPACT, "coordinates": false, "scenario": false},
	]:
		hud.apply_available_size(fixture.size)
		_assert(hud.active_profile == fixture.profile, "HUD did not choose the richest fitting profile at %s." % fixture.size)
		_assert(hud.coordinate_panel.visible == fixture.coordinates and hud.scenario_panel.visible == fixture.scenario, "HUD optional visibility hierarchy is wrong at %s." % fixture.size)
		_assert(hud.score_label.visible and hud.timer_label.visible and hud.pause_button.visible, "Score, Time, or Pause disappeared at %s." % fixture.size)
		_assert(hud.pause_button.custom_minimum_size.x >= 56.0 and hud.pause_button.custom_minimum_size.y >= 56.0, "Pause target shrank below 56px.")

	ScenarioManager.load_scenario(SIERRA.id)
	_assert(hud.scenario_label.text.contains("SIERRA"), "Scenario loop did not rebind after a scenario load.")
	_assert(_coordinates_within(hud.coordinate_label.text, HUDCoordinateProfile.fallback_for_scenario(SIERRA.id)), "Sierra coordinates did not use its scenario range.")
	GameFlow.development_jump_to_state(GameFlow.PAUSED)
	await get_tree().process_frame
	_assert(hud.pause_overlay.visible and hud.pause_overlay.summary.visible and hud.pause_overlay.portraits.size() == 4 and hud.pause_overlay.back_button.visible, "Pause lost mandatory controls.")

	GameFlow.development_jump_to_state(GameFlow.RUN_INTRO)
	_assert(not hud.visible, "HUD is visible before RUN_INTRO has settled.")
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_assert(hud.visible, "HUD did not return after RUN_INTRO settled.")
	root.preview_layout(Vector2(360, 640), true, Vector4(16, 28, 16, 28))
	root.preview_layout(Vector2(960, 720), false)
	_assert(main.runner.get_instance_id() == runner_id and main.logo_frontend.get_instance_id() == logo_id, "Resize/safe-area updates recreated gameplay or frontend state.")
	_assert(FileAccess.get_file_as_string("res://ui/hud/HUD.gd").find("global_position") == -1, "HUD coordinates are coupled to player transforms.")

	main.queue_free()
	if failures.is_empty():
		print("TASK27_PASS")
		get_tree().quit(0)
	else:
		for message: String in failures:
			push_error(message)
		get_tree().quit(1)


func _coordinates_within(text: String, profile: HUDCoordinateProfile) -> bool:
	var values: Array[float] = []
	for line: String in text.split("\n"):
		values.append(float(line.substr(1).strip_edges()))
	return values.size() == 3 \
		and values[0] >= profile.minimum.x and values[0] <= profile.maximum.x \
		and values[1] >= profile.minimum.y and values[1] <= profile.maximum.y \
		and values[2] >= profile.minimum.z and values[2] <= profile.maximum.z


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
