class_name LogoRevealController
extends Node3D

signal reveal_stage_changed(stage_index: int, stage_id: StringName)
signal reveal_completed(logo_instance_id: int)

const STAGE_IDS: Array[StringName] = [
	&"blue_handoff", &"logo_letters", &"alicorn_approach", &"alicorn_pass", &"selector_entry",
]
const STAGE_STARTS: Array[float] = [0.0, 0.12, 0.34, 0.57, 0.78]
const LETTER_TEXT := "CALIFORNICATION"
const ENTRY_DETENT_RADIANS := deg_to_rad(35.0)
const DETENT_STEP_RADIANS := TAU / 4.0

@export_range(2.0, 20.0, 0.1, "suffix:s") var reveal_duration := 7.5
@export_range(0.1, 4.0, 0.05) var narrow_composition_distance_scale := 1.45

@onready var blue_environment: WorldEnvironment = %BlueEnvironment
@onready var logo_camera: Camera3D = %LogoCamera
@onready var logo_assembly: Node3D = %LogoAssembly
@onready var logo_extrusion: CSGPolygon3D = %LogoExtrusion
@onready var panel_anchors: Array[Node3D] = [%PanelAnchor0, %PanelAnchor1, %PanelAnchor2, %PanelAnchor3]
@onready var letter_ring: Node3D = %LetterRing
@onready var alicorn: Node3D = %Alicorn
@onready var blue_handoff_plane: MeshInstance3D = %BlueHandoffPlane
@onready var carousel_controller: LogoCarouselController = %LogoCarouselController
@onready var player_select_presenter: PlayerSelectPresenter = %PlayerSelectPresenter

var reveal_elapsed := 0.0
var reveal_stage_index := -1
var reveal_play_count := 0
var hidden_swap_count := 0
var logo_instance_id := 0
var alicorn_passed_camera := false
var parked_at_first_detent := false
var _focus_active := true
var _composition_distance_scale := 1.0
var _environment_resource: Environment


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_environment_resource = blue_environment.environment
	logo_instance_id = logo_assembly.get_instance_id()
	_build_letter_geometry()
	carousel_controller.configure(logo_assembly, panel_anchors, player_select_presenter)
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


## Deterministic stepping path used by acceptance checks and DevHarness previews.
func advance_for_test(delta: float) -> void:
	if delta <= 0.0 or not _focus_active or GameFlow.current_state != GameFlow.LOGO_REVEAL:
		return
	reveal_elapsed = minf(reveal_elapsed + delta, reveal_duration)
	_update_reveal(reveal_elapsed / reveal_duration)
	if is_equal_approx(reveal_elapsed, reveal_duration):
		_complete_reveal()


func development_enter_reveal() -> void:
	if GameFlow.current_state == GameFlow.LOGO_REVEAL:
		_begin_reveal()
	else:
		GameFlow.development_jump_to_state(GameFlow.LOGO_REVEAL)


func development_skip_reveal() -> void:
	if GameFlow.current_state != GameFlow.LOGO_REVEAL:
		development_enter_reveal()
	reveal_elapsed = reveal_duration
	_update_reveal(1.0)
	_complete_reveal()


func development_skip_stage() -> void:
	if GameFlow.current_state != GameFlow.LOGO_REVEAL:
		return
	var next_index := mini(reveal_stage_index + 1, STAGE_STARTS.size() - 1)
	reveal_elapsed = STAGE_STARTS[next_index] * reveal_duration
	_update_reveal(STAGE_STARTS[next_index])


func composition_snapshot(viewport_size: Vector2) -> Dictionary:
	var scale := _distance_scale_for(viewport_size)
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var logo_width_ratio := clampf(0.50 / scale, 0.30, 0.55)
	return {
		"distance_scale": scale,
		"logo_width_ratio": logo_width_ratio,
		"logo_center": Vector2(0.5, 0.49),
		"letters_inside_safe_region": aspect >= 0.5 and logo_width_ratio <= 0.55,
		"alicorn_inside_safe_region": aspect >= 0.5,
		"panel_anchors_readable": scale <= narrow_composition_distance_scale + 0.01,
	}


func panel_anchor_count() -> int:
	return panel_anchors.size()


func handoff_blue_color() -> Color:
	return _environment_resource.background_color


func panel_anchor_detent(index: int) -> float:
	return ENTRY_DETENT_RADIANS + DETENT_STEP_RADIANS * float(posmod(index, panel_anchors.size()))


func _on_game_flow_state_changed(_previous: StringName, next: StringName) -> void:
	_apply_state(next)


