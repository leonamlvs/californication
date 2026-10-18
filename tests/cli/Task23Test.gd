extends Node

const ISLAND_FRONTEND_SCENE := preload("res://frontend/island/IslandFrontend.tscn")
const SEQUENCE_SCENE := preload("res://frontend/island/live/IslandProductionSequence.tscn")
const TOUCH_SURFACE_SCRIPT := preload("res://ui/menus/IslandAttractTouchSurface.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameFlow.development_jump_to_state(GameFlow.BOOT)
	GameFlow.intro_seen = false
	var frontend := ISLAND_FRONTEND_SCENE.instantiate() as IslandFrontendController
	add_child(frontend)
	var sequence := SEQUENCE_SCENE.instantiate() as IslandProductionSequence
	add_child(sequence)
	await get_tree().process_frame
	sequence.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	sequence.size = Vector2(960, 720)
	sequence.scene_ready = true # Deterministic headless fixture has no presentation window.
	sequence._focused = true
	frontend.set_process(false)

	_assert(GameFlow.begin_session(), "Session did not enter LOADING.")
	_assert(frontend.loading_overlay.visible and frontend.frontend_camera.current, "Loading presentation or frontend camera was not established.")
	_assert(is_equal_approx(frontend.loading_duration, 2.0), "Reference loading presentation does not last exactly two active seconds.")
	frontend.loading_overlay.size = Vector2(960, 720)
	var loading_snapshot := frontend.loading_overlay.get_visual_snapshot()
	_assert(is_zero_approx(loading_snapshot.fill_fraction) and loading_snapshot.revealed_image_count == 0, "Loading did not begin empty.")
	_assert(loading_snapshot.image_frame_rects.size() == 8, "Loading presentation does not expose all eight image frames.")
	_assert(_rect_is_near(loading_snapshot.bar_outer_rect, Rect2(58, 249, 838, 43)), "Loading bar does not match the 960x720 reference geometry: %s." % loading_snapshot.bar_outer_rect)
	_assert(_rect_is_near(loading_snapshot.text_bounds, Rect2(80, 195, 374, 40)), "NOW LOADING bounds do not match the reference geometry.")
	_assert(_rect_is_near(loading_snapshot.image_frame_rects[0], Rect2(55, 409, 82, 82)), "First loading image frame does not match the reference geometry.")
	_assert(_rect_is_near(loading_snapshot.image_frame_rects[7], Rect2(817, 373, 82, 82)), "Last loading image frame does not match the reference geometry.")
	_check_loading_background(frontend.loading_overlay, loading_snapshot)
	for reveal_index: int in frontend.loading_overlay.IMAGE_REVEAL_FRAMES.size():
		var reveal_frame: float = frontend.loading_overlay.IMAGE_REVEAL_FRAMES[reveal_index]
		frontend.loading_overlay.set_progress((reveal_frame - 11.01) / 59.0 * 0.95)
		_assert(frontend.loading_overlay.revealed_image_count == reveal_index, "Image %d appeared before its measured reference frame." % (reveal_index + 1))
		frontend.loading_overlay.set_progress((reveal_frame - 11.0) / 59.0 * 0.95)
		_assert(frontend.loading_overlay.revealed_image_count == reveal_index + 1, "Image %d did not appear on its measured reference frame." % (reveal_index + 1))

	_assert(_seek_matches(frontend.loading_overlay, 20.0, 2, (404.0 - 221.0) / 833.0), "Frame 20 loading state does not match the measured reference.")
	_assert(_seek_matches(frontend.loading_overlay, 40.0, 4, (630.0 - 221.0) / 833.0), "Frame 40 loading state does not match the measured reference.")
	_assert(_seek_matches(frontend.loading_overlay, 60.0, 7, (934.0 - 221.0) / 833.0), "Frame 60 loading state does not match the measured reference.")
	_assert(_seek_matches(frontend.loading_overlay, 70.0, 8, (1040.0 - 221.0) / 833.0), "Frame 70 loading state does not match the measured reference.")
	_assert(_plateau_matches(frontend.loading_overlay, 30.0, 39.0), "First measured loading plateau was not preserved.")
	_assert(_plateau_matches(frontend.loading_overlay, 43.0, 52.0), "Second measured loading plateau was not preserved.")
	_assert(_plateau_matches(frontend.loading_overlay, 62.0, 68.0), "Third measured loading plateau was not preserved.")
	frontend.loading_overlay.set_progress(0.975)
	_assert(is_equal_approx(frontend.loading_overlay.fill_fraction, 1.0), "Loading bar did not reach 100 percent at 1.95 seconds.")
	var fill_before_resize := frontend.loading_overlay.fill_fraction
	var images_before_resize := frontend.loading_overlay.revealed_image_count
	_assert(_composition_fits(frontend.loading_overlay), "Loading composition did not preserve centered 4:3 fitting.")
	_assert(is_equal_approx(frontend.loading_overlay.fill_fraction, fill_before_resize) and frontend.loading_overlay.revealed_image_count == images_before_resize, "Live resize changed loading progress.")

	GameFlow.development_jump_to_state(GameFlow.BOOT)
	_assert(GameFlow.begin_session(), "Loading could not be re-entered for focus validation.")
	_assert(is_zero_approx(frontend.loading_elapsed) and is_zero_approx(frontend.loading_overlay.fill_fraction) and frontend.loading_overlay.revealed_image_count == 0, "Re-entering loading did not reset its visual state.")
	var reentry_background := frontend.loading_overlay.get_visual_snapshot()
	_assert(reentry_background.background_viewport_update_mode == SubViewport.UPDATE_ONCE and reentry_background.background_texture_path.ends_with("art/loading/california-map.svg"), "Re-entering loading did not request a cached SVG render.")
	frontend._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	frontend.advance_for_test(0.5)
	_assert(is_zero_approx(frontend.loading_elapsed), "Loading advanced while the application was unfocused.")
	frontend._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_assert(not GameFlow.handle_intent(InputRouter.INTENT_CONFIRM), "Confirm skipped the unskippable loading presentation.")
	frontend.advance_for_test(1.99)
	_assert(GameFlow.current_state == GameFlow.LOADING and is_equal_approx(frontend.loading_overlay.fill_fraction, 1.0), "Loading did not hold its full bar through 1.99 seconds.")
	frontend.advance_for_test(100.0)
	_assert(GameFlow.current_state == GameFlow.ISLAND_INTRO, "Loading did not hand off automatically to Island Intro.")
	_assert(frontend.loading_overlay.get_visual_snapshot().background_viewport_update_mode == SubViewport.UPDATE_DISABLED, "Hidden loading background kept rendering after handoff.")
	_assert(frontend.loading_overlay.get_visual_snapshot().background_effect_update_modes == [SubViewport.UPDATE_DISABLED, SubViewport.UPDATE_DISABLED], "Hidden loading blur passes kept rendering after handoff.")
	_assert(sequence.intro_play_count == 1 and sequence.visible, "Production video/live intro did not start once after loading.")
	_assert(not frontend.visible and frontend.active_group_count() == 0, "Obsolete staged geometry remained visible during video intro.")
	_assert(sequence.profile.camera_profile.video_end > 3.47 and sequence.profile.camera_profile.settle_end < 4.14, "Approved transition profile was not loaded.")
	_assert(sequence.study.ocean.mesh is PlaneMesh and sequence.study.island_asset != null, "Production island and flat ocean resources were not mounted.")
	_assert(sequence.poster.visible and not sequence.prompt.visible, "Video first-frame poster or intro prompt state was wrong.")
	_assert(sequence.player.state in [&"preparing", &"ready", &"playing"], "Runtime video did not begin preparing during loading.")
	sequence._started = true
	sequence.clock.time = 3.37
	sequence._apply(3.37)
	var held_size: float = sequence.study.camera.size
	var held_water: float = sequence.study.water_time
	for playback_state: StringName in [&"buffering", &"error", &"gesture_required"]:
		sequence.player.state = playback_state
		sequence._process(0.5)
		_assert(is_equal_approx(sequence.clock.time, 3.37) and is_equal_approx(sequence.study.camera.size, held_size) and is_equal_approx(sequence.study.water_time, held_water), "Interrupted production playback advanced the coordinated presentation.")
	sequence._focused = false
	sequence._process(0.5)
	_assert(is_equal_approx(sequence.clock.time, 3.37), "Focus loss advanced the production presentation.")
	sequence._focused = true
	sequence.development_skip_stage()
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT and GameFlow.intro_seen, "Video/live completion did not enter one-shot attract.")
	_assert(sequence.player.state == &"released" and sequence.prompt.visible, "Attract did not release video and show its prompt.")
	var camera_size: float = sequence.study.camera.size
	sequence._process(0.01) # Consume the resumed-focus tick without hidden elapsed time.
	sequence._process(1.0)
	_assert(is_equal_approx(sequence.study.camera.size, camera_size) and sequence.clock.time > sequence.profile.camera_profile.settle_end, "Attract reset the final camera or stopped its clock.")
	var rotation_before: float = sequence.study.pivot.rotation.y
	sequence._process(31.0)
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT and not is_equal_approx(rotation_before, sequence.study.pivot.rotation.y), "Indefinite attract rotation did not continue.")
	for viewport_size: Vector2 in [Vector2(960, 720), Vector2(844, 390), Vector2(360, 640)]:
		var fitted := IslandVideoPlayback.fit_picture(Rect2(Vector2.ZERO, viewport_size))
		_assert(is_equal_approx(fitted.size.x / fitted.size.y, 4.0 / 3.0), "Island picture lost its fixed 4:3 framing.")
	var touch_surface := Control.new()
	touch_surface.set_script(TOUCH_SURFACE_SCRIPT)
	add_child(touch_surface)
	await get_tree().process_frame
	touch_surface._gui_input(_touch_event(Vector2(0, 620)))
	touch_surface._gui_input(_touch_event(Vector2(0, 620)))
	_assert(GameFlow.current_state == GameFlow.LOGO_REVEAL, "Whole-screen touch did not advance Attract exactly once.")
	_assert(frontend.blue_handoff_is_ready and sequence.cover.visible, "Blue logo handoff did not cover the island.")
	sequence._process(0.31)
	_assert(not sequence.visible and sequence.player.state == &"released", "Covered logo transition did not release the presentation.")
	GameFlow.development_jump_to_state(GameFlow.ISLAND_INTRO)
	_assert(sequence.intro_play_count == 2 and sequence.poster.visible, "Development replay did not restart the video intro.")
	sequence.development_skip_stage()
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT, "Development skip did not reach Attract.")
	touch_surface.queue_free()
	sequence.queue_free()
	frontend.queue_free()
	if failures.is_empty():
		print("TASK23_PASS")
		get_tree().quit(0)
	else:
		for failure_message: String in failures:
			push_error(failure_message)
		get_tree().quit(1)


