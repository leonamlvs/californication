extends Node3D

const FIXTURE_A := preload("res://dev/fixtures/fixture_scenario_a.tres")
const FIXTURE_B := preload("res://dev/fixtures/fixture_scenario_b.tres")
const BOULEVARD := preload("res://data/scenarios/boulevard.tres")
const SIERRA := preload("res://data/scenarios/sierra_nevada.tres")
const BAY := preload("res://data/scenarios/san_francisco_bay.tres")
const SEQUOIA := preload("res://data/scenarios/sequoia.tres")
const FILMING_SETS := preload("res://data/scenarios/filming_sets.tres")
const GOLDEN_GATE := preload("res://data/scenarios/golden_gate.tres")
const HOLLYWOOD := preload("res://data/scenarios/hollywood.tres")
const GRASS := preload("res://data/scenarios/grass.tres")
const EARTHQUAKE := preload("res://data/scenarios/earthquake.tres")
const BLOCK_DEFINITION := preload("res://data/obstacles/block.tres")
const ISLAND_FRONTEND_SCENE := preload("res://frontend/island/IslandFrontend.tscn")
const LOGO_REVEAL_SCENE := preload("res://frontend/logo_reveal/LogoPresentationRig.tscn")
const CINEMATIC_FX_PROFILES: Array[CinematicFXProfile] = [
	preload("res://data/cinematic_fx/island_pullback.tres"),
	preload("res://data/cinematic_fx/run_intro_push.tres"),
]
const CHARACTERS: Array[CharacterDefinition] = [
	preload("res://data/characters/character_01.tres"),
	preload("res://data/characters/character_02.tres"),
	preload("res://data/characters/character_03.tres"),
	preload("res://data/characters/character_04.tres"),
]

@onready var runner: RunnerController = %Runner
@onready var generator: TrackGenerator = %TrackGenerator
@onready var coordinator: TransitionCoordinator = %TransitionCoordinator
@onready var hud: RunnerHUD = %HUD
@onready var scenario_root: Node3D = %ScenarioRoot
@onready var status_label: Label = %StatusLabel
@onready var camera_3d: Camera3D = %Camera3D
@onready var cinematic_fx: CinematicTransitionFX = %CinematicTransitionFX

var _layout_index := 0
var _speed_index := 0
var _message := "Boulevard and Task 08 fixture services ready."
var _speeds: Array[float] = [10.0, 13.0, 16.0]
var _character_presenter: CharacterPresenter
var _failure_coordinator: FailureCoordinator
var _fx_profile_index := 0
var _fx_quality := CinematicTransitionFX.Quality.DESKTOP
var _fx_force_fallback := false
var _island_preview: IslandFrontendController
var _logo_preview: LogoRevealController
var _run_intro_preview: RunIntroController


func _ready() -> void:
	ScenarioManager.reset_for_tests()
	ScenarioManager.set_scenario_root(scenario_root)
	ScenarioManager.register_scenario(BOULEVARD)
	ScenarioManager.register_scenario(SIERRA)
	ScenarioManager.register_scenario(BAY)
	ScenarioManager.register_scenario(SEQUOIA)
	ScenarioManager.register_scenario(FILMING_SETS)
	ScenarioManager.register_scenario(GOLDEN_GATE)
	ScenarioManager.register_scenario(HOLLYWOOD)
	ScenarioManager.register_scenario(GRASS)
	ScenarioManager.register_scenario(EARTHQUAKE)
	ScenarioManager.register_scenario(FIXTURE_A, true)
	ScenarioManager.register_scenario(FIXTURE_B, true)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	runner.development_simulation_enabled = true
	_character_presenter = CharacterPresenter.new()
	add_child(_character_presenter)
	_character_presenter.bind_runner(runner)
	_apply_selected_character(GameFlow.selected_character_id, GameFlow.selected_character_index)
	GameFlow.selected_character_changed.connect(_apply_selected_character)
	generator.set_runner(runner)
	hud.bind_run_stats(generator.run_stats)
	coordinator.configure_services(runner, generator, generator.run_stats, hud)
	_failure_coordinator = FailureCoordinator.new()
	add_child(_failure_coordinator)
	_failure_coordinator.configure_services(runner, generator, coordinator)
	_load_debug_scenario(BOULEVARD)
	_configure_fx_preview_from_command_line()


func _apply_selected_character(_character_id: StringName, selection_index: int) -> void:
	if _character_presenter != null and selection_index >= 0 and selection_index < CHARACTERS.size():
		_character_presenter.apply_definition(CHARACTERS[selection_index])


