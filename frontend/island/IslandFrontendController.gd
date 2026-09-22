class_name IslandFrontendController
extends Node3D

signal intro_stage_changed(stage_index: int, stage_id: StringName)
signal blue_handoff_ready()

const INTRO_STAGE_IDS: Array[StringName] = [&"vegetation_close", &"city_roads", &"landscape", &"california_island"]
const INTRO_STAGE_STARTS: Array[float] = [0.0, 0.24, 0.50, 0.73]
const CAMERA_POINTS: Array[Vector3] = [
	Vector3(0.0, 1.8, 7.0),
	Vector3(0.0, 4.2, 11.0),
	Vector3(0.0, 8.0, 15.5),
	Vector3(0.0, 12.0, 20.0),
	Vector3(0.0, 13.0, 22.0),
]
const CAMERA_FOV_POINTS: Array[float] = [52.0, 58.0, 64.0, 68.0, 70.0]

@export_range(0.05, 3.0, 0.05, "suffix:s") var loading_duration := 0.35
@export_range(2.0, 20.0, 0.1, "suffix:s") var intro_duration := 8.0
@export_range(0.1, 30.0, 0.1, "suffix:deg/s") var attract_rotation_speed_degrees := 5.0
@export var intro_fx_profile: CinematicFXProfile = preload("res://data/cinematic_fx/island_pullback.tres")
@export var cinematic_quality: CinematicTransitionFX.Quality = CinematicTransitionFX.Quality.AUTO

@onready var frontend_camera: Camera3D = %FrontendCamera
@onready var blue_environment: WorldEnvironment = %BlueEnvironment
@onready var close_vegetation: Node3D = %CloseVegetation
@onready var city_roads: Node3D = %CityRoads
@onready var landscape: Node3D = %Landscape
@onready var island_pivot: Node3D = %IslandPivot
@onready var ocean: MeshInstance3D = %Ocean
@onready var cinematic_fx: CinematicTransitionFX = %CinematicTransitionFX
@onready var loading_overlay: Control = %LoadingOverlay
@onready var loading_progress: ProgressBar = %LoadingProgress
@onready var attract_prompt: Control = %AttractPrompt

var intro_elapsed := 0.0
var loading_elapsed := 0.0
var intro_stage_index := -1
var intro_play_count := 0
var lod_swap_count := 0
var blue_handoff_is_ready := false
var _focus_active := true
var _composition_distance_scale := 1.0
var _environment_resource: Environment


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_environment_resource = blue_environment.environment
	GameFlow.state_changed.connect(_on_game_flow_state_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_composition(get_viewport().get_visible_rect().size)
	_apply_state(GameFlow.current_state)


func _exit_tree() -> void:
	if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.disconnect(_on_game_flow_state_changed)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)


func _process(delta: float) -> void:
	advance_for_test(delta)


## Deterministic stepping path used by Task 23 acceptance checks and stage preview.
func advance_for_test(delta: float) -> void:
	if delta <= 0.0 or not _focus_active:
		return
	match GameFlow.current_state:
		GameFlow.LOADING:
			loading_elapsed = minf(loading_elapsed + delta, loading_duration)
			loading_progress.value = loading_elapsed / loading_duration * 100.0
			if is_equal_approx(loading_elapsed, loading_duration):
				GameFlow.request_transition(GameFlow.ISLAND_INTRO)
		GameFlow.ISLAND_INTRO:
			intro_elapsed = minf(intro_elapsed + delta, intro_duration)
			_update_intro(intro_elapsed / intro_duration)
			if is_equal_approx(intro_elapsed, intro_duration):
				GameFlow.complete_island_intro()
		GameFlow.ISLAND_ATTRACT:
			island_pivot.rotate_y(deg_to_rad(attract_rotation_speed_degrees) * delta)


func development_enter_intro() -> void:
	GameFlow.development_jump_to_state(GameFlow.ISLAND_INTRO)


func development_enter_attract() -> void:
	GameFlow.development_jump_to_state(GameFlow.ISLAND_ATTRACT)


func development_replay_intro() -> void:
	if GameFlow.current_state == GameFlow.ISLAND_INTRO:
		_begin_intro()
	else:
		GameFlow.development_jump_to_state(GameFlow.ISLAND_INTRO)


func development_skip_stage() -> void:
	if GameFlow.current_state != GameFlow.ISLAND_INTRO:
		return
	var next_index := mini(intro_stage_index + 1, INTRO_STAGE_STARTS.size())
	if next_index >= INTRO_STAGE_STARTS.size():
		intro_elapsed = intro_duration
		_update_intro(1.0)
		GameFlow.complete_island_intro()
		return
	intro_elapsed = INTRO_STAGE_STARTS[next_index] * intro_duration
	_update_intro(INTRO_STAGE_STARTS[next_index])


