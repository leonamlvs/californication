class_name PresentationRoot
extends Control

## Owns frame policy and safe presentation geometry. It does not own game state.
signal layout_changed(snapshot: Dictionary)

enum FrameMode {
	AUTO,
	DESKTOP_4_3,
	MOBILE_FLEX,
}

const DESKTOP_REFERENCE_SIZE := Vector2(960.0, 720.0)
const MOBILE_ASPECT_DEVIATION := 0.25

@export var debug_frame_mode: FrameMode = FrameMode.AUTO
@export var debug_force_touch_capable := false
@export var debug_safe_insets := Vector4.ZERO

@onready var game_frame: Control = %GameFrame
@onready var game_viewport: SubViewport = %GameViewport
@onready var hud: RunnerHUD = %HUD
@onready var frontend_safe_guide: FrontendSafeComposition = %FrontendSafeGuide
@onready var gameplay_runner: RunnerController = $GameFrame/WorldContainer/GameViewport/World/Runner
@onready var placeholder_block: MeshInstance3D = $GameFrame/WorldContainer/GameViewport/World/PlaceholderBlock
@onready var logo_frontend: LogoRevealController = $GameFrame/WorldContainer/GameViewport/World/LogoPresentationRig

var _last_snapshot: Dictionary = {}


func _ready() -> void:
	resized.connect(_refresh_layout)
	GameFlow.state_changed.connect(_on_game_flow_state_changed)
	_on_game_flow_state_changed(&"", GameFlow.current_state)
	_refresh_layout()


func _exit_tree() -> void:
	if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.disconnect(_on_game_flow_state_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_refresh_layout()


## Development and CLI path for deterministic layout previews.
func preview_layout(available_size: Vector2, touch_capable: bool, safe_insets := Vector4.ZERO) -> Dictionary:
	var safe_rect := _safe_rect_for(available_size, safe_insets)
	var mobile_flex := _should_use_mobile_flex(safe_rect.size, touch_capable)
	var frame_rect := safe_rect if mobile_flex else _centered_desktop_frame(safe_rect)
	_apply_layout(frame_rect, mobile_flex, safe_rect)
	return _last_snapshot.duplicate(true)


func get_layout_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


func _refresh_layout() -> void:
	if not is_node_ready():
		return
	var available_size := size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		available_size = get_viewport_rect().size
	var device_safe_rect := _device_safe_rect(available_size)
	var safe_rect := _safe_rect_for(device_safe_rect.size, debug_safe_insets)
	safe_rect.position += device_safe_rect.position
	var mobile_flex := _should_use_mobile_flex(safe_rect.size, _is_touch_capable())
	var frame_rect := safe_rect if mobile_flex else _centered_desktop_frame(safe_rect)
	_apply_layout(frame_rect, mobile_flex, safe_rect)


func _apply_layout(frame_rect: Rect2, mobile_flex: bool, safe_rect: Rect2) -> void:
	game_frame.position = frame_rect.position
	game_frame.size = frame_rect.size
	hud.apply_available_size(frame_rect.size)
	logo_frontend.apply_composition_size(frame_rect.size)
	frontend_safe_guide._layout_guides()
	InputRouter.set_usable_viewport_size(safe_rect.size)
	_last_snapshot = {
		"safe_rect": safe_rect,
		"frame_rect": frame_rect,
		"mobile_flex": mobile_flex,
		"hud_profile": hud.active_profile,
		"frontend_safe_rect": frontend_safe_guide.get_safe_rect(),
	}
	layout_changed.emit(_last_snapshot.duplicate(true))


func _should_use_mobile_flex(safe_size: Vector2, touch_capable: bool) -> bool:
	match debug_frame_mode:
		FrameMode.DESKTOP_4_3:
			return false
		FrameMode.MOBILE_FLEX:
			return true

	if not touch_capable:
		return false
	var aspect := safe_size.x / maxf(safe_size.y, 1.0)
	var desktop_aspect := DESKTOP_REFERENCE_SIZE.x / DESKTOP_REFERENCE_SIZE.y
	var differs_from_desktop := absf(aspect - desktop_aspect) > MOBILE_ASPECT_DEVIATION
	var lacks_reference_space := safe_size.x < DESKTOP_REFERENCE_SIZE.x or safe_size.y < DESKTOP_REFERENCE_SIZE.y
	return differs_from_desktop or lacks_reference_space


func _centered_desktop_frame(safe_rect: Rect2) -> Rect2:
	var scale := minf(safe_rect.size.x / DESKTOP_REFERENCE_SIZE.x, safe_rect.size.y / DESKTOP_REFERENCE_SIZE.y)
	var frame_size := DESKTOP_REFERENCE_SIZE * maxf(scale, 0.01)
	return Rect2(safe_rect.get_center() - frame_size * 0.5, frame_size)


func _safe_rect_for(available_size: Vector2, insets: Vector4) -> Rect2:
	var left := clampf(insets.x, 0.0, available_size.x)
	var top := clampf(insets.y, 0.0, available_size.y)
	var right := clampf(insets.z, 0.0, available_size.x - left)
	var bottom := clampf(insets.w, 0.0, available_size.y - top)
	return Rect2(Vector2(left, top), Vector2(maxf(1.0, available_size.x - left - right), maxf(1.0, available_size.y - top - bottom)))


func _device_safe_rect(available_size: Vector2) -> Rect2:
	var safe_area := DisplayServer.get_display_safe_area()
	var candidate := Rect2(safe_area.position, safe_area.size)
	if candidate.size.x <= 0.0 or candidate.size.y <= 0.0 or candidate.size.x > available_size.x or candidate.size.y > available_size.y:
		return Rect2(Vector2.ZERO, available_size)
	return candidate


func _is_touch_capable() -> bool:
	return debug_force_touch_capable or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _on_game_flow_state_changed(_previous: StringName, next: StringName) -> void:
	var gameplay_visible := next in [
		GameFlow.RUN_INTRO, GameFlow.RUNNING, GameFlow.TRANSITION_READY,
		GameFlow.TOKEN_COLLECTED, GameFlow.SCENARIO_TRANSITION, GameFlow.NEXT_SCENARIO,
		GameFlow.PAUSED, GameFlow.FAILURE_TRANSITION, GameFlow.LAVA_GAME_OVER, GameFlow.TRY_AGAIN,
	]
	gameplay_runner.visible = gameplay_visible
	placeholder_block.visible = gameplay_visible
	hud.visible = gameplay_visible
