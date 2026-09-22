extends Node

const FX_SCENE := preload("res://presentation/cinematic_fx/CinematicTransitionFX.tscn")
const ISLAND_PROFILE := preload("res://data/cinematic_fx/island_pullback.tres")
const RUN_PROFILE := preload("res://data/cinematic_fx/run_intro_push.tres")

var failures: Array[String] = []
var completed_ids: Array[StringName] = []
var cancellation_reasons: Array[StringName] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var camera := Camera3D.new()
	camera.fov = 68.0
	add_child(camera)
	var fx := FX_SCENE.instantiate() as CinematicTransitionFX
	add_child(fx)
	await get_tree().process_frame
	fx.completed.connect(func(profile_id: StringName) -> void: completed_ids.append(profile_id))
	fx.cancelled.connect(func(_profile_id: StringName, reason: StringName) -> void: cancellation_reasons.append(reason))

	_assert(ISLAND_PROFILE.is_valid_profile() and RUN_PROFILE.is_valid_profile(), "Task 22 profiles are invalid.")
	_assert(ISLAND_PROFILE.mobile_sample_count < ISLAND_PROFILE.desktop_sample_count, "Mobile profile does not reduce shader samples.")
	_assert(_shader_api_is_compatibility_safe(), "Shader does not use the verified Godot 4 screen-texture CanvasItem API.")

	GameFlow.development_jump_to_state(GameFlow.ISLAND_INTRO)
	_assert(fx.play(ISLAND_PROFILE, camera, CinematicTransitionFX.Quality.DESKTOP), "Desktop screen-blur effect did not start.")
	_assert(fx.using_screen_blur and fx.active_sample_count == ISLAND_PROFILE.desktop_sample_count, "Desktop quality did not select the profiled screen-blur sample count.")
	_assert(fx.back_buffer_copy.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT, "Fullscreen back-buffer copy was not enabled.")
	fx.advance_for_test(ISLAND_PROFILE.duration * 0.5)
	_assert(float(fx.shader_parameter(&"blur_strength")) > 0.0 and float(fx.shader_parameter(&"effect_mix")) > 0.0, "Radial blur did not reach an active midpoint.")
	_assert(not is_equal_approx(camera.fov, 68.0) and fx.fade_rect.color.a > 0.0, "Camera/FOV/fade cues did not animate with blur timing.")
	fx.advance_for_test(ISLAND_PROFILE.duration * 0.5)
	_assert(completed_ids == [ISLAND_PROFILE.id], "Effect did not complete exactly once.")
	_assert(_is_neutral(fx, camera, 68.0), "Completion did not restore neutral material, camera, and copy state.")

	_assert(fx.play(ISLAND_PROFILE, camera, CinematicTransitionFX.Quality.MOBILE_LOW), "Mobile quality did not start.")
	_assert(fx.active_sample_count == ISLAND_PROFILE.mobile_sample_count, "Mobile quality did not select its reduced profile count.")
	fx.cancel(&"manual")
	_assert(cancellation_reasons.back() == &"manual" and _is_neutral(fx, camera, 68.0), "Explicit cancellation did not neutralize the effect.")

	_assert(fx.play(RUN_PROFILE, camera, CinematicTransitionFX.Quality.HIGH, true), "Forced fallback did not start.")
	_assert(not fx.using_screen_blur and fx.back_buffer_copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "Fallback retained the screen-texture path.")
	fx.advance_for_test(RUN_PROFILE.duration * 0.5)
	_assert(not is_equal_approx(camera.fov, 68.0) and fx.fade_rect.color.a > 0.0, "Fallback did not preserve timed FOV/overlay cues.")
	fx.advance_for_test(RUN_PROFILE.duration * 0.5)
	_assert(completed_ids.back() == RUN_PROFILE.id and _is_neutral(fx, camera, 68.0), "Fallback did not finish on the profile duration.")

	fx.play(ISLAND_PROFILE, camera)
	fx._on_viewport_size_changed()
	_assert(cancellation_reasons.back() == &"resize" and _is_neutral(fx, camera, 68.0), "Resize did not safely cancel and neutralize.")
	fx.play(ISLAND_PROFILE, camera)
	fx._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_assert(cancellation_reasons.back() == &"focus_lost" and _is_neutral(fx, camera, 68.0), "Focus loss did not safely cancel and neutralize.")

	GameFlow.development_jump_to_state(GameFlow.LOGO_REVEAL)
	_assert(fx.play(ISLAND_PROFILE, camera), "State-exit fixture effect did not start.")
	GameFlow.development_jump_to_state(GameFlow.CHARACTER_SELECT_ENTER)
	_assert(cancellation_reasons.back() == &"state_exit" and _is_neutral(fx, camera, 68.0), "Owning state exit did not neutralize the effect.")

	for blocked_state: StringName in [GameFlow.CHARACTER_SELECT_ACTIVE, GameFlow.RUNNING]:
		GameFlow.development_jump_to_state(blocked_state)
		_assert(not fx.play(ISLAND_PROFILE, camera), "Effect started in blocked state %s." % blocked_state)
		_assert(_is_neutral(fx, camera, 68.0), "Effect remained active in blocked state %s." % blocked_state)
	_assert(fx.play(ISLAND_PROFILE, camera, CinematicTransitionFX.Quality.DESKTOP, false, true), "DevHarness preview override did not permit direct gameplay-state inspection.")
	fx.cancel(&"test_cleanup")

	if failures.is_empty():
		print("TASK22_PASS")
		get_tree().quit(0)
	else:
		for failure_message: String in failures:
			push_error(failure_message)
		get_tree().quit(1)


func _shader_api_is_compatibility_safe() -> bool:
	var source := FileAccess.get_file_as_string("res://presentation/cinematic_fx/cinematic_zoom_blur.gdshader")
	return source.contains("shader_type canvas_item") \
		and source.contains("hint_screen_texture") \
		and source.contains("SCREEN_UV") \
		and not source.contains("texture(SCREEN_TEXTURE")


func _is_neutral(fx: CinematicTransitionFX, camera: Camera3D, expected_fov: float) -> bool:
	return not fx.is_active \
		and not fx.visible \
		and not fx.blur_rect.visible \
		and not fx.fade_rect.visible \
		and fx.back_buffer_copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED \
		and is_zero_approx(float(fx.shader_parameter(&"blur_strength"))) \
		and is_zero_approx(float(fx.shader_parameter(&"effect_mix"))) \
		and is_equal_approx(camera.fov, expected_fov)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