func _apply_state(state: StringName) -> void:
	var frontend_active := state in [
		GameFlow.LOGO_REVEAL, GameFlow.CHARACTER_SELECT_ENTER,
		GameFlow.CHARACTER_SELECT_ACTIVE, GameFlow.CHARACTER_CONFIRMED,
	]
	var intro_active := state == GameFlow.RUN_INTRO
	visible = frontend_active or intro_active
	blue_environment.environment = _environment_resource if frontend_active else null
	logo_camera.current = frontend_active or intro_active
	if state == GameFlow.LOGO_REVEAL:
		_begin_reveal()
	elif state == GameFlow.CHARACTER_SELECT_ENTER:
		_park_selector_composition()
	elif state == GameFlow.CHARACTER_SELECT_ACTIVE or state == GameFlow.CHARACTER_CONFIRMED:
		visible = true
		logo_camera.current = true
	elif state == GameFlow.RUN_INTRO:
		# RunIntroController owns the visual handoff once the run reset has completed.
		visible = true
	else:
		blue_handoff_plane.visible = false


## Keeps the selected carousel visual in-place while stripping the selector's
## surrounding UI and logo meshes for the continuous front-character push.
func begin_run_intro_presentation(_uses_frontend_visual: bool) -> void:
	visible = true
	blue_environment.environment = null
	logo_camera.current = true
	blue_handoff_plane.visible = false
	logo_extrusion.visible = false
	letter_ring.visible = false
	alicorn.visible = false
	for anchor: Node3D in panel_anchors:
		var surface := anchor.get_node_or_null("PanelSurface") as MeshInstance3D
		if surface != null:
			surface.visible = false
	player_select_presenter.visible = true
	set_player_select_fade(1.0)


func set_player_select_fade(alpha: float) -> void:
	player_select_presenter.root_control.modulate.a = clampf(alpha, 0.0, 1.0)


func end_run_intro_presentation() -> void:
	set_player_select_fade(1.0)
	player_select_presenter.visible = false
	logo_assembly.visible = false


func _restore_selector_meshes() -> void:
	logo_extrusion.visible = true
	for anchor: Node3D in panel_anchors:
		var surface := anchor.get_node_or_null("PanelSurface") as MeshInstance3D
		if surface != null:
			surface.visible = true


func _begin_reveal() -> void:
	visible = true
	logo_camera.current = true
	reveal_elapsed = 0.0
	reveal_stage_index = -1
	reveal_play_count += 1
	hidden_swap_count += 1
	alicorn_passed_camera = false
	parked_at_first_detent = false
	logo_assembly.visible = false
	_restore_selector_meshes()
	letter_ring.visible = false
	alicorn.visible = false
	blue_handoff_plane.visible = true
	logo_assembly.rotation = Vector3(0.0, -1.15, 0.0)
	logo_assembly.scale = Vector3.ONE * 0.36
	_apply_camera_pose(Vector3(0.0, 0.3, 10.5), 66.0)
	_set_stage(0)


func _update_reveal(normalized: float) -> void:
	normalized = clampf(normalized, 0.0, 1.0)
	var next_stage := 0
	for index: int in STAGE_STARTS.size():
		if normalized >= STAGE_STARTS[index]:
			next_stage = index
	if next_stage != reveal_stage_index:
		_set_stage(next_stage)

	var reveal_t := smoothstep(STAGE_STARTS[1], 0.36, normalized)
	logo_assembly.scale = Vector3.ONE * lerpf(0.36, 1.0, reveal_t)
	letter_ring.scale = Vector3.ONE * lerpf(0.55, 1.0, reveal_t)
	var logo_rotation_t := smoothstep(0.15, 1.0, normalized)
	logo_assembly.rotation.y = lerp_angle(-1.15, ENTRY_DETENT_RADIANS, logo_rotation_t)
	letter_ring.rotation.z = lerpf(-0.22, 0.0, reveal_t)

	if normalized >= STAGE_STARTS[2]:
		var flight_t := inverse_lerp(STAGE_STARTS[2], 0.82, normalized)
		flight_t = clampf(flight_t, 0.0, 1.0)
		var start := Vector3(-4.8, 2.4, -12.0)
		var control := Vector3(0.2, 1.0, 3.5)
		# The flight must pass the actual camera, including portrait pullback.
		var finish := Vector3(6.2, 4.0, maxf(16.5, logo_camera.position.z + 6.0))
		alicorn.position = _quadratic_bezier(start, control, finish, flight_t)
		alicorn.scale = Vector3.ONE * lerpf(0.18, 1.15, sin(flight_t * PI))
		alicorn.rotation = Vector3(0.0, lerpf(-0.18, 0.38, flight_t), lerpf(-0.12, 0.18, flight_t))
		if alicorn.position.z >= logo_camera.position.z:
			alicorn_passed_camera = true

	var camera_t := smoothstep(0.72, 1.0, normalized)
	var camera_position := Vector3(0.0, 0.3, 10.5).lerp(Vector3(0.0, 0.15, 9.2), camera_t)
	_apply_camera_pose(camera_position, lerpf(66.0, 58.0, camera_t))