func _process(_delta: float) -> void:
	status_label.text = "State: %s  Scenario: %s  Mode: %s\nSpeed: %.1f  Invulnerable: %s  Input: %s  Suspended: %s\nScore: %d  Time: %s  Pools S/O/C/T: %d/%d/%d/%d\n%s" % [
		GameFlow.current_state,
		ScenarioManager.active_scenario_id,
		runner.current_movement_mode,
		runner.current_speed,
		runner.is_invulnerable,
		GameFlow.gameplay_input_enabled,
		generator.suspended,
		generator.run_stats.score,
		generator.run_stats.formatted_time(),
		generator.pool.available_segment_count(),
		generator.pool.available_obstacle_count(),
		generator.pool.available_collectible_count(),
		generator.pool.available_token_count(),
		_message,
	]


func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % _speeds.size()
	runner.current_speed = _speeds[_speed_index]
	_message = "Speed set to %.1f m/s." % runner.current_speed


func _on_obstacle_pressed() -> void:
	if generator.active_segments.is_empty():
		return
	var obstacle := generator.pool.acquire_obstacle(BLOCK_DEFINITION)
	obstacle.reset_for_spawn(runner.logical_forward_distance + 15.0, 1, runner.logical_forward_distance)
	generator.active_segments.front().active_obstacles.append(obstacle)
	_message = "Spawned BLOCK through the production pool."


func _on_layout_pressed() -> void:
	var layouts := generator.collectible_layout_library.layouts
	if layouts.is_empty():
		return
	var layout: CollectibleLayout = layouts[_layout_index % layouts.size()]
	_layout_index += 1
	_message = "%s %s." % [layout.id, "spawned" if generator.spawn_collectible_layout(layout) else "could not spawn"]


func _on_ready_pressed() -> void:
	_message = "Transition ready: %s." % coordinator.development_force_ready()


func _on_token_pressed() -> void:
	_message = "Token collected: %s." % coordinator.development_force_token_collection()


func _on_miss_pressed() -> void:
	_message = "Token missed/retry scheduled: %s." % coordinator.development_force_token_miss()


func _on_death_pressed() -> void:
	_message = "Failure presentation started: %s." % (_failure_coordinator != null and _failure_coordinator.begin_failure())


func _on_invulnerability_pressed() -> void:
	runner.set_invulnerable(not runner.is_invulnerable)
	_message = "Invulnerability toggled."


func _on_bonus_pressed() -> void:
	var awarded := generator.run_stats.award_transition_bonus(coordinator.transition_bonus_key(), 1000)
	_message = "Duplicate bonus accepted: %s (expected false after collection)." % awarded


func _on_complete_pressed() -> void:
	_message = "Fixture cinematic completed: %s." % coordinator.development_force_complete_cinematic()


func _on_skip_pressed() -> void:
	_on_complete_pressed()


func _on_cycle_pressed() -> void:
	var target := FIXTURE_B if ScenarioManager.active_scenario_id == FIXTURE_A.id else FIXTURE_A
	_load_debug_scenario(target)


func _on_sierra_pressed() -> void:
	_load_debug_scenario(SIERRA)


func _on_bay_pressed() -> void:
	_load_debug_scenario(BAY)


func _on_sequoia_pressed() -> void:
	_load_debug_scenario(SEQUOIA)


func _on_filming_sets_pressed() -> void:
	_load_debug_scenario(FILMING_SETS)

func _on_golden_gate_pressed() -> void:
	_load_debug_scenario(GOLDEN_GATE)
func _on_hollywood_pressed() -> void:
	_load_debug_scenario(HOLLYWOOD)
func _on_grass_pressed() -> void:
	_load_debug_scenario(GRASS)


func _load_debug_scenario(definition: ScenarioDefinition) -> void:
	if not ScenarioManager.load_scenario(definition.id):
		_message = "Could not load %s." % definition.display_name
		return
	runner.movement_profile = definition.movement_profile
	if not runner.set_movement_mode(definition.movement_mode):
		_message = "Could not install %s mode." % definition.movement_mode
		return
	runner.reset_for_run()
	if not generator.configure_for_scenario(definition):
		_message = "Could not configure generator for %s." % definition.display_name
		return
	generator.reset_generator(generator.deterministic_seed, 0.0, runner.current_speed)
	coordinator.begin_scenario(definition, true)
	if _failure_coordinator != null:
		_failure_coordinator.begin_scenario(definition)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_message = "Loaded %s." % definition.display_name


func _on_state_pressed() -> void:
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	_message = "Generic GameFlow development jump used for RUNNING."


func _on_collisions_pressed() -> void:
	get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
	_message = "Collision visibility: %s." % get_tree().debug_collisions_hint


func _on_fx_profile_pressed() -> void:
	_fx_profile_index = (_fx_profile_index + 1) % CINEMATIC_FX_PROFILES.size()
	_preview_cinematic_fx()


