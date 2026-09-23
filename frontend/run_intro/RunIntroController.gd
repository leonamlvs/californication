class_name RunIntroController
extends Node

signal stage_changed(stage: Stage)
signal settled(character_id: StringName)
signal preparation_failed(reason: String)

enum Stage { IDLE, PUSH, HOLD, ORBIT, SETTLED }

const BOULEVARD := preload("res://data/scenarios/boulevard.tres")
const CHARACTERS: Array[CharacterDefinition] = [
	preload("res://data/characters/character_01.tres"),
	preload("res://data/characters/character_02.tres"),
	preload("res://data/characters/character_03.tres"),
	preload("res://data/characters/character_04.tres"),
]
const RUN_INTRO_FX := preload("res://data/cinematic_fx/run_intro_push.tres")

@export_range(0.1, 2.0, 0.05, "suffix:s") var push_duration := 0.45
@export_range(0.05, 2.0, 0.05, "suffix:s") var front_hold_duration := 0.28
@export_range(0.1, 3.0, 0.05, "suffix:s") var orbit_duration := 0.75
@export_range(15.0, 80.0, 1.0, "suffix:m") var safe_runway_distance := 35.0
@export var force_fx_fallback := false

var runner: RunnerController
var generator: TrackGenerator
var transition_coordinator: TransitionCoordinator
var scenario_root: Node3D
var gameplay_camera: Camera3D
var logo_frontend: LogoRevealController
var cinematic_fx: CinematicTransitionFX
var character_presenter: CharacterPresenter
var hud: RunnerHUD

var stage := Stage.IDLE
var stage_elapsed := 0.0
var is_active := false
var scenario_prepared := false
var camera_settled := false
var gameplay_ready := false
var selected_definition: CharacterDefinition
var source_visual: CharacterVisual
var _push_start_transform := Transform3D.IDENTITY
var _push_end_position := Vector3.ZERO
var _orbit_start_transform := Transform3D.IDENTITY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameFlow.state_changed.connect(_on_game_flow_state_changed)
	GameFlow.run_reset_requested.connect(_on_run_reset_requested)


func _exit_tree() -> void:
	if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.disconnect(_on_game_flow_state_changed)
	if GameFlow.run_reset_requested.is_connected(_on_run_reset_requested):
		GameFlow.run_reset_requested.disconnect(_on_run_reset_requested)


func _process(delta: float) -> void:
	advance_for_test(delta)


func configure_services(
	runner_service: RunnerController,
	generator_service: TrackGenerator,
	scenario_root_service: Node3D,
	gameplay_camera_service: Camera3D,
	logo_frontend_service: LogoRevealController,
	fx_service: CinematicTransitionFX,
	character_presenter_service: CharacterPresenter,
	hud_service: RunnerHUD = null,
	transition_service: TransitionCoordinator = null,
) -> void:
	runner = runner_service
	generator = generator_service
	scenario_root = scenario_root_service
	gameplay_camera = gameplay_camera_service
	logo_frontend = logo_frontend_service
	cinematic_fx = fx_service
	character_presenter = character_presenter_service
	hud = hud_service
	transition_coordinator = transition_service
	ScenarioManager.set_scenario_root(scenario_root)


func advance_for_test(delta: float) -> void:
	if not is_active or delta <= 0.0:
		return
	var remaining := delta
	while remaining > 0.0 and is_active:
		var duration := _duration_for_stage(stage)
		var step := minf(remaining, maxf(0.0, duration - stage_elapsed))
		stage_elapsed += step
		remaining -= step
		_update_stage(stage_elapsed / maxf(duration, 0.001))
		if is_equal_approx(stage_elapsed, duration):
			_advance_stage()
		elif step <= 0.0:
			break


func development_enter_run_intro() -> bool:
	if GameFlow.current_state != GameFlow.CHARACTER_CONFIRMED:
		GameFlow.development_jump_to_state(GameFlow.CHARACTER_CONFIRMED)
	if not scenario_prepared:
		_prepare_boulevard()
	return GameFlow.start_new_run()