func _check_loading_background(presentation: LoadingPresentation, baseline: Dictionary) -> void:
	_assert(baseline.background_viewport_size == Vector2i(960, 720), "Loading SVG render target is not full logical resolution.")
	_assert(baseline.background_all_targets_2d and presentation.background_map.find_children("*", "Node3D", true, false).is_empty(), "Loading SVG retained a 3D renderer or model.")
	_assert(baseline.background_texture_path.ends_with("art/loading/california-map.svg") and not baseline.background_using_fallback, "Loading did not use the supplied SVG.")
	_assert(baseline.background_texture_size.x >= 1224 and baseline.background_texture_size.y >= 936, "Loading SVG import is too small for clean fitting.")
	_assert(baseline.background_effect_target_sizes == [Vector2i(960, 720), Vector2i(960, 720)], "Loading blur targets changed logical resolution.")
	_assert(baseline.background_effect_worlds_isolated, "SVG and blur passes share their 2D world with one another or the game.")
	_assert(baseline.background_effect_update_modes == [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_ONCE], "Loading did not schedule both cached blur passes.")
	var generation_before_seek: int = baseline.background_render_generation
	presentation.set_progress(0.5)
	presentation.size = Vector2(844, 390)
	_assert(presentation.get_visual_snapshot().background_render_generation == generation_before_seek, "Seeking or resizing reran the static loading background.")
	presentation.size = Vector2(960, 720)
	presentation.set_progress(0.0)
	presentation.background_map.set_loading_active(false)
	_assert(presentation.get_visual_snapshot().background_effect_update_modes == [SubViewport.UPDATE_DISABLED, SubViewport.UPDATE_DISABLED], "Hidden blur targets kept rendering.")
	presentation.background_map.set_loading_active(true)
	_assert(presentation.get_visual_snapshot().background_render_generation > generation_before_seek, "Loading re-entry did not request a fresh background generation.")
	var progress_before_refresh := presentation.normalized_time
	var initial_radius := presentation.background_halo_radius
	presentation.background_halo_radius = 16.0
	presentation.refresh_background()
	_assert(is_equal_approx(presentation.normalized_time, progress_before_refresh), "Appearance refresh changed loading progress.")
	var broad_pairs: PackedVector2Array = presentation.background_map.horizontal_pass.material.get_shader_parameter("broad_pairs")
	_assert(broad_pairs[7].x <= 16.0 and broad_pairs[8].is_zero_approx(), "Appearance refresh did not regenerate the configured Gaussian support.")
	presentation.background_halo_radius = initial_radius
	var original_softness := presentation.background_shadow_softness
	presentation.background_shadow_softness = 4.0
	presentation.refresh_background()
	var narrow_pairs: PackedVector2Array = presentation.background_map.horizontal_pass.material.get_shader_parameter("narrow_pairs")
	_assert(narrow_pairs[5].x <= 12.0 and narrow_pairs[6].is_zero_approx(), "Shadow softness did not update its independent Gaussian support.")
	presentation.background_shadow_softness = original_softness
	presentation.refresh_background()
	_assert(_rect_near_within(baseline.background_projected_bounds, Rect2(145, 82, 714, 546), 1.0), "California SVG did not fit its reference subject rectangle: %s." % baseline.background_projected_bounds)
	var material := presentation.background_map.texture_rect.material as ShaderMaterial
	_assert(material.get_shader_parameter("shadow_offset_px") == Vector2(2, 3) and is_equal_approx(material.get_shader_parameter("shadow_opacity"), presentation.background_shadow_opacity), "Subtle shadow settings did not reach the composite.")
	var fixture := Image.create(240, 120, false, Image.FORMAT_RGBA8)
	fixture.fill(Color(0.8, 0.6, 0.9, 1.0))
	presentation.background_texture = ImageTexture.create_from_image(fixture)
	presentation.background_map_scale = 0.8
	presentation.background_map_offset = Vector2(10.0, -5.0)
	presentation.refresh_background()
	var replaced := presentation.get_visual_snapshot()
	_assert(not replaced.background_using_fallback and replaced.background_texture_size == Vector2(240, 120), "Replacement texture was not assigned.")
	_assert(replaced.background_projected_bounds.size.distance_to(Vector2(574.4, 287.2)) < 0.1, "Replacement texture was stretched or ignored Inspector scale.")
	_assert(replaced.background_projected_bounds.get_center().distance_to(Vector2(512.0, 350.0)) < 0.1, "Replacement texture ignored its logical-pixel offset.")
	presentation.background_texture = null
	presentation.refresh_background()
	var fallback := presentation.get_visual_snapshot()
	_assert(fallback.background_using_fallback and fallback.background_texture_path.ends_with("art/loading/california-map.svg"), "Missing texture did not fall back to the bundled SVG.")
	presentation.background_texture = presentation.DEFAULT_BACKGROUND_TEXTURE
	presentation.background_map_scale = 1.0
	presentation.background_map_offset = Vector2.ZERO
	presentation.refresh_background()
	_assert(_rect_is_near(presentation.get_visual_snapshot().background_projected_bounds, baseline.background_projected_bounds), "Restoring the default SVG did not restore its bounds.")


