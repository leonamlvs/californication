extends Node

const ISLAND_FRONTEND_SCENE := preload("res://frontend/island/IslandFrontend.tscn")
const FLOW_PLACEHOLDER_SCENE := preload("res://ui/menus/GameFlowPlaceholder.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameFlow.development_jump_to_state(GameFlow.BOOT)
	GameFlow.intro_seen = false
	var frontend := ISLAND_FRONTEND_SCENE.instantiate() as IslandFrontendController
	add_child(frontend)
	await get_tree().process_frame
	frontend.set_process(false)

	_assert(GameFlow.begin_session(), "Session did not enter LOADING.")
	_assert(frontend.loading_overlay.visible and frontend.frontend_camera.current, "Loading presentation or frontend camera was not established.")
	frontend.advance_for_test(frontend.loading_duration)
	_assert(GameFlow.current_state == GameFlow.ISLAND_INTRO, "Loading did not hand off automatically to Island Intro.")
	_assert(frontend.intro_play_count == 1 and frontend.intro_stage_index == 0, "Island Intro did not start exactly once at close vegetation.")
	_assert(frontend.active_group_count() == 1 and frontend.close_vegetation.visible, "Intro did not isolate the close-vegetation group.")
	_assert(_placeholder_scale_is_readable(frontend), "Placeholder palm/car proportions do not match the frontend scale contract.")
	_assert(_is_california_silhouette(frontend), "Island placeholder does not expose a replaceable California polygon silhouette.")

	frontend.cinematic_quality = CinematicTransitionFX.Quality.MOBILE_LOW
	frontend.advance_for_test(frontend.intro_duration * 0.25)
	_assert(frontend.intro_stage_index == 1 and frontend.city_roads.visible, "Vegetation-to-city LOD swap did not occur.")
	_assert(frontend.cinematic_fx.active_sample_count == frontend.intro_fx_profile.mobile_sample_count, "Island pullback did not select reduced mobile effect quality.")
	frontend.advance_for_test(frontend.intro_duration * 0.26)
	_assert(frontend.intro_stage_index == 2 and frontend.landscape.visible, "City-to-landscape LOD swap did not occur.")
	frontend.advance_for_test(frontend.intro_duration * 0.23)
	_assert(frontend.intro_stage_index == 3 and frontend.island_pivot.visible, "Landscape-to-island LOD swap did not occur.")
	frontend.advance_for_test(frontend.intro_duration)
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT and GameFlow.intro_seen, "Intro completion did not enter attract or record the one-shot session history.")
	_assert(frontend.intro_play_count == 1 and frontend.lod_swap_count == 3, "Intro replayed or performed an unexpected number of hidden swaps.")
	_assert(not frontend.cinematic_fx.is_active, "Cinematic effect remained active at Island Attract.")

	var rotation_before := frontend.island_pivot.rotation.y
	frontend.advance_for_test(180.0)
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT, "Island Attract advanced itself instead of waiting indefinitely.")
	_assert(not is_equal_approx(rotation_before, frontend.island_pivot.rotation.y), "Island did not rotate while attract waited.")
	_assert(frontend.attract_prompt.visible and frontend.active_group_count() == 1, "Attract prompt/island composition was not stable.")

	for viewport_size: Vector2 in [Vector2(960, 720), Vector2(844, 390), Vector2(360, 640)]:
		var snapshot := frontend.composition_snapshot(viewport_size)
		_assert(snapshot.safe_readable and snapshot.focal_point.x >= 0.18 and snapshot.focal_point.x <= 0.82, "Island focal subject leaves the safe composition at %s." % viewport_size)
	_assert(frontend.composition_snapshot(Vector2(360, 640)).distance_scale > 1.0, "Narrow mobile composition did not pull the camera back.")

	var placeholder := FLOW_PLACEHOLDER_SCENE.instantiate()
	add_child(placeholder)
	await get_tree().process_frame
	placeholder.touch_confirm_surface._gui_input(_touch_event(Vector2(120, 180)))
	placeholder.touch_confirm_surface._gui_input(_touch_event(Vector2(120, 180)))
	_assert(GameFlow.current_state == GameFlow.LOGO_REVEAL, "Ordinary screen touch did not advance Island Attract exactly once.")
	_assert(frontend.blue_handoff_is_ready and frontend.active_group_count() == 0 and frontend.ocean.visible, "Island departure did not leave a mostly blue hidden-loading handoff frame.")

	frontend.development_replay_intro()
	_assert(GameFlow.current_state == GameFlow.ISLAND_INTRO and frontend.intro_play_count == 2 and frontend.intro_stage_index == 0, "Development replay override did not restart the intro deterministically.")
	frontend.development_skip_stage()
	_assert(frontend.intro_stage_index == 1, "Development stage skip did not reach the next authored group.")
	frontend.development_enter_attract()
	_assert(GameFlow.current_state == GameFlow.ISLAND_ATTRACT, "Development direct-attract shortcut failed.")

	placeholder.queue_free()
	frontend.queue_free()
	if failures.is_empty():
		print("TASK23_PASS")
		get_tree().quit(0)
	else:
		for failure_message: String in failures:
			push_error(failure_message)
		get_tree().quit(1)


func _placeholder_scale_is_readable(frontend: IslandFrontendController) -> bool:
	var palm := frontend.get_node("CloseVegetation/PalmLeftTrunk") as MeshInstance3D
	var car := frontend.get_node("CityRoads/CarA") as MeshInstance3D
	return palm.mesh is CylinderMesh and is_equal_approx((palm.mesh as CylinderMesh).height, 9.0) \
		and car.mesh is BoxMesh and is_equal_approx((car.mesh as BoxMesh).size.z, 4.5)


func _is_california_silhouette(frontend: IslandFrontendController) -> bool:
	var surface := frontend.island_pivot.get_node("CaliforniaSurface") as CSGPolygon3D
	return surface != null and surface.polygon.size() >= 10


func _touch_event(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = true
	return event


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