func development_complete_run_intro() -> bool:
	if GameFlow.current_state != GameFlow.RUN_INTRO:
		return false
	_force_settled()
	return GameFlow.current_state == GameFlow.RUNNING


func composition_snapshot(viewport_size: Vector2) -> Dictionary:
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var distance_scale := clampf((4.0 / 3.0) / maxf(aspect, 0.5), 1.0, 1.45)
	return {
		"distance_scale": distance_scale,
		"character_inside_safe_region": aspect >= 0.5,
		"boulevard_inside_safe_region": aspect >= 0.5,
	}


func _on_run_reset_requested(target_scenario: StringName) -> void:
	if target_scenario == GameFlow.BOULEVARD_ID:
		_prepare_boulevard()


func _prepare_boulevard() -> bool:
	if runner == null or generator == null or scenario_root == null or gameplay_camera == null or character_presenter == null:
		preparation_failed.emit("Run Intro services are not configured.")
		return false
	if not ScenarioManager.load_scenario(BOULEVARD.id):
		preparation_failed.emit("Boulevard is not registered.")
		return false
	var definition := ScenarioManager.active_definition
	if definition == null or not generator.configure_for_scenario(definition):
		preparation_failed.emit("Boulevard generator configuration failed.")
		return false
	runner.movement_profile = definition.movement_profile
	if not runner.set_movement_mode(definition.movement_mode):
		preparation_failed.emit("Boulevard runner mode configuration failed.")
		return false
	runner.reset_for_run()
	if not character_presenter.apply_definition(_selected_definition()):
		preparation_failed.emit("Selected character presentation could not bind to the runner.")
		return false
	character_presenter.cosmetic.visible = false
	generator.set_runner(runner)
	generator.reset_generator(generator.deterministic_seed, 0.0, runner.current_speed)
	generator.prepare_safe_runway(safe_runway_distance)
	generator.set_suspended(true)
	runner.set_invulnerable(true)
	runner.set_movement_suspended(true)
	if transition_coordinator != null:
		transition_coordinator.configure_services(runner, generator, generator.run_stats, hud)
		transition_coordinator.begin_scenario(definition)
	selected_definition = _selected_definition()
	scenario_prepared = true
	gameplay_ready = _safe_runway_ready()
	return gameplay_ready


func _begin_run_intro() -> void:
	if not scenario_prepared and not _prepare_boulevard():
		return
	selected_definition = _selected_definition()
	gameplay_ready = _safe_runway_ready()
	if not gameplay_ready:
		preparation_failed.emit("Boulevard safe runway is not ready.")
		return
	is_active = true
	camera_settled = false
	stage = Stage.PUSH
	stage_elapsed = 0.0
	source_visual = _selected_frontend_visual()
	if source_visual == null:
		source_visual = character_presenter.cosmetic
		logo_frontend.begin_run_intro_presentation(false)
	else:
		logo_frontend.begin_run_intro_presentation(true)
	source_visual.visible = true
	_push_start_transform = logo_frontend.logo_camera.global_transform
	if source_visual == character_presenter.cosmetic:
		logo_frontend.logo_camera.global_transform = gameplay_camera.global_transform
		_push_start_transform = logo_frontend.logo_camera.global_transform
	var source_focus := source_visual.global_position + Vector3(0.0, 0.65, 0.0)
	_push_end_position = source_focus + Vector3(0.0, 0.10, 2.15)
	logo_frontend.logo_camera.current = true
	gameplay_camera.current = false
	if cinematic_fx != null:
		cinematic_fx.play(RUN_INTRO_FX, logo_frontend.logo_camera, CinematicTransitionFX.Quality.AUTO, force_fx_fallback)
	stage_changed.emit(stage)