func _on_fx_quality_pressed() -> void:
	var qualities: Array[CinematicTransitionFX.Quality] = [
		CinematicTransitionFX.Quality.MOBILE_LOW,
		CinematicTransitionFX.Quality.DESKTOP,
		CinematicTransitionFX.Quality.HIGH,
	]
	var current_index := qualities.find(_fx_quality)
	_fx_quality = qualities[(current_index + 1) % qualities.size()]
	_preview_cinematic_fx()


func _on_fx_fallback_pressed() -> void:
	_fx_force_fallback = not _fx_force_fallback
	_preview_cinematic_fx()


func _preview_cinematic_fx() -> void:
	var profile := CINEMATIC_FX_PROFILES[_fx_profile_index]
	var started := cinematic_fx.play(profile, camera_3d, _fx_quality, _fx_force_fallback, true)
	_message = "FX %s | quality %s | %s | samples %d | started %s." % [
		profile.id,
		CinematicTransitionFX.Quality.keys()[_fx_quality],
		"FOV/overlay fallback" if _fx_force_fallback else "screen blur",
		cinematic_fx.active_sample_count,
		started,
	]


func _configure_fx_preview_from_command_line() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.has("--preview-fx"):
		return
	if arguments.has("--fx-mobile"):
		_fx_quality = CinematicTransitionFX.Quality.MOBILE_LOW
	elif arguments.has("--fx-high"):
		_fx_quality = CinematicTransitionFX.Quality.HIGH
	_fx_force_fallback = arguments.has("--fx-fallback")
	call_deferred("_preview_cinematic_fx")


func _ensure_island_preview() -> IslandFrontendController:
	if _island_preview == null:
		_island_preview = ISLAND_FRONTEND_SCENE.instantiate() as IslandFrontendController
		add_child(_island_preview)
	return _island_preview


func _on_island_intro_pressed() -> void:
	_ensure_island_preview().development_enter_intro()
	_message = "Entered Island Intro at the authored first stage."


func _on_island_attract_pressed() -> void:
	_ensure_island_preview().development_enter_attract()
	_message = "Entered indefinite Island Attract directly."


func _on_island_replay_pressed() -> void:
	_ensure_island_preview().development_replay_intro()
	_message = "Replaying Island Intro with the development override."


func _on_island_skip_stage_pressed() -> void:
	var preview := _ensure_island_preview()
	preview.development_skip_stage()
	_message = "Island stage: %s." % (preview.INTRO_STAGE_IDS[preview.intro_stage_index] if preview.intro_stage_index >= 0 else &"inactive")


func _ensure_logo_preview() -> LogoRevealController:
	if _logo_preview == null:
		_logo_preview = LOGO_REVEAL_SCENE.instantiate() as LogoRevealController
		add_child(_logo_preview)
	return _logo_preview


func _ensure_run_intro_preview() -> RunIntroController:
	if _run_intro_preview == null:
		_ensure_logo_preview()
		_run_intro_preview = RunIntroController.new()
		add_child(_run_intro_preview)
		_run_intro_preview.configure_services(runner, generator, scenario_root, camera_3d, _logo_preview, cinematic_fx, _character_presenter, hud, coordinator)
	return _run_intro_preview


func _on_logo_reveal_pressed() -> void:
	_ensure_island_preview()
	_ensure_logo_preview().development_enter_reveal()
	_message = "Entered Logo/Alicorn Reveal at the continuous blue handoff."


func _on_logo_stage_pressed() -> void:
	var preview := _ensure_logo_preview()
	preview.development_skip_stage()
	_message = "Logo stage: %s." % (preview.STAGE_IDS[preview.reveal_stage_index] if preview.reveal_stage_index >= 0 else &"inactive")


func _on_logo_complete_pressed() -> void:
	var preview := _ensure_logo_preview()
	preview.development_skip_reveal()
	_message = "Logo reveal parked at first detent: %s." % preview.parked_at_first_detent


func _on_player_select_pressed() -> void:
	_ensure_logo_preview().development_enter_player_select()
	_message = "Entered active Player Select directly."


func _on_player_detent_pressed() -> void:
	var preview := _ensure_logo_preview()
	preview.development_next_detent()
	_message = "Player Select detent: %d." % preview.carousel_controller.current_index


func _on_player_stats_pressed() -> void:
	var preview := _ensure_logo_preview()
	_message = "Stat animation replayed: %s." % preview.development_replay_stats()


func _on_run_intro_pressed() -> void:
	var logo := _ensure_logo_preview()
	logo.development_enter_player_select()
	GameFlow.development_jump_to_state(GameFlow.CHARACTER_CONFIRMED)
	_message = "Entered Boulevard Run Intro: %s." % _ensure_run_intro_preview().development_enter_run_intro()


func _on_run_intro_complete_pressed() -> void:
	_message = "Run Intro settled: %s." % _ensure_run_intro_preview().development_complete_run_intro()