func composition_snapshot(viewport_size: Vector2) -> Dictionary:
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var width_ratio := clampf(0.50 * minf(aspect / (4.0 / 3.0), 1.0), 0.28, 0.50)
	return {
		"focal_point": Vector2(0.5, 0.47),
		"island_width_ratio": width_ratio,
		"distance_scale": _distance_scale_for(viewport_size),
		"safe_readable": width_ratio <= 0.64,
	}


func active_group_count() -> int:
	var count := 0
	for group: Node3D in [close_vegetation, city_roads, landscape, island_pivot]:
		count += 1 if group.visible else 0
	return count


func _on_game_flow_state_changed(_previous: StringName, next: StringName) -> void:
	_apply_state(next)


func _apply_state(state: StringName) -> void:
	var frontend_active := state in [GameFlow.LOADING, GameFlow.ISLAND_INTRO, GameFlow.ISLAND_ATTRACT, GameFlow.LOGO_REVEAL]
	blue_environment.environment = _environment_resource if frontend_active else null
	loading_overlay.visible = state == GameFlow.LOADING
	attract_prompt.visible = state == GameFlow.ISLAND_ATTRACT
	blue_handoff_is_ready = false
	match state:
		GameFlow.LOADING:
			visible = true
			frontend_camera.current = true
			loading_elapsed = 0.0
			loading_progress.value = 0.0
			_set_all_groups_hidden()
			ocean.visible = false
		GameFlow.ISLAND_INTRO:
			visible = true
			frontend_camera.current = true
			_begin_intro()
		GameFlow.ISLAND_ATTRACT:
			visible = true
			frontend_camera.current = true
			_set_only_group(island_pivot)
			ocean.visible = true
			_apply_camera_pose(CAMERA_POINTS.back(), CAMERA_FOV_POINTS.back())
		GameFlow.LOGO_REVEAL:
			# Task 24 can mount its next scene group behind this near-solid blue frame.
			visible = true
			frontend_camera.current = true
			_set_all_groups_hidden()
			ocean.visible = true
			_apply_camera_pose(Vector3(0.0, 2.0, 9.0), 72.0)
			blue_handoff_is_ready = true
			blue_handoff_ready.emit()
		_:
			visible = false
			frontend_camera.current = false
			if cinematic_fx.is_active:
				cinematic_fx.cancel(&"frontend_state_exit")


func _begin_intro() -> void:
	intro_elapsed = 0.0
	intro_stage_index = -1
	intro_play_count += 1
	island_pivot.rotation.y = 0.0
	ocean.visible = true
	_update_intro(0.0)


func _update_intro(normalized: float) -> void:
	normalized = clampf(normalized, 0.0, 1.0)
	var next_stage := 0
	for index: int in INTRO_STAGE_STARTS.size():
		if normalized >= INTRO_STAGE_STARTS[index]:
			next_stage = index
	if next_stage != intro_stage_index:
		_set_intro_stage(next_stage)
	var segment := mini(int(floor(normalized * 4.0)), 3)
	var local_t := clampf(normalized * 4.0 - float(segment), 0.0, 1.0)
	var camera_position := CAMERA_POINTS[segment].lerp(CAMERA_POINTS[segment + 1], smoothstep(0.0, 1.0, local_t))
	var camera_fov := lerpf(CAMERA_FOV_POINTS[segment], CAMERA_FOV_POINTS[segment + 1], local_t)
	_apply_camera_pose(camera_position, camera_fov)


func _set_intro_stage(stage: int) -> void:
	intro_stage_index = clampi(stage, 0, INTRO_STAGE_IDS.size() - 1)
	var groups: Array[Node3D] = [close_vegetation, city_roads, landscape, island_pivot]
	_set_only_group(groups[intro_stage_index])
	if intro_stage_index > 0:
		lod_swap_count += 1
		cinematic_fx.play(intro_fx_profile, frontend_camera, cinematic_quality)
	intro_stage_changed.emit(intro_stage_index, INTRO_STAGE_IDS[intro_stage_index])


func _set_only_group(active_group: Node3D) -> void:
	for group: Node3D in [close_vegetation, city_roads, landscape, island_pivot]:
		group.visible = group == active_group


func _set_all_groups_hidden() -> void:
	for group: Node3D in [close_vegetation, city_roads, landscape, island_pivot]:
		group.visible = false


func _apply_camera_pose(base_position: Vector3, fov: float) -> void:
	frontend_camera.position = base_position * _composition_distance_scale
	frontend_camera.fov = fov
	frontend_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)


func _on_viewport_size_changed() -> void:
	_update_composition(get_viewport().get_visible_rect().size)
	if GameFlow.current_state == GameFlow.ISLAND_ATTRACT:
		_apply_camera_pose(CAMERA_POINTS.back(), CAMERA_FOV_POINTS.back())


func _update_composition(viewport_size: Vector2) -> void:
	_composition_distance_scale = _distance_scale_for(viewport_size)


func _distance_scale_for(viewport_size: Vector2) -> float:
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	return clampf((4.0 / 3.0) / maxf(aspect, 0.45), 1.0, 1.65)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focus_active = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focus_active = true