func _update_stage(normalized: float) -> void:
	normalized = clampf(normalized, 0.0, 1.0)
	match stage:
		Stage.PUSH:
			var position := _push_start_transform.origin.lerp(_push_end_position, smoothstep(0.0, 1.0, normalized))
			logo_frontend.logo_camera.global_position = position
			logo_frontend.logo_camera.look_at(source_visual.global_position + Vector3(0.0, 0.65, 0.0), Vector3.UP)
			logo_frontend.set_player_select_fade(1.0 - normalized)
		Stage.HOLD:
			logo_frontend.set_player_select_fade(0.0)
		Stage.ORBIT:
			if normalized >= 0.45:
				character_presenter.cosmetic.visible = true
			if normalized >= 0.65 and source_visual != character_presenter.cosmetic:
				source_visual.visible = false
			logo_frontend.logo_camera.global_transform = _orbit_start_transform.interpolate_with(gameplay_camera.global_transform, smoothstep(0.0, 1.0, normalized))


func _advance_stage() -> void:
	match stage:
		Stage.PUSH:
			stage = Stage.HOLD
			stage_elapsed = 0.0
		Stage.HOLD:
			stage = Stage.ORBIT
			stage_elapsed = 0.0
			_orbit_start_transform = logo_frontend.logo_camera.global_transform
		Stage.ORBIT:
			_force_settled()
			return
	stage_changed.emit(stage)


func _force_settled() -> void:
	if GameFlow.current_state != GameFlow.RUN_INTRO:
		return
	if source_visual != null and source_visual != character_presenter.cosmetic:
		source_visual.visible = false
	character_presenter.cosmetic.visible = true
	logo_frontend.end_run_intro_presentation()
	gameplay_camera.current = true
	camera_settled = true
	stage = Stage.SETTLED
	stage_elapsed = 0.0
	if cinematic_fx != null and cinematic_fx.is_active:
		cinematic_fx.cancel(&"run_intro_settled")
	if GameFlow.report_run_intro_ready(camera_settled, gameplay_ready):
		is_active = false
		settled.emit(selected_definition.id)


func _safe_runway_ready() -> bool:
	return ScenarioManager.active_scenario_id == BOULEVARD.id \
		and not generator.active_segments.is_empty() \
		and generator.active_segments.front().pattern != null \
		and generator.active_segments.front().pattern.safe_fallback


func _selected_definition() -> CharacterDefinition:
	var index := clampi(GameFlow.selected_character_index, 0, CHARACTERS.size() - 1)
	return CHARACTERS[index]


func _selected_frontend_visual() -> CharacterVisual:
	if logo_frontend == null or logo_frontend.carousel_controller == null:
		return null
	var visuals := logo_frontend.carousel_controller.character_visuals
	var index := GameFlow.selected_character_index
	if index < 0 or index >= visuals.size():
		return null
	var visual := visuals[index]
	return visual if is_instance_valid(visual) and visual.matches_definition(_selected_definition()) else null


func _duration_for_stage(current_stage: Stage) -> float:
	match current_stage:
		Stage.PUSH:
			return push_duration
		Stage.HOLD:
			return front_hold_duration
		Stage.ORBIT:
			return orbit_duration
	return 0.001


func _on_game_flow_state_changed(previous: StringName, next_state: StringName) -> void:
	if next_state == GameFlow.CHARACTER_CONFIRMED:
		call_deferred("_start_confirmed_run")
	elif next_state == GameFlow.RUN_INTRO:
		_begin_run_intro()
	elif previous == GameFlow.RUN_INTRO and next_state == GameFlow.RUNNING:
		runner.set_invulnerable(false)
		runner.set_movement_suspended(false)
		generator.set_suspended(false)
	elif next_state != GameFlow.RUN_INTRO and is_active:
		is_active = false
		if cinematic_fx != null and cinematic_fx.is_active:
			cinematic_fx.cancel(&"run_intro_state_exit")


func _start_confirmed_run() -> void:
	if GameFlow.current_state == GameFlow.CHARACTER_CONFIRMED:
		GameFlow.start_new_run()


func _notification(what: int) -> void:
	if is_active and (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT):
		_force_settled()