func _touch_event(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = true
	return event


func _seek_matches(presentation: LoadingPresentation, source_frame: float, expected_images: int, expected_fill: float) -> bool:
	presentation.set_progress((source_frame - 11.0) / 59.0 * 0.95)
	return presentation.revealed_image_count == expected_images \
		and presentation.highlighted_image_index == expected_images - 1 \
		and is_equal_approx(presentation.fill_fraction, expected_fill)


func _plateau_matches(presentation: LoadingPresentation, first_frame: float, last_frame: float) -> bool:
	presentation.set_progress((first_frame - 11.0) / 59.0 * 0.95)
	var first_fill := presentation.fill_fraction
	presentation.set_progress((last_frame - 11.0) / 59.0 * 0.95)
	return is_equal_approx(first_fill, presentation.fill_fraction)


func _composition_fits(presentation: LoadingPresentation) -> bool:
	for check: Dictionary in [
		{"size": Vector2(960, 720), "rect": Rect2(0, 0, 960, 720)},
		{"size": Vector2(1280, 720), "rect": Rect2(160, 0, 960, 720)},
		{"size": Vector2(844, 390), "rect": Rect2(162, 0, 520, 390)},
		{"size": Vector2(360, 640), "rect": Rect2(0, 185, 360, 270)},
	]:
		presentation.size = check.size
		if not _rect_is_near(presentation.get_visual_snapshot().composition_rect, check.rect):
			return false
	presentation.size = Vector2(960, 720)
	return true


func _rect_is_near(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= 0.1 and actual.size.distance_to(expected.size) <= 0.1


func _rect_near_within(actual: Rect2, expected: Rect2, tolerance: float) -> bool:
	return actual.position.distance_to(expected.position) <= tolerance and actual.size.distance_to(expected.size) <= tolerance


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
