class_name IslandFrontendController
extends Node3D

signal blue_handoff_ready()

@export_range(0.05, 3.0, 0.05, "suffix:s") var loading_duration := 2.0

@onready var frontend_camera: Camera3D = %FrontendCamera
@onready var blue_environment: WorldEnvironment = %BlueEnvironment
@onready var ocean: MeshInstance3D = %Ocean
@onready var loading_overlay: LoadingPresentation = %LoadingOverlay

var loading_elapsed := 0.0
var blue_handoff_is_ready := false
var _focus_active := true
var _environment_resource: Environment


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _environment_resource = blue_environment.environment
    GameFlow.state_changed.connect(_on_game_flow_state_changed)
    _apply_state(GameFlow.current_state)


func _exit_tree() -> void:
    if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
        GameFlow.state_changed.disconnect(_on_game_flow_state_changed)


func _process(delta: float) -> void:
    advance_for_test(delta)


func advance_for_test(delta: float) -> void:
    if delta <= 0.0 or not _focus_active or GameFlow.current_state != GameFlow.LOADING:
        return
    loading_elapsed = minf(loading_elapsed + delta, loading_duration)
    loading_overlay.set_progress(loading_elapsed / loading_duration)
    if is_equal_approx(loading_elapsed, loading_duration):
        GameFlow.request_transition(GameFlow.ISLAND_INTRO)


func development_preview_loading(normalized: float) -> void:
    GameFlow.development_jump_to_state(GameFlow.LOADING)
    set_process(false)
    loading_elapsed = clampf(normalized, 0.0, 1.0) * loading_duration
    loading_overlay.set_progress(clampf(normalized, 0.0, 1.0))


func active_group_count() -> int:
    return 0


func _on_game_flow_state_changed(_previous: StringName, next: StringName) -> void:
    _apply_state(next)


func _apply_state(state: StringName) -> void:
    blue_handoff_is_ready = false
    loading_overlay.visible = state == GameFlow.LOADING
    match state:
        GameFlow.LOADING:
            visible = true
            frontend_camera.current = true
            blue_environment.environment = _environment_resource
            loading_elapsed = 0.0
            loading_overlay.reset()
            ocean.hide()
        GameFlow.LOGO_REVEAL:
            # Blue cover matches LogoRevealController's first hidden-swap frame.
            visible = true
            frontend_camera.current = true
            blue_environment.environment = _environment_resource
            # The logo owns its solid blue plane; old ocean geometry can occlude it.
            ocean.hide()
            frontend_camera.position = Vector3(0.0, 2.0, 9.0)
            frontend_camera.fov = 72.0
            frontend_camera.look_at(Vector3.ZERO, Vector3.UP)
            blue_handoff_is_ready = true
            blue_handoff_ready.emit()
        GameFlow.ISLAND_INTRO, GameFlow.ISLAND_ATTRACT:
            visible = false
            frontend_camera.current = false
            blue_environment.environment = _environment_resource
            ocean.hide()
        _:
            visible = false
            frontend_camera.current = false
            blue_environment.environment = null
            ocean.hide()


func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
        _focus_active = false
    elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
        _focus_active = true