func _set_stage(stage: int) -> void:
	reveal_stage_index = clampi(stage, 0, STAGE_IDS.size() - 1)
	match reveal_stage_index:
		0:
			blue_handoff_plane.visible = true
			logo_assembly.visible = false
			letter_ring.visible = false
			alicorn.visible = false
		1:
			blue_handoff_plane.visible = false
			logo_assembly.visible = true
			letter_ring.visible = true
		2, 3:
			alicorn.visible = true
		4:
			alicorn.visible = false
	reveal_stage_changed.emit(reveal_stage_index, STAGE_IDS[reveal_stage_index])


func _complete_reveal() -> void:
	if GameFlow.current_state != GameFlow.LOGO_REVEAL:
		return
	_park_selector_composition()
	reveal_completed.emit(logo_instance_id)
	GameFlow.request_transition(GameFlow.CHARACTER_SELECT_ENTER)


func _park_selector_composition() -> void:
	visible = true
	logo_camera.current = true
	blue_handoff_plane.visible = false
	logo_assembly.visible = true
	_restore_selector_meshes()
	letter_ring.visible = true
	alicorn.visible = false
	logo_assembly.scale = Vector3.ONE
	logo_assembly.rotation = Vector3(0.0, ENTRY_DETENT_RADIANS, 0.0)
	letter_ring.scale = Vector3.ONE
	letter_ring.rotation = Vector3.ZERO
	_apply_camera_pose(Vector3(0.0, 0.15, 9.2), 58.0)
	parked_at_first_detent = true


func _build_letter_geometry() -> void:
	if letter_ring.get_child_count() > 0:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.98, 1.0)
	material.metallic = 0.08
	material.roughness = 0.52
	var count := LETTER_TEXT.length()
	for index: int in count:
		var angle := lerpf(-2.22, 2.22, float(index) / float(count - 1))
		var mesh := TextMesh.new()
		mesh.text = LETTER_TEXT.substr(index, 1)
		mesh.depth = 0.16
		mesh.font_size = 48
		mesh.material = material
		var letter := MeshInstance3D.new()
		letter.name = "Letter%02d_%s" % [index, mesh.text]
		letter.mesh = mesh
		letter.position = Vector3(sin(angle) * 3.45, cos(angle) * 2.55, 0.05)
		letter.rotation.z = -angle
		letter.scale = Vector3.ONE * 1.15
		letter_ring.add_child(letter)


func _quadratic_bezier(start: Vector3, control: Vector3, finish: Vector3, t: float) -> Vector3:
	var inverse := 1.0 - t
	return inverse * inverse * start + 2.0 * inverse * t * control + t * t * finish


func _apply_camera_pose(base_position: Vector3, fov: float) -> void:
	logo_camera.position = base_position * _composition_distance_scale
	logo_camera.fov = fov
	logo_camera.look_at(Vector3(0.0, 0.15, 0.0), Vector3.UP)


func _on_viewport_size_changed() -> void:
	_update_composition(get_viewport().get_visible_rect().size)
	if GameFlow.current_state == GameFlow.CHARACTER_SELECT_ENTER:
		_park_selector_composition()
	elif GameFlow.current_state == GameFlow.LOGO_REVEAL:
		_update_reveal(reveal_elapsed / reveal_duration)


func _update_composition(viewport_size: Vector2) -> void:
	_composition_distance_scale = _distance_scale_for(viewport_size)
	if is_instance_valid(player_select_presenter):
		player_select_presenter.apply_available_size(viewport_size)


func apply_composition_size(viewport_size: Vector2) -> void:
	_update_composition(viewport_size)
	if GameFlow.current_state in [GameFlow.CHARACTER_SELECT_ENTER, GameFlow.CHARACTER_SELECT_ACTIVE, GameFlow.CHARACTER_CONFIRMED]:
		_apply_camera_pose(Vector3(0.0, 0.15, 9.2), 58.0)


func development_enter_player_select() -> void:
	carousel_controller.development_enter_active()


func development_next_detent() -> void:
	carousel_controller.development_next_detent()


func development_replay_stats() -> bool:
	return carousel_controller.development_replay_stats()


func _distance_scale_for(viewport_size: Vector2) -> float:
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	return clampf((4.0 / 3.0) / maxf(aspect, 0.5), 1.0, narrow_composition_distance_scale)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focus_active = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focus_active = true
