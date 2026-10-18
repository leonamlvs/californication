class_name CinematicTransitionFX
extends CanvasLayer

signal completed(profile_id: StringName)
signal cancelled(profile_id: StringName, reason: StringName)

enum Quality {
	AUTO,
	MOBILE_LOW,
	DESKTOP,
	HIGH,
}

const BLOCKED_STATES: Array[StringName] = [
	GameFlow.ISLAND_ATTRACT,
	GameFlow.CHARACTER_SELECT_ENTER,
	GameFlow.CHARACTER_SELECT_ACTIVE,
	GameFlow.RUNNING,
	GameFlow.TRANSITION_READY,
	GameFlow.PAUSED,
	GameFlow.FAILURE_TRANSITION,
	GameFlow.LAVA_GAME_OVER,
]

@onready var back_buffer_copy: BackBufferCopy = %BackBufferCopy
@onready var blur_rect: ColorRect = %BlurRect
@onready var fade_rect: ColorRect = %FadeRect

var active_profile: CinematicFXProfile
var camera: Camera3D
var is_active := false
var using_screen_blur := false
var elapsed := 0.0
var active_sample_count := 0
var _original_fov := 75.0
var _started_state: StringName = &""
var _development_preview := false
var _material: ShaderMaterial
var externally_sampled := false
var _default_shader: Shader


func set_handoff_cover(amount: float) -> void:
	visible = amount > 0.0
	fade_rect.visible = amount > 0.0
	fade_rect.color = Color(0.055, 0.13, 0.22, clampf(amount, 0.0, 1.0))


func _ready() -> void:
	_material = blur_rect.material.duplicate() as ShaderMaterial
	_default_shader = _material.shader
	blur_rect.material = _material
	_neutralize()
	GameFlow.state_changed.connect(_on_game_flow_state_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _exit_tree() -> void:
	if GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.disconnect(_on_game_flow_state_changed)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)
	if is_active:
		cancel(&"tree_exit")


func play(profile: CinematicFXProfile, target_camera: Camera3D = null, quality: Quality = Quality.AUTO, force_fallback := false, development_preview := false) -> bool:
	if profile == null or not profile.is_valid_profile():
		return false
	if not development_preview and BLOCKED_STATES.has(GameFlow.current_state):
		return false
	if is_active:
		cancel(&"replaced")
	active_profile = profile
	_material.shader = profile.screen_shader if profile.screen_shader != null else _default_shader
	if profile.screen_shader != null:
		_material.set_shader_parameter("softness_lod",profile.softness_lod)
	camera = target_camera
	_original_fov = camera.fov if camera != null else 75.0
	_started_state = GameFlow.current_state
	_development_preview = development_preview
	elapsed = 0.0
	active_sample_count = _samples_for(profile, quality)
	using_screen_blur = profile.blur_enabled \
		and profile.fallback_policy != CinematicFXProfile.FallbackPolicy.FORCE_CAMERA_OVERLAY \
		and not force_fallback
	back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if using_screen_blur else BackBufferCopy.COPY_MODE_DISABLED
	blur_rect.visible = using_screen_blur
	fade_rect.visible = true
	_material.set_shader_parameter("blur_center", profile.radial_blur_center)
	_material.set_shader_parameter("sample_count", active_sample_count)
	_material.set_shader_parameter("blur_strength", 0.0)
	_material.set_shader_parameter("effect_mix", 0.0)
	fade_rect.color = Color(profile.overlay_color, 0.0)
	is_active = true
	visible = true
	set_process(true)
	return true


func _process(delta: float) -> void:
	if not is_active or active_profile == null or externally_sampled:
		return
	advance_for_test(delta)


func advance_for_test(delta: float) -> void:
	if not is_active or active_profile == null or delta <= 0.0 or externally_sampled:
		return
	elapsed = minf(elapsed + delta, active_profile.duration)
	var normalized := clampf(elapsed / active_profile.duration, 0.0, 1.0)
	var envelope := sin(normalized * PI)
	if using_screen_blur:
		_material.set_shader_parameter("blur_strength", active_profile.radial_blur_strength * envelope)
		_material.set_shader_parameter("effect_mix", envelope)
	if camera != null:
		camera.fov = _original_fov + active_profile.fov_kick * envelope
	var fade_color := active_profile.overlay_color
	fade_color.a *= active_profile.fade_amount * envelope
	fade_rect.color = fade_color
	if is_equal_approx(normalized, 1.0):
		var completed_id := active_profile.id
		_neutralize()
		completed.emit(completed_id)


func begin_external(profile: CinematicFXProfile, quality: Quality = Quality.AUTO, development_preview := false) -> bool:
	# External consumers own their camera and clock. Existing play() consumers
	# retain their FOV/envelope/cancellation behavior.
	if not play(profile, null, quality, false, development_preview):
		return false
	externally_sampled = true
	set_process(false)
	return true


func sample_external(progress: float, envelope_override := -1.0) -> void:
	if not externally_sampled or not is_active or active_profile == null:
		return
	var normalized := clampf(progress, 0.0, 1.0)
	elapsed = normalized * active_profile.duration
	var envelope := sin(normalized * PI) if envelope_override < 0.0 else clampf(envelope_override, 0.0, 1.0)
	if using_screen_blur:
		_material.set_shader_parameter("blur_strength", active_profile.radial_blur_strength * envelope)
		_material.set_shader_parameter("effect_mix", envelope)
		blur_rect.visible = envelope > 0.0
		back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if envelope > 0.0 else BackBufferCopy.COPY_MODE_DISABLED
	var color := active_profile.overlay_color
	color.a *= active_profile.fade_amount * envelope
	fade_rect.color = color


func cancel(reason: StringName = &"cancelled") -> void:
	if not is_active:
		_neutralize()
		return
	var cancelled_id := active_profile.id if active_profile != null else &""
	_neutralize()
	cancelled.emit(cancelled_id, reason)


func shader_parameter(name: StringName) -> Variant:
	return _material.get_shader_parameter(name) if _material != null else null


func _samples_for(profile: CinematicFXProfile, quality: Quality) -> int:
	match quality:
		Quality.MOBILE_LOW:
			return profile.mobile_sample_count
		Quality.DESKTOP:
			return profile.desktop_sample_count
		Quality.HIGH:
			return 12
	return profile.mobile_sample_count if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") else profile.desktop_sample_count


func _neutralize() -> void:
	if camera != null:
		camera.fov = _original_fov
	if _material != null:
		_material.set_shader_parameter("blur_strength", 0.0)
		_material.set_shader_parameter("effect_mix", 0.0)
		_material.set_shader_parameter("sample_count", 2)
	if is_instance_valid(fade_rect):
		fade_rect.color = Color.TRANSPARENT
		fade_rect.visible = false
	if is_instance_valid(blur_rect):
		blur_rect.visible = false
	if is_instance_valid(back_buffer_copy):
		back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	is_active = false
	using_screen_blur = false
	elapsed = 0.0
	active_sample_count = 0
	set_process(false)
	visible = false
	active_profile = null
	camera = null
	_started_state = &""
	_development_preview = false
	externally_sampled = false


func _on_game_flow_state_changed(previous: StringName, _next: StringName) -> void:
	if is_active and not _development_preview and previous == _started_state:
		cancel(&"state_exit")


func _on_viewport_size_changed() -> void:
	if is_active and not externally_sampled:
		cancel(&"resize")


func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT) and is_active and not externally_sampled:
		cancel(&"focus_lost")
